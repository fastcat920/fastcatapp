package fcn

import (
	"context"
	"net"
	"testing"
	"time"
)

func TestLatencyScoreDoesNotRewardBulkForHighRate(t *testing.T) {
	light := LaneState{RTTUS: 100000, Active: 1, Opening: 1}
	bulk := LaneState{RTTUS: 100000, Active: 1, Heavy: 1}
	if latencyScore(bulk) <= latencyScore(light) {
		t.Fatal("bulk load attracted first packets")
	}
	fastBusy := LaneState{RTTUS: 80000, Active: 3, Opening: 2, Heavy: 1, PendingWriteBytes: 1 << 20}
	if latencyScore(fastBusy) <= latencyScore(LaneState{RTTUS: 150000}) {
		t.Fatal("busy fast lane monopolized unknown streams")
	}
}
func TestLatencyWaitExpiresAndIsBounded(t *testing.T) {
	now := time.Now()
	var w waitEstimate
	w.observe(100*time.Millisecond, now)
	w.observe(500*time.Millisecond, now.Add(time.Second))
	if v := w.value(now.Add(time.Second)); v != 200*time.Millisecond {
		t.Fatal(v)
	}
	if w.value(now.Add(12*time.Second)) != 0 {
		t.Fatal("stale destination wait remained influential")
	}
	w.observe(time.Hour, now.Add(13*time.Second))
	if w.value(now.Add(13*time.Second)) != 5*time.Second {
		t.Fatal("unbounded sample")
	}
}
func TestLatencyLifecycleResetAndDiagnostics(t *testing.T) {
	c, _, stop := adaptiveFixture(t)
	defer stop()
	c.cfg.LatencyAware = true
	events := make(chan LaneEvent, 32)
	c.cfg.LaneTrace = func(e LaneEvent) { events <- e }
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := c.Warm(ctx); err != nil {
		t.Fatal(err)
	}
	target, _ := echoTarget(t)
	if err := checkEcho(ctx, c, target, make([]byte, 300<<10)); err != nil {
		t.Fatal(err)
	}
	c.mu.Lock()
	for i, m := range c.laneMetrics {
		if m.latency.opening.Load() != 0 || m.latency.heavy.Load() != 0 || c.laneActive[i] != 0 {
			t.Fatal("load reservation leaked")
		}
	}
	c.mu.Unlock()
	var selected bool
	for len(events) > 0 {
		e := <-events
		if e.Stage == "lane_select" {
			selected = true
			if e.Selection.Policy != "latency" || e.Selection.Request == 0 {
				t.Fatal(e)
			}
		}
	}
	if !selected {
		t.Fatal("missing sanitized selection")
	}
	c.Reset()
	c.mu.Lock()
	for _, m := range c.laneMetrics {
		if m.latency.readBytes.Load() != 0 {
			t.Fatal("stale generation metrics")
		}
	}
	c.mu.Unlock()
}
func TestLatencyReadyLaneNeverWaitsForMissingOther(t *testing.T) {
	c, _, stop := adaptiveFixture(t)
	defer stop()
	c.cfg.LatencyAware = true
	sink, e := net.ListenPacket("udp4", "127.0.0.1:0")
	if e != nil {
		t.Fatal(e)
	}
	defer sink.Close()
	c.lanes[0].cfg.Endpoint = sink.LocalAddr().String()
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if e = c.lanes[1].Warm(ctx); e != nil {
		t.Fatal(e)
	}
	target, _ := echoTarget(t)
	start := time.Now()
	conn, e := c.Dial(ctx, target)
	if e != nil {
		t.Fatal(e)
	}
	defer conn.Close()
	if conn.(*laneConn).selection.Lane != 1 || time.Since(start) > time.Second {
		t.Fatal("ready spare did not bypass missing primary")
	}
}

func TestReserveStartupAndPathSafety(t *testing.T) {
	now := time.Now()
	c := &Client{cfg: Config{ReserveInteractive: true}, laneMetrics: []*laneMetrics{{}, {}}}
	c.laneMetrics[0].latency.assignedAt = now
	s := [2]LaneState{{Ready: true, Active: 1, Opening: 1, RTTUS: 100000, ScoreUS: 250000}, {Ready: true, RTTUS: 110000, ScoreUS: 110000}}
	if got := c.refineLatencyLocked(1, s, now.Add(time.Millisecond)); got != 0 {
		t.Fatal("startup affinity lost", got)
	}
	if got := c.refineLatencyLocked(1, s, now.Add(300*time.Millisecond)); got != 1 {
		t.Fatal("affinity exceeded bounded time", got)
	}
	s[0].RTTUS = 500000
	if got := c.refineLatencyLocked(1, s, now); got != 1 {
		t.Fatal("affinity forced poor path", got)
	}
	s[0] = LaneState{Ready: true, Active: 2, Heavy: 2, RTTUS: 100000, ScoreUS: 500000}
	s[1].RTTUS = 100000
	if got := c.refineLatencyLocked(1, s, now); got != 1 {
		t.Fatal("no admission space for unknown work")
	}
	s[1].RTTUS = 600000
	s[1].ScoreUS = 900000
	if got := c.refineLatencyLocked(0, s, now); got != 0 {
		t.Fatal("reserved unhealthy spare")
	}
}
func TestHysteresisBoundAndLargeImprovement(t *testing.T) {
	now := time.Now()
	c := &Client{cfg: Config{ScheduleHysteresis: true}, laneStreak: 1, lastLane: 0, laneSwitchAt: now}
	s := [2]LaneState{{Ready: true, ScoreUS: 110000}, {Ready: true, ScoreUS: 100000}}
	if got := c.refineLatencyLocked(1, s, now.Add(time.Millisecond)); got != 0 {
		t.Fatal("small score change caused flapping")
	}
	c.laneStreak = 3
	if got := c.refineLatencyLocked(0, s, now); got != 1 {
		t.Fatal("burst cap did not admit comparable alternative")
	}
	c.lastLane = 0
	c.laneStreak = 1
	s[0].ScoreUS = 500000
	if got := c.refineLatencyLocked(1, s, now); got != 1 {
		t.Fatal("hysteresis held substantially worse path")
	}
}

func TestLaneWindowOnlyCountsRecentDeltas(t *testing.T) {
	var m laneLatency
	now := time.Now()
	m.window(now)
	m.readBytes.Add(1000)
	m.writtenBytes.Add(300)
	r, w, ms := m.window(now.Add(time.Second))
	if r != 1000 || w != 300 || ms != 1000 {
		t.Fatal(r, w, ms)
	}
	r, w, ms = m.window(now.Add(5 * time.Second))
	if r != 0 || w != 0 || ms != 0 {
		t.Fatal("stale byte window")
	}
}

func TestReserveOnlyGroupsFirstTwoOpens(t *testing.T) {
	c, _, stop := adaptiveFixture(t)
	defer stop()
	c.cfg.LatencyAware = true
	c.cfg.ReserveInteractive = true
	c.cfg.ScheduleHysteresis = true
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if e := c.Warm(ctx); e != nil {
		t.Fatal(e)
	}
	target, _ := echoTarget(t)
	var conns []net.Conn
	for i := 0; i < 3; i++ {
		n, e := c.Dial(ctx, target)
		if e != nil {
			t.Fatal(e)
		}
		conns = append(conns, n)
		defer n.Close()
	}
	got := [3]int{conns[0].(*laneConn).selection.Lane, conns[1].(*laneConn).selection.Lane, conns[2].(*laneConn).selection.Lane}
	if got[0] != got[1] || got[2] == got[0] {
		t.Fatal("startup grouping monopolized every new open", got)
	}
	c.Reset()
	for _, m := range c.laneMetrics {
		if m.latency.opening.Load() != 0 {
			t.Fatal("reset leaked opening count")
		}
	}
	for _, n := range conns {
		_ = n.Close()
	}
	for _, m := range c.laneMetrics {
		if m.latency.opening.Load() != 0 {
			t.Fatal("old close damaged new generation")
		}
	}
}
