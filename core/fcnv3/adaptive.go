package fcnv3

import (
	"io"
	"math/rand/v2"
	"sync"
	"sync/atomic"

	"github.com/metacubex/quic-go/http3"
	"github.com/metacubex/quic-go/quicvarint"
)

const (
	adaptiveInteractiveSize = 8 * 1024
	adaptiveBulkSize        = 128 * 1024
	adaptiveModeReads       = 2
)

var (
	adaptiveInteractiveBuffers = sync.Pool{New: func() any { return new([adaptiveInteractiveSize]byte) }}
	adaptiveBulkBuffers        = sync.Pool{New: func() any { return new([adaptiveBulkSize]byte) }}
)

// copyAdaptiveDownlink changes the maximum read size based on recent reads.
// Each read is written immediately, with no buffering across reads.
func copyAdaptiveDownlink(dst io.Writer, src io.Reader) error {
	interactive := adaptiveInteractiveBuffers.Get().(*[adaptiveInteractiveSize]byte)
	defer adaptiveInteractiveBuffers.Put(interactive)
	var bulk *[adaptiveBulkSize]byte
	defer func() {
		if bulk != nil {
			adaptiveBulkBuffers.Put(bulk)
		}
	}()
	buffer := interactive[:]
	streak := 0
	for {
		n, readErr := src.Read(buffer)
		if n > 0 {
			written, err := dst.Write(buffer[:n])
			if err != nil {
				return err
			}
			if written != n {
				return io.ErrShortWrite
			}
		}
		if readErr == io.EOF {
			return nil
		}
		if readErr != nil {
			return readErr
		}
		switch {
		case bulk == nil && n == len(buffer):
			streak++
			if streak == adaptiveModeReads {
				bulk = adaptiveBulkBuffers.Get().(*[adaptiveBulkSize]byte)
				buffer = bulk[:]
				streak = 0
			}
		case bulk != nil && n > 0 && n <= adaptiveInteractiveSize:
			streak++
			if streak == adaptiveModeReads {
				adaptiveBulkBuffers.Put(bulk)
				bulk = nil
				buffer = interactive[:]
				streak = 0
			}
		default:
			streak = 0
		}
	}
}

const (
	downlinkPaddingFrameType     = 0x21 // Reserved for use with arbitrary payloads (RFC 9114 §7.2.8).
	downlinkPaddingPayloadLimit  = 512
	downlinkPaddingMinFrameBytes = 32
	downlinkPaddingMaxFrameBytes = 128
	downlinkPaddingConnectionCap = 512
)

// downlinkPaddingBudget caps serialized HTTP/3 padding bytes across all
// CONNECT streams on a single QUIC connection, excluding retransmissions.
type downlinkPaddingBudget struct {
	used atomic.Int32
}

func (b *downlinkPaddingBudget) take(wanted int) int {
	for {
		used := b.used.Load()
		allowed := min(wanted, downlinkPaddingConnectionCap-int(used))
		if allowed < downlinkPaddingMinFrameBytes {
			return 0
		}
		if b.used.CompareAndSwap(used, used+int32(allowed)) {
			return allowed
		}
	}
}

func (b *downlinkPaddingBudget) wrap(stream *http3.Stream) io.Writer {
	return &paddedDownlinkWriter{data: stream, tryWrite: stream.QUICStream().TryWriteAll, budget: b}
}

// paddedDownlinkWriter is used by the one goroutine writing CONNECT replies.
// A reserved HTTP/3 frame can follow the first small DATA frame. Normal writes
// still use the HTTP/3 library. The raw stream is only used for the reserved frame.
type paddedDownlinkWriter struct {
	data     io.Writer
	tryWrite func([]byte) error
	budget   *downlinkPaddingBudget
	started  bool
}

func (w *paddedDownlinkWriter) Write(p []byte) (int, error) {
	if len(p) == 0 || w.started {
		return w.data.Write(p)
	}
	w.started = true
	n, err := w.data.Write(p)
	if err != nil || n != len(p) || len(p) > downlinkPaddingPayloadLimit {
		return n, err
	}
	wanted := downlinkPaddingMinFrameBytes + rand.IntN(downlinkPaddingMaxFrameBytes-downlinkPaddingMinFrameBytes+1)
	size := w.budget.take(wanted)
	if size == 0 {
		return n, nil
	}
	// The type uses one byte and the length uses two, allowing every budgeted
	// size to be represented exactly, including the one-byte length boundary.
	var padding [downlinkPaddingMaxFrameBytes]byte
	frame := quicvarint.Append(padding[:0], downlinkPaddingFrameType)
	frame = quicvarint.AppendWithLen(frame, uint64(size-3), 2)
	// TryWriteAll either queues the whole frame immediately or queues nothing.
	// An unavailable send window can therefore skip padding without delaying DATA.
	if err := w.tryWrite(frame[:size]); err != nil {
		w.budget.used.Add(-int32(size))
	}
	return n, nil
}
