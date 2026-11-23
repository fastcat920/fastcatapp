package fcn

import (
	"context"
	"math"
	"sync"
	"testing"
	"time"
)

func primaryFixture(t *testing.T) (*Client, *Server, func()) {
	old, s, stop := fixture(t, "quic", time.Second)
	cfg := old.cfg
	old.Close()
	cfg.QUICLanes = 2
	cfg.AdaptiveLanes = true
	cfg.PrimaryPreferred = true
	c, e := NewClient(context.Background(), cfg, "quic")
	if e != nil {
		t.Fatal(e)
	}
	return c, s, func() { c.Close(); stop() }
}
func TestPrimaryColdBatchKeepsOneConnection(t *testing.T) {
	c, s, stop := primaryFixture(t)
	defer stop()
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if e := c.Warm(ctx); e != nil {
		t.Fatal(e)
	}
	if ready, _ := c.lanes[1].laneReady(); ready {
		t.Fatal("warm eagerly created a spare")
	}
	target, _ := echoTarget(t)
	// Hold reservations before sending payload: a cold batch must not get split.
	conns := make([]interface{ Close() error }, 0, 4)
	var wg sync.WaitGroup
	for i := 0; i < 4; i++ {
		n, e := c.Dial(ctx, target)
		if e != nil {
			t.Fatal(e)
		}
		conns = append(conns, n)
	}
	usage := c.LaneUsage()
	if usage.Assigned != [2]uint64{4, 0} {
		t.Fatalf("cold split: %+v", usage)
	}
	for _, n := range conns {
		n.Close()
	}
	for i := 0; i < 4; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			if e := checkEcho(ctx, c, target, make([]byte, 512<<10)); e != nil {
				t.Error(e)
			}
		}()
	}
	wg.Wait()
	if s.Counters().Sessions.Load() != 1 {
		t.Fatalf("sessions=%d", s.Counters().Sessions.Load())
	}
}
func seedEvidence(d *deliveryEvidence, now time.Time, rate float64, windows int32) {
	d.loadAt.Store(now.UnixNano())
	d.lastRead.Store(now.UnixNano())
	d.loadRate.Store(math.Float64bits(rate))
	d.proofAt.Store(now.UnixNano())
	d.rate.Store(math.Float64bits(rate))
	d.windows.Store(windows)
}
func TestPrimaryTrialAndPromotionAreBounded(t *testing.T) {
	c, _, stop := primaryFixture(t)
	defer stop()
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	for _, child := range c.lanes {
		if e := child.Warm(ctx); e != nil {
			t.Fatal(e)
		}
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	now := time.Now()
	c.laneActive[0] = 3
	if i, _ := c.choosePrimaryLocked(now); i != 0 {
		t.Fatal("handshake alone counted as capacity evidence")
	}
	seedEvidence(&c.laneMetrics[0].delivery, now, 1e6, 2)
	for n := 0; n < 4; n++ {
		if i, why := c.choosePrimaryLocked(now); i != 1 || why != "bounded_trial" {
			t.Fatalf("trial %d: %d %s", n, i, why)
		}
	}
	if i, _ := c.choosePrimaryLocked(now); i != 0 {
		t.Fatal("unbounded trial starts")
	}
	seedEvidence(&c.laneMetrics[1].delivery, now, 1.5e6, 1)
	if i, _ := c.choosePrimaryLocked(now); i != 0 {
		t.Fatal("one good window promoted spare")
	}
	seedEvidence(&c.laneMetrics[1].delivery, now, 1.5e6, 2)
	if i, why := c.choosePrimaryLocked(now); i != 1 || why != "proven_spill" {
		t.Fatalf("qualified spare unused: %d %s", i, why)
	}
	c.laneActive[1] = 1
	if i, _ := c.choosePrimaryLocked(now); i != 0 {
		t.Fatal("spill ignored active-flow share bound")
	}
	c.laneActive[1] = 0
	seedEvidence(&c.laneMetrics[1].delivery, now.Add(-16*time.Second), 2e6, 2)
	if i, _ := c.choosePrimaryLocked(now); i != 0 {
		t.Fatal("expired evidence reused")
	}
}
func TestDeliveryEvidenceRequiresSustainedReads(t *testing.T) {
	d := new(deliveryEvidence)
	now := time.Now()
	d.observe(1, now.UnixNano())
	d.observe(512<<10, now.Add(100*time.Millisecond).UnixNano())
	if _, ok := d.proof(now, 1); ok {
		t.Fatal("short burst qualified")
	}
	d.observe(1, now.Add(600*time.Millisecond).UnixNano())
	if _, ok := d.proof(now.Add(600*time.Millisecond), 2); ok {
		t.Fatal("one window qualified as two")
	}
	d.observe(512<<10, now.Add(1200*time.Millisecond).UnixNano())
	if _, ok := d.proof(now.Add(1200*time.Millisecond), 2); !ok {
		t.Fatal("sustained evidence missing")
	}
	if _, ok := d.proof(now.Add(20*time.Second), 1); ok {
		t.Fatal("stale proof survived")
	}
}
func TestPrimaryIdleRetirementCannotCloseReusedSpare(t *testing.T) {
	c, _, stop := primaryFixture(t)
	defer stop()
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if e := c.lanes[1].Warm(ctx); e != nil {
		t.Fatal(e)
	}
	c.mu.Lock()
	c.scheduleSpareIdleLocked()
	epoch, seq := c.epoch, c.spareIdleSeq
	c.cancelSpareIdleLocked()
	c.mu.Unlock()
	c.expireSpare(epoch, seq)
	if ready, _ := c.lanes[1].laneReady(); !ready {
		t.Fatal("stale idle callback closed reused spare")
	}
	c.mu.Lock()
	c.scheduleSpareIdleLocked()
	epoch, seq = c.epoch, c.spareIdleSeq
	c.mu.Unlock()
	c.expireSpare(epoch, seq)
	if ready, _ := c.lanes[1].laneReady(); ready {
		t.Fatal("idle spare not released")
	}
}

func TestPrimaryLoadEvidenceDoesNotExcludeSlowTransfers(t *testing.T) {
	d := new(deliveryEvidence)
	now := time.Now()
	for i := 0; i < 3; i++ {
		d.observe(16<<10, now.Add(time.Duration(i)*time.Second).UnixNano())
	}
	if _, ok := d.proof(now.Add(2*time.Second), 1); ok {
		t.Fatal("slow reads counted as strong capacity proof")
	}
	if _, ok := d.load(now.Add(2 * time.Second)); !ok {
		t.Fatal("slow ongoing primary could never try a spare")
	}
	if _, ok := d.load(now.Add(8 * time.Second)); ok {
		t.Fatal("old busy state stayed active")
	}
}
