package main

import (
	"core/state"
	"github.com/metacubex/mihomo/config"
)

// Return a complete, disabled response until setup has committed a configuration.
// The FFI caller always decodes JSON, so an empty string is not a safe fallback.
func buildAndroidVpnOptions(cfg *config.Config) state.AndroidVpnOptions {
	options := state.AndroidVpnOptions{
		Ipv4Address:      state.DefaultIpv4Address,
		DnsServerAddress: state.GetDnsServerAddress(),
		BypassDomain:     []string{},
	}
	if state.CurrentState == nil || cfg == nil || cfg.General == nil {
		return options
	}
	props := state.CurrentState.VpnProps
	options.Enable = props.Enable
	options.Port = cfg.General.MixedPort
	options.Ipv6Address = state.GetIpv6Address()
	options.AccessControl = props.AccessControl
	options.SystemProxy = props.SystemProxy
	options.AllowBypass = props.AllowBypass
	options.RouteAddress = cfg.General.Tun.RouteAddress
	if state.CurrentState.BypassDomain != nil {
		options.BypassDomain = state.CurrentState.BypassDomain
	}
	return options
}
