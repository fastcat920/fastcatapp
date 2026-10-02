package main

import (
	"github.com/metacubex/mihomo/config"
	"testing"
)

func TestRejectedConfigurationPreservesCurrentProfile(t *testing.T) {
	previous, previousURL := currentConfig, testURL
	defer func() { currentConfig, testURL = previous, previousURL }()
	sentinel := &config.Config{}
	currentConfig, testURL = sentinel, "previous-url"
	raw := config.DefaultRawConfig()
	raw.Proxy = []map[string]any{{"name": "invalid", "type": "unsupported-test-proxy"}}
	err := setupConfig(&SetupParams{Config: raw, TestURL: "new-url"})
	if err == nil {
		t.Fatal("invalid proxy must be rejected")
	}
	if currentConfig != sentinel {
		t.Fatal("rejected update replaced the active profile")
	}
	if testURL != "previous-url" {
		t.Fatal("rejected update changed the test URL")
	}
}
