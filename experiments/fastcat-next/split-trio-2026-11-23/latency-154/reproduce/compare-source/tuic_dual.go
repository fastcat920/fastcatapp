package main

import (
	"context"
	"crypto/x509"
	"net"
	"sync"
)

// Diagnostic control only: match Next's two independent congestion domains
// with two unmodified TUIC clients, assigning new streams by active count.
func newDualTUIC(ctx context.Context, cfg configuration, roots *x509.CertPool) (client, error) {
	children := make([]client, 0, 2)
	for i := 0; i < 2; i++ {
		c, e := newClient(ctx, cfg, roots, "tuic", "quic")
		if e != nil {
			for _, x := range children {
				x.close()
			}
			return client{}, e
		}
		children = append(children, c)
	}
	var mu sync.Mutex
	active := [2]int{}
	closed := false
	return client{
		dial: func(ctx context.Context, target string) (net.Conn, error) {
			mu.Lock()
			if closed {
				mu.Unlock()
				return nil, net.ErrClosed
			}
			i := 0
			if active[1] < active[0] {
				i = 1
			}
			active[i]++
			mu.Unlock()
			release := func() { mu.Lock(); active[i]--; mu.Unlock() }
			n, e := children[i].dial(ctx, target)
			if e != nil {
				release()
				return nil, e
			}
			return &dualTUICConn{Conn: n, release: release}, nil
		},
		close: func() {
			mu.Lock()
			if closed {
				mu.Unlock()
				return
			}
			closed = true
			mu.Unlock()
			for _, x := range children {
				x.close()
			}
		},
	}, nil
}

type dualTUICConn struct {
	net.Conn
	once    sync.Once
	release func()
}

func (c *dualTUICConn) Close() error  { e := c.Conn.Close(); c.once.Do(c.release); return e }
func (c *dualTUICConn) Upstream() any { return c.Conn }
