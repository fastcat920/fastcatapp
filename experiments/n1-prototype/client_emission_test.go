package main

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"strings"
	"sync"
	"testing"
	"time"
)

func TestClientEmissionTraceAndCompatibility(t *testing.T) {
	for _, server := range []string{"legacy", "coalesced"} {
		for _, client := range []string{"legacy", "coalesced"} {
			t.Run(server+"/"+client, func(t *testing.T) {
				cfg, _, target := fixtureWithEmission(t, server)
				cfg.ClientEmission = client
				var mu sync.Mutex
				var events []writeEvent
				c, e := dialObserved(context.Background(), cfg, target, func(v writeEvent) { mu.Lock(); events = append(events, v); mu.Unlock() })
				if e != nil {
					t.Fatal(e)
				}
				defer c.Close()
				c.conn.SetDeadline(time.Now().Add(5 * time.Second))
				// No aggregation timer or waiting for FIN is allowed for small writes.
				if _, e = c.Write([]byte("x")); e != nil {
					t.Fatal(e)
				}
				var one [1]byte
				if _, e = io.ReadFull(c, one[:]); e != nil || one[0] != 'x' {
					t.Fatal("interactive stall", e)
				}
				if e = c.CloseWrite(); e != nil {
					t.Fatal(e)
				}
				if _, e = io.ReadAll(c); e != nil {
					t.Fatal(e)
				}
				if e = c.CloseWrite(); e != nil {
					t.Fatal(e)
				}
				if _, e = c.Write([]byte("late")); e != io.ErrClosedPipe {
					t.Fatal("late write accepted", e)
				}
				if e = c.Close(); e != nil {
					t.Fatal(e)
				}
				mu.Lock()
				defer mu.Unlock()
				b, _ := json.Marshal(events)
				t.Log("request plaintext writes:", string(b))
				want := 4
				if client == "coalesced" {
					want = 3
				}
				if len(events) != want {
					t.Fatalf("want %d header/DATA/FIN writes, got %s", want, b)
				}
				if events[0].Shape != "request-headers" {
					t.Fatal("missing immediate headers")
				}
				if client == "coalesced" && events[len(events)-1].Shape == "http-ending-only" {
					t.Fatal("unmerged HTTP ending")
				}
			})
		}
	}
}

func TestCoalescedClientBulkAndAuthFailure(t *testing.T) {
	cfg, _, target := fixtureWithEmission(t, "coalesced")
	cfg.ClientEmission = "coalesced"
	c, e := dial(context.Background(), cfg, target)
	if e != nil {
		t.Fatal(e)
	}
	defer c.Close()
	c.conn.SetDeadline(time.Now().Add(5 * time.Second))
	p := bytes.Repeat([]byte("bulk\x00"), 100000)
	done := make(chan error, 1)
	go func() {
		_, e := c.Write(p)
		if e == nil {
			e = c.CloseWrite()
		}
		done <- e
	}()
	got, e := io.ReadAll(c)
	if e != nil {
		t.Fatal(e)
	}
	if e = <-done; e != nil {
		t.Fatal(e)
	}
	if !bytes.Equal(p, got) {
		t.Fatal("bulk mismatch")
	}
	if e = c.Close(); e != nil {
		t.Fatal(e)
	}
	cfg.Key = strings.Repeat("00", 32)
	if bad, e := dial(context.Background(), cfg, target); e == nil {
		bad.Close()
		t.Fatal("bad key accepted")
	}
	cfg.ClientEmission = "typo"
	if _, e = dial(context.Background(), cfg, target); e == nil {
		t.Fatal("unknown profile accepted")
	}
}
