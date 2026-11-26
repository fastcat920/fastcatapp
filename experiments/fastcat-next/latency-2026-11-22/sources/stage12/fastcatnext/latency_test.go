package fastcatnext

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
