package main

import (
	"strings"
	"testing"

	"github.com/metacubex/mihomo/config"
	"github.com/metacubex/mihomo/log"
)

func TestColdStartLogUpdateBeforeAndAfterInit(t *testing.T) {
	previous, previousLevel, previousInit := currentConfig, log.Level(), isInit
	defer func() { currentConfig = previous; log.SetLevel(previousLevel); isInit = previousInit }()
	currentConfig, isInit = nil, false
	// The first Flutter frame can update logging before init/setupConfig.
	for _, initialized := range []bool{false, true} {
		isInit = initialized // initClash marks the process ready, not the profile.
		for _, level := range []string{"info", "error", "info"} {
			if result := handleUpdateConfig([]byte(`{"log-level":"` + level + `"}`)); result != "" {
				t.Fatalf("initialized=%v: %s", initialized, result)
			}
			if log.Level().String() != level || currentConfig != nil {
				t.Fatal("logging must work before setup without creating a partial proxy config")
			}
		}
	}
}

func TestConfigUpdateNotReadyReturnsErrorWithoutSideEffects(t *testing.T) {
	previous, previousLevel := currentConfig, log.Level()
	defer func() { currentConfig = previous; log.SetLevel(previousLevel) }()
	for _, cfg := range []*config.Config{nil, {}} {
		currentConfig = cfg
		log.SetLevel(log.INFO)
		for _, payload := range []string{`{"mixed-port":7890}`, `{"log-level":"error","mixed-port":7890}`} {
			if result := handleUpdateConfig([]byte(payload)); !strings.Contains(result, "not ready") {
				t.Fatalf("expected not-ready error, got %q", result)
			}
			if currentConfig != cfg || log.Level() != log.INFO {
				t.Fatal("a rejected configuration update must not partially apply")
			}
		}
	}
}

func TestLogUpdateWithMissingGeneral(t *testing.T) {
	previous, previousLevel := currentConfig, log.Level()
	defer func() { currentConfig = previous; log.SetLevel(previousLevel) }()
	currentConfig = &config.Config{}
	if result := handleUpdateConfig([]byte(`{"log-level":"info"}`)); result != "" {
		t.Fatal(result)
	}
	if currentConfig.General != nil || log.Level() != log.INFO {
		t.Fatal("do not synthesize an incomplete general config for logging")
	}
}

func TestNullConfigUpdateReturnsError(t *testing.T) {
	if result := handleUpdateConfig([]byte(`null`)); result == "" {
		t.Fatal("null updates must be rejected")
	}
}

func TestLogOnlyUpdateDoesNotRequireOrReplaceListenerConfiguration(t *testing.T) {
	previous, previousLevel := currentConfig, log.Level()
	defer func() { currentConfig = previous; log.SetLevel(previousLevel) }()
	// Deliberately omit listener/TUN/DNS config: invoking updateListeners here
	// would touch unrelated runtime state (and require the missing configuration).
	general := &config.General{}
	currentConfig = &config.Config{General: general}
	if result := handleUpdateConfig([]byte(`{"log-level":"info"}`)); result != "" {
		t.Fatal(result)
	}
	if currentConfig.General != general || log.Level() != log.INFO {
		t.Fatal("log-only update must change the level without replacing config")
	}
}
