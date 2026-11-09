package tun

import (
	"context"
	"github.com/metacubex/sing/common/logger"
	"net"
	"syscall"
	"testing"
	"time"
)

func TestRecoveringTCPListenerKernelShutdown(t *testing.T) {
	original := initialListener(t)
	raw, e := original.(syscall.Conn).SyscallConn()
	if e != nil {
		t.Fatal(e)
	}
	var shutdownError error
	if e = raw.Control(func(fd uintptr) { shutdownError = syscall.Shutdown(int(fd), syscall.SHUT_RDWR) }); e != nil || shutdownError != nil {
		t.Fatalf("shutdown: %v %v", e, shutdownError)
	}
	rebound := make(chan struct{})
	lc := net.ListenConfig{}
	wrapped := newRecoveringTCPListener(context.Background(), original, "tcp4", func(c context.Context, n, a string) (net.Listener, error) {
		l, e := lc.Listen(c, n, a)
		if e == nil {
			close(rebound)
		}
		return l, e
	}, logger.NOP())
	wrapped.retryDelay = time.Millisecond
	defer wrapped.Close()
	done := make(chan error, 1)
	go func() {
		c, e := wrapped.Accept()
		if e == nil {
			c.Close()
		}
		done <- e
	}()
	select {
	case <-rebound:
	case <-time.After(time.Second):
		t.Fatal("kernel-aborted listener did not recover")
	}
	c, e := net.DialTimeout("tcp4", wrapped.Addr().String(), time.Second)
	if e != nil {
		t.Fatal(e)
	}
	c.Close()
	if e = resultWithin(t, done); e != nil {
		t.Fatal(e)
	}
	if wrapped.health().Recoveries != 1 {
		t.Fatal("missing recovery")
	}
}

func TestBorrowedDescriptorRemainsOwnedByCaller(t *testing.T) {
	fds := make([]int, 2)
	if e := syscall.Pipe(fds); e != nil {
		t.Fatal(e)
	}
	defer syscall.Close(fds[0])
	defer syscall.Close(fds[1])
	release := BorrowFileDescriptor(fds[0])
	defer release()
	driver, e := New(Options{FileDescriptor: fds[0]})
	if e != nil {
		t.Fatal(e)
	}
	if driver.(*NativeTun).tunFd == fds[0] {
		t.Fatal("borrowed descriptor was adopted directly")
	}
	if e = driver.Close(); e != nil {
		t.Fatal(e)
	}
	var stat syscall.Stat_t
	if e = syscall.Fstat(fds[0], &stat); e != nil {
		t.Fatalf("driver closed caller descriptor: %v", e)
	}
}
