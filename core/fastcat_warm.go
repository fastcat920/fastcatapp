package main

import (
	"context"
	"sync"
	"time"

	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel"
)

var fastcatStartupWarm struct {
	sync.Mutex
	cancel context.CancelFunc
}

func stopFastCatStartupWarm() {
	fastcatStartupWarm.Lock()
	defer fastcatStartupWarm.Unlock()
	if fastcatStartupWarm.cancel != nil {
		fastcatStartupWarm.cancel()
		fastcatStartupWarm.cancel = nil
	}
}

// Warm only the selected default route, never every subscription node. Other
// per-domain routes stay demand-driven. Socket protection must already be ready.
func startFastCatStartupWarm() {
	stopFastCatStartupWarm()
	name := "GLOBAL"
	switch tunnel.Mode() {
	case tunnel.Direct:
		return
	case tunnel.Rule:
		name = ""
		for _, rule := range tunnel.Rules() {
			if rule.RuleType() == C.MATCH {
				name = rule.Adapter()
				break
			}
		}
	}
	p := tunnel.Proxies()[name]
	for depth := 0; p != nil && depth < 8; depth++ {
		if w, ok := p.Adapter().(interface{ Warm(context.Context) error }); ok {
			ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
			fastcatStartupWarm.Lock()
			fastcatStartupWarm.cancel = cancel
			fastcatStartupWarm.Unlock()
			go func() { defer cancel(); _ = w.Warm(ctx) }()
			return
		}
		p = p.Unwrap(&C.Metadata{}, false)
	}
}
