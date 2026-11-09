package tun

import (
	"context"
	"errors"
	"github.com/metacubex/sing/common/logger"
	"net"
	"sync"
	"syscall"
	"time"
)

// The wrapper's address never changes, so System's TCP NAT port stays valid.
// Accept owns replacement; Close cancels backoff and fences publication.
type recoveringTCPListener struct {
	ctx        context.Context
	cancel     context.CancelFunc
	mu         sync.Mutex
	current    net.Listener
	address    net.Addr
	network    string
	listen     func(context.Context, string, string) (net.Listener, error)
	logger     logger.Logger
	closed     bool
	state      string
	reason     string
	recoveries uint64
	retryDelay time.Duration
	attempts   int
}

func newRecoveringTCPListener(ctx context.Context, listener net.Listener, network string,
	listen func(context.Context, string, string) (net.Listener, error), log logger.Logger,
) *recoveringTCPListener {
	ctx, cancel := context.WithCancel(ctx)
	return &recoveringTCPListener{ctx: ctx, cancel: cancel, current: listener, address: listener.Addr(),
		network: network, listen: listen, logger: log, state: "ready", retryDelay: 100 * time.Millisecond, attempts: 3}
}
func (l *recoveringTCPListener) Addr() net.Addr { return l.address }
func (l *recoveringTCPListener) Close() error {
	l.mu.Lock()
	if l.closed {
		l.mu.Unlock()
		return nil
	}
	l.closed = true
	l.state = "stopped"
	l.cancel()
	current := l.current
	l.current = nil
	l.mu.Unlock()
	if current != nil {
		return current.Close()
	}
	return nil
}
func (l *recoveringTCPListener) Accept() (net.Conn, error) {
	resourceRetries := 0
	socketRestarts := 0
	for {
		l.mu.Lock()
		current, closed := l.current, l.closed
		l.mu.Unlock()
		if closed || l.ctx.Err() != nil {
			return nil, net.ErrClosed
		}
		if current == nil {
			return nil, errors.New("TUN TCP listener unavailable")
		}
		conn, err := current.Accept()
		if err == nil {
			return conn, nil
		}
		if l.isStopped() {
			return nil, net.ErrClosed
		}
		if errors.Is(err, syscall.EMFILE) || errors.Is(err, syscall.ENFILE) || errors.Is(err, syscall.ENOBUFS) || errors.Is(err, syscall.ENOMEM) {
			resourceRetries++
			if resourceRetries <= l.attempts && l.wait(resourceRetries) {
				continue
			}
			return nil, l.fail(err)
		}
		if errors.Is(err, net.ErrClosed) || errors.Is(err, context.Canceled) {
			return nil, l.fail(err)
		}
		socketRestarts++
		if socketRestarts > l.attempts {
			return nil, l.fail(err)
		}
		if err = l.replace(current, err); err != nil {
			return nil, err
		}
	}
}
func (l *recoveringTCPListener) isStopped() bool {
	l.mu.Lock()
	defer l.mu.Unlock()
	return l.closed || l.ctx.Err() != nil
}
func (l *recoveringTCPListener) wait(attempt int) bool {
	timer := time.NewTimer(time.Duration(attempt) * l.retryDelay)
	defer timer.Stop()
	select {
	case <-l.ctx.Done():
		return false
	case <-timer.C:
		return !l.isStopped()
	}
}
func (l *recoveringTCPListener) replace(old net.Listener, cause error) error {
	l.mu.Lock()
	if l.closed || l.ctx.Err() != nil {
		l.mu.Unlock()
		return net.ErrClosed
	}
	l.state = "recovering"
	l.reason = listenerErrorCode(cause)
	l.current = nil
	l.mu.Unlock()
	_ = old.Close()
	l.logger.Warn("tun_forwarder event=recovering family=", l.network, " reason=", listenerErrorCode(cause))
	last := cause
	for attempt := 1; attempt <= l.attempts; attempt++ {
		if !l.wait(attempt) {
			return net.ErrClosed
		}
		next, err := l.listen(l.ctx, l.network, l.address.String())
		if err != nil {
			last = err
			continue
		}
		if next.Addr().String() != l.address.String() {
			_ = next.Close()
			last = errors.New("replacement address changed")
			continue
		}
		l.mu.Lock()
		if l.closed || l.ctx.Err() != nil {
			l.mu.Unlock()
			_ = next.Close()
			return net.ErrClosed
		}
		l.current = next
		l.state = "ready"
		l.reason = ""
		l.recoveries++
		count := l.recoveries
		l.mu.Unlock()
		l.logger.Warn("tun_forwarder event=recovered family=", l.network, " attempts=", attempt, " recoveries=", count)
		return nil
	}
	return l.fail(last)
}
func (l *recoveringTCPListener) fail(err error) error {
	l.mu.Lock()
	if l.closed || l.ctx.Err() != nil {
		l.mu.Unlock()
		return net.ErrClosed
	}
	l.state = "failed"
	l.reason = listenerErrorCode(err)
	current := l.current
	l.current = nil
	l.mu.Unlock()
	if current != nil {
		_ = current.Close()
	}
	l.logger.Error("tun_forwarder event=failed family=", l.network, " reason=", listenerErrorCode(err))
	return err
}
func listenerErrorCode(err error) string {
	switch {
	case errors.Is(err, syscall.EINVAL):
		return "invalid_state"
	case errors.Is(err, syscall.ECONNABORTED):
		return "aborted"
	case errors.Is(err, syscall.EMFILE), errors.Is(err, syscall.ENFILE):
		return "descriptor_limit"
	case errors.Is(err, syscall.ENOBUFS), errors.Is(err, syscall.ENOMEM):
		return "resource_limit"
	case errors.Is(err, net.ErrClosed):
		return "unexpected_close"
	default:
		return "socket_error"
	}
}

// Health contains no addresses, destinations or credentials.
type ForwarderHealth struct {
	State      string `json:"state"`
	Reason     string `json:"reason,omitempty"`
	Recoveries uint64 `json:"recoveries"`
}

func (l *recoveringTCPListener) health() ForwarderHealth {
	l.mu.Lock()
	defer l.mu.Unlock()
	return ForwarderHealth{State: l.state, Reason: l.reason, Recoveries: l.recoveries}
}

var systemForwarders sync.Map // provided TUN descriptor -> *System
// The mixed stack embeds System. Pure userspace stacks have no host listener.
func SystemForwarderHealth(fd int) (ForwarderHealth, bool) {
	value, ok := systemForwarders.Load(fd)
	if !ok {
		return ForwarderHealth{}, false
	}
	s := value.(*System)
	result := ForwarderHealth{State: "ready"}
	for _, listener := range []net.Listener{s.tcpListener, s.tcpListener6} {
		if l, ok := listener.(*recoveringTCPListener); ok {
			h := l.health()
			result.Recoveries += h.Recoveries
			if h.State == "failed" || h.State == "stopped" {
				result.State = "failed"
				result.Reason = h.Reason
			} else if h.State == "recovering" && result.State != "failed" {
				result.State = "recovering"
				result.Reason = h.Reason
			}
		}
	}
	return result, true
}
