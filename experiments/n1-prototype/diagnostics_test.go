package main

import (
	"context"
	"encoding/pem"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestSetupCancellationDuringTLS(t *testing.T) {
	l, e := net.Listen("tcp4", "127.0.0.1:0")
	if e != nil {
		t.Fatal(e)
	}
	defer l.Close()
	accepted := make(chan net.Conn, 1)
	go func() {
		c, e := l.Accept()
		if e == nil {
			accepted <- c
		}
	}()
	ctx, cancel := context.WithTimeout(context.Background(), 70*time.Millisecond)
	defer cancel()
	tr := newEntryTrace()
	_, _, _, e = connectTLS(ctx, settings{Server: l.Addr().String(), Name: "example.com"}, tr)
	if e == nil || tr.snapshot()["failure_phase"] != "tls" {
		t.Fatal(e, tr.snapshot())
	}
	c := <-accepted
	defer c.Close()
	c.SetReadDeadline(time.Now().Add(time.Second))
	b := make([]byte, 4096)
	for {
		if _, e = c.Read(b); e != nil {
			break
		}
	}
}
func TestBodyFailurePhaseAndPartialByteCount(t *testing.T) {
	cfg, n, _ := fixtureWithEmission(t, "coalesced")
	cfg.ClientEmission = "coalesced"
	source := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Length", "1000")
		w.Write([]byte{0, 1, 2})
	}))
	defer source.Close()
	target := strings.TrimPrefix(source.URL, "http://")
	n.targets[target] = true
	row, e := executeWorkload(cfg, target, "matched-n1", workload{N: 1000, Chunk: 1000}, 2*time.Second)
	if e == nil {
		t.Fatal("partial body accepted")
	}
	trace := row["trace"].(map[string]any)
	if trace["failure_phase"] != "body" || trace["body_received_bytes"] != int64(3) {
		t.Fatal(trace)
	}
	if _, ok := row["payload_read_mbps"]; ok {
		t.Fatal("partial body speed")
	}
}
func TestTraceSeparatesDNSAndTCP(t *testing.T) {
	cfg, _, target := fixture(t)
	_, port, _ := net.SplitHostPort(cfg.Server)
	cfg.Server = net.JoinHostPort("localhost", port)
	row, e := executeWorkload(cfg, target, "n1", workload{N: 1, Chunk: 1}, time.Second)
	// Echo target is not an HTTP source; failure may be target headers. TCP/TLS
	// hooks must still record phases without leaking the literal address.
	_ = e
	trace := row["trace"].(map[string]any)
	durations := trace["durations_ms"].(map[string]float64)
	if _, ok := durations["tcp_attempts"]; !ok {
		t.Fatal(trace)
	}
	if _, ok := durations["dns"]; !ok {
		t.Fatal("missing DNS trace", trace)
	}
	if _, ok := durations["tls"]; !ok {
		t.Fatal(trace)
	}
}

func TestSyntheticDNSFailureStage(t *testing.T) {
	tr := newEntryTrace()
	tr.resolver = &net.Resolver{PreferGo: true, Dial: func(context.Context, string, string) (net.Conn, error) {
		return nil, fmt.Errorf("synthetic resolver failure")
	}}
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	if _, _, _, e := connectTLS(ctx, settings{Server: "n1-fault.invalid:443", Name: "example.com"}, tr); e == nil {
		t.Fatal("DNS accepted")
	}
	if tr.snapshot()["failure_phase"] != "dns" {
		t.Fatal(tr.snapshot())
	}
}
func TestSyntheticTCPFailureStage(t *testing.T) {
	l, e := net.Listen("tcp4", "127.0.0.1:0")
	if e != nil {
		t.Fatal(e)
	}
	address := l.Addr().String()
	l.Close()
	tr := newEntryTrace()
	if _, _, _, e = connectTLS(context.Background(), settings{Server: address, Name: "example.com"}, tr); e == nil {
		t.Fatal("TCP accepted")
	}
	if tr.snapshot()["failure_phase"] != "tcp" {
		t.Fatal(tr.snapshot())
	}
}

type firstDropListener struct {
	net.Listener
	dropped bool
}

func (l *firstDropListener) Accept() (net.Conn, error) {
	for {
		c, e := l.Listener.Accept()
		if e != nil {
			return nil, e
		}
		if !l.dropped {
			l.dropped = true
			c.Close()
			continue
		}
		return c, nil
	}
}
func TestRetryOnlyBeforeAuthentication(t *testing.T) {
	cfg, _, target := fixture(t)
	cfg.SetupAttempts = 2
	// A verification failure must not be bypassed or retried.
	cfg.Name = "wrong.example"
	ctx := context.WithValue(context.Background(), traceContextKey{}, newEntryTrace())
	if _, e := dial(ctx, cfg, target); e == nil {
		t.Fatal("certificate failure accepted")
	}
	tr := traceFrom(ctx)
	if tr.snapshot()["setup_attempts"] != 1 {
		t.Fatal(tr.snapshot())
	}
	// Wrong key reaches HTTP auth exactly once, even with setup retry enabled.
	cfg.Name = "example.com"
	cfg.Key = strings.Repeat("00", 32)
	tr = newEntryTrace()
	ctx = context.WithValue(context.Background(), traceContextKey{}, tr)
	if _, e := dial(ctx, cfg, target); e == nil {
		t.Fatal("wrong key accepted")
	}
	if tr.snapshot()["setup_attempts"] != 1 {
		t.Fatal(tr.snapshot())
	}
}
func TestTransientTLSRetryIsBoundedAndRecorded(t *testing.T) {
	s := httptest.NewUnstartedServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(200) }))
	s.Listener = &firstDropListener{Listener: s.Listener}
	s.StartTLS()
	defer s.Close()
	file := filepath.Join(t.TempDir(), "ca.pem")
	os.WriteFile(file, pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: s.Certificate().Raw}), 0600)
	cfg := settings{Server: strings.TrimPrefix(s.URL, "https://"), Name: "example.com", CAFile: file, SetupAttempts: 2}
	tr := newEntryTrace()
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	c, _, _, e := connectTLS(ctx, cfg, tr)
	if e != nil {
		t.Fatal(e)
	}
	c.Close()
	snap := tr.snapshot()
	if snap["setup_attempts"] != 2 || len(snap["setup_failures"].([]map[string]any)) != 1 || snap["failure_phase"] != "" {
		t.Fatal(snap)
	}
}

func TestSetupCancellationDoesNotKillEstablishedStream(t *testing.T) {
	cfg, _, target := fixture(t)
	cfg.ClientEmission = "coalesced"
	ctx, cancel := context.WithCancel(context.Background())
	c, e := dial(ctx, cfg, target)
	if e != nil {
		cancel()
		t.Fatal(e)
	}
	defer c.Close()
	cancel()
	if _, e = c.Write([]byte("ok")); e != nil {
		t.Fatal("setup context killed stream", e)
	}
	var b [2]byte
	if _, e = io.ReadFull(c, b[:]); e != nil || string(b[:]) != "ok" {
		t.Fatal(e)
	}
	c.CloseWrite()
	io.ReadAll(c)
}
