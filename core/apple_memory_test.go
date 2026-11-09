package main

import (
	"github.com/metacubex/mihomo/config"
	"testing"
)

func TestAppleMemoryConfigBoundsCacheWithoutChangingRouting(t *testing.T) {
	for _, size := range []int{0, -1, 128, 4096} {
		cfg := config.DefaultRawConfig()
		cfg.DNS.CacheMaxSize = size
		cfg.TCPConcurrent = true
		cfg.DNS.FakeIPRange = "198.18.0.1/16"
		patchAppleMemoryConfig(cfg)
		if cfg.DNS.CacheMaxSize <= 0 || cfg.DNS.CacheMaxSize > 512 {
			t.Fatal(cfg.DNS.CacheMaxSize)
		}
		if size == 128 && cfg.DNS.CacheMaxSize != size {
			t.Fatal("smaller user cache increased")
		}
		if cfg.DNS.FakeIPRange != "198.18.0.1/16" {
			t.Fatal("fake-IP mappings changed")
		}
		if cfg.GeodataLoader != "memconservative" || cfg.TCPConcurrent {
			t.Fatal("memory policy not applied")
		}
	}
}
