package outbound

import (
	"context"
	"encoding/pem"
	"errors"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strconv"
	"sync"
	"sync/atomic"
	"syscall"
	"testing"
	"time"

	"github.com/metacubex/mihomo/component/fastcatentry"
	"github.com/metacubex/mihomo/component/fastcatprobe"
	C "github.com/metacubex/mihomo/constant"
)

type autoTestDialer struct {
	C.Dialer
	primary       string
	fail          atomic.Bool
	primaryDials  atomic.Int32
	fallbackDials atomic.Int32
}

func (d *autoTestDialer) DialContext(ctx context.Context, network, endpoint string) (net.Conn, error) {
	if endpoint == d.primary {
		d.primaryDials.Add(1)
		if d.fail.Load() {
			return nil, syscall.ECONNREFUSED
		}
	} else {
		d.fallbackDials.Add(1)
	}
	return (&net.Dialer{}).DialContext(ctx, network, endpoint)
}

func TestFastCatAutoRealGateways(t *testing.T) {
	const h2Token = "dummy-primary-credential-for-test"
	const v1Token = "dummy-backup-credential-for-test"
	var reject atomic.Int32
	h2 := httptest.NewUnstartedServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.ProtoMajor != 2 || r.Method != "CONNECT" || r.Header.Get("Proxy-Authorization") != "Bearer "+h2Token {
			w.WriteHeader(407)
			return
		}
		if status := reject.Load(); status != 0 {
			w.WriteHeader(int(status))
			return
		}
		w.WriteHeader(200)
		w.(http.Flusher).Flush()
		msg := make([]byte, 5)
		if _, err := io.ReadFull(r.Body, msg); err != nil {
			return
		}
		if _, err := w.Write(msg); err != nil {
			return
		}
		w.(http.Flusher).Flush()
	}))
	h2.EnableHTTP2 = true
	h2.StartTLS()
	defer h2.Close()
	v1 := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.ProtoMajor != 1 || r.Method != "CONNECT" || r.Header.Get("Authorization") != "Bearer "+v1Token {
			w.WriteHeader(407)
			return
		}
		conn, rw, err := w.(http.Hijacker).Hijack()
		if err != nil {
			return
		}
		defer conn.Close()
		_, _ = rw.WriteString("HTTP/1.1 200 OK\r\n\r\n")
		_ = rw.Flush()
		_, _ = io.Copy(conn, rw)
	}))
	defer v1.Close()
	ca := filepath.Join(t.TempDir(), "ca.pem")
	if err := os.WriteFile(ca, pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: h2.Certificate().Raw}), 0600); err != nil {
		t.Fatal(err)
	}
	host, port, _ := net.SplitHostPort(h2.Listener.Addr().String())
	_, other, _ := net.SplitHostPort(v1.Listener.Addr().String())
	p, _ := strconv.Atoi(port)
	b, _ := strconv.Atoi(other)
	d := &autoTestDialer{primary: h2.Listener.Addr().String()}
	opt := FastCatAutoOption{FastCatHTTPSOption: FastCatHTTPSOption{Name: "Region", Server: host, Port: p, Token: h2Token, CAFile: ca, BasicOption: BasicOption{DialerForAPI: d}}, FallbackPort: b, FallbackToken: v1Token}
	a, err := NewFastCatAuto(opt)
	if err != nil {
		t.Fatal(err)
	}
	defer a.Close()
	if a.Type() != C.FastCatAuto || a.SupportUDP() {
		t.Fatal("wrong capabilities")
	}
	m := &C.Metadata{Host: "example.com", DstPort: 443}
	run := func(want string) {
		t.Helper()
		phases := new(fastcatprobe.Timing)
		ctx, cancel := context.WithTimeout(phases.WithContext(context.Background()), 3*time.Second)
		defer cancel()
		conn, err := a.DialContext(ctx, m)
		if err != nil {
			t.Fatal(err)
		}
		defer conn.Close()
		if phases.Snapshot()["used-protocol"] != want || conn.Chains().String() != "Region" {
			t.Fatalf("incorrect route: %v %v", phases.Snapshot(), conn.Chains())
		}
		// Verify the selected stream carries application bytes in both directions.
		_ = conn.SetDeadline(time.Now().Add(2 * time.Second))
		if _, err = conn.Write([]byte("probe")); err != nil {
			t.Fatal(err)
		}
		buf := make([]byte, 5)
		if _, err := io.ReadFull(conn, buf); err != nil || string(buf) != "probe" {
			t.Fatal("echo failed", err)
		}
	}
	run("h2")
	for _, status := range []int32{403, 407, 502, 503} {
		reject.Store(status)
		if c, err := a.DialContext(context.Background(), m); err == nil {
			c.Close()
			t.Fatal("unexpected CONNECT success")
		}
	}
	if d.fallbackDials.Load() != 0 {
		t.Fatal("HTTP status routed to fallback")
	}
	reject.Store(0)
	ResetFastCatH2Connections()
	d.fail.Store(true)
	before := d.primaryDials.Load()
	run("v1")
	if tries := d.primaryDials.Load() - before; tries != 2 {
		t.Fatalf("primary connection attempts: %d", tries)
	}
	d.fail.Store(false)
	ResetFastCatH2Connections()
	before = d.primaryDials.Load()
	run("v1")
	if d.primaryDials.Load() != before {
		t.Fatal("forgot working entry after network change")
	}
	a.mu.Lock()
	a.fallbackUntil = time.Now().Add(-time.Second)
	a.mu.Unlock()
	run("h2")
	if d.primaryDials.Load() == before {
		t.Fatal("did not retry primary after cooldown")
	}

	opt.SNI = "mismatch.invalid"
	opt.FallbackSNI = host
	bad, err := NewFastCatAuto(opt)
	if err != nil {
		t.Fatal(err)
	}
	defer bad.Close()
	before = d.fallbackDials.Load()
	if c, err := bad.DialContext(context.Background(), m); err == nil {
		c.Close()
		t.Fatal("accepted mismatched certificate")
	}
	if d.fallbackDials.Load() != before {
		t.Fatal("retried certificate failure")
	}
}

type autoTestChild struct {
	*Base
	dial func(context.Context) (C.Conn, error)
}

func (c *autoTestChild) DialContext(ctx context.Context, _ *C.Metadata) (C.Conn, error) {
	return c.dial(ctx)
}

func TestFastCatAutoDeadline(t *testing.T) {
	m := &C.Metadata{Host: "test.invalid", DstPort: 443}
	var count atomic.Int32
	block := &autoTestChild{Base: NewBase(BaseOption{}), dial: func(ctx context.Context) (C.Conn, error) { count.Add(1); <-ctx.Done(); return nil, ctx.Err() }}
	v1 := &autoTestChild{Base: NewBase(BaseOption{}), dial: func(context.Context) (C.Conn, error) { return nil, syscall.ECONNREFUSED }}
	a := &FastCatAuto{h2: block, v1: v1}
	ctx, cancel := context.WithTimeout(context.Background(), 600*time.Millisecond)
	defer cancel()
	if _, err := a.DialContext(ctx, m); !errors.Is(err, syscall.ECONNREFUSED) || count.Load() != 2 {
		t.Fatalf("didn't reserve time for fallback: %v, attempts %d", err, count.Load())
	}
	cancel()
	if _, err := a.DialContext(ctx, m); !errors.Is(err, context.Canceled) || count.Load() != 2 {
		t.Fatal("dial after cancellation", err)
	}
	var calls atomic.Int32
	block.dial = func(ctx context.Context) (C.Conn, error) {
		calls.Add(1)
		fastcatentry.Ready(ctx)
		return nil, io.ErrUnexpectedEOF
	}
	if _, err := a.DialContext(context.Background(), m); !errors.Is(err, io.ErrUnexpectedEOF) || calls.Load() != 1 {
		t.Fatal("retried after CONNECT started", err)
	}
}

func TestFastCatAutoConcurrent(t *testing.T) {
	m := &C.Metadata{Host: "test.invalid", DstPort: 443}
	h2 := &autoTestChild{Base: NewBase(BaseOption{}), dial: func(context.Context) (C.Conn, error) { return nil, syscall.ECONNREFUSED }}
	v1 := &autoTestChild{Base: NewBase(BaseOption{})}
	v1.dial = func(ctx context.Context) (C.Conn, error) {
		fastcatentry.Ready(ctx)
		l, r := net.Pipe()
		r.Close()
		return NewConn(l, v1), nil
	}
	a := &FastCatAuto{h2: h2, v1: v1}
	var wg sync.WaitGroup
	for i := 0; i < 12; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			c, err := a.DialContext(context.Background(), m)
			if err != nil {
				t.Error(err)
				return
			}
			c.Close()
		}()
	}
	wg.Wait()
	if v, _, _ := a.preference(); !v {
		t.Fatal("fallback preference lost")
	}
	a.Close()
	if _, err := a.DialContext(context.Background(), m); !errors.Is(err, net.ErrClosed) {
		t.Fatal("dial after close", err)
	}
}
