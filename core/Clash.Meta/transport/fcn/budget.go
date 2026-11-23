package fcn

import (
	"context"
	"errors"
	quic "github.com/metacubex/quic-go"
	"io"
	"sync"
	"time"
)

const bulkThreshold = 256 << 10

// This is a shared, packetization-time burst budget, not an ACK window or rate estimate.
// It applies only when a fresh stream coexists with bulk streams on the same connection.
type downstreamBudget struct {
	mu     sync.Mutex
	fresh  int
	tokens int
	epoch  time.Time
}
type budgetFlow struct {
	b     *downstreamBudget
	fresh bool
	bulk  bool
	timer *time.Timer
	bytes int64
}

func newDownstreamBudget() *downstreamBudget {
	return &downstreamBudget{tokens: 16 << 10, epoch: time.Now()}
}
func (b *downstreamBudget) open() *budgetFlow {
	b.mu.Lock()
	b.fresh++
	f := &budgetFlow{b: b, fresh: true}
	f.timer = time.AfterFunc(500*time.Millisecond, f.close)
	b.mu.Unlock()
	return f
}
func (f *budgetFlow) close() {
	f.b.mu.Lock()
	defer f.b.mu.Unlock()
	if f.timer != nil {
		f.timer.Stop()
	}
	if f.fresh {
		f.fresh = false
		f.b.fresh--
	}
}
func (f *budgetFlow) progress(n int) {
	f.bytes += int64(n)
	if f.bytes >= bulkThreshold {
		f.b.mu.Lock()
		f.bulk = true
		f.b.mu.Unlock()
		f.close()
	}
}
func (f *budgetFlow) competing() bool {
	f.b.mu.Lock()
	defer f.b.mu.Unlock()
	return f.bulk && f.b.fresh > 0
}
func (f *budgetFlow) take(max int) int {
	b := f.b
	b.mu.Lock()
	defer b.mu.Unlock()
	if !f.bulk || b.fresh == 0 {
		return max
	}
	now := time.Now()
	if now.Sub(b.epoch) >= 2*time.Millisecond {
		b.epoch = now
		b.tokens = 16 << 10
	}
	if max > b.tokens {
		max = b.tokens
	}
	b.tokens -= max
	return max
}

type limitedStream interface {
	Write([]byte) (int, error)
	WriteWithLimit([]byte, func(int) int) (int, error)
}
type budgetWriter struct {
	ctx     context.Context
	stream  limitedStream
	flow    *budgetFlow
	trace   Trace
	wait    time.Duration
	limited int
}

func (w *budgetWriter) Write(p []byte) (int, error) {
	total := 0
	for len(p) > 0 {
		size := len(p)
		if size > 16<<10 {
			size = 16 << 10
		}
		part := p[:size]
		var n int
		var err error
		if w.flow.competing() {
			n, err = w.stream.WriteWithLimit(part, w.flow.take)
		} else {
			n, err = w.stream.Write(part)
		}
		w.flow.progress(n)
		total += n
		p = p[n:]
		if errors.Is(err, quic.ErrWriteLimitReached) {
			w.limited++
			start := time.Now()
			timer := time.NewTimer(2 * time.Millisecond)
			select {
			case <-w.ctx.Done():
				timer.Stop()
				return total, w.ctx.Err()
			case <-timer.C:
			}
			w.wait += time.Since(start)
			continue
		}
		if err != nil {
			return total, err
		}
		if n != len(part) {
			return total, io.ErrShortWrite
		}
	}
	return total, nil
}
