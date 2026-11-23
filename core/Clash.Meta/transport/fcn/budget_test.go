package fcn

import (
	"bytes"
	"context"
	quic "github.com/metacubex/quic-go"
	"io"
	"sync"
	"testing"
	"time"
)

type budgetSink struct {
	bytes.Buffer
	limitedCalls int
}

func (s *budgetSink) WriteWithLimit(p []byte, f func(int) int) (int, error) {
	s.limitedCalls++
	n := f(len(p))
	s.Buffer.Write(p[:n])
	if n < len(p) {
		return n, quic.ErrWriteLimitReached
	}
	return n, nil
}
func TestBudgetContentCancellationAndRelease(t *testing.T) {
	b := newDownstreamBudget()
	bulk := b.open()
	bulk.progress(bulkThreshold)
	fresh := b.open()
	defer fresh.close()
	sink := &budgetSink{}
	w := &budgetWriter{ctx: context.Background(), stream: sink, flow: bulk}
	p := bytes.Repeat([]byte("abcd"), 32<<10)
	n, e := w.Write(p)
	if e != nil || n != len(p) || !bytes.Equal(p, sink.Bytes()) || w.limited == 0 || sink.limitedCalls == 0 {
		t.Fatal(n, e, w.limited)
	}
	fresh.close()
	old := w.limited
	if _, e = w.Write(p); e != nil || w.limited != old {
		t.Fatal("idle budget limited bulk", e)
	}
	fresh = b.open()
	b.mu.Lock()
	b.tokens = 0
	b.epoch = time.Now()
	b.mu.Unlock()
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	w.ctx = ctx
	if _, e = w.Write(p); e != context.Canceled {
		t.Fatal("budget did not cancel", e)
	}
}
func TestBudgetSharedAndConcurrentCredits(t *testing.T) {
	b := newDownstreamBudget()
	bulk := b.open()
	bulk.progress(bulkThreshold)
	f := b.open()
	defer f.close()
	b.mu.Lock()
	b.epoch = time.Now().Add(time.Second)
	b.mu.Unlock()
	var wg sync.WaitGroup
	var mu sync.Mutex
	total := 0
	for i := 0; i < 8; i++ {
		wg.Add(1)
		go func() { defer wg.Done(); n := bulk.take(8 << 10); mu.Lock(); total += n; mu.Unlock() }()
	}
	wg.Wait()
	if total > 16<<10 {
		t.Fatal("unbounded shared burst", total)
	}
}
func TestBudgetServerIntegrityAndCounters(t *testing.T) {
	c, s, stop := fixtureProfileConfig(t, "quic", time.Second, 1, "", func(s *ServerConfig) { s.DownstreamBudget = true })
	defer stop()
	target, _ := echoTarget(t)
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	conn, e := c.Dial(ctx, target)
	if e != nil {
		t.Fatal(e)
	}
	defer conn.Close()
	p := bytes.Repeat([]byte("0123456789abcdef"), 64<<10)
	done := make(chan error, 1)
	go func() { _, e := conn.Write(p); done <- e }()
	out := make([]byte, len(p))
	if _, e = io.ReadFull(conn, out); e != nil || !bytes.Equal(p, out) {
		t.Fatal("bulk corrupted", e)
	}
	if e = <-done; e != nil {
		t.Fatal(e)
	}
	// Counts may be published only after the stream closes; existing integration tests cover final billing.
	if s.Counters().Accepted.Load() != 1 {
		t.Fatal("accepted counter changed")
	}
}
func TestCopyTraceFirstDataAndQueueStages(t *testing.T) {
	var events []Event
	var mu sync.Mutex
	trace := func(e Event) { mu.Lock(); events = append(events, e); mu.Unlock() }
	var out bytes.Buffer
	n, e := copyTrace(context.Background(), &out, bytes.NewBufferString("payload"), trace, "quic", "download")
	if e != nil || n != 7 || out.String() != "payload" {
		t.Fatal(n, e)
	}
	counts := map[string]int{}
	for _, e := range events {
		counts[e.Stage]++
	}
	if counts["download_first_data_ready"] != 1 || counts["download_first_write_accepted"] != 1 || counts["download_end"] != 1 {
		t.Fatal(counts)
	}
}

func TestBudgetFreshLeaseDoesNotHoldBulkForever(t *testing.T) {
	b := newDownstreamBudget()
	bulk := b.open()
	bulk.progress(bulkThreshold)
	fresh := b.open()
	defer fresh.close()
	if !bulk.competing() {
		t.Fatal("missing initial reservation")
	}
	until := time.Now().Add(time.Second)
	for bulk.competing() && time.Now().Before(until) {
		time.Sleep(10 * time.Millisecond)
	}
	if bulk.competing() {
		t.Fatal("silent fresh stream reserved indefinitely")
	}
	if fresh.competing() {
		t.Fatal("expired lease misclassified short stream as bulk")
	}
}
