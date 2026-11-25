package fcnv3

import (
	"bytes"
	"context"
	"errors"
	"io"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/metacubex/quic-go"
	"github.com/metacubex/quic-go/quicvarint"
)

func TestHTTP3ConnectWithDownlinkOptions(t *testing.T) {
	for _, mode := range []struct {
		name     string
		adaptive bool
		padding  bool
	}{
		{"defaults", false, false},
		{"adaptive only", true, false},
		{"padding only", false, true},
		{"adaptive and padding", true, true},
	} {
		t.Run(mode.name, func(t *testing.T) {
			target, _ := startTestEcho(t)
			observed := make(chan *serverConnection, 1)
			_, config := startTestServerObservingConnection(t, target, func(conn *serverConnection) {
				select {
				case observed <- conn:
				default:
				}
			}, func(serverConfig *ServerConfig) {
				serverConfig.AdaptiveWrites = mode.adaptive
				serverConfig.Padding = mode.padding
			})
			client := newTestClient(t, config)
			ctx, cancel := context.WithTimeout(t.Context(), 10*time.Second)
			defer cancel()
			pooled, err := client.acquire(ctx)
			if err != nil {
				t.Fatal(err)
			}
			conn := dialTestStream(t, ctx, client, target)
			checkEchoAndHalfClose(t, conn, []byte("first interactive response"))
			var serverConn *serverConnection
			select {
			case serverConn = <-observed:
			case <-ctx.Done():
				t.Fatal("server did not install the authenticated connection context")
			}
			used := int(serverConn.padding.used.Load())
			if mode.padding && (used < downlinkPaddingMinFrameBytes || used > downlinkPaddingMaxFrameBytes) {
				t.Fatalf("first CONNECT used %d bytes of padding, want %d to %d", used, downlinkPaddingMinFrameBytes, downlinkPaddingMaxFrameBytes)
			}
			if !mode.padding && used != 0 {
				t.Fatalf("disabled padding used %d bytes", used)
			}
			t.Logf("first CONNECT used %d serialized padding bytes", used)

			for range 16 {
				conn := dialTestStream(t, ctx, client, target)
				checkEchoAndHalfClose(t, conn, []byte("interactive response"))
				conn.Close()
			}
			used = int(serverConn.padding.used.Load())
			if mode.padding && (used > downlinkPaddingConnectionCap || used <= downlinkPaddingConnectionCap-downlinkPaddingMinFrameBytes) {
				t.Fatalf("pooled connection used %d bytes of padding, cap %d", used, downlinkPaddingConnectionCap)
			}
			if !mode.padding && used != 0 {
				t.Fatalf("pooled connection with padding disabled used %d bytes", used)
			}
			t.Logf("pooled connection used %d serialized padding bytes", used)

			bulk := dialTestStream(t, ctx, client, target)
			checkEchoAndHalfClose(t, bulk, bytes.Repeat([]byte("bulk"), adaptiveBulkSize/2))
			if after := int(serverConn.padding.used.Load()); after != used {
				t.Fatalf("bulk stream used %d more bytes of padding", after-used)
			}
			if current, err := client.acquire(ctx); err != nil || current != pooled {
				t.Fatalf("CONNECT requests changed the pooled HTTP/3 connection: %v", err)
			}
		})
	}
}

type testReadFunc func([]byte) (int, error)

func (f testReadFunc) Read(p []byte) (int, error) { return f(p) }

type testWriteFunc func([]byte) (int, error)

func (f testWriteFunc) Write(p []byte) (int, error) { return f(p) }

func TestAdaptiveDownlinkForwardsBeforeNextRead(t *testing.T) {
	steps := []struct {
		capacity int
		size     int
	}{
		{adaptiveInteractiveSize, 1},
		{adaptiveInteractiveSize, adaptiveInteractiveSize},
		{adaptiveInteractiveSize, 17},
		{adaptiveInteractiveSize, adaptiveInteractiveSize},
		{adaptiveInteractiveSize, adaptiveInteractiveSize},
		{adaptiveBulkSize, adaptiveBulkSize},
		{adaptiveBulkSize, 3},
		{adaptiveBulkSize, 2},
		{adaptiveInteractiveSize, 7},
	}
	var output, expected bytes.Buffer
	i := 0
	r := testReadFunc(func(p []byte) (int, error) {
		if i >= len(steps) {
			t.Fatal("relay kept reading after EOF")
		}
		if !bytes.Equal(output.Bytes(), expected.Bytes()) {
			t.Fatalf("relay did not forward read %d before the next read", i-1)
		}
		step := steps[i]
		if len(p) != step.capacity {
			t.Fatalf("read %d used buffer size %d, want %d", i, len(p), step.capacity)
		}
		i++
		b := bytes.Repeat([]byte{byte(i)}, step.size)
		expected.Write(b)
		n := copy(p, b)
		if i == len(steps) {
			return n, io.EOF
		}
		return n, nil
	})
	if err := copyAdaptiveDownlink(&output, r); err != nil {
		t.Fatal(err)
	}
	if i != len(steps) || !bytes.Equal(output.Bytes(), expected.Bytes()) {
		t.Fatal("relayed bytes differ from source")
	}
}

func TestAdaptiveDownlinkPropagatesCopyErrors(t *testing.T) {
	t.Run("a short write", func(t *testing.T) {
		w := testWriteFunc(func(p []byte) (int, error) { return len(p) - 1, nil })
		if err := copyAdaptiveDownlink(w, bytes.NewBufferString("data")); !errors.Is(err, io.ErrShortWrite) {
			t.Fatalf("short write = %v, want %v", err, io.ErrShortWrite)
		}
	})
	t.Run("data and read error together", func(t *testing.T) {
		wantErr := errors.New("upstream failed")
		source := testReadFunc(func(p []byte) (int, error) { return copy(p, "final data"), wantErr })
		var output bytes.Buffer
		if err := copyAdaptiveDownlink(&output, source); !errors.Is(err, wantErr) || output.String() != "final data" {
			t.Fatalf("relay = (%q, %v), want final data and %v", output.String(), err, wantErr)
		}
	})
}

func TestDownlinkPaddingPreservesData(t *testing.T) {
	var b downlinkPaddingBudget
	var wire bytes.Buffer
	w := paddedDownlinkWriter{data: testWriteFunc(func(p []byte) (int, error) {
		if len(p) > 0 {
			frame := quicvarint.Append(nil, 0) // DATA
			wire.Write(quicvarint.Append(frame, uint64(len(p))))
			wire.Write(p)
		}
		return len(p), nil
	}), tryWrite: func(p []byte) error {
		wire.Write(p)
		return nil
	}, budget: &b}
	for _, data := range []string{"", "first small response", "second response"} {
		if n, err := w.Write([]byte(data)); n != len(data) || err != nil {
			t.Fatalf("Write(%q) = (%d, %v)", data, n, err)
		}
	}
	for _, want := range []struct {
		frameType uint64
		data      string
	}{{0, "first small response"}, {downlinkPaddingFrameType, ""}, {0, "second response"}} {
		before := wire.Len()
		frameType, err := quicvarint.Read(&wire)
		if err != nil || frameType != want.frameType {
			t.Fatalf("frame type = (%#x, %v), want %#x", frameType, err, want.frameType)
		}
		length, err := quicvarint.Read(&wire)
		if err != nil || length > uint64(wire.Len()) {
			t.Fatalf("frame length = (%d, %v), remaining %d", length, err, wire.Len())
		}
		p := wire.Next(int(length))
		if frameType == downlinkPaddingFrameType {
			size := before - wire.Len()
			if size < downlinkPaddingMinFrameBytes || size > downlinkPaddingMaxFrameBytes || int(b.used.Load()) != size {
				t.Fatalf("padding used %d serialized bytes, budget recorded %d", size, b.used.Load())
			}
			if !bytes.Equal(p, make([]byte, len(p))) {
				t.Fatal("padding frame contains nonzero payload")
			}
		} else if string(p) != want.data {
			t.Fatalf("DATA payload = %q, want %q", p, want.data)
		}
	}
	if wire.Len() != 0 {
		t.Fatalf("extra serialized data after second write, %d bytes", wire.Len())
	}
}

func TestDownlinkPaddingSkipsBulkStream(t *testing.T) {
	var b downlinkPaddingBudget
	var data bytes.Buffer
	w := paddedDownlinkWriter{data: &data, budget: &b, tryWrite: func([]byte) error {
		t.Fatal("bulk stream attempted a padding write")
		return nil
	}}
	input := append(bytes.Repeat([]byte("b"), 2*1024), 's')
	for _, p := range [][]byte{input[:len(input)-1], input[len(input)-1:]} {
		if n, err := w.Write(p); n != len(p) || err != nil {
			t.Fatalf("bulk stream write = (%d, %v)", n, err)
		}
	}
	if !bytes.Equal(data.Bytes(), input) || b.used.Load() != 0 {
		t.Fatal("bulk stream was changed or consumed the connection's padding budget")
	}
}

func TestDownlinkPaddingSkipsBusyStream(t *testing.T) {
	var b downlinkPaddingBudget
	var data bytes.Buffer
	attempts := 0
	w := paddedDownlinkWriter{data: &data, budget: &b, tryWrite: func([]byte) error {
		attempts++
		return quic.ErrWouldBlock
	}}
	for _, p := range []string{"first", "second"} {
		if n, err := w.Write([]byte(p)); n != len(p) || err != nil {
			t.Fatalf("busy stream write = (%d, %v)", n, err)
		}
	}
	if data.String() != "firstsecond" || b.used.Load() != 0 || attempts != 1 {
		t.Fatalf("data = %q, reserved padding = %d, attempts = %d", data.String(), b.used.Load(), attempts)
	}
}

func TestDownlinkPaddingBudgetAcrossConcurrentStreams(t *testing.T) {
	var b downlinkPaddingBudget
	var sent atomic.Int32
	var writers sync.WaitGroup
	for range 32 {
		writers.Go(func() {
			w := paddedDownlinkWriter{data: io.Discard, tryWrite: func(p []byte) error {
				sent.Add(int32(len(p)))
				return nil
			}, budget: &b}
			if n, err := w.Write([]byte("small")); n != 5 || err != nil {
				t.Errorf("concurrent write = (%d, %v)", n, err)
			}
		})
	}
	writers.Wait()
	if actual := sent.Load(); actual != b.used.Load() || actual > downlinkPaddingConnectionCap || actual <= downlinkPaddingConnectionCap-downlinkPaddingMinFrameBytes {
		t.Fatalf("sent %d serialized padding bytes and reserved %d, cap %d", actual, b.used.Load(), downlinkPaddingConnectionCap)
	}
	if more := b.take(downlinkPaddingMaxFrameBytes); more != 0 {
		t.Fatalf("exhausted connection granted %d more padding bytes", more)
	}
	var other downlinkPaddingBudget
	if got := other.take(downlinkPaddingMaxFrameBytes); got != downlinkPaddingMaxFrameBytes {
		t.Fatalf("a new connection granted %d, want %d", got, downlinkPaddingMaxFrameBytes)
	}
}
