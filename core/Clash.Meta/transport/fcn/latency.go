package fcn

import (
	"sync/atomic"
	"time"
)

// Wait samples expire so old destination delays do not permanently poison a lane.
// No target, credential, payload or QUIC connection identifier is retained.
type waitEstimate struct{ us, at atomic.Int64 }

func (w *waitEstimate) observe(d time.Duration, now time.Time) {
	n := d.Microseconds()
	if n < 1 {
		n = 1
	}
	if n > 5000000 {
		n = 5000000
	}
	for {
		old := w.us.Load()
		next := n
		if old > 0 && now.UnixNano()-w.at.Load() < int64(10*time.Second) {
			next = (old*3 + n) / 4
		}
		if w.us.CompareAndSwap(old, next) {
			break
		}
	}
	w.at.Store(now.UnixNano())
}
func (w *waitEstimate) value(now time.Time) time.Duration {
	if at := w.at.Load(); at == 0 || now.UnixNano()-at > int64(10*time.Second) {
		return 0
	}
	return time.Duration(w.us.Load()) * time.Microsecond
}

type laneLatency struct {
	assignedAt                                     time.Time // parent Client.mu
	windowAt                                       time.Time
	windowRX, windowTX, deltaRX, deltaTX, windowMS int64
	writtenBytes                                   atomic.Int64

	opening, heavy, readBytes atomic.Int64
	setup, firstRead          waitEstimate
}
type LaneState struct {
	RecoveryHoldMS    int64  `json:"recovery_hold_ms,omitempty"`
	RecoveryLoss      uint64 `json:"recovery_loss,omitempty"`
	WindowReadBytes   int64  `json:"window_read_bytes"`
	WindowWriteBytes  int64  `json:"window_write_bytes"`
	WindowMS          int64  `json:"window_ms"`
	WrittenBytes      int64  `json:"written_bytes"`
	Ready             bool   `json:"ready"`
	Active            int    `json:"active"`
	Opening           int64  `json:"opening"`
	Heavy             int64  `json:"heavy"`
	PendingWriteBytes int64  `json:"pending_write_bytes"`
	ReadBytes         int64  `json:"read_bytes"`
	RTTUS             int64  `json:"rtt_us"`
	SetupEWMAUS       int64  `json:"setup_ewma_us"`
	FirstReadEWMAUS   int64  `json:"first_read_ewma_us"`
	ScoreUS           int64  `json:"score_us"`
}
type LaneSelection struct {
	Request    uint64       `json:"request"`
	Generation uint64       `json:"generation"`
	Lane       int          `json:"lane"`
	Policy     string       `json:"policy"`
	Lanes      [2]LaneState `json:"lanes"`
}
type LaneEvent struct {
	Stage        string        `json:"stage"`
	Selection    LaneSelection `json:"selection"`
	DurationUS   int64         `json:"duration_us,omitempty"`
	OK           bool          `json:"ok"`
	ReadBytes    int64         `json:"read_bytes,omitempty"`
	WrittenBytes int64         `json:"written_bytes,omitempty"`
}
type LaneObservation struct {
	Selection       LaneSelection `json:"selection"`
	FirstReadWaitUS int64         `json:"first_read_wait_us"`
	ReadBytes       int64         `json:"read_bytes"`
	WrittenBytes    int64         `json:"written_bytes"`
}

func (c *laneConn) LaneObservation() LaneObservation {
	return LaneObservation{c.selection, c.firstReadWait.Load(), c.readBytes.Load(), c.writeBytes.Load()}
}
func (c *laneConn) finishOpening() { c.openingDone.Do(func() { c.metrics.latency.opening.Add(-1) }) }
func (c *laneConn) observeRead(n int) {
	now := time.Now()
	c.metrics.latency.readBytes.Add(int64(n))
	total := c.readBytes.Add(int64(n))
	c.openingDone.Do(func() {
		c.metrics.latency.opening.Add(-1)
		if at := c.firstWrite.Load(); at > 0 {
			wait := now.Sub(time.Unix(0, at))
			c.firstReadWait.Store(wait.Microseconds())
			c.metrics.latency.firstRead.observe(wait, now)
		}
	})
	if total >= 256<<10 {
		c.bulkMu.Lock()
		if !c.heavy && !c.ended {
			c.heavy = true
			c.metrics.latency.heavy.Add(1)
		}
		c.bulkMu.Unlock()
	}
}
func latencyScore(s LaneState) int64 {
	rtt := s.RTTUS
	if rtt <= 0 {
		rtt = 150000
	}
	if rtt < 20000 {
		rtt = 20000
	}
	if rtt > 800000 {
		rtt = 800000
	}
	setup := s.SetupEWMAUS
	if setup > 2*rtt {
		setup = 2 * rtt
	}
	first := s.FirstReadEWMAUS
	if first > 4*rtt {
		first = 4 * rtt
	}
	pending := s.PendingWriteBytes / 16384
	if pending > 4 {
		pending = 4
	}
	if pending < 0 {
		pending = 0
	}
	// Throughput is not a capacity discount: high bulk delivery must not attract
	// all new short/unknown flows. Each stream is still assigned exactly once.
	return rtt + setup/3 + first/2 + int64(s.Active)*rtt/3 + s.Opening*rtt + s.Heavy*rtt*3/2 + pending*rtt/2
}
func (c *Client) laneStatesLocked(now time.Time) (out [2]LaneState) {
	for i := range c.lanes {
		ready, rtt := c.lanes[i].laneReady()
		m := c.laneMetrics[i]
		s := LaneState{Ready: ready, Active: c.laneActive[i], Opening: m.latency.opening.Load(), Heavy: m.latency.heavy.Load(), PendingWriteBytes: m.pending.Load(), ReadBytes: m.latency.readBytes.Load(), RTTUS: rtt.Microseconds(), SetupEWMAUS: m.latency.setup.value(now).Microseconds(), FirstReadEWMAUS: m.latency.firstRead.value(now).Microseconds()}
		if c.cfg.RecoveryAware {
			s.RecoveryHoldMS = c.recovery[i].remaining(now).Milliseconds()
			s.RecoveryLoss = c.recovery[i].lastLost
		}
		s.WindowReadBytes, s.WindowWriteBytes, s.WindowMS = m.latency.window(now)
		s.WrittenBytes = m.latency.writtenBytes.Load()
		s.ScoreUS = latencyScore(s)
		out[i] = s
	}
	return
}
func (c *Client) selectionLocked(i int, now time.Time) LaneSelection {
	policy := "adaptive"
	if c.cfg.RecoveryAware {
		policy = "recovery"
	}
	if c.cfg.LatencyAware {
		policy = "latency"
		if c.cfg.ReserveInteractive {
			policy = "reserve"
		}
	}
	if c.cfg.PrimaryPreferred {
		policy = "primary"
	}
	return LaneSelection{c.laneSequence, c.epoch, i, policy, c.laneStatesLocked(now)}
}
func (c *Client) chooseLatencyLocked(now time.Time) int {
	s := c.laneStatesLocked(now)
	i := 0
	if s[1].Ready && (!s[0].Ready || s[1].ScoreUS < s[0].ScoreUS) {
		i = 1
	}
	i = c.refineLatencyLocked(i, s, now)
	other := 1 - i
	if c.laneActive[0]+c.laneActive[1] > 0 && !s[other].Ready {
		c.prepareLaneLocked(other)
	}
	return i
}

// Cold requests have unknown payload sizes. At most the first two in-flight
// opens share startup affinity, for <=250ms, and only while the sibling is ready
// and has a comparable path. Later traffic is free to use either lane.
func (c *Client) refineLatencyLocked(best int, s [2]LaneState, now time.Time) int {
	preferred := best
	if c.cfg.ReserveInteractive && s[0].Ready && s[1].Ready {
		if s[0].Active+s[1].Active == 1 {
			busy := 0
			if s[1].Active == 1 {
				busy = 1
			}
			other := 1 - busy
			age := now.Sub(c.laneMetrics[busy].latency.assignedAt)
			if s[busy].Opening == 1 && s[busy].Heavy == 0 && age >= 0 && age <= 250*time.Millisecond && comparablePath(s[busy], s[other]) {
				preferred = busy
			}
		}
		// Prefer the lane with no established bulk flow only if its observed path is
		// comparable. This is an admission preference, never a bandwidth reservation.
		if s[0].Heavy+s[1].Heavy > 0 && (s[0].Heavy == 0 || s[1].Heavy == 0) {
			light := 0
			if s[0].Heavy > 0 {
				light = 1
			}
			other := 1 - light
			if s[light].Opening <= 1 && comparablePath(s[light], s[other]) {
				preferred = light
			}
		}
	}
	if c.cfg.ScheduleHysteresis && c.laneStreak > 0 && s[0].Ready && s[1].Ready {
		prev := c.lastLane
		// Never override an explicit reserve preference or hold a substantially worse lane.
		if preferred == best && preferred != prev && now.Sub(c.laneSwitchAt) < 200*time.Millisecond && c.laneStreak < 3 && s[prev].ScoreUS*100 <= s[preferred].ScoreUS*115 {
			preferred = prev
		}
		other := 1 - preferred
		if preferred == prev && c.laneStreak >= 3 && s[other].ScoreUS*100 <= s[preferred].ScoreUS*125 {
			preferred = other
		}
	}
	if c.laneStreak == 0 || preferred != c.lastLane {
		c.lastLane = preferred
		c.laneStreak = 1
		c.laneSwitchAt = now
	} else {
		c.laneStreak++
	}
	return preferred
}
func comparablePath(a, b LaneState) bool {
	ar, br := a.RTTUS, b.RTTUS
	if ar <= 0 {
		ar = 150000
	}
	if br <= 0 {
		br = 150000
	}
	if ar > br*3/2+25000 {
		return false
	}
	if a.FirstReadEWMAUS > 0 && b.FirstReadEWMAUS > 0 && a.FirstReadEWMAUS > b.FirstReadEWMAUS*2+100000 {
		return false
	}
	return true
}

// window is called under parent Client.mu; counters themselves are atomic.
func (m *laneLatency) window(now time.Time) (int64, int64, int64) {
	rx, tx := m.readBytes.Load(), m.writtenBytes.Load()
	if m.windowAt.IsZero() {
		m.windowAt = now
		m.windowRX = rx
		m.windowTX = tx
		return 0, 0, 0
	}
	elapsed := now.Sub(m.windowAt)
	if elapsed > 3*time.Second {
		m.deltaRX = 0
		m.deltaTX = 0
		m.windowMS = 0
		m.windowAt = now
		m.windowRX = rx
		m.windowTX = tx
		return 0, 0, 0
	}
	if elapsed >= 200*time.Millisecond {
		m.deltaRX = rx - m.windowRX
		m.deltaTX = tx - m.windowTX
		m.windowMS = elapsed.Milliseconds()
		m.windowRX = rx
		m.windowTX = tx
		m.windowAt = now
	}
	return m.deltaRX, m.deltaTX, m.windowMS
}
