package main

import (
	"github.com/metacubex/mihomo/config"
	"testing"
)

func TestAppleProbeHasNoBackgroundListenersOrHealthChecks(t *testing.T) {
	source := config.DefaultRawConfig()
	source.MixedPort = 7890
	source.Rule = []string{"DOMAIN,example.com,DIRECT"}
	source.ProxyGroup = []map[string]any{{"name": "auto", "type": "url-test", "url": "https://example.com", "interval": 300, "proxies": []string{"DIRECT"}}}
	source.ProxyProvider = map[string]map[string]any{"test": {"type": "http", "interval": 300, "health-check": map[string]any{"enable": true}}}
	result := probeIOSConfig(source)
	if result.MixedPort != 0 || result.DNS.Listen != "" || result.ExternalController != "" || result.Tun.Enable {
		t.Fatal("probe exposed listener")
	}
	if len(result.Rule) != 1 || result.Rule[0] != "MATCH,DIRECT" {
		t.Fatal("probe loaded routing rules")
	}
	if result.ProxyGroup[0]["type"] != "select" {
		t.Fatal("probe started active strategy")
	}
	if _, ok := result.ProxyGroup[0]["interval"]; ok {
		t.Fatal("probe kept timer")
	}
	if result.ProxyProvider["test"]["health-check"].(map[string]any)["enable"] != false {
		t.Fatal("health check enabled")
	}
	if source.ProxyGroup[0]["type"] != "url-test" || source.ProxyProvider["test"]["interval"] != 300 {
		t.Fatal("live source modified")
	}
}
