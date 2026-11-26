package main

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http/httptrace"
	"os"
	"sync"
	"syscall"
	"time"
)

type phaseEvent struct {
	Phase    string  `json:"phase"`
	OffsetMS float64 `json:"offset_ms"`
}
type ioProgress struct {
	OffsetMS float64 `json:"offset_ms"`
	Received int64   `json:"received_bytes"`
}
type entryTrace struct {
	setupAttempts      int
	setupFailures      []map[string]any
	resolver           *net.Resolver
	didResume          bool
	mu                 sync.Mutex
	start              time.Time
	phase              string
	events             []phaseEvent
	durations          map[string]float64
	dnsStart, tcpStart time.Time
	failurePhase       string
	progress           []ioProgress
	received           int64
	lastReadMS         float64
	attempts           map[string]time.Time
}
type traceContextKey struct{}

func newEntryTrace() *entryTrace {
	return &entryTrace{start: time.Now(), durations: map[string]float64{}, attempts: map[string]time.Time{}}
}
func traceFrom(ctx context.Context) *entryTrace {
	t, _ := ctx.Value(traceContextKey{}).(*entryTrace)
	return t
}
func (t *entryTrace) begin(phase string) {
	if t == nil {
		return
	}
	t.mu.Lock()
	defer t.mu.Unlock()
	t.phase = phase
	t.events = append(t.events, phaseEvent{phase, float64(time.Since(t.start).Microseconds()) / 1000})
}
func (t *entryTrace) elapsed(phase string, d time.Duration) {
	if t == nil {
		return
	}
	t.mu.Lock()
	defer t.mu.Unlock()
	t.durations[phase] += float64(d.Microseconds()) / 1000
}
func (t *entryTrace) fail() {
	if t == nil {
		return
	}
	t.mu.Lock()
	defer t.mu.Unlock()
	if t.failurePhase == "" {
		t.failurePhase = t.phase
	}
}
func (t *entryTrace) bytes(n int) {
	if t == nil || n <= 0 {
		return
	}
	t.mu.Lock()
	defer t.mu.Unlock()
	t.received += int64(n)
	ms := float64(time.Since(t.start).Microseconds()) / 1000
	t.lastReadMS = ms
	if len(t.progress) == 0 || ms-t.progress[len(t.progress)-1].OffsetMS >= 250 {
		if len(t.progress) >= 128 {
			t.progress = append(t.progress[:1], t.progress[2:]...)
		}
		t.progress = append(t.progress, ioProgress{ms, t.received})
	}
}
func (t *entryTrace) snapshot() map[string]any {
	if t == nil {
		return nil
	}
	t.mu.Lock()
	defer t.mu.Unlock()
	d := map[string]float64{}
	for k, v := range t.durations {
		d[k] = v
	}
	p := append([]ioProgress(nil), t.progress...)
	if t.received > 0 {
		p = append(p, ioProgress{t.lastReadMS, t.received})
	}
	return map[string]any{"events": append([]phaseEvent(nil), t.events...), "durations_ms": d, "failure_phase": t.failurePhase, "tls_resumed": t.didResume, "setup_attempts": t.setupAttempts, "setup_failures": append([]map[string]any(nil), t.setupFailures...), "body_received_bytes": t.received, "progress": p}
}
func (t *entryTrace) netContext(ctx context.Context) context.Context {
	if t == nil {
		return ctx
	}
	return httptrace.WithClientTrace(ctx, &httptrace.ClientTrace{
		DNSStart: func(httptrace.DNSStartInfo) { t.begin("dns"); t.mu.Lock(); t.dnsStart = time.Now(); t.mu.Unlock() },
		DNSDone: func(info httptrace.DNSDoneInfo) {
			t.mu.Lock()
			start := t.dnsStart
			t.mu.Unlock()
			t.elapsed("dns", time.Since(start))
			if info.Err != nil {
				t.fail()
			}
		},
		ConnectStart: func(network, address string) {
			t.begin("tcp")
			t.mu.Lock()
			t.attempts[network+address] = time.Now()
			t.mu.Unlock()
		},
		ConnectDone: func(network, address string, err error) {
			t.mu.Lock()
			start := t.attempts[network+address]
			delete(t.attempts, network+address)
			t.mu.Unlock()
			t.elapsed("tcp_attempts", time.Since(start))
		},
	})
}
func phaseDeadline(ctx context.Context, budget time.Duration) time.Time {
	d := time.Now().Add(budget)
	if x, ok := ctx.Deadline(); ok && x.Before(d) {
		return x
	}
	return d
}
func tlsConfigFor(cfg settings) (*tls.Config, error) {
	c := &tls.Config{ServerName: cfg.Name, MinVersion: tls.VersionTLS13, NextProtos: []string{"http/1.1"}}
	if cfg.CAFile != "" {
		b, e := os.ReadFile(cfg.CAFile)
		if e != nil {
			return nil, e
		}
		c.RootCAs = x509.NewCertPool()
		if !c.RootCAs.AppendCertsFromPEM(b) {
			return nil, fmt.Errorf("invalid CA file")
		}
	}
	switch cfg.TestCurve {
	case "", "default":
	case "x25519":
		c.CurvePreferences = []tls.CurveID{tls.X25519}
	default:
		return nil, fmt.Errorf("unknown diagnostic curve")
	}
	if e := applySessionCache(c, cfg); e != nil {
		return nil, e
	}
	return c, nil
}
func connectTLSOnce(ctx context.Context, cfg settings, t *entryTrace) (c *tls.Conn, tcpDone, tlsDone time.Time, err error) {
	tc, e := tlsConfigFor(cfg)
	if e != nil {
		return nil, tcpDone, tlsDone, e
	}
	t.begin("dns_tcp")
	dialer := &net.Dialer{Timeout: 8 * time.Second}
	if t != nil {
		dialer.Resolver = t.resolver
	}
	raw, e := dialer.DialContext(t.netContext(ctx), "tcp", cfg.Server)
	tcpDone = time.Now()
	if e != nil {
		t.fail()
		return nil, tcpDone, tlsDone, fmt.Errorf("entry_dns_tcp: %w", e)
	}
	stop := context.AfterFunc(ctx, func() { raw.Close() })
	defer func() {
		stop()
		if err != nil {
			raw.Close()
		}
	}()
	c = tls.Client(raw, tc)
	t.begin("tls")
	started := time.Now()
	c.SetDeadline(phaseDeadline(ctx, 12*time.Second))
	e = c.HandshakeContext(ctx)
	t.elapsed("tls", time.Since(started))
	tlsDone = time.Now()
	if e == nil && t != nil {
		t.mu.Lock()
		t.didResume = c.ConnectionState().DidResume
		t.mu.Unlock()
	}
	if e != nil {
		t.fail()
		return nil, tcpDone, tlsDone, fmt.Errorf("entry_tls: %w", e)
	}
	stop()
	if e = ctx.Err(); e != nil {
		t.fail()
		return nil, tcpDone, tlsDone, e
	}
	return c, tcpDone, tlsDone, nil
}

type progressReadCloser struct {
	io.ReadCloser
	t *entryTrace
}

func (r *progressReadCloser) Read(b []byte) (int, error) {
	n, e := r.ReadCloser.Read(b)
	r.t.bytes(n)
	return n, e
}

type entryStatusError struct{ code int }

func (e entryStatusError) Error() string { return fmt.Sprintf("entry returned HTTP %d", e.code) }

func errorCategory(err error) string {
	if err == nil {
		return ""
	}
	if errors.Is(err, context.Canceled) {
		return "cancelled"
	}
	var status entryStatusError
	if errors.As(err, &status) {
		switch status.code {
		case 404:
			return "authorization_or_target_rejected"
		case 503:
			return "entry_capacity"
		case 502:
			return "target_connect"
		}
		return "entry_http_status"
	}
	var n net.Error
	if errors.As(err, &n) && n.Timeout() {
		return "timeout"
	}
	var dns *net.DNSError
	if errors.As(err, &dns) {
		return "dns"
	}
	var cert *tls.CertificateVerificationError
	if errors.As(err, &cert) {
		return "certificate"
	}
	if errors.Is(err, io.EOF) || errors.Is(err, io.ErrUnexpectedEOF) || errors.Is(err, syscall.ECONNRESET) {
		return "truncated"
	}
	return "transport_or_protocol"
}

// Retries are bounded and happen before any HTTP authorization or business
// write. Verification failures and application errors are never retried.
func connectTLS(ctx context.Context, cfg settings, t *entryTrace) (c *tls.Conn, tcpDone, tlsDone time.Time, err error) {
	attempts := cfg.SetupAttempts
	if attempts == 0 {
		attempts = 1
	}
	if attempts < 1 || attempts > 2 {
		return nil, tcpDone, tlsDone, fmt.Errorf("setup attempts must be 1 or 2")
	}
	for i := 0; i < attempts; i++ {
		if t != nil {
			t.mu.Lock()
			t.setupAttempts++
			t.mu.Unlock()
		}
		c, tcpDone, tlsDone, err = connectTLSOnce(ctx, cfg, t)
		if err == nil {
			return
		}
		transient := errorCategory(err) == "timeout" || errors.Is(err, io.EOF) || errors.Is(err, io.ErrUnexpectedEOF) || errors.Is(err, syscall.ECONNRESET)
		retry := i+1 < attempts && ctx.Err() == nil && transient
		if t != nil {
			t.mu.Lock()
			t.setupFailures = append(t.setupFailures, map[string]any{"attempt": i + 1, "phase": t.failurePhase, "category": errorCategory(err)})
			if retry {
				t.failurePhase = ""
			}
			t.mu.Unlock()
		}
		if !retry {
			return
		}
		t.begin("setup_retry_wait")
		timer := time.NewTimer(150 * time.Millisecond)
		select {
		case <-ctx.Done():
			timer.Stop()
			err = ctx.Err()
			t.fail()
			return
		case <-timer.C:
		}
	}
	return
}

func endingError(label string, n int, e error) error {
	if e != nil {
		return fmt.Errorf("%s: bytes=%d: %w", label, n, e)
	}
	return fmt.Errorf("%s: unexpected bytes=%d", label, n)
}
