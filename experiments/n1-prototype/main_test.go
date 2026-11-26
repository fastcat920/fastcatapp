package main

import (
	"bytes"
	"context"
	"crypto/tls"
	"encoding/pem"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestRecords(t *testing.T) {
	var wire bytes.Buffer
	s := &records{w: &wire}
	payload := bytes.Repeat([]byte("n1-record"), 2048)
	if e := sendRecords(s, bytes.NewReader(payload)); e != nil {
		t.Fatal(e)
	}
	r := &records{r: &wire}
	var got bytes.Buffer
	if e := receiveRecords(&got, r); e != nil {
		t.Fatal(e)
	}
	if !bytes.Equal(payload, got.Bytes()) {
		t.Fatal("payload changed")
	}
	if _, e := (&records{r: bytes.NewReader(nil)}).read(); e != io.ErrUnexpectedEOF {
		t.Fatal("transport EOF without FIN must be a truncation error", e)
	}
	for _, b := range [][]byte{{0, 5, 0, 0, 0, 0, 0}, {0xff, 0xff}, {0, 6, 0, 0, 0, 1, 0, 0}, {0, 6, 0, 0, 0, 0, 0, 1}} {
		if _, e := (&records{r: bytes.NewReader(b)}).read(); e == nil || e == io.EOF {
			t.Fatalf("malformed record accepted: %x", b)
		}
	}
}

func fixture(t *testing.T) (settings, *node, string) {
	return fixtureWithEmission(t, "legacy")
}

type panicCheckingLog struct{ t *testing.T }

func (w panicCheckingLog) Write(p []byte) (int, error) {
	if bytes.Contains(p, []byte("http: panic serving")) {
		w.t.Errorf("unexpected server panic: %s", p)
	}
	return len(p), nil
}

func fixtureWithEmission(t *testing.T, emission string) (settings, *node, string) {
	t.Helper()
	echo, e := net.Listen("tcp4", "127.0.0.1:0")
	if e != nil {
		t.Fatal(e)
	}
	t.Cleanup(func() { echo.Close() })
	go func() {
		for {
			c, e := echo.Accept()
			if e != nil {
				return
			}
			go func() { defer c.Close(); io.Copy(c, c) }()
		}
	}()
	key := bytes.Repeat([]byte{7}, 32)
	n := &node{key: key, targets: map[string]bool{echo.Addr().String(): true}, seen: map[string]time.Time{}, slots: make(chan struct{}, 32), emission: emission}
	s := httptest.NewUnstartedServer(n)
	s.Config.ConnContext = withServerConnection
	s.Config.ErrorLog = log.New(panicCheckingLog{t}, "", 0)
	s.TLS = &tls.Config{MinVersion: tls.VersionTLS13, NextProtos: []string{"http/1.1"}}
	s.StartTLS()
	t.Cleanup(s.Close)
	path := filepath.Join(t.TempDir(), "ca.pem")
	if e = os.WriteFile(path, pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: s.Certificate().Raw}), 0600); e != nil {
		t.Fatal(e)
	}
	return settings{Server: strings.TrimPrefix(s.URL, "https://"), Name: "example.com", Key: strings.Repeat("07", 32), CAFile: path}, n, echo.Addr().String()
}

func TestRealTunnel(t *testing.T) {
	cfg, _, target := fixture(t)
	c, e := dial(context.Background(), cfg, target)
	if e != nil {
		t.Fatal(e)
	}
	defer c.Close()
	payload := bytes.Repeat([]byte("original-record-prototype\x00"), 12000)
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
	if !bytes.Equal(payload, got) {
		t.Fatalf("integrity mismatch %d/%d", len(got), len(payload))
	}
}

func TestConcurrentTunnels(t *testing.T) {
	cfg, _, target := fixture(t)
	done := make(chan error, 8)
	for i := 0; i < 8; i++ {
		go func(i int) {
			c, e := dial(context.Background(), cfg, target)
			if e != nil {
				done <- e
				return
			}
			defer c.Close()
			payload := bytes.Repeat([]byte{byte(i + 1)}, 65536)
			written := make(chan error, 1)
			go func() {
				_, e := c.Write(payload)
				if e == nil {
					e = c.CloseWrite()
				}
				written <- e
			}()
			got, e := io.ReadAll(c)
			writeError := <-written
			if e == nil {
				e = writeError
			}
			if e == nil && !bytes.Equal(payload, got) {
				e = fmt.Errorf("stream %d data mismatch", i)
			}
			done <- e
		}(i)
	}
	for i := 0; i < 8; i++ {
		if e := <-done; e != nil {
			t.Fatal(e)
		}
	}
}

func TestTargetHalfClosePreservesUpload(t *testing.T) {
	cfg, n, _ := fixture(t)
	l, e := net.Listen("tcp4", "127.0.0.1:0")
	if e != nil {
		t.Fatal(e)
	}
	defer l.Close()
	n.targets[l.Addr().String()] = true
	got := make(chan []byte, 1)
	go func() {
		c, e := l.Accept()
		if e != nil {
			got <- nil
			return
		}
		defer c.Close()
		c.SetDeadline(time.Now().Add(3 * time.Second))
		c.Write([]byte("ready"))
		c.(*net.TCPConn).CloseWrite()
		b, _ := io.ReadAll(c)
		got <- b
	}()
	c, e := dial(context.Background(), cfg, l.Addr().String())
	if e != nil {
		t.Fatal(e)
	}
	defer c.Close()
	b, e := io.ReadAll(c)
	if e != nil || string(b) != "ready" {
		t.Fatalf("target FIN missing: %q %v", b, e)
	}
	if _, e = c.Write([]byte("upload-after-target-fin")); e != nil {
		t.Fatal(e)
	}
	if e = c.CloseWrite(); e != nil {
		t.Fatal(e)
	}
	if b = <-got; string(b) != "upload-after-target-fin" {
		t.Fatalf("upload lost after target half-close: %q", b)
	}
}

func TestWrongKeyAndDestination(t *testing.T) {
	started := time.Now()
	cfg, _, target := fixture(t)
	bad := cfg
	bad.Key = strings.Repeat("08", 32)
	if c, e := dial(context.Background(), bad, target); e == nil {
		c.Close()
		t.Fatal("wrong key accepted")
	}
	if c, e := dial(context.Background(), cfg, "127.0.0.1:1"); e == nil {
		c.Close()
		t.Fatal("unlisted target accepted")
	}
	bad = cfg
	bad.Name = "wrong.example"
	if c, e := dial(context.Background(), bad, target); e == nil {
		c.Close()
		t.Fatal("wrong certificate name accepted")
	}
	if time.Since(started) > 3*time.Second {
		t.Fatal("authentication rejection stalled waiting for request body")
	}
}

func TestNormalAndInvalidRequests(t *testing.T) {
	cfg, n, _ := fixture(t)
	for _, p := range []string{"/missing", route} {
		r := httptest.NewRequest("POST", "https://example.com"+p, nil)
		r.AddCookie(&http.Cookie{Name: "session", Value: "invalid"})
		w := httptest.NewRecorder()
		n.ServeHTTP(w, r)
		if w.Code != 404 || w.Body.String() != "404 page not found\n" {
			t.Fatal("unexpected public failure response")
		}
	}
	_ = cfg
	r := httptest.NewRequest("GET", "https://example.com/assets/sample.bin", nil)
	w := httptest.NewRecorder()
	n.ServeHTTP(w, r)
	if w.Code != 200 || w.Body.Len() != 32768 {
		t.Fatal("public baseline sample unavailable")
	}
	for i, b := range w.Body.Bytes() {
		if b != byte(i%251) {
			t.Fatal("baseline content differs from tunnel test source")
		}
	}
	r = httptest.NewRequest("GET", "https://example.com/assets/sample.bin?stream=1", nil)
	w = httptest.NewRecorder()
	n.ServeHTTP(w, r)
	if w.Code != 200 || w.Body.Len() != 32768 || w.Header().Get("Content-Length") != "" {
		t.Fatal("streaming control must use the same payload without fixed content length")
	}
}

func TestExporterBinding(t *testing.T) {
	cfg, n, target := fixture(t)
	// Obtain genuine TLS states from separate handshakes, then check that a
	// proof from one connection cannot authenticate another connection.
	var states []tls.ConnectionState
	for i := 0; i < 2; i++ {
		c, e := tls.Dial("tcp", cfg.Server, &tls.Config{InsecureSkipVerify: true, MinVersion: tls.VersionTLS13}) // fixture only
		if e != nil {
			t.Fatal(e)
		}
		states = append(states, c.ConnectionState())
		c.Close()
	}
	key, _ := keyBytes(cfg.Key)
	proof, e := capability(&states[0], key, target)
	if e != nil {
		t.Fatal(e)
	}
	if _, e = verify(&states[0], key, proof, time.Now()); e != nil {
		t.Fatal(e)
	}
	if _, e = verify(&states[1], key, proof, time.Now()); e == nil {
		t.Fatal("cross-session replay accepted")
	}
	if _, e = verify(&states[0], key, proof, time.Now().Add(time.Minute)); e == nil {
		t.Fatal("expired proof accepted")
	}
	for i := 0; i < 2; i++ {
		r := httptest.NewRequest("POST", "https://example.com"+route, nil)
		r.TLS = &states[0]
		r.AddCookie(&http.Cookie{Name: "session", Value: proof})
		w := httptest.NewRecorder()
		n.ServeHTTP(w, r)
		if i == 0 && w.Code != 503 {
			t.Fatalf("expected recorder full-duplex rejection after authentication, got %d", w.Code)
		}
		if i == 1 && w.Code != 404 {
			t.Fatalf("same-session replay accepted: %d", w.Code)
		}
	}
}
