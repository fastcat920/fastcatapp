package fcn

import (
	"context"
	"net"
	"testing"
	"time"
)

func adaptiveFixture(t *testing.T) (*Client, *Server, func()) {
	old, s, stop := fixture(t, "quic", time.Second)
	cfg := old.cfg
	old.Close()
	cfg.QUICLanes = 2
	cfg.AdaptiveLanes = true
	c, e := NewClient(context.Background(), cfg, "quic")
	if e != nil {
		t.Fatal(e)
	}
	return c, s, func() { c.Close(); stop() }
}
func TestAdaptiveWarmAndParallelIntegrity(t *testing.T) {
	c, s, stop := adaptiveFixture(t)
	defer stop()
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if e := c.Warm(ctx); e != nil {
		t.Fatal(e)
	}
	for _, child := range c.lanes {
		if ready, _ := child.laneReady(); !ready {
			t.Fatal("explicit warm did not prepare both lanes")
		}
	}
	target, _ := echoTarget(t)
	a, e := c.Dial(ctx, target)
	if e != nil {
		t.Fatal(e)
	}
	defer a.Close()
	b, e := c.Dial(ctx, target)
	if e != nil {
		t.Fatal(e)
	}
	defer b.Close()
	c.mu.Lock()
	active := append([]int(nil), c.laneActive...)
	c.mu.Unlock()
	if active[0] != 1 || active[1] != 1 {
		t.Fatalf("ready lanes not shared: %v", active)
	}
	a.Close()
	b.Close()
	if e := checkEcho(ctx, c, target, make([]byte, 2<<20)); e != nil {
		t.Fatal(e)
	}
	if s.Counters().Sessions.Load() != 2 {
		t.Fatal("unbounded warm sessions")
	}
}
func TestAdaptiveDoesNotWaitForUnavailableSecondary(t *testing.T) {
	c, _, stop := adaptiveFixture(t)
	defer stop()
	sink, e := net.ListenPacket("udp4", "127.0.0.1:0")
	if e != nil {
		t.Fatal(e)
	}
	defer sink.Close()
	c.lanes[1].cfg.Endpoint = sink.LocalAddr().String()
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if e := c.lanes[0].Warm(ctx); e != nil {
		t.Fatal(e)
	}
	target, _ := echoTarget(t)
	a, e := c.Dial(ctx, target)
	if e != nil {
		t.Fatal(e)
	}
	defer a.Close()
	b, e := c.Dial(ctx, target)
	if e != nil {
		t.Fatal(e)
	}
	defer b.Close()
	aa := a.(*laneConn).Conn.(*quicConn)
	bb := b.(*laneConn).Conn.(*quicConn)
	if aa.local.String() != bb.local.String() {
		t.Fatal("Dial waited for a new transport")
	}
	c.mu.Lock()
	done := c.laneWarming[1]
	c.mu.Unlock()
	if done == nil {
		t.Fatal("secondary preparation was not started")
	}
	c.Reset()
	select {
	case <-done:
	case <-time.After(2 * time.Second):
		t.Fatal("background handshake survived reset")
	}
	a.Close()
	b.Close()
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.laneActive[0] != 0 || c.laneActive[1] != 0 {
		t.Fatalf("old generation corrupted reservations: %v", c.laneActive)
	}
}
func TestAdaptiveRateExpiresAndWeightIsBounded(t *testing.T) {
	now := time.Now()
	m := new(laneMetrics)
	m.sample(now)
	m.bytes.Add(1 << 20)
	m.progress.Store(now.Add(time.Second).UnixNano())
	if m.sample(now.Add(time.Second)) <= 0 {
		t.Fatal("missing measured rate")
	}
	if m.sample(now.Add(5*time.Second)) != 0 {
		t.Fatal("idle sample stayed influential")
	}
	if m.rate != 0 {
		t.Fatal("idle rate was retained for reuse")
	}
	if laneScore(8, 100, 100, time.Millisecond, 0) <= laneScore(1, 1, 100, time.Millisecond, 0) {
		t.Fatal("fast lane monopolized traffic")
	}
	if laneScore(1, 0, 0, time.Millisecond, 0) != 2 {
		t.Fatal("invalid idle score")
	}
}

func TestAdaptiveRecoversMissingPrimary(t *testing.T) {
	c, _, stop := adaptiveFixture(t)
	defer stop()
	sink, e := net.ListenPacket("udp4", "127.0.0.1:0")
	if e != nil {
		t.Fatal(e)
	}
	defer sink.Close()
	c.lanes[0].cfg.Endpoint = sink.LocalAddr().String()
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if e := c.lanes[1].Warm(ctx); e != nil {
		t.Fatal(e)
	}
	target, _ := echoTarget(t)
	a, e := c.Dial(ctx, target)
	if e != nil {
		t.Fatal(e)
	}
	defer a.Close()
	b, e := c.Dial(ctx, target)
	if e != nil {
		t.Fatal(e)
	}
	defer b.Close()
	c.mu.Lock()
	done := c.laneWarming[0]
	c.mu.Unlock()
	if done == nil {
		t.Fatal("healthy secondary never prepared a replacement primary")
	}
	c.Reset()
	select {
	case <-done:
	case <-ctx.Done():
		t.Fatal("primary background warm leaked")
	}
}
