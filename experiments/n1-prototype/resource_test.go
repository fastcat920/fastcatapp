package main

import (
	"io"
	"net"
	"sync/atomic"
	"testing"
	"time"
)

type queuedListener struct{ conns []net.Conn }

func (l *queuedListener) Accept() (net.Conn, error) {
	if len(l.conns) == 0 {
		return nil, io.EOF
	}
	c := l.conns[0]
	l.conns = l.conns[1:]
	return c, nil
}
func (l *queuedListener) Close() error   { return nil }
func (l *queuedListener) Addr() net.Addr { return &net.TCPAddr{} }

type testConn struct {
	host   string
	closed atomic.Int32
}

func (c *testConn) Read([]byte) (int, error)         { return 0, io.EOF }
func (c *testConn) Write(b []byte) (int, error)      { return len(b), nil }
func (c *testConn) Close() error                     { c.closed.Add(1); return nil }
func (c *testConn) LocalAddr() net.Addr              { return &net.TCPAddr{} }
func (c *testConn) RemoteAddr() net.Addr             { return &net.TCPAddr{IP: net.ParseIP(c.host), Port: 12345} }
func (c *testConn) SetDeadline(time.Time) error      { return nil }
func (c *testConn) SetReadDeadline(time.Time) error  { return nil }
func (c *testConn) SetWriteDeadline(time.Time) error { return nil }

func TestPerPeerAdmissionAndRelease(t *testing.T) {
	a, b, rejected, other := &testConn{host: "192.0.2.1"}, &testConn{host: "192.0.2.1"}, &testConn{host: "192.0.2.1"}, &testConn{host: "192.0.2.2"}
	l := &boundedListener{Listener: &queuedListener{conns: []net.Conn{a, b, rejected, other}}, slots: make(chan struct{}, 4), perPeer: 2}
	first, e := l.Accept()
	if e != nil {
		t.Fatal(e)
	}
	second, e := l.Accept()
	if e != nil {
		t.Fatal(e)
	}
	third, e := l.Accept()
	if e != nil {
		t.Fatal(e)
	}
	if third.RemoteAddr().String() != other.RemoteAddr().String() || rejected.closed.Load() != 1 {
		t.Fatal("same peer exhausted other peer admission")
	}
	first.Close()
	first.Close()
	second.Close()
	third.Close()
	if len(l.slots) != 0 || len(l.peers) != 0 {
		t.Fatal("admission slots leaked or released twice")
	}
}

func TestGlobalAdmissionLimit(t *testing.T) {
	a, b := &testConn{host: "192.0.2.1"}, &testConn{host: "192.0.2.2"}
	l := &boundedListener{Listener: &queuedListener{conns: []net.Conn{a, b}}, slots: make(chan struct{}, 1), perPeer: 2}
	c, e := l.Accept()
	if e != nil {
		t.Fatal(e)
	}
	if _, e = l.Accept(); e != io.EOF || b.closed.Load() != 1 {
		t.Fatal("global limit not enforced")
	}
	c.Close()
	if len(l.slots) != 0 {
		t.Fatal("global slot leaked")
	}
}
