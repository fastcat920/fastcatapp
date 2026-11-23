package fcn

import (
	quic "github.com/metacubex/quic-go"
	"time"
)

type recoverySignal struct {
	physical *physical
	lastLost uint64
	until    time.Time
}

func (s *recoverySignal) remaining(now time.Time) time.Duration {
	if s.until.After(now) {
		return s.until.Sub(now)
	}
	return 0
}
func (s *recoverySignal) update(p *physical, stats quic.ConnectionStats, now time.Time) bool {
	if p == nil {
		*s = recoverySignal{}
		return false
	}
	changed := s.physical != p
	if changed {
		*s = recoverySignal{physical: p}
	}
	recentLoss := stats.PacketsLost > s.lastLost
	s.lastLost = stats.PacketsLost
	inflated := stats.MinRTT > 0 && stats.LatestRTT > 250*time.Millisecond && stats.LatestRTT > stats.MinRTT*5/2
	if recentLoss || inflated {
		hold := stats.SmoothedRTT * 2
		if hold < 300*time.Millisecond {
			hold = 300 * time.Millisecond
		}
		if hold > time.Second {
			hold = time.Second
		}
		s.until = now.Add(hold)
	}
	return s.remaining(now) > 0
}
func (c *Client) recoverySnapshot() (*physical, quic.ConnectionStats) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.closed || c.pool == nil || c.pool.retired || !c.pool.alive() {
		return nil, quic.ConnectionStats{}
	}
	return c.pool, c.pool.q.ConnectionStats()
}
func (c *Client) refineRecoveryLocked(base int, now time.Time) int {
	var ready, bad [2]bool
	for i, child := range c.lanes {
		p, s := child.recoverySnapshot()
		ready[i] = p != nil
		bad[i] = c.recovery[i].update(p, s, now)
	}
	other := 1 - base
	if !ready[base] || !bad[base] || !ready[other] || bad[other] {
		return base
	}
	if !c.recoverySwitchAt.IsZero() && other != c.recoveryLastLane && now.Sub(c.recoverySwitchAt) < 500*time.Millisecond {
		return base
	}
	if c.recoverySwitchAt.IsZero() || other != c.recoveryLastLane {
		c.recoverySwitchAt = now
		c.recoveryLastLane = other
	}
	return other
}
