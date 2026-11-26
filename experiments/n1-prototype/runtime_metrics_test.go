package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestRuntimeMetricsPrivateBoundedAndReleased(t *testing.T) {
	p := filepath.Join(t.TempDir(), "metrics.jsonl")
	n := &node{slots: make(chan struct{}, 2)}
	stop, e := startRuntimeMetrics(p, n, make(chan struct{}, 2))
	if e != nil {
		t.Fatal(e)
	}
	if _, e = startRuntimeMetrics(p, n, make(chan struct{}, 2)); e == nil {
		t.Fatal("concurrent file writer allowed")
	}
	stop()
	stop()
	f, e := os.Stat(p)
	if e != nil || f.Mode().Perm() != 0600 || f.Size() == 0 {
		t.Fatal(e, f)
	}
	link := filepath.Join(t.TempDir(), "linked")
	os.Symlink(p, link)
	if _, e = startRuntimeMetrics(link, n, make(chan struct{}, 2)); e == nil {
		t.Fatal("symlink followed")
	}
}

func TestClientRuntimeMetricsWithoutServerState(t *testing.T) {
	p := filepath.Join(t.TempDir(), "client.jsonl")
	stop, e := startRuntimeMetrics(p, nil, nil)
	if e != nil {
		t.Fatal(e)
	}
	stop()
	if b, e := os.ReadFile(p); e != nil || len(b) == 0 {
		t.Fatal(e)
	}
}
