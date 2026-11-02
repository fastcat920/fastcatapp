package main

import (
	"core/state"
	"encoding/json"
	"github.com/metacubex/mihomo/config"
	"testing"
)

func TestAndroidVpnOptionsBeforeSetup(t *testing.T) {
	previous := state.CurrentState
	defer func() { state.CurrentState = previous }()
	for _, s := range []*state.State{nil, {VpnProps: state.AndroidVpnRawOptions{Enable: true}}} {
		state.CurrentState = s
		for _, cfg := range []*config.Config{nil, {}} {
			options := buildAndroidVpnOptions(cfg)
			if options.Enable || options.Port != 0 || options.BypassDomain == nil || options.Ipv4Address == "" {
				t.Fatalf("unsafe startup options: %+v", options)
			}
			if _, err := json.Marshal(options); err != nil {
				t.Fatal(err)
			}
		}
	}
}

func TestAndroidVpnOptionsAfterSetup(t *testing.T) {
	previous := state.CurrentState
	defer func() { state.CurrentState = previous }()
	state.CurrentState = &state.State{VpnProps: state.AndroidVpnRawOptions{Enable: true, SystemProxy: true, Ipv6: true}, BypassDomain: []string{"example.com"}}
	cfg := &config.Config{General: &config.General{}}
	cfg.General.MixedPort = 7890
	options := buildAndroidVpnOptions(cfg)
	if !options.Enable || !options.SystemProxy || options.Port != 7890 || options.Ipv6Address == "" || len(options.BypassDomain) != 1 {
		t.Fatalf("configured options lost: %+v", options)
	}
}
