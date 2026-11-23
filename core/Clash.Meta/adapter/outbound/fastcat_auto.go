package outbound

import (
	"context"
	"errors"
	"fmt"
	"io"
	"net"
	"sync"
	"syscall"
	"time"

	"github.com/metacubex/mihomo/component/fastcatentry"
	"github.com/metacubex/mihomo/component/fastcatprobe"
	"github.com/metacubex/mihomo/component/resolver"
	C "github.com/metacubex/mihomo/constant"
)

type FastCatAutoOption struct {
	FastCatHTTPSOption
	FallbackPort   int    `proxy:"fallback-port,omitempty"`
	FallbackToken  string `proxy:"fallback-token,omitempty"`
	FallbackServer string `proxy:"fallback-server,omitempty"`
	FallbackSNI    string `proxy:"fallback-sni,omitempty"`
	V2Transport    string `proxy:"transport-mode,omitempty"`
	H3Port         int    `proxy:"h3-port,omitempty"`
	H3Token        string `proxy:"h3-token,omitempty"`
	H3Server       string `proxy:"h3-server,omitempty"`
	H3SNI          string `proxy:"h3-sni,omitempty"`
}

type FastCatAuto struct {
	*Base
	h2, v1, h3    ProxyAdapter
	routes        pathHistory
	mu            sync.Mutex
	fallbackUntil time.Time
	generation    uint64
	closed        bool
	warmNetwork   context.Context
	warmedAt      time.Time
}

func NewFastCatAuto(o FastCatAutoOption) (*FastCatAuto, error) {
	primary := o.FastCatHTTPSOption
	if o.V2Transport == "h3" {
		if o.H3Port < 1 || o.H3Port > 65535 || o.H3Token == "" {
			return nil, errors.New("HTTP/3 mode requires h3-port and h3-token")
		}
		h3, err := newFastCatH3(o)
		if err != nil {
			return nil, err
		}
		base := primary.base(C.FastCatAuto)
		a := &FastCatAuto{Base: base, h3: h3}
		h3.owner = a
		return a, nil
	}
	if o.V2Transport != "" && o.V2Transport != "auto" {
		return nil, fmt.Errorf("unsupported FastCat transport mode: %s", o.V2Transport)
	}
	if o.H3Port != 0 || o.H3Server != "" || o.H3SNI != "" || o.H3Token != "" {
		if o.H3Port < 1 || o.H3Port > 65535 || o.H3Token == "" {
			return nil, errors.New("fastcat-auto requires h3-port and h3-token together")
		}
		primary.UDP = false
		h2, err := NewFastCatH2(primary)
		if err != nil {
			return nil, err
		}
		h3, err := newFastCatH3(o)
		if err != nil {
			h2.Close()
			return nil, err
		}
		base := primary.base(C.FastCatAuto)
		base.udp = o.UDP
		a := &FastCatAuto{Base: base, h2: h2, h3: h3}
		h3.owner = a
		return a, nil
	}
	backup := primary
	backup.Port, backup.Token = o.FallbackPort, o.FallbackToken
	if o.FallbackServer != "" {
		backup.Server = o.FallbackServer
		if backup.Server != primary.Server {
			backup.SNI = ""
		}
	}
	if o.FallbackSNI != "" {
		backup.SNI = o.FallbackSNI
	}
	v1, err := NewFastCatHTTPS(backup)
	if err != nil {
		return nil, fmt.Errorf("fastcat-auto fallback: %w", err)
	}
	h2, err := NewFastCatH2(primary)
	if err != nil {
		return nil, fmt.Errorf("fastcat-auto primary: %w", err)
	}
	return &FastCatAuto{Base: primary.base(C.FastCatAuto), h2: h2, v1: v1}, nil
}

func (a *FastCatAuto) preference() (fallback bool, version uint64, closed bool) {
	a.mu.Lock()
	defer a.mu.Unlock()
	if !a.fallbackUntil.IsZero() && !time.Now().Before(a.fallbackUntil) {
		a.fallbackUntil = time.Time{}
		a.generation++
	}
	return !a.fallbackUntil.IsZero(), a.generation, a.closed
}

func (a *FastCatAuto) remember(fallback bool, version uint64) {
	a.mu.Lock()
	defer a.mu.Unlock()
	if a.generation != version || a.closed {
		return
	}
	a.generation++
	a.fallbackUntil = time.Time{}
	if fallback {
		a.fallbackUntil = time.Now().Add(5 * time.Minute)
	}
}

// Only an entry network failure can select an alternate. TLS verification,
// protocol errors, authentication, destination policy and CONNECT responses
// all surface to the caller.
func fastCatEntryNetworkError(err error) bool {
	var dns *net.DNSError
	var network net.Error
	return errors.Is(err, resolver.ErrIPNotFound) || errors.As(err, &dns) || (errors.As(err, &network) && network.Timeout()) ||
		errors.Is(err, syscall.ECONNREFUSED) || errors.Is(err, syscall.ECONNRESET) ||
		errors.Is(err, syscall.EHOSTUNREACH) || errors.Is(err, syscall.ENETUNREACH) ||
		errors.Is(err, syscall.EPIPE) || errors.Is(err, io.EOF) || errors.Is(err, io.ErrUnexpectedEOF)
}

// DialContext attempts only tunnel setup. No application payload is available
// until the selected child returns a successfully established stream.
func (a *FastCatAuto) DialContext(ctx context.Context, m *C.Metadata) (C.Conn, error) {
	conn, err := a.dial(ctx, m)
	if err != nil {
		return nil, fmt.Errorf("%w: %w", C.ErrFastCatAutoDialFinished, err)
	}
	return conn, nil
}

func (a *FastCatAuto) dial(ctx context.Context, m *C.Metadata) (C.Conn, error) {
	if m == nil || !m.Valid() || m.NetWork != C.TCP || m.DstPort == 0 {
		return nil, fmt.Errorf("fastcat-auto requires a valid TCP destination")
	}
	if a.h3 != nil {
		return a.dialV2(ctx, m)
	}
	fallback, version, closed := a.preference()
	if closed {
		return nil, net.ErrClosed
	}
	parentTiming := fastcatprobe.From(ctx)
	for attempt := 0; ; attempt++ {
		if err := ctx.Err(); err != nil {
			return nil, err
		}
		alternative := attempt == 2
		useV1 := fallback != alternative
		child, protocol := a.h2, "h2"
		if useV1 {
			child, protocol = a.v1, "v1"
		}
		// Leave room for the remaining attempts under Mihomo's TCP deadline.
		budget := 4 * time.Second
		if deadline, ok := ctx.Deadline(); ok {
			share := time.Until(deadline) / time.Duration(3-attempt)
			if share < budget {
				budget = share
			}
		}
		attemptCtx, entry, cancel := fastcatentry.Start(ctx, budget)
		var timing *fastcatprobe.Timing
		if parentTiming != nil {
			timing = new(fastcatprobe.Timing)
			attemptCtx = timing.WithContext(attemptCtx)
		}
		conn, err := child.DialContext(attemptCtx, m)
		cancel()
		if err == nil {
			if err = ctx.Err(); err != nil {
				conn.Close()
				return nil, err
			}
			if alternative {
				a.remember(useV1, version)
			}
			if timing != nil {
				parentTiming.UseGateway(timing, protocol)
			}
			return conn, nil
		}
		if ctx.Err() != nil {
			return nil, ctx.Err()
		}
		ready, expired := entry.State()
		if ready || !(fastCatEntryNetworkError(err) || (expired && errors.Is(err, context.Canceled))) {
			return nil, err
		}
		if alternative {
			if expired && errors.Is(err, context.Canceled) {
				return nil, context.DeadlineExceeded
			}
			return nil, err
		}
	}
}

func (a *FastCatAuto) Close() error {
	a.mu.Lock()
	a.closed = true
	a.mu.Unlock()
	if a.h2 == nil {
		return a.h3.Close()
	}
	if a.h3 != nil {
		return errors.Join(a.h2.Close(), a.h3.Close())
	}
	return errors.Join(a.h2.Close(), a.v1.Close())
}

// Warm is demand-triggered by VPN startup, never by subscription parsing.
// Prepare at most one connection for each carrier, without target traffic.
func (a *FastCatAuto) Warm(ctx context.Context) error {
	if a.h3 == nil {
		return nil
	}
	network := currentFastCatH2Network()
	a.mu.Lock()
	if a.closed || a.warmNetwork == network && time.Since(a.warmedAt) < 30*time.Second {
		a.mu.Unlock()
		return nil
	}
	a.warmNetwork = network
	a.warmedAt = time.Now()
	a.mu.Unlock()
	bounded, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	stop := fastcatWarmAfter(network, cancel)
	defer stop()
	var wg sync.WaitGroup
	results := make(chan error, 2)
	for _, child := range []ProxyAdapter{a.h3, a.h2} {
		if w, ok := child.(interface{ Warm(context.Context) error }); ok {
			wg.Add(1)
			go func() { defer wg.Done(); results <- w.Warm(bounded) }()
		}
	}
	wg.Wait()
	close(results)
	var failures []error
	for err := range results {
		if err != nil {
			failures = append(failures, err)
		}
	}
	return errors.Join(failures...)
}

// Compatible with the core's oldest supported Go toolchain.
func fastcatWarmAfter(ctx context.Context, cancel context.CancelFunc) func() {
	done := make(chan struct{})
	go func() {
		select {
		case <-ctx.Done():
			cancel()
		case <-done:
		}
	}()
	return func() { close(done) }
}
