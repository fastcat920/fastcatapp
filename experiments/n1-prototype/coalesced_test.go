package main

import (
	"bufio"
	"bytes"
	"context"
	"fmt"
	"io"
	"net"
	"net/http"
	"strings"
	"testing"
	"time"
)

type countedBuffer struct {
	bytes.Buffer
	calls int
}

func (b *countedBuffer) Write(p []byte) (int, error) { b.calls++; return b.Buffer.Write(p) }

func TestCoalescedChunkFramingAndStableFIN(t *testing.T) {
	var buffer countedBuffer
	writer := &records{w: &chunkBatchWriter{destination: &buffer}}
	if e := writer.write([]byte("payload")); e != nil {
		t.Fatal(e)
	}
	if e := writer.write(nil); e != nil {
		t.Fatal(e)
	}
	if buffer.calls != 2 {
		t.Fatalf("want one complete transport write per DATA/FIN, got %d", buffer.calls)
	}
	if e := writer.write(nil); e != nil || buffer.calls != 2 {
		t.Fatal("duplicate FIN emitted")
	}
	if e := writer.write([]byte("late")); e != io.ErrClosedPipe {
		t.Fatal("write after FIN accepted", e)
	}
	httpStream := "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n" + buffer.String()
	response, e := http.ReadResponse(bufio.NewReader(strings.NewReader(httpStream)), nil)
	if e != nil {
		t.Fatal(e)
	}
	reader := &records{r: response.Body}
	p, e := reader.read()
	if e != nil || string(p) != "payload" {
		t.Fatal("chunk framing changed payload", e)
	}
	for i := 0; i < 2; i++ {
		if _, e = reader.read(); e != io.EOF {
			t.Fatal("FIN must remain EOF on repeated read", e)
		}
	}
	if b, e := io.ReadAll(response.Body); e != nil || len(b) != 0 {
		t.Fatal("outer chunk terminator missing", e)
	}
}

func TestCoalescedInteractiveAndBulk(t *testing.T) {
	for _, profile := range []string{"legacy", "coalesced", "capped"} {
		t.Run(profile, func(t *testing.T) { checkTestCoalescedInteractiveAndBulk(t, profile) })
	}
}

func checkTestCoalescedInteractiveAndBulk(t *testing.T, profile string) {
	cfg, n, target := fixtureWithEmission(t, "coalesced")
	cfg.ClientEmission = profile
	if profile == "capped" {
		cfg.ClientEmission = "coalesced"
		n.writeLimit = 16384
	}
	c, e := dial(context.Background(), cfg, target)
	if e != nil {
		t.Fatal(e)
	}
	defer c.Close()
	c.conn.SetDeadline(time.Now().Add(5 * time.Second))
	// The target waits for input. Dial must complete without waiting for target
	// bytes, and each single byte must return without waiting for FIN or 16KiB.
	for _, b := range []byte("interactive") {
		if _, e = c.Write([]byte{b}); e != nil {
			t.Fatal(e)
		}
		var got [1]byte
		if _, e = io.ReadFull(c, got[:]); e != nil || got[0] != b {
			t.Fatal("interactive write was buffered", e)
		}
	}
	payload := bytes.Repeat([]byte("bulk-data\x00"), 50000)
	done := make(chan error, 1)
	go func() {
		_, e := c.Write(payload)
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
	if !bytes.Equal(got, payload) {
		t.Fatal("bulk data changed")
	}
	if e = c.Close(); e != nil {
		t.Fatal("graceful HTTP/TLS shutdown failed", e)
	}
}

func TestCoalescedServerFirstAndEmptyFIN(t *testing.T) {
	for _, profile := range []string{"legacy", "coalesced", "capped"} {
		t.Run(profile, func(t *testing.T) { checkTestCoalescedServerFirstAndEmptyFIN(t, profile) })
	}
}

func checkTestCoalescedServerFirstAndEmptyFIN(t *testing.T, profile string) {
	for _, greeting := range []string{"ready", ""} {
		t.Run("greeting-"+greeting, func(t *testing.T) {
			cfg, n, _ := fixtureWithEmission(t, "coalesced")
			cfg.ClientEmission = profile
			if profile == "capped" {
				cfg.ClientEmission = "coalesced"
				n.writeLimit = 16384
			}
			l, e := net.Listen("tcp4", "127.0.0.1:0")
			if e != nil {
				t.Fatal(e)
			}
			defer l.Close()
			n.targets[l.Addr().String()] = true
			done := make(chan []byte, 1)
			go func() {
				c, e := l.Accept()
				if e != nil {
					done <- nil
					return
				}
				defer c.Close()
				c.SetDeadline(time.Now().Add(5 * time.Second))
				io.WriteString(c, greeting)
				c.(*net.TCPConn).CloseWrite()
				b, _ := io.ReadAll(c)
				done <- b
			}()
			c, e := dial(context.Background(), cfg, l.Addr().String())
			if e != nil {
				t.Fatal(e)
			}
			defer c.Close()
			c.conn.SetDeadline(time.Now().Add(5 * time.Second))
			got, e := io.ReadAll(c)
			if e != nil || string(got) != greeting {
				t.Fatal("server-first FIN failed", e)
			}
			var b [1]byte
			if _, e = c.Read(b[:]); e != io.EOF {
				t.Fatal("EOF was not stable", e)
			}
			if _, e = c.Write([]byte("upload-after-fin")); e != nil {
				t.Fatal(e)
			}
			if e = c.CloseWrite(); e != nil {
				t.Fatal(e)
			}
			if string(<-done) != "upload-after-fin" {
				t.Fatal("server FIN truncated reverse direction")
			}
		})
	}
}

func TestCoalescedAuthorizationFailure(t *testing.T) {
	for _, profile := range []string{"legacy", "coalesced", "capped"} {
		t.Run(profile, func(t *testing.T) { checkTestCoalescedAuthorizationFailure(t, profile) })
	}
}

func checkTestCoalescedAuthorizationFailure(t *testing.T, profile string) {
	cfg, n, target := fixtureWithEmission(t, "coalesced")
	cfg.ClientEmission = profile
	if profile == "capped" {
		cfg.ClientEmission = "coalesced"
		n.writeLimit = 16384
	}
	cfg.Key = strings.Repeat("08", 32)
	if c, e := dial(context.Background(), cfg, target); e == nil {
		c.Close()
		t.Fatal("wrong key accepted")
	} else if !strings.Contains(e.Error(), "HTTP 404") {
		t.Fatal("wrong key did not use ordinary rejection", e)
	}
}

func TestCoalescedCancelReleasesSession(t *testing.T) {
	for _, profile := range []string{"legacy", "coalesced", "capped"} {
		t.Run(profile, func(t *testing.T) { checkTestCoalescedCancelReleasesSession(t, profile) })
	}
}

func checkTestCoalescedCancelReleasesSession(t *testing.T, profile string) {
	cfg, n, target := fixtureWithEmission(t, "coalesced")
	cfg.ClientEmission = profile
	if profile == "capped" {
		cfg.ClientEmission = "coalesced"
		n.writeLimit = 16384
	}
	c, e := dial(context.Background(), cfg, target)
	if e != nil {
		t.Fatal(e)
	}
	if _, e = c.Write([]byte("before-cancel")); e != nil {
		t.Fatal(e)
	}
	c.Close()
	deadline := time.Now().Add(3 * time.Second)
	for len(n.slots) > 0 && time.Now().Before(deadline) {
		time.Sleep(5 * time.Millisecond)
	}
	if len(n.slots) != 0 {
		t.Fatal("canceled duplex request retained a session slot")
	}
}

func TestCoalescedWaitsForOuterRequestEOF(t *testing.T) {
	cfg, n, target := fixtureWithEmission(t, "coalesced")
	c, e := diagnosticTLS(cfg)
	if e != nil {
		t.Fatal(e)
	}
	defer c.Close()
	state := c.ConnectionState()
	key, _ := keyBytes(cfg.Key)
	proof, e := capability(&state, key, target)
	if e != nil {
		t.Fatal(e)
	}
	request := "POST " + route + " HTTP/1.1\r\nHost: " + cfg.Name + "\r\nCookie: session=" + proof + "\r\nTransfer-Encoding: chunked\r\n\r\n"
	if _, e = io.WriteString(c, request); e != nil {
		t.Fatal(e)
	}
	response, e := http.ReadResponse(bufio.NewReader(c), nil)
	if e != nil || response.StatusCode != 200 {
		t.Fatal("entry response", e)
	}
	var body bytes.Buffer
	record := &records{w: &body}
	record.write([]byte("before-outer-eof"))
	record.write(nil)
	if _, e = fmt.Fprintf(c, "%x\r\n", body.Len()); e != nil {
		t.Fatal(e)
	}
	if _, e = c.Write(body.Bytes()); e != nil {
		t.Fatal(e)
	}
	io.WriteString(c, "\r\n")
	var got bytes.Buffer
	if e = receiveRecords(&got, &records{r: response.Body}); e != nil || got.String() != "before-outer-eof" {
		t.Fatal("payload", e)
	}
	// The inner FIN is delivered, but the outer HTTP terminator is intentionally
	// withheld. The node must not retire the connection while those bytes may
	// still be in flight. This recreates the public-network close race locally.
	until := time.Now().Add(100 * time.Millisecond)
	for time.Now().Before(until) {
		if len(n.slots) != 1 {
			t.Fatal("session closed before outer request EOF")
		}
		time.Sleep(5 * time.Millisecond)
	}
	if _, e = io.WriteString(c, "0\r\n\r\n"); e != nil {
		t.Fatal(e)
	}
	if b, e := io.ReadAll(response.Body); e != nil || len(b) != 0 {
		t.Fatal("response chunk terminator", e)
	}
	c.Close()
	until = time.Now().Add(3 * time.Second)
	for len(n.slots) > 0 && time.Now().Before(until) {
		time.Sleep(5 * time.Millisecond)
	}
	if len(n.slots) != 0 {
		t.Fatal("completed HTTP request retained its slot")
	}
}
