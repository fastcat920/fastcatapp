package main

import (
	"bytes"
	"context"
	"io"
	"sync/atomic"
	"testing"
	"time"
)

func TestProgressReaderPreservesBodyAndCount(t *testing.T) {
	body := bytes.Repeat([]byte("abcd"), 10000)
	total := 0
	var out bytes.Buffer
	n, e := io.Copy(&out, &progressReader{r: bytes.NewReader(body), progress: func(n int) { total += n }})
	if e != nil || n != int64(len(body)) || total != len(body) || !bytes.Equal(out.Bytes(), body) {
		t.Fatal(n, total, e)
	}
}
func TestMixedReadinessWaitsForBothOrCancellation(t *testing.T) {
	ch := make(chan struct{}, 2)
	var count atomic.Int64
	count.Store(1)
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	start := time.Now()
	awaitMixedReady(ctx, ch, &count, time.Second)
	if time.Since(start) > 100*time.Millisecond {
		t.Fatal("cancellation ignored")
	}
	ctx = context.Background()
	done := make(chan struct{})
	go func() { awaitMixedReady(ctx, ch, &count, time.Second); close(done) }()
	select {
	case <-done:
		t.Fatal("one background treated as both ready")
	case <-time.After(10 * time.Millisecond):
	}
	count.Store(2)
	ch <- struct{}{}
	select {
	case <-done:
	case <-time.After(time.Second):
		t.Fatal("both ready did not release foreground")
	}
	count.Store(0)
	start = time.Now()
	awaitMixedReady(ctx, ch, &count, 10*time.Millisecond)
	if time.Since(start) > 100*time.Millisecond {
		t.Fatal("readiness wait unbounded")
	}
}
