package outbound

import (
	"context"
	"errors"
	"fmt"
	"io"
	"net"
	"sync"
	"time"

	"github.com/metacubex/mihomo/component/fastcatentry"
	"github.com/metacubex/mihomo/component/fastcatprobe"
	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/sing/common/bufio"
	N "github.com/metacubex/sing/common/network"
)

type entryPath uint8

const (
	pathH3 entryPath = iota
	pathH2
)

func (p entryPath) name() string {
	if p == pathH3 {
		return "h3"
	}
	return "h2"
}

type pathSample struct {
	at                  time.Time
	success             bool
	setup, firstPayload time.Duration // CONNECT and first inbound tunnel payload, respectively
}
type pathWindow struct {
	recent                    [8]pathSample
	count                     uint64
	lastAttempt, blockedUntil time.Time
}
type pathHistory struct {
	network    context.Context
	paths      [2]pathWindow
	status     routeStatus
	preferred  entryPath
	switchedAt time.Time
}

const pathCooldown = 30 * time.Second
const pathMemory = 5 * time.Minute

func (w *pathWindow) score(now time.Time) time.Duration {
	var successLatency time.Duration
	var successes, failures int
	for _, s := range w.recent {
		if s.at.IsZero() || now.Sub(s.at) > pathMemory {
			continue
		}
		if !s.success {
			failures++
			continue
		}
		latency := s.firstPayload
		if latency == 0 {
			latency = s.setup
		}
		successLatency += latency
		successes++
	}
	if failures+successes == 0 {
		return 0
	}
	if successes == 0 {
		return pathCooldown
	}
	return successLatency/time.Duration(successes) + 4*time.Second*time.Duration(failures)/time.Duration(successes+failures)
}

func (w *pathWindow) successes(now time.Time) int {
	n := 0
	for _, s := range w.recent {
		if !s.at.IsZero() && now.Sub(s.at) <= pathMemory && s.success {
			n++
		}
	}
	return n
}

// All exploration uses a new real request. Idle nodes send no probe traffic.
func (a *FastCatAuto) choose(now time.Time) (context.Context, entryPath, error) {
	a.mu.Lock()
	defer a.mu.Unlock()
	if a.closed {
		return nil, 0, net.ErrClosed
	}
	netCtx := currentFastCatH2Network()
	if a.routes.network != netCtx {
		a.routes = pathHistory{network: netCtx}
	}
	h3, h2 := &a.routes.paths[pathH3], &a.routes.paths[pathH2]
	preferred := a.routes.preferred
	other := 1 - preferred
	current, alternative := &a.routes.paths[preferred], &a.routes.paths[other]
	switch {
	case now.Before(current.blockedUntil) && !now.Before(alternative.blockedUntil):
		preferred = other
		a.routes.preferred = preferred
		a.routes.switchedAt = now
	case now.Before(alternative.blockedUntil):
	case alternative.lastAttempt.IsZero() || now.Sub(alternative.lastAttempt) >= pathCooldown:
		// At most one real business request explores the other path per cooldown.
		preferred = other
	case current.lastAttempt.IsZero():
	case current.successes(now) >= 3 && alternative.successes(now) >= 3 &&
		(a.routes.switchedAt.IsZero() || now.Sub(a.routes.switchedAt) >= 10*time.Second):
		oldScore, newScore := current.score(now), alternative.score(now)
		margin := oldScore / 5
		if margin < 50*time.Millisecond {
			margin = 50 * time.Millisecond
		}
		if newScore+margin < oldScore {
			preferred = other
			a.routes.preferred = preferred
			a.routes.switchedAt = now
		}
	}
	// The initial request retains H3 preference; the next samples H2.
	if h3.lastAttempt.IsZero() && h2.lastAttempt.IsZero() {
		preferred = pathH3
	}

	a.routes.paths[preferred].lastAttempt = now
	return netCtx, preferred, nil
}

func (a *FastCatAuto) observed(netCtx context.Context, p entryPath, start time.Time, ok bool) uint64 {
	a.mu.Lock()
	defer a.mu.Unlock()
	if a.routes.network != netCtx || netCtx.Err() != nil {
		return 0
	}
	w := &a.routes.paths[p]
	w.count++
	now := time.Now()
	if start.After(w.lastAttempt) {
		w.lastAttempt = start
	}
	w.recent[(w.count-1)%uint64(len(w.recent))] = pathSample{at: now, success: ok, setup: now.Sub(start)}
	if ok {
		w.blockedUntil = time.Time{}
	} else {
		w.blockedUntil = now.Add(pathCooldown)
	}
	return w.count
}

func (a *FastCatAuto) firstPayload(netCtx context.Context, p entryPath, seq uint64, elapsed time.Duration) {
	a.mu.Lock()
	defer a.mu.Unlock()
	w := &a.routes.paths[p]
	if seq == 0 || a.routes.network != netCtx || netCtx.Err() != nil || seq > w.count || w.count-seq >= uint64(len(w.recent)) {
		return
	}
	// A server-push or an idle application can keep a tunnel open a long time.
	// Such observations are not comparable with an interactive request.
	if elapsed > 10*time.Second {
		return
	}
	w.recent[(seq-1)%uint64(len(w.recent))].firstPayload = elapsed
}

func (a *FastCatAuto) dialV2(ctx context.Context, m *C.Metadata) (C.Conn, error) {
	netCtx, preferred, err := a.choose(time.Now())
	if err != nil {
		return nil, err
	}
	paths := []entryPath{preferred, 1 - preferred}
	if a.h2 == nil {
		paths = []entryPath{pathH3}
	}
	for i, p := range paths {
		if err = ctx.Err(); err != nil {
			return nil, err
		}
		if netCtx.Err() != nil {
			return nil, errors.New("fastcat-auto physical network changed")
		}
		child := a.h3
		if p == pathH2 {
			child = a.h2
		}
		start := time.Now()
		budget := 4 * time.Second
		if i == 0 && len(paths) > 1 {
			budget = 2 * time.Second
		} // reserve time for TCP when UDP is filtered
		if end, ok := ctx.Deadline(); ok {
			if share := time.Until(end) / time.Duration(len(paths)-i); share < budget {
				budget = share
			}
		}
		attempt, entry, stop := fastcatentry.Start(ctx, budget)
		parentTiming := fastcatprobe.From(ctx)
		var timing *fastcatprobe.Timing
		if parentTiming != nil {
			timing = new(fastcatprobe.Timing)
			attempt = timing.WithContext(attempt)
		}
		conn, dialErr := child.DialContext(attempt, m)
		stop()
		if ctx.Err() != nil || netCtx.Err() != nil {
			if conn != nil {
				conn.Close()
			}
			if ctx.Err() != nil {
				return nil, ctx.Err()
			}
			return nil, errors.New("fastcat-auto physical network changed")
		}
		if dialErr == nil {
			seq := a.observed(netCtx, p, start, true)
			a.status(netCtx, false, p.name(), "")
			if timing != nil {
				parentTiming.UseGateway(timing, p.name())
			}
			var once sync.Once
			record := func(n int64) {
				if n > 0 {
					once.Do(func() { a.firstPayload(netCtx, p, seq, time.Since(start)) })
				}
			}
			return NewConn(bufio.NewCounterConn(conn, []N.CountFunc{record}, nil), a), nil
		}
		ready, expired := entry.State()
		if !entryFailure(dialErr, ready, expired) {
			a.status(netCtx, false, "", routeError(dialErr, !ready))
			return nil, dialErr
		}
		if expired && errors.Is(dialErr, context.Canceled) {
			dialErr = context.DeadlineExceeded
		}
		a.observed(netCtx, p, start, false)
		err = fmt.Errorf("fastcat-auto %s entry: %w", p.name(), dialErr)
	}
	a.status(netCtx, false, "", "entry")
	return nil, err
}

// After CONNECT has started, a target timeout alone cannot select another entry.
func entryFailure(err error, ready, expired bool) bool {
	if errors.Is(err, fastcatentry.ErrUnresponsive) {
		return true
	}
	return !ready && (fastCatEntryNetworkError(err) || expired && errors.Is(err, context.Canceled))
}

func (a *FastCatAuto) ListenPacketContext(ctx context.Context, m *C.Metadata) (C.PacketConn, error) {
	if a.h3 == nil || !a.SupportUDP() {
		return nil, C.ErrNotSupport
	}
	// No UDP payload is sent while opening the association. Wrap errors so the
	// outer tunnel does not retry certificate, authorization or policy failures.
	return openV2UDP(ctx, a, currentFastCatH2Network(), func(attempt context.Context) (C.PacketConn, error) { return a.h3.ListenPacketContext(attempt, m) })
}

func openV2UDP[T io.Closer](ctx context.Context, a *FastCatAuto, network context.Context, open func(context.Context) (T, error)) (T, error) {
	var zero T
	a.mu.Lock()
	if a.closed || network.Err() != nil {
		a.mu.Unlock()
		return zero, net.ErrClosed
	}
	if a.routes.network != network {
		a.routes = pathHistory{network: network}
	}
	unavailable := time.Now().Before(a.routes.paths[pathH3].blockedUntil)
	a.mu.Unlock()
	if unavailable {
		a.status(network, true, "", "entry")
		return zero, fmt.Errorf("%w: HTTP/3 UDP entry recently unreachable", C.ErrFastCatAutoDialFinished)
	}
	start := time.Now()
	attempt, entry, stop := fastcatentry.Start(ctx, 4*time.Second)
	pc, err := open(attempt)
	stop()
	if err != nil {
		ready, expired := entry.State()
		if ctx.Err() == nil && (!errors.Is(err, context.Canceled) || expired) {
			a.status(network, true, "", routeError(err, !ready || expired))
		}
		if ctx.Err() == nil && !errors.Is(err, fastcatentry.ErrTarget) && entryFailure(err, ready, expired) {
			a.observed(network, pathH3, start, false)
		}
		return zero, fmt.Errorf("%w: HTTP/3 UDP path unavailable: %w", C.ErrFastCatAutoDialFinished, err)
	}
	if ctx.Err() != nil || network.Err() != nil {
		pc.Close()
		if ctx.Err() != nil {
			return zero, ctx.Err()
		}
		return zero, net.ErrClosed
	}
	a.status(network, true, "h3", "")
	return pc, nil
}
