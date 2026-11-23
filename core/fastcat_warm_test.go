package main

import (
	"context"
	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/adapter/outbound"
	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel"
	"testing"
	"time"
)

type startupWarmProbe struct {
	*outbound.Base
	started chan context.Context
}

func (p *startupWarmProbe) Warm(ctx context.Context) error {
	p.started <- ctx
	<-ctx.Done()
	return ctx.Err()
}
func TestFastCatStartupWarmsSelectedOnlyAndCancels(t *testing.T) {
	oldProxies, oldProviders, oldMode := tunnel.Proxies(), tunnel.Providers(), tunnel.Mode()
	defer func() {
		stopFastCatStartupWarm()
		tunnel.UpdateProxies(oldProxies, oldProviders)
		tunnel.SetMode(oldMode)
	}()
	selected := &startupWarmProbe{Base: outbound.NewBase(outbound.BaseOption{Name: "selected"}), started: make(chan context.Context, 1)}
	other := &startupWarmProbe{Base: outbound.NewBase(outbound.BaseOption{Name: "unused"}), started: make(chan context.Context, 1)}
	tunnel.UpdateProxies(map[string]C.Proxy{"GLOBAL": adapter.NewProxy(selected), "unused": adapter.NewProxy(other)}, oldProviders)
	tunnel.SetMode(tunnel.Global)
	startFastCatStartupWarm()
	var ctx context.Context
	select {
	case ctx = <-selected.started:
	case <-time.After(time.Second):
		t.Fatal("selected route was not warmed")
	}
	select {
	case <-other.started:
		t.Fatal("warmed an unselected subscription node")
	default:
	}
	stopFastCatStartupWarm()
	select {
	case <-ctx.Done():
	case <-time.After(time.Second):
		t.Fatal("stop did not cancel warm setup")
	}
	tunnel.SetMode(tunnel.Direct)
	startFastCatStartupWarm()
	select {
	case <-selected.started:
		t.Fatal("warmed in direct mode")
	default:
	}
}
