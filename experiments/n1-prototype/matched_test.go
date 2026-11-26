package main

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestMatchedStreamingStagesAndSizes(t *testing.T) {
	cfg, n, _ := fixtureWithEmission(t, "coalesced")
	n.controls = true
	source := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		s, e := parseWorkloadLimit(r.URL.Query(), 32*1024*1024)
		if e != nil {
			t.Error(e)
			return
		}
		servePattern(w, r, s, false)
	}))
	defer source.Close()
	target := strings.TrimPrefix(source.URL, "http://")
	n.targets[target] = true
	// Derive a real N1 write shape with no premature upload close.
	cfg.ClientEmission = "coalesced"
	var events []writeEvent
	c, e := dialObserved(context.Background(), cfg, target, func(v writeEvent) { events = append(events, v) })
	if e != nil {
		t.Fatal(e)
	}
	defer c.Close()
	c.conn.SetDeadline(time.Now().Add(5 * time.Second))
	req := "GET /bytes?n=1024&chunk=512&gap_ms=1 HTTP/1.1\r\nHost: origin\r\nConnection: close\r\n\r\n"
	if _, e = io.WriteString(c, req); e != nil {
		t.Fatal(e)
	}
	if _, e = io.ReadAll(c); e != nil {
		t.Fatal(e)
	}
	if e = c.CloseWrite(); e != nil {
		t.Fatal(e)
	}
	if e = c.Close(); e != nil {
		t.Fatal(e)
	}
	if len(events) != 3 {
		t.Fatal(events)
	}
	shape := fmt.Sprintf("%d,%d,%d", events[0].Bytes, events[1].BodyBytes, events[2].BodyBytes)
	for _, gap := range []int{0, 1} {
		if e = runMatchedRPC(cfg, workload{N: 4096, Chunk: 512, GapMS: gap}, shape); e != nil {
			t.Fatal(e)
		}
	}
	for _, bad := range []string{"", "1,2,3", "300,9999,10", "300,100,40"} {
		if _, e = parseMatchShape(bad); e == nil {
			t.Fatal("invalid shape", bad)
		}
	}
}
func TestMatchedControlDisabled(t *testing.T) {
	_, n, _ := fixture(t)
	w := httptest.NewRecorder()
	r := httptest.NewRequest("POST", "https://example.com/j", nil)
	n.ServeHTTP(w, r)
	if w.Code != 404 {
		t.Fatal(w.Code)
	}
}
