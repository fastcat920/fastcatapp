package fcn

import (
	"math"
	"sync/atomic"
	"time"
)

// Positive read evidence only. Silence or a slow destination never retires an
// entry. The sampler is non-blocking on the read path and rejects short bursts.
type deliveryEvidence struct {
	lastRead             atomic.Int64
	loadAt               atomic.Int64
	loadRate             atomic.Uint64
	loadStart, loadBytes int64
	received             atomic.Int64
	busy                 atomic.Bool
	at, baseline         int64 // guarded by busy
	rate                 atomic.Uint64
	proofAt              atomic.Int64
	windows              atomic.Int32
}

func (d *deliveryEvidence) observe(n int, now int64) {
	total := d.received.Add(int64(n))
	d.lastRead.Store(now)
	if !d.busy.CompareAndSwap(false, true) {
		return
	}
	defer d.busy.Store(false)
	if d.loadStart == 0 {
		d.loadStart = now
		d.loadBytes = total
	} else if elapsed := now - d.loadStart; elapsed >= int64(2*time.Second) || elapsed < 0 {
		if elapsed > 0 && elapsed <= int64(4*time.Second) && total-d.loadBytes >= 32<<10 {
			d.loadAt.Store(now)
			d.loadRate.Store(math.Float64bits(float64(total-d.loadBytes) / float64(elapsed) * 1e9))
		} else {
			d.loadAt.Store(0)
		}
		d.loadStart = now
		d.loadBytes = total
	}
	if d.at == 0 {
		d.at = now
		d.baseline = total
		return
	}
	elapsed := now - d.at
	if elapsed >= 0 && elapsed < int64(500*time.Millisecond) {
		return
	}
	delta := total - d.baseline
	d.at = now
	d.baseline = total
	if elapsed <= 0 || elapsed > int64(3*time.Second) {
		d.windows.Store(0)
		d.proofAt.Store(0)
		d.rate.Store(0)
		return
	}
	if delta < 256<<10 {
		return
	}
	rate := float64(delta) / float64(elapsed) * 1e9
	last := d.proofAt.Load()
	if last != 0 && now-last < int64(15*time.Second) {
		rate = .75*math.Float64frombits(d.rate.Load()) + .25*rate
	} else {
		d.windows.Store(0)
	}
	d.rate.Store(math.Float64bits(rate))
	d.proofAt.Store(now)
	if d.windows.Load() < 2 {
		d.windows.Add(1)
	}
}
func (d *deliveryEvidence) proof(now time.Time, minWindows int32) (float64, bool) {
	at := d.proofAt.Load()
	age := now.UnixNano() - at
	if at == 0 || age < 0 || age > int64(15*time.Second) || d.windows.Load() < minWindows {
		return 0, false
	}
	rate := math.Float64frombits(d.rate.Load())
	return rate, rate > 0
}

func (d *deliveryEvidence) load(now time.Time) (float64, bool) {
	at := d.loadAt.Load()
	last := d.lastRead.Load()
	ns := now.UnixNano()
	if at == 0 || ns-at < 0 || ns-at > int64(3*time.Second) || ns-last > int64(2*time.Second) {
		return 0, false
	}
	rate := math.Float64frombits(d.loadRate.Load())
	return rate, rate > 0
}

// A ready handshake alone is not evidence of spare download capacity. Cold
// batches stay on one connection. Under sustained load, allow one trial at a
// time, at most four starts / five seconds; received trial bytes bound further
// starts, never truncate an already assigned flow.
func (c *Client) choosePrimaryLocked(now time.Time) (int, string) {
	ready0, rtt0 := c.lanes[0].laneReady()
	ready1, rtt1 := c.lanes[1].laneReady()
	if !ready0 {
		if ready1 {
			c.prepareLaneLocked(0)
			return 1, "primary_unavailable"
		}
		return 0, "primary"
	}
	primaryRate, busy := c.laneMetrics[0].delivery.load(now)
	if rate, ok := c.laneMetrics[0].delivery.proof(now, 1); ok {
		primaryRate = rate
	}

	if c.laneActive[0] < 2 || !busy {
		return 0, "primary"
	}
	if !ready1 {
		c.prepareLaneLocked(1)
		return 0, "preparing_spare"
	}
	spareRate, proven := c.laneMetrics[1].delivery.proof(now, 2)
	if proven && spareRate >= primaryRate*1.25 && (rtt1 <= rtt0*3/2 || rtt1 <= rtt0+25*time.Millisecond) && (c.laneActive[1]+1)*3 <= c.laneActive[0] {
		c.laneSpills++
		return 1, "proven_spill"
	}
	if c.laneActive[1] != 0 {
		return 0, "primary"
	}
	received := c.laneMetrics[1].delivery.received.Load()
	if c.probeWindow.IsZero() || now.Sub(c.probeWindow) >= 5*time.Second {
		c.probeWindow = now
		c.probeCount = 0
		c.probeBytes = received
	}
	if c.probeCount < 4 && received-c.probeBytes < 64<<10 {
		c.probeCount++
		c.laneTrials++
		return 1, "bounded_trial"
	}
	return 0, "primary"
}
func (c *Client) cancelSpareIdleLocked() {
	c.spareIdleSeq++
	if c.spareIdle != nil {
		c.spareIdle.Stop()
		c.spareIdle = nil
	}
}
func (c *Client) scheduleSpareIdleLocked() {
	if c.closed || !c.cfg.PrimaryPreferred || c.laneActive[1] != 0 {
		return
	}
	c.cancelSpareIdleLocked()
	epoch, seq := c.epoch, c.spareIdleSeq
	c.spareIdle = time.AfterFunc(15*time.Second, func() { c.expireSpare(epoch, seq) })
}
func (c *Client) expireSpare(epoch, seq uint64) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.closed || c.epoch != epoch || c.spareIdleSeq != seq || c.laneActive[1] != 0 {
		return
	}
	c.cancelSpareIdleLocked()
	c.lanes[1].Reset()
	c.laneMetrics[1] = new(laneMetrics)
	c.probeWindow = time.Time{}
	c.probeCount = 0
	c.probeBytes = 0

}

type LaneUsage struct {
	LiveWireSent     uint64    `json:"live_wire_sent"`
	LiveWireReceived uint64    `json:"live_wire_received"`
	LiveSessions     int       `json:"live_sessions"`
	Assigned         [2]uint64 `json:"tcp_assignments"`
	Trials           uint64    `json:"trial_assignments"`
	Spills           uint64    `json:"proven_spill_assignments"`
}

func (c *Client) LaneUsage() LaneUsage {
	c.mu.Lock()
	defer c.mu.Unlock()
	u := LaneUsage{Assigned: c.laneAssigned, Trials: c.laneTrials, Spills: c.laneSpills}
	for _, child := range c.lanes {
		n := child.LaneUsage()
		u.LiveWireSent += n.LiveWireSent
		u.LiveWireReceived += n.LiveWireReceived
		u.LiveSessions += n.LiveSessions
	}
	for p := range c.all {
		if p.q != nil {
			n := p.q.ConnectionStats()
			u.LiveWireSent += n.BytesSent
			u.LiveWireReceived += n.BytesReceived
			u.LiveSessions++
		}
	}
	return u
}
