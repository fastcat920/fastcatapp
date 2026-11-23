package h3client

import (
	"context"
	"errors"
	"net/url"
	"time"

	http "github.com/metacubex/http"
	"github.com/metacubex/mihomo/component/fastcatentry"
	quic "github.com/metacubex/quic-go"
	"github.com/metacubex/quic-go/http3"
)

// A target dial may legitimately take several seconds. Only check the gateway
// after a reused connection has stalled, using a different stream on that same
// authenticated connection. The gateway answers non-CONNECT requests directly.
const (
	stalledSetup          = time.Second
	gatewayResponseBudget = 1500 * time.Millisecond
)

type gatewayCheck struct {
	done     chan struct{}
	timedOut bool
}

func (s *session) watch(ctx context.Context, cancel context.CancelCauseFunc, gateway string) *time.Timer {
	start := s.responses.Load()
	return time.AfterFunc(stalledSetup, func() {
		s.mu.Lock()
		if ctx.Err() != nil || s.responses.Load() != start || s.conn.Context().Err() != nil {
			s.mu.Unlock()
			return
		}
		check := s.check
		if check == nil {
			check = &gatewayCheck{done: make(chan struct{})}
			s.check = check
			go func() {
				timedOut := s.gatewayTimedOut(gateway)
				s.mu.Lock()
				check.timedOut = timedOut
				close(check.done)
				s.check = nil
				s.mu.Unlock()
			}()
		}
		s.mu.Unlock()
		select {
		case <-ctx.Done():
		case <-check.done:
			if check.timedOut && s.responses.Load() == start {
				cancel(fastcatentry.ErrUnresponsive)
			}
		}
	})
}

func (s *session) gatewayTimedOut(gateway string) bool {
	ctx, cancel := context.WithTimeout(s.conn.Context(), gatewayResponseBudget)
	defer cancel()
	str, err := s.http.OpenRequestStream(ctx)
	if err != nil {
		return false
	} // Stream quota exhaustion gives no path evidence.
	abort := func() {
		str.CancelRead(quic.StreamErrorCode(http3.ErrCodeRequestCanceled))
		str.CancelWrite(quic.StreamErrorCode(http3.ErrCodeRequestCanceled))
	}
	stop := after(ctx, abort)
	defer func() { stop(); abort() }()
	head := &http.Request{Method: "HEAD", URL: &url.URL{Scheme: "https", Host: gateway, Path: "/"}, Host: gateway}
	if err = str.SendRequestHeader(head); err != nil {
		return false
	}
	if err = str.Close(); err != nil {
		return false
	}
	if _, err = str.ReadResponse(); err == nil {
		s.responses.Add(1) // Any response, including 405, proves gateway liveness.
		return false
	}
	return errors.Is(ctx.Err(), context.DeadlineExceeded) && s.conn.Context().Err() == nil
}
