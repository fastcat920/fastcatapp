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

func TestReplyPrefixFirstDataAndAccounting(t *testing.T) {
	var dst bytes.Buffer
	w := newReplyPrefix(&dst, time.Hour, nil)
	defer w.Stop()
	payload := []byte{1, 2, 0, 3}
	n, e := w.Write(payload)
	if e != nil || n != len(payload) {
		t.Fatal(n, e)
	}
	if e = w.Flush(); e != nil {
		t.Fatal(e)
	}
	if !bytes.Equal(dst.Bytes(), append([]byte{0}, payload...)) {
		t.Fatal(dst.Bytes())
	}
}
func TestReplyPrefixTimerWriteRaceSingleStatus(t *testing.T) {
	for i := 0; i < 100; i++ {
		var dst bytes.Buffer
		w := newReplyPrefix(&dst, time.Hour, nil)
		var wg sync.WaitGroup
		wg.Add(2)
		go func() { defer wg.Done(); _ = w.Flush() }()
		go func() { defer wg.Done(); _, _ = w.Write([]byte("data")) }()
		wg.Wait()
		w.Stop()
		if !bytes.Equal(dst.Bytes(), []byte("\x00data")) {
			t.Fatal(dst.Bytes())
		}
	}
}
func TestReplyPrefixEOFStillHasSuccessStatus(t *testing.T) {
	var dst bytes.Buffer
	w := newReplyPrefix(&dst, time.Hour, nil)
	if e := w.Flush(); e != nil {
		t.Fatal(e)
	}
	w.Stop()
	if !bytes.Equal(dst.Bytes(), []byte{0}) {
		t.Fatal(dst.Bytes())
	}
}
func TestReplyPrefixLegacyWaitsForStatusBeforePayload(t *testing.T) {
	c, _, stop := fixtureProfileConfig(t, "quic", time.Second, 1, "", func(s *ServerConfig) { s.ReplyCoalesceDelay = 5 * time.Millisecond })
	defer stop()
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	target, _ := echoTarget(t)
	conn, e := c.Dial(ctx, target)
	if e != nil {
		t.Fatal(e)
	}
	defer conn.Close()
	q := conn.(*quicConn)
	q.Stream.SetReadDeadline(time.Now().Add(time.Second))
	var status [1]byte
	if _, e = io.ReadFull(q.Stream, status[:]); e != nil || status[0] != 0 {
		t.Fatal("legacy client could not obtain status before sending payload", e, status)
	}
	// This test read the wire status directly, so use the raw stream for payload.
	if _, e = q.Stream.Write([]byte("abc")); e != nil {
		t.Fatal(e)
	}
	got := make([]byte, 3)
	if _, e = io.ReadFull(q.Stream, got); e != nil || string(got) != "abc" {
		t.Fatal(e, string(got))
	}
}
func TestReplyPrefixServerFirstAndBusinessCounters(t *testing.T) {
	listener, e := net.Listen("tcp4", "127.0.0.1:0")
	if e != nil {
		t.Fatal(e)
	}
	defer listener.Close()
	go func() {
		n, e := listener.Accept()
		if e != nil {
			return
		}
		defer n.Close()
		_, _ = n.Write([]byte("greeting"))
	}()
	c, s, stop := fixtureProfileConfig(t, "quic", time.Second, 1, "", func(s *ServerConfig) { s.ReplyCoalesceDelay = 5 * time.Millisecond })
	defer stop()
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	conn, e := c.Dial(ctx, listener.Addr().String())
	if e != nil {
		t.Fatal(e)
	}
	defer conn.Close()
	conn.SetDeadline(time.Now().Add(time.Second))
	got, e := io.ReadAll(conn)
	if e != nil || string(got) != "greeting" {
		t.Fatal(e, string(got))
	}
	if s.Counters().Download.Load() != 8 {
		t.Fatal("status byte entered billing counter", s.Counters().Download.Load())
	}
}
func TestReplyCoalescingStillRejectsInvalidCredentials(t *testing.T) {
	c, s, stop := fixtureProfileConfig(t, "quic", time.Second, 1, "", func(s *ServerConfig) { s.ReplyCoalesceDelay = 5 * time.Millisecond })
	defer stop()
	c.cfg.Key = bytes.Repeat([]byte{8}, 32)
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	target, count := echoTarget(t)
	conn, e := c.Dial(ctx, target)
	if e != nil {
		t.Fatal(e)
	}
	defer conn.Close()
	conn.SetDeadline(time.Now().Add(time.Second))
	_, e = conn.Read(make([]byte, 1))
	if e != ErrAuth || count.Load() != 0 || s.Counters().Accepted.Load() != 0 {
		t.Fatal("auth semantics changed", e, count.Load())
	}
}

func TestReplyCoalescingTargetFailureStillImmediate(t *testing.T) {
	c, s, stop := fixtureProfileConfig(t, "quic", time.Second, 1, "", func(s *ServerConfig) {
		s.ReplyCoalesceDelay = 5 * time.Millisecond
		s.DialContext = func(context.Context, string, string) (net.Conn, error) { return nil, ErrTarget }
	})
	defer stop()
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	conn, e := c.Dial(ctx, "127.0.0.1:1")
	if e != nil {
		t.Fatal(e)
	}
	defer conn.Close()
	conn.SetDeadline(time.Now().Add(time.Second))
	_, e = conn.Read(make([]byte, 1))
	if e != ErrTarget || s.Counters().Accepted.Load() != 0 {
		t.Fatal("target error semantics changed", e)
	}
}
