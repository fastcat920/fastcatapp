package fcn

import (
	"bytes"
	"context"
	quic "github.com/metacubex/quic-go"
	"testing"
	"time"
)

func TestRecoveryLossExpiryAndNonMonotonicCounters(t *testing.T) {
	now := time.Now()
	p := new(physical)
	s := new(recoverySignal)
	v := quic.ConnectionStats{MinRTT: 100 * time.Millisecond, LatestRTT: 100 * time.Millisecond, SmoothedRTT: 100 * time.Millisecond}
	if s.update(p, v, now) {
		t.Fatal("healthy penalized")
	}
	v.PacketsLost = 1
	if !s.update(p, v, now) {
		t.Fatal("new loss ignored")
	}
	if s.update(p, v, now.Add(time.Second)) {
		t.Fatal("old loss persisted")
	}
	v.PacketsLost = 0
	if s.update(p, v, now.Add(2*time.Second)) {
		t.Fatal("counter decrease treated as overflow")
	}
	v.LatestRTT = 400 * time.Millisecond
	if !s.update(p, v, now.Add(3*time.Second)) {
		t.Fatal("RTT inflation ignored")
	}
	if s.update(nil, v, now.Add(3*time.Second)) {
		t.Fatal("dead pool retained evidence")
	}
	v.LatestRTT = 100 * time.Millisecond
	v.PacketsLost = 0
	if s.update(new(physical), v, now.Add(4*time.Second)) {
		t.Fatal("new physical inherited old evidence")
	}
}
func TestRecoveryConfigAndReset(t *testing.T) {
	cfg := Config{Endpoint: "127.0.0.1:443", ServerName: "example.com", Account: "test", Key: bytes.Repeat([]byte{7}, 32), QUICLanes: 2, AdaptiveLanes: true, RecoveryAware: true}
	c, e := NewClient(context.Background(), cfg, "quic")
	if e != nil {
		t.Fatal(e)
	}
	defer c.Close()
	for _, ch := range c.lanes {
		if ch.cfg.RecoveryAware {
			t.Fatal("recursive recovery scheduler")
		}
	}
	c.recovery[0].until = time.Now().Add(time.Second)
	c.recoverySwitchAt = time.Now()
	c.Reset()
	if !c.recovery[0].until.IsZero() || !c.recoverySwitchAt.IsZero() {
		t.Fatal("reset kept network evidence")
	}
	cfg.LatencyAware = true
	if _, e = NewClient(context.Background(), cfg, "quic"); e == nil {
		t.Fatal("untested combined policy accepted")
	}
}
func TestRecoverySelectsOnlyReadyHealthyAlternative(t *testing.T) {
	base, _, stop := fixture(t, "quic", 2*time.Second)
	defer stop()
	cfg := base.cfg
	cfg.QUICLanes = 2
	cfg.AdaptiveLanes = true
	cfg.RecoveryAware = true
	c, e := NewClient(context.Background(), cfg, "quic")
	if e != nil {
		t.Fatal(e)
	}
	defer c.Close()
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	if e = c.Warm(ctx); e != nil {
		t.Fatal(e)
	}
	now := time.Now()
	c.mu.Lock()
	defer c.mu.Unlock()
	p0, v0 := c.lanes[0].recoverySnapshot()
	p1, v1 := c.lanes[1].recoverySnapshot()
	if p0 == nil || p1 == nil {
		t.Fatal("warm did not prepare both lanes")
	}
	c.recovery[0] = recoverySignal{physical: p0, lastLost: v0.PacketsLost, until: now.Add(time.Second)}
	if got := c.refineRecoveryLocked(0, now); got != 1 {
		t.Fatal("did not avoid recovering primary", got)
	}
	c.recovery[1] = recoverySignal{physical: p1, lastLost: v1.PacketsLost, until: now.Add(time.Second)}
	if got := c.refineRecoveryLocked(0, now); got != 0 {
		t.Fatal("both unhealthy should preserve base policy", got)
	}
	c.recovery[1] = recoverySignal{}
	c.recoverySwitchAt = now
	c.recoveryLastLane = 0
	if got := c.refineRecoveryLocked(0, now); got != 0 {
		t.Fatal("recovery override switched too frequently", got)
	}
	if p0.q.Context().Err() != nil || p1.q.Context().Err() != nil {
		t.Fatal("selection closed existing physical connection")
	}
}
