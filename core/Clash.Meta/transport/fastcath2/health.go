package h2client

import (
	"context"
	"net"
	"net/http"
	"net/http/httptrace"
	"net/url"
	"sync"
	"sync/atomic"
	"time"

	"github.com/metacubex/mihomo/component/fastcatentry"
)

type generation struct {
	transport transport
	responses atomic.Uint64
	mu        sync.Mutex
	check     *healthCheck
}
type healthCheck struct {
	done   chan struct{}
	failed bool
}

// Only a stalled reused entry triggers a control request. No idle probing,
// target retries, or cancellation of other active business streams.
func (c *Client) watchGeneration(ctx context.Context, cancel context.CancelCauseFunc, g *generation, physical net.Conn) *time.Timer {
	start := g.responses.Load()
	return time.AfterFunc(time.Second, func() {
		if ctx.Err() != nil || g.responses.Load() != start {
			return
		}
		g.mu.Lock()
		check := g.check
		if check == nil {
			check = &healthCheck{done: make(chan struct{})}
			g.check = check
			go func() {
				failed := c.gatewayTimedOut(g, physical)
				g.mu.Lock()
				check.failed = failed
				close(check.done)
				g.check = nil
				g.mu.Unlock()
			}()
		}
		g.mu.Unlock()
		select {
		case <-ctx.Done():
		case <-check.done:
			if check.failed && g.responses.Load() == start && ctx.Err() == nil {
				c.retire(g, time.Now())
				cancel(fastcatentry.ErrUnresponsive)
			}
		}
	})
}
func (c *Client) gatewayTimedOut(g *generation, physical net.Conn) bool {
	ctx, cancel := context.WithTimeout(c.ctx, 1500*time.Millisecond)
	defer cancel()
	var same atomic.Bool
	trace := &httptrace.ClientTrace{GotConn: func(info httptrace.GotConnInfo) { same.Store(info.Conn == physical && info.Reused) }}
	req := (&http.Request{Method: "HEAD", Header: make(http.Header), URL: &url.URL{Scheme: "https", Host: c.config.Endpoint, Path: "/"}}).WithContext(httptrace.WithClientTrace(ctx, trace))
	resp, err := g.transport.RoundTrip(req)
	if resp != nil {
		resp.Body.Close()
		g.responses.Add(1)
	}
	return err != nil && ctx.Err() == context.DeadlineExceeded && c.ctx.Err() == nil && same.Load()
}
func (c *Client) retire(g *generation, now time.Time) bool {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.ctx.Err() != nil || c.generation != g || !c.lastReplacement.IsZero() && now.Sub(c.lastReplacement) < 30*time.Second {
		return false
	}
	next, err := c.newTransport()
	if err != nil {
		return false
	}
	c.transport = next
	c.generation = &generation{transport: next}
	c.lastReplacement = now
	// Existing streams finish on their original transport. Its configured idle
	// timeout bounds remaining idle sockets; network cancellation closes all.
	g.transport.CloseIdleConnections()
	return true
}

// Warm prepares one entry with no target connection or application replay.
// A normal HTTP response proves reachability, not token authorization.
func (c *Client) Warm(ctx context.Context) error {
	c.mu.Lock()
	g := c.generation
	c.mu.Unlock()
	req := (&http.Request{Method: "HEAD", Header: make(http.Header), URL: &url.URL{Scheme: "https", Host: c.config.Endpoint, Path: "/"}}).WithContext(ctx)
	resp, err := g.transport.RoundTrip(req)
	if resp != nil {
		resp.Body.Close()
	}
	return err
}
