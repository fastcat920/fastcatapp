package main

import (
	"io"
	"net"
	"testing"
	"time"
)

func tcpPair(t *testing.T) (net.Conn, *net.TCPConn) {
	t.Helper()
	l, e := net.Listen("tcp", "127.0.0.1:0")
	if e != nil {
		t.Fatal(e)
	}
	defer l.Close()
	c, e := net.Dial("tcp", l.Addr().String())
	if e != nil {
		t.Fatal(e)
	}
	peer, e := l.Accept()
	if e != nil {
		c.Close()
		t.Fatal(e)
	}
	c.SetDeadline(time.Now().Add(3 * time.Second))
	peer.SetDeadline(time.Now().Add(3 * time.Second))
	t.Cleanup(func() { c.Close(); peer.Close() })
	return c, peer.(*net.TCPConn)
}
func TestRelayReverseHalfClose(t *testing.T) {
	a, client := tcpPair(t)
	b, target := tcpPair(t)
	done := make(chan struct{})
	go func() { relay(a, a, b); close(done) }()
	target.CloseWrite()
	data, e := io.ReadAll(client)
	if e != nil || len(data) != 0 {
		t.Fatalf("target EOF: %q %v", data, e)
	}
	// The target has stopped sending but must still receive a request body.
	if _, e = client.Write([]byte("after-target-fin")); e != nil {
		t.Fatal(e)
	}
	client.CloseWrite()
	data, e = io.ReadAll(target)
	if e != nil || string(data) != "after-target-fin" {
		t.Fatalf("reverse half-close lost data: %q %v", data, e)
	}
	select {
	case <-done:
	case <-time.After(3 * time.Second):
		t.Fatal("relay did not terminate")
	}
}
