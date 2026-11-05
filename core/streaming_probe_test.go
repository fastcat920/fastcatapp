package main

import (
	"testing"
	"time"
)

func TestStreamingRunCancellation(t *testing.T) {
	id := "cancel-active"
	ctx1, done1 := acquireStreamingRun(id)
	defer done1()
	ctx2, done2 := acquireStreamingRun(id)
	defer done2()
	cancelStreamingProbes(id)
	for _, ctx := range []<-chan struct{}{ctx1.Done(), ctx2.Done()} {
		select {
		case <-ctx:
		case <-time.After(time.Second):
			t.Fatal("request was not cancelled")
		}
	}
	late, release := acquireStreamingRun(id)
	defer release()
	if late.Err() == nil {
		t.Fatal("late request restarted a cancelled run")
	}
	unrelated, finish := acquireStreamingRun("unrelated")
	defer finish()
	if unrelated.Err() != nil {
		t.Fatal("cancelled another run")
	}
}

func TestStreamingCancelBeforeRequest(t *testing.T) {
	cancelStreamingProbes("cancel-before")
	ctx, release := acquireStreamingRun("cancel-before")
	defer release()
	if ctx.Err() == nil {
		t.Fatal("cancel-before-start must be retained")
	}
}
