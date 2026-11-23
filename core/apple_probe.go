package main

import (
	"sync/atomic"

	"github.com/metacubex/mihomo/config"
)

// The PacketTunnel advances this whenever its selected physical interface changes.
// Other platforms and the app's isolated probe leave this counter at zero.
var applePhysicalPathGeneration atomic.Uint64

func probeIOSConfig(source *config.RawConfig) *config.RawConfig {
	// Construct an allowlist rather than trusting subscription inbound settings.
	// Keep transport, host resolution and provider encryption handled by the core.
	cfg := &config.RawConfig{
		Proxy: source.Proxy, ProxyProvider: source.ProxyProvider,
		DNS: source.DNS, Hosts: source.Hosts, IPv6: source.IPv6,
		GeodataMode: source.GeodataMode, GeodataLoader: source.GeodataLoader,
		GeositeMatcher: source.GeositeMatcher, GeoXUrl: source.GeoXUrl,
		GlobalClientFingerprint: source.GlobalClientFingerprint,
		TCPConcurrent:           source.TCPConcurrent, UnifiedDelay: source.UnifiedDelay,
		LogLevel: source.LogLevel, Rule: []string{"MATCH,DIRECT"},
	}
	cfg.DNS.Listen = ""
	cfg.DNS.RespectRules = false
	for _, group := range source.ProxyGroup {
		// A selector retains relay dependencies without background URL tests.
		selector := map[string]any{"name": group["name"], "type": "select"}
		for _, key := range []string{"proxies", "use", "include-all", "include-all-proxies", "include-all-providers", "filter", "exclude-filter", "exclude-type"} {
			if value, ok := group[key]; ok {
				selector[key] = value
			}
		}
		cfg.ProxyGroup = append(cfg.ProxyGroup, selector)
	}
	cfg.ProxyProvider = make(map[string]map[string]any, len(source.ProxyProvider))
	for name, provider := range source.ProxyProvider {
		copy := make(map[string]any, len(provider)+1)
		for key, value := range provider {
			copy[key] = value
		}
		copy["health-check"] = map[string]any{"enable": false}
		copy["interval"] = 0
		cfg.ProxyProvider[name] = copy
	}
	return cfg
}
