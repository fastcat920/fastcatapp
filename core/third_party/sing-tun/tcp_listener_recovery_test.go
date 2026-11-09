package tun

import (
	"context"
	"errors"
	"github.com/metacubex/sing/common/logger"
	"io"
	"net"
	"sync"
	"sync/atomic"
	"syscall"
	"testing"
	"time"
)

type firstErrorListener struct {
	net.Listener
	once   sync.Once
	fault  error
	closed chan struct{}
}

func (l *firstErrorListener) Accept() (net.Conn, error) {
	first := false
	l.once.Do(func() { first = true })
	if first {
		return nil, l.fault
	}
	return l.Listener.Accept()
}
func (l *firstErrorListener) Close() error {
	if l.closed != nil {
		select {
		case <-l.closed:
		default:
			close(l.closed)
		}
	}
	return l.Listener.Close()
}
func initialListener(t *testing.T) net.Listener {
	t.Helper()
	l, e := net.Listen("tcp4", "127.0.0.1:0")
	if e != nil {
		t.Fatal(e)
	}
	t.Cleanup(func() { l.Close() })
	return l
}
func resultWithin(t *testing.T, c <-chan error) error {
	t.Helper()
	select {
	case e := <-c:
		return e
	case <-time.After(2 * time.Second):
		t.Fatal("Accept did not finish")
		return nil
	}
}
func TestRecoveringTCPListenerRestoresRealTrafficOnSamePort(t *testing.T) {
	original := initialListener(t)
	address := original.Addr().String()
	bound := make(chan struct{})
	lc := net.ListenConfig{}
	wrapped := newRecoveringTCPListener(context.Background(), &firstErrorListener{Listener: original, fault: syscall.EINVAL}, "tcp4", func(c context.Context, n, a string) (net.Listener, error) {
		l, e := lc.Listen(c, n, a)
		if e == nil {
			close(bound)
		}
		return l, e
	}, logger.NOP())
	wrapped.retryDelay = time.Millisecond
	defer wrapped.Close()
	result := make(chan error, 1)
	go func() {
		c, e := wrapped.Accept()
		if e != nil {
			result <- e
			return
		}
		defer c.Close()
		buf := make([]byte, 4)
		_, e = io.ReadFull(c, buf)
		if e == nil && string(buf) != "ping" {
			e = errors.New("payload mismatch")
		}
		if e == nil {
			_, e = c.Write([]byte("pong"))
		}
		result <- e
	}()
	select {
	case <-bound:
	case <-time.After(time.Second):
		t.Fatal("not recreated")
	}
	conn, e := net.DialTimeout("tcp4", address, time.Second)
	if e != nil {
		t.Fatal(e)
	}
	defer conn.Close()
	conn.SetDeadline(time.Now().Add(time.Second))
	conn.Write([]byte("ping"))
	buf := make([]byte, 4)
	if _, e = io.ReadFull(conn, buf); e != nil || string(buf) != "pong" {
		t.Fatalf("reply %q: %v", buf, e)
	}
	if e = resultWithin(t, result); e != nil {
		t.Fatal(e)
	}
	if h := wrapped.health(); h.State != "ready" || h.Recoveries != 1 {
		t.Fatalf("health %+v", h)
	}
	if wrapped.Addr().String() != address {
		t.Fatal("NAT port changed")
	}
}
func TestRecoveringTCPListenerExplicitCloseNeverRebinds(t *testing.T) {
	var calls atomic.Int32
	wrapped := newRecoveringTCPListener(context.Background(), initialListener(t), "tcp4", func(context.Context, string, string) (net.Listener, error) {
		calls.Add(1)
		return nil, errors.New("unexpected")
	}, logger.NOP())
	result := make(chan error, 1)
	go func() { _, e := wrapped.Accept(); result <- e }()
	wrapped.Close()
	if e := resultWithin(t, result); !errors.Is(e, net.ErrClosed) {
		t.Fatal(e)
	}
	if calls.Load() != 0 {
		t.Fatal("explicit stop resurrected listener")
	}
}
func TestRecoveringTCPListenerCloseCancelsBackoff(t *testing.T) {
	closed := make(chan struct{})
	var calls atomic.Int32
	wrapped := newRecoveringTCPListener(context.Background(), &firstErrorListener{Listener: initialListener(t), fault: syscall.EINVAL, closed: closed}, "tcp4", func(context.Context, string, string) (net.Listener, error) {
		calls.Add(1)
		return nil, syscall.EADDRINUSE
	}, logger.NOP())
	wrapped.retryDelay = time.Hour
	result := make(chan error, 1)
	go func() { _, e := wrapped.Accept(); result <- e }()
	select {
	case <-closed:
	case <-time.After(time.Second):
		t.Fatal("not recovering")
	}
	wrapped.Close()
	if e := resultWithin(t, result); !errors.Is(e, net.ErrClosed) {
		t.Fatal(e)
	}
	if calls.Load() != 0 {
		t.Fatal("backoff was not cancelled")
	}
}
func TestRecoveringTCPListenerDiscardsLateBindAfterStop(t *testing.T) {
	entered, release := make(chan struct{}), make(chan struct{})
	var late net.Listener
	wrapped := newRecoveringTCPListener(context.Background(), &firstErrorListener{Listener: initialListener(t), fault: syscall.EINVAL}, "tcp4", func(c context.Context, n, a string) (net.Listener, error) {
		l, e := net.Listen(n, a)
		late = l
		close(entered)
		<-release
		return l, e
	}, logger.NOP())
	wrapped.retryDelay = time.Millisecond
	result := make(chan error, 1)
	go func() { _, e := wrapped.Accept(); result <- e }()
	select {
	case <-entered:
	case <-time.After(time.Second):
		t.Fatal("bind not entered")
	}
	wrapped.Close()
	close(release)
	if e := resultWithin(t, result); !errors.Is(e, net.ErrClosed) {
		t.Fatal(e)
	}
	if late == nil {
		t.Fatal("missing late bind")
	}
	if _, e := late.Accept(); !errors.Is(e, net.ErrClosed) {
		t.Fatalf("late listener leaked: %v", e)
	}
}
func TestRecoveringTCPListenerBoundedBindFailure(t *testing.T) {
	var calls atomic.Int32
	wrapped := newRecoveringTCPListener(context.Background(), &firstErrorListener{Listener: initialListener(t), fault: syscall.EINVAL}, "tcp4", func(context.Context, string, string) (net.Listener, error) {
		calls.Add(1)
		return nil, syscall.EADDRINUSE
	}, logger.NOP())
	wrapped.retryDelay = time.Millisecond
	defer wrapped.Close()
	if _, e := wrapped.Accept(); !errors.Is(e, syscall.EADDRINUSE) {
		t.Fatal(e)
	}
	if calls.Load() != 3 || wrapped.health().State != "failed" {
		t.Fatalf("unbounded or hidden failure: %d %+v", calls.Load(), wrapped.health())
	}
}
func TestRecoveringTCPListenerParentCancellationDoesNotRebind(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	closed := make(chan struct{})
	var calls atomic.Int32
	wrapped := newRecoveringTCPListener(ctx, &firstErrorListener{Listener: initialListener(t), fault: syscall.ECONNABORTED, closed: closed}, "tcp4", func(context.Context, string, string) (net.Listener, error) {
		calls.Add(1)
		return nil, syscall.EADDRINUSE
	}, logger.NOP())
	wrapped.retryDelay = time.Hour
	defer wrapped.Close()
	result := make(chan error, 1)
	go func() { _, e := wrapped.Accept(); result <- e }()
	select {
	case <-closed:
	case <-time.After(time.Second):
		t.Fatal("not recovering")
	}
	cancel()
	if e := resultWithin(t, result); !errors.Is(e, net.ErrClosed) {
		t.Fatal(e)
	}
	if calls.Load() != 0 {
		t.Fatal("rebound after cancellation")
	}
}

func TestRecoveringTCPListenerBoundsRepeatedAbortAfterSuccessfulBind(t *testing.T) {
	var calls atomic.Int32
	wrapped := newRecoveringTCPListener(context.Background(), &firstErrorListener{Listener: initialListener(t), fault: syscall.EINVAL}, "tcp4", func(c context.Context, n, a string) (net.Listener, error) {
		calls.Add(1)
		l, e := net.Listen(n, a)
		if e != nil {
			return nil, e
		}
		return &firstErrorListener{Listener: l, fault: syscall.EINVAL}, nil
	}, logger.NOP())
	wrapped.retryDelay = time.Millisecond
	defer wrapped.Close()
	if _, e := wrapped.Accept(); !errors.Is(e, syscall.EINVAL) {
		t.Fatal(e)
	}
	if calls.Load() != 3 || wrapped.health().State != "failed" {
		t.Fatalf("rebind loop not bounded: %d %+v", calls.Load(), wrapped.health())
	}
}
