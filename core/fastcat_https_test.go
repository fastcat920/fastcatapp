package main

import (
	"github.com/metacubex/mihomo/config"
	C "github.com/metacubex/mihomo/constant"
	"testing"
)

func TestRetiredFastCatHTTPSRemovedFromAppleConfigurations(t *testing.T) {
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
		if _, ok := parsed.Proxies["FastCat v1"]; ok {
			t.Fatal("retired FastCat transport loaded in Apple configuration")
		}
	}
	if raw.ProxyGroup[0]["proxies"].([]string)[0] != "DIRECT" {
		t.Fatal("default selection changed")
	}
}
