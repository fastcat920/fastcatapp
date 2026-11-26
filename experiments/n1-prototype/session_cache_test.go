package main

import (
	"context"
	"crypto/tls"
	"io"
	"testing"
	"time"
)

func cachedDialState(t *testing.T, cfg settings, target string) tls.ConnectionState {
	t.Helper()
	c, e := dial(context.Background(), cfg, target)
	if e != nil {
		t.Fatal(e)
	}
	state := c.conn.(*tls.Conn).ConnectionState()
	if e = c.CloseWrite(); e != nil {
		t.Fatal(e)
	}
	if _, e = io.ReadAll(c); e != nil {
		t.Fatal(e)
	}
	if e = c.Close(); e != nil {
		t.Fatal(e)
	}
	return state
}
func TestSessionCacheResumesAndSeparatesNetworkEpoch(t *testing.T) {
	cfg, _, target := fixtureWithEmission(t, "coalesced")
	cfg.ClientEmission = "coalesced"
	cfg.SessionCacheSize = 8
	cfg.NetworkEpoch = "one"
	if cachedDialState(t, cfg, target).DidResume {
		t.Fatal("first unexpectedly resumed")
	}
	if !cachedDialState(t, cfg, target).DidResume {
		t.Fatal("second did not resume")
	}
	cfg.NetworkEpoch = "two"
	if cachedDialState(t, cfg, target).DidResume {
		t.Fatal("network epoch reused session")
	}
	cfg.Name = "wrong.example"
	if c, e := dial(context.Background(), cfg, target); e == nil {
		c.Close()
		t.Fatal("cache bypassed name validation")
	}
}
func TestCacheBoundsAndDefaultOff(t *testing.T) {
	c, e := tlsConfigFor(settings{})
	if e != nil || c.ClientSessionCache != nil {
		t.Fatal(e)
	}
	if _, e = tlsConfigFor(settings{SessionCacheSize: 999}); e == nil {
		t.Fatal("unbounded cache accepted")
	}
	for i := 0; i < 40; i++ {
		cfg := settings{Server: string(rune(65 + i)), SessionCacheSize: 8}
		if _, e = tlsConfigFor(cfg); e != nil {
			t.Fatal(e)
		}
	}
	cacheProfiles.Lock()
	defer cacheProfiles.Unlock()
	if len(cacheProfiles.profiles) > 16 {
		t.Fatal("profile growth")
	}
}

func TestCacheForcesFullValidationAfterProfileLifetime(t *testing.T) {
	cfg, _, target := fixtureWithEmission(t, "coalesced")
	cfg.ClientEmission = "coalesced"
	cfg.SessionCacheSize = 8
	cfg.NetworkEpoch = "expiry"
	cachedDialState(t, cfg, target)
	if !cachedDialState(t, cfg, target).DidResume {
		t.Fatal("setup did not resume")
	}
	tc, e := tlsConfigFor(cfg)
	if e != nil {
		t.Fatal(e)
	}
	cacheProfiles.Lock()
	for _, p := range cacheProfiles.profiles {
		if p.cache == tc.ClientSessionCache {
			p.created = time.Now().Add(-2 * time.Minute)
		}
	}
	cacheProfiles.Unlock()
	if cachedDialState(t, cfg, target).DidResume {
		t.Fatal("profile lifetime did not force full validation")
	}
}
