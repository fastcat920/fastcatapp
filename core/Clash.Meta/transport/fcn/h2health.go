package fcn

import (
	"context"
	"errors"
	"net"
	"time"
)

// Probe only the entry, never a target. A slow target whose H2 peer answers PING
// cannot retire a connection. Retirement affects future business only.
func (c *Client) checkH2(p *physical) {
	c.mu.Lock()
	if c.closed || p.h2 == nil || c.pool != p || p.retired || p.checking {
		c.mu.Unlock()
		return
	}
	p.checking = true
	c.mu.Unlock()
	ctx, cancel := context.WithTimeout(c.ctx, 1500*time.Millisecond)
	defer cancel()
	start := time.Now()
	e := p.h2.Ping(ctx)
	emitStage(c.cfg.Trace, "h2", "entry_health", start, e)
	c.mu.Lock()
	defer c.mu.Unlock()
	p.checking = false
	if !errors.Is(e, context.DeadlineExceeded) || c.closed || c.pool != p || p.retired {
		return
	}
	if !c.lastReplacement.IsZero() && time.Since(c.lastReplacement) < 30*time.Second {
		return
	}
	c.lastReplacement = time.Now()
	p.retired = true
	c.pool = nil
	if p.active == 0 {
		p.close()
		delete(c.all, p)
	}
}
func (c *Client) retain(p *physical) error {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.closed || p.retired || !c.all[p] {
		return net.ErrClosed
	}
	p.active++
	return nil
}
func (c *Client) release(p *physical) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if p.active > 0 {
		p.active--
	}
	if p.active == 0 && (p.retired || p != c.pool) {
		p.close()
		delete(c.all, p)
	}
}
