package fcn

import (
	"bytes"
	"context"
	"io"
	"net"
	"sync"
	"testing"
	"time"
)

func TestTwoQUICLanesBoundedAndReset(t *testing.T) {
	original, server, stop := fixture(t, "quic", time.Second)
	defer stop()
	cfg := original.cfg
	original.Close()
	cfg.QUICLanes = 2
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	c, err := NewClient(ctx, cfg, "quic")
	if err != nil {
		t.Fatal(err)
	}
	defer c.Close()
	if err = c.Warm(ctx); err != nil {
		t.Fatal(err)
	}
	target, _ := echoTarget(t)
	conns := make([]net.Conn, 4)
	for i := range conns {
		conns[i], err = c.Dial(ctx, target)
		if err != nil {
			t.Fatal(err)
		}
		defer conns[i].Close()
		conns[i].SetDeadline(time.Now().Add(5 * time.Second))
	}
	c.mu.Lock()
	active := append([]int(nil), c.laneActive...)
	c.mu.Unlock()
	if active[0] != 2 || active[1] != 2 {
		t.Fatalf("unbalanced streams: %v", active)
	}
	var wg sync.WaitGroup
	for _, n := range conns {
		wg.Add(1)
		go func(n net.Conn) {
			defer wg.Done()
			payload := bytes.Repeat([]byte{1, 2, 3, 4}, 128<<10)
			written := make(chan error, 1)
			go func() {
				_, e := n.Write(payload)
				if e == nil {
					e = n.(interface{ CloseWrite() error }).CloseWrite()
				}
				written <- e
			}()
			got, e := io.ReadAll(n)
			if e != nil || !bytes.Equal(got, payload) {
				t.Errorf("duplex: %d %v", len(got), e)
			}
			if e = <-written; e != nil {
				t.Error(e)
			}
			n.Close()
			n.Close()
		}(n)
	}
	wg.Wait()
	if got := server.Counters().Sessions.Load(); got != 2 {
		t.Fatalf("sessions=%d, want 2", got)
	}
	c.mu.Lock()
	for _, n := range c.laneActive {
		if n != 0 {
			t.Errorf("reservation leaked: %v", c.laneActive)
		}
	}
	c.mu.Unlock()
	old, err := c.Dial(ctx, target)
	if err != nil {
		t.Fatal(err)
	}
	old.SetDeadline(time.Now().Add(2 * time.Second))
	if _, err = old.Write([]byte("x")); err != nil {
		t.Fatal(err)
	}
	if _, err = io.ReadFull(old, make([]byte, 1)); err != nil {
		t.Fatal(err)
	}
	c.Reset()
	if _, err = old.Read(make([]byte, 1)); err == nil {
		t.Fatal("reset left old stream readable")
	}
	old.Close()
	if err := checkEcho(ctx, c, target, []byte("after reset")); err != nil {
		t.Fatal(err)
	}
	c.Close()
	if _, err := c.Dial(ctx, target); err == nil {
		t.Fatal("Dial after Close succeeded")
	}
}

func TestTwoQUICLanesDatagramOwner(t *testing.T) {
	original, _, stop := fixture(t, "quic", time.Second)
	defer stop()
	cfg := original.cfg
	original.Close()
	cfg.QUICLanes = 2
	c, err := NewClient(context.Background(), cfg, "quic")
	if err != nil {
		t.Fatal(err)
	}
	defer c.Close()
	udp, err := net.ListenPacket("udp4", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer udp.Close()
	go func() {
		b := make([]byte, 128)
		n, a, e := udp.ReadFrom(b)
		if e == nil {
			udp.WriteTo(b[:n], a)
		}
	}()
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	p, err := c.DialPacket(ctx, udp.LocalAddr().String())
	if err != nil {
		t.Fatal(err)
	}
	defer p.Close()
	p.SetDeadline(time.Now().Add(2 * time.Second))
	if _, err = p.WriteTo([]byte("lane udp"), nil); err != nil {
		t.Fatal(err)
	}
	b := make([]byte, 128)
	n, _, err := p.ReadFrom(b)
	if err != nil || string(b[:n]) != "lane udp" {
		t.Fatalf("datagram owner: %q %v", b[:n], err)
	}
}

func TestParallelConfigIsBounded(t *testing.T) {
	c, _, stop := fixture(t, "quic", time.Second)
	defer stop()
	for _, n := range []int{-1, 3, 100} {
		cfg := c.cfg
		cfg.QUICLanes = n
		if _, err := NewClient(context.Background(), cfg, "quic"); err == nil {
			t.Fatalf("accepted %d", n)
		}
	}
	cfg := c.cfg
	cfg.QUICLanes = 2
	if _, err := NewClient(context.Background(), cfg, "h2"); err == nil {
		t.Fatal("H2 accepted QUIC lanes")
	}
}
