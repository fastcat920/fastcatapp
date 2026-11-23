// Package fastcatprobe records timings for a single explicitly requested diagnostic.
package fastcatprobe

import (
	"context"
	"sync"
	"time"

	"github.com/metacubex/mihomo/component/fastcattls"
)

type Event uint8

const (
	TunnelStart Event = iota
	GatewayTCPStart
	GatewayTCPDone
	GatewayTLSStart
	GatewayTLSDone
	ConnectStart
	TunnelReady
	OriginTLSStart
	OriginTLSDone
	RequestWritten
	FirstByte
	eventCount
)

type Timing struct {
	mu         sync.Mutex
	events     [eventCount]time.Time
	protocol   string
	security   fastcattls.Negotiated
	gotGateway bool
	reused     bool
}

type timingKey struct{}

func From(ctx context.Context) *Timing {
	timing, _ := ctx.Value(timingKey{}).(*Timing)
	return timing
}

func (t *Timing) WithContext(ctx context.Context) context.Context {
	return context.WithValue(ctx, timingKey{}, t)
}

func (t *Timing) Mark(event Event) {
	if t != nil {
		t.mu.Lock()
		t.events[event] = time.Now()
		t.mu.Unlock()
	}
}

// GatewayAcquired starts timing the CONNECT exchange on a ready physical connection.
func (t *Timing) GatewayAcquired(reused bool) {
	if t != nil {
		t.mu.Lock()
		t.gotGateway, t.reused = true, reused
		t.events[ConnectStart] = time.Now()
		t.mu.Unlock()
	}
}

func (t *Timing) SetGatewaySecurity(security fastcattls.Negotiated) {
	if t != nil {
		t.mu.Lock()
		t.security = security
		t.mu.Unlock()
	}
}

// UseGateway copies only the winning attempt. TunnelStart/TunnelReady still
// enclose the full operation, including time spent on a failed entry.
func (t *Timing) UseGateway(from *Timing, protocol string) {
	from.mu.Lock()
	defer from.mu.Unlock()
	t.mu.Lock()
	defer t.mu.Unlock()
	copy(t.events[GatewayTCPStart:TunnelReady], from.events[GatewayTCPStart:TunnelReady])
	t.protocol, t.gotGateway, t.reused, t.security = protocol, from.gotGateway, from.reused, from.security
}

// Snapshot is detached from late callbacks. A missing phase has no measured
// interval. In particular, no handshake duration is attributed to a reused socket.
func (t *Timing) Snapshot() map[string]any {
	t.mu.Lock()
	defer t.mu.Unlock()
	result := make(map[string]any)
	if t.security.Version != "" {
		result["gateway-tls-version"] = t.security.Version
	}
	if t.security.Cipher != "" {
		result["gateway-cipher"] = t.security.Cipher
	}
	if t.security.Group != "" {
		result["gateway-group"] = t.security.Group
	}
	if t.protocol != "" {
		result["used-protocol"] = t.protocol
	}
	add := func(name string, start, end Event) {
		a, b := t.events[start], t.events[end]
		if !a.IsZero() && !b.IsZero() && !b.Before(a) {
			result[name] = b.Sub(a).Milliseconds()
		}
	}
	if t.gotGateway {
		result["gateway-reused"] = t.reused
	}
	if !t.reused {
		add("gateway-tcp-ms", GatewayTCPStart, GatewayTCPDone)
		add("gateway-tls-ms", GatewayTLSStart, GatewayTLSDone)
	}
	add("connect-response-ms", ConnectStart, TunnelReady)
	add("tunnel-ready-ms", TunnelStart, TunnelReady)
	add("origin-tls-ms", OriginTLSStart, OriginTLSDone)
	add("response-wait-ms", RequestWritten, FirstByte)
	return result
}
