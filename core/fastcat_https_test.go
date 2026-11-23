package main

import (
	"github.com/metacubex/mihomo/config"
	C "github.com/metacubex/mihomo/constant"
	"testing"
)

func TestFastCatHTTPSAppleProbeAndTunnelConfiguration(t *testing.T) {
	oldHome := C.Path.HomeDir()
	C.SetHomeDir(t.TempDir())
	defer C.SetHomeDir(oldHome)
	raw := config.DefaultRawConfig()
	raw.Proxy = []map[string]any{{"name": "FastCat v1", "type": "fastcat-https", "server": "localhost", "port": 18443, "token": "test-token-at-least-24-bytes"}}
	raw.ProxyGroup = []map[string]any{{"name": "test-select", "type": "select", "proxies": []string{"DIRECT", "FastCat v1"}}}
	raw.Rule = []string{"MATCH,test-select"}
	for _, candidate := range []*config.RawConfig{raw, probeIOSConfig(raw)} {
		parsed, e := config.ParseRawConfig(candidate)
		if e != nil {
			t.Fatal(e)
		}
		node, ok := parsed.Proxies["FastCat v1"]
		if !ok || node.Type() != C.FastCatHTTPS || node.SupportUDP() {
			t.Fatal("new TCP protocol lost in Apple configuration path")
		}
	}
	if raw.ProxyGroup[0]["proxies"].([]string)[0] != "DIRECT" {
		t.Fatal("default selection changed")
	}
}
