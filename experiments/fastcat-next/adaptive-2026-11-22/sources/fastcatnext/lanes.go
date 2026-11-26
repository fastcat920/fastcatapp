package fastcatnext

import (
	"context"
	"net"
	"sync"
	"sync/atomic"
	"time"
)

type laneMetrics struct {
	bytes     atomic.Int64
	pending   atomic.Int64
	progress  atomic.Int64
	sampled   int64 // fields below are guarded by parent Client.mu
	sampledAt time.Time
	rate      float64
}

func (m *laneMetrics) sample(now time.Time) float64 {
	n := m.bytes.Load()
	if m.sampledAt.IsZero() {
		m.sampledAt = now
		m.sampled = n
		return 0
	}
	elapsed := now.Sub(m.sampledAt)
	if elapsed > 3*time.Second {
		m.rate = 0
	}
	if elapsed >= 200*time.Millisecond {
		delta := n - m.sampled
		if delta >= 64<<10 && elapsed <= 3*time.Second {
			rate := float64(delta) / elapsed.Seconds()
			if m.rate == 0 {
				m.rate = rate
			} else {
				m.rate = m.rate*.75 + rate*.25
			}
		}
		m.sampledAt = now
		m.sampled = n
	}
	if last := m.progress.Load(); last == 0 || now.Sub(time.Unix(0, last)) > 3*time.Second {
		m.rate = 0
		return 0
	}
	return m.rate
}

func (c *Client) laneReady() (bool, time.Duration) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.closed || c.pool == nil || c.pool.retired || !c.pool.alive() {
		return false, 0
	}
	return true, c.pool.q.ConnectionStats().SmoothedRTT
}

// Never wait for a new handshake in Dial. Optional background work is bounded
// to one attempt per second and is canceled on Reset / Close.
func (c *Client) prepareLaneLocked(i int) <-chan struct{} {
	if c.closed {
		return nil
	}
	if ready, _ := c.lanes[i].laneReady(); ready {
		return nil
	}
	if done := c.laneWarming[i]; done != nil {
		return done
	}
	if !c.laneWarmLast[i].IsZero() && time.Since(c.laneWarmLast[i]) < time.Second {
		return nil
	}
	ctx, cancel := context.WithTimeout(c.ctx, time.Second)
	done := make(chan struct{})
	epoch := c.epoch
	c.laneWarming[i] = done
	c.laneWarmCancel[i] = cancel
	c.laneWarmLast[i] = time.Now()
	go func() {
		defer close(done)
		defer cancel()
		_ = c.lanes[i].Warm(ctx)
		c.mu.Lock()
		defer c.mu.Unlock()
		if c.epoch == epoch {
			c.laneWarming[i] = nil
			c.laneWarmCancel[i] = nil
		}
	}()
	return done
}

func laneScore(active int, rate, fastest float64, rtt time.Duration, pending int64) float64 {
	// Limit quality weighting so a fast sample cannot monopolize all new streams.
	capacity := 1.0
	if rate > 0 && fastest > 0 {
		capacity = rate / fastest * 1.5
		if capacity < .5 {
			capacity = .5
		}
		if capacity > 1.5 {
			capacity = 1.5
		}
	}
	delay := 1.0
	if rtt > 200*time.Millisecond {
		delay = float64(rtt) / float64(200*time.Millisecond)
		if delay > 2 {
			delay = 2
		}
	}
	queued := float64(pending) / float64(256<<10)
	if queued > 1 {
		queued = 1
	}
	return (float64(active+1) + queued) * delay / capacity
}

// Assign each new stream once. Existing streams never move or replay bytes.
func (c *Client) dialLane(ctx context.Context, target string) (net.Conn, error) {
	c.mu.Lock()
	if c.closed {
		c.mu.Unlock()
		return nil, net.ErrClosed
	}
	i := 0
	if !c.cfg.AdaptiveLanes {
		for j := 1; j < len(c.lanes); j++ {
			if c.laneActive[j] < c.laneActive[i] {
				i = j
			}
		}
	} else {
		now := time.Now()
		ready := [2]bool{}
		rtt := [2]time.Duration{}
		rates := [2]float64{}
		fastest := 0.0
		for j := range c.lanes {
			ready[j], rtt[j] = c.lanes[j].laneReady()
			rates[j] = c.laneMetrics[j].sample(now)
			if rates[j] > fastest {
				fastest = rates[j]
			}
		}
		if ready[1] && !ready[0] {
			i = 1
		} else if ready[0] && ready[1] {
			if c.laneActive[0] == 0 {
				i = 0
			} else if c.laneActive[1] == 0 {
				i = 1
			} else if laneScore(c.laneActive[1], rates[1], fastest, rtt[1], c.laneMetrics[1].pending.Load()) < laneScore(c.laneActive[0], rates[0], fastest, rtt[0], c.laneMetrics[0].pending.Load()) {
				i = 1
			}
		}
		other := 1 - i
		if c.laneActive[0]+c.laneActive[1] > 0 && !ready[other] {
			c.prepareLaneLocked(other)
		}
	}
	epoch := c.epoch
	metric := c.laneMetrics[i]
	c.laneActive[i]++
	c.mu.Unlock()
	release := func() {
		c.mu.Lock()
		if c.epoch == epoch {
			c.laneActive[i]--
		}
		c.mu.Unlock()
	}
	n, err := c.lanes[i].Dial(ctx, target)
	if err != nil {
		release()
		return nil, err
	}
	c.mu.Lock()
	stale := c.closed || c.epoch != epoch
	c.mu.Unlock()
	if stale {
		n.Close()
		release()
		return nil, net.ErrClosed
	}
	return &laneConn{Conn: n, release: release, metrics: metric, measure: c.cfg.AdaptiveLanes}, nil
}

type laneConn struct {
	net.Conn
	once    sync.Once
	release func()
	metrics *laneMetrics
	measure bool
}

func (c *laneConn) Read(p []byte) (int, error) {
	n, e := c.Conn.Read(p)
	if c.measure && n > 0 {
		c.metrics.bytes.Add(int64(n))
		c.metrics.progress.Store(time.Now().UnixNano())
	}
	return n, e
}
func (c *laneConn) Write(p []byte) (int, error) {
	if c.measure {
		c.metrics.pending.Add(int64(len(p)))
		defer c.metrics.pending.Add(-int64(len(p)))
	}
	n, e := c.Conn.Write(p)
	if c.measure && n > 0 {
		c.metrics.bytes.Add(int64(n))
		c.metrics.progress.Store(time.Now().UnixNano())
	}
	return n, e
}
func (c *laneConn) Close() error      { e := c.Conn.Close(); c.once.Do(c.release); return e }
func (c *laneConn) CloseWrite() error { return c.Conn.(interface{ CloseWrite() error }).CloseWrite() }
