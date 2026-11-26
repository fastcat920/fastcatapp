package main

import (
	"context"
	"io"
	"net"
	"net/netip"
	"sync"
)

// Explicit test-lifetime sockets avoid keeping cold TUIC sessions/heartbeats
// alive after an adapter with no custom Close method is discarded.
type trackedDialer struct {
	mu      sync.Mutex
	closed  bool
	sockets []io.Closer
	wrapUDP func(*net.UDPConn) net.PacketConn
}

func (t *trackedDialer) add(c io.Closer) error {
	t.mu.Lock()
	defer t.mu.Unlock()
	if t.closed {
		c.Close()
		return net.ErrClosed
	}
	t.sockets = append(t.sockets, c)
	return nil
}
func (t *trackedDialer) DialContext(ctx context.Context, n, a string) (net.Conn, error) {
	c, e := (&net.Dialer{}).DialContext(ctx, n, a)
	if e == nil {
		e = t.add(c)
	}
	if e != nil {
		return nil, e
	}
	return c, nil
}
func (t *trackedDialer) ListenPacket(ctx context.Context, n, a string, _ netip.AddrPort) (net.PacketConn, error) {
	c, e := (&net.ListenConfig{}).ListenPacket(ctx, n, a)
	if e == nil {
		if udp, ok := c.(*net.UDPConn); ok && t.wrapUDP != nil {
			c = t.wrapUDP(udp)
		}
		e = t.add(c)
	}
	if e != nil {
		return nil, e
	}
	return c, nil
}
func (t *trackedDialer) Close() {
	t.mu.Lock()
	if t.closed {
		t.mu.Unlock()
		return
	}
	t.closed = true
	s := t.sockets
	t.sockets = nil
	t.mu.Unlock()
	for _, c := range s {
		c.Close()
	}
}
