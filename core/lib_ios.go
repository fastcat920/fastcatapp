//go:build ios && cgo

package main

/*
#include <stdlib.h>
*/
import "C"
import (
	"encoding/json"
	"unsafe"

	"github.com/metacubex/mihomo/config"
	MC "github.com/metacubex/mihomo/constant"
)

// ClashCore_init initialises the mihomo core.
// homeDir: path to writable directory for config/cache files.
// config:  raw YAML config string.
// Returns 0 on success, non-zero on failure.
//
// On iOS the NetworkExtension owns the TUN device; mihomo runs in proxy mode
// only (mixed-port / HTTP / SOCKS). TUN is force-disabled in the config to
// prevent sing-tun from trying to create its own TUN device (which would fail
// inside the sandbox).
//
//export ClashCore_init
func ClashCore_init(homeDir *C.char, configYaml *C.char) C.int {
	homeDirStr := C.GoString(homeDir)
	configStr := C.GoString(configYaml)

	// Initialise clash home directory
	initParams := InitParams{
		HomeDir: homeDirStr,
	}
	initData, _ := json.Marshal(initParams)
	if !handleInitClash(string(initData)) {
		return 1
	}

	if configStr == "" {
		return 2
	}

	// Parse YAML into RawConfig. Previously we passed raw YAML to
	// handleSetupConfig which expects JSON-encoded SetupParams — that
	// caused UnmarshalJson to fail silently, so mihomo never started
	// and all nodes showed timeout.
	rawCfg, err := config.UnmarshalRawConfig([]byte(configStr))
	if err != nil {
		return 2
	}

	// Force iOS-specific config overrides on the parsed config object.
	patchConfigForIOS(rawCfg)

	params := &SetupParams{
		Config:      rawCfg,
		TestURL:     "https://www.gstatic.com/generate_204",
		SelectedMap: map[string]string{},
	}
	if err := setupConfig(params); err != nil {
		return 3
	}

	// Start listener
	handleStartListener()
	return 0
}

// patchConfigForIOS modifies the parsed RawConfig for iOS proxy mode:
// - Disables TUN (sing-tun can't create a device inside the NE sandbox)
// - Ensures mixed-port is set (proxy listener)
// - Enables DNS with fake-ip mode so domains resolve through proxy
// - Sets allow-lan so the local proxy is accessible
func patchConfigForIOS(cfg *config.RawConfig) {
	// Disable TUN — iOS uses proxy mode, not packet forwarding
	cfg.Tun.Enable = false

	// Allow LAN connections so proxy is reachable on 127.0.0.1
	cfg.AllowLan = true
	cfg.BindAddress = "*"

	// Ensure mixed-port exists (default 7890)
	if cfg.MixedPort == 0 {
		cfg.MixedPort = 7890
	}

	// Enable DNS with fake-ip mode. This is critical for iOS in China:
	// - External DNS (8.8.8.8, 1.1.1.1) are blocked/polluted
	// - fake-ip returns synthetic IPs from 198.18.0.1/16 for all domains
	// - When the proxy connection is made, mihomo resolves the real IP
	//   through the proxy server, bypassing local DNS pollution
	cfg.DNS.Enable = true
	cfg.DNS.Listen = "127.0.0.1:6053"
	cfg.DNS.EnhancedMode = MC.DNSFakeIP
	cfg.DNS.FakeIPRange = "198.18.0.1/16"
	cfg.DNS.FakeIPFilter = []string{
		"*.lan",
		"*.local",
		"localhost",
		"+.msftconnecttest.com",
		"+.msftncsi.com",
	}

	// Nameservers for mihomo's internal resolution.
	// Chinese-accessible DNS for direct/bypass domains.
	if len(cfg.DNS.NameServer) == 0 {
		cfg.DNS.NameServer = []string{
			"223.5.5.5",
			"119.29.29.29",
		}
	}
	// Fallback DNS for foreign domains — resolved through proxy tunnel,
	// so these don't need to be directly reachable from China.
	if len(cfg.DNS.Fallback) == 0 {
		cfg.DNS.Fallback = []string{
			"8.8.8.8",
			"1.1.1.1",
		}
	}
}

// ClashCore_get_mixed_port returns the mixed-port that mihomo is listening on.
// Returns 0 if not yet initialised.
//
//export ClashCore_get_mixed_port
func ClashCore_get_mixed_port() C.int {
	if currentConfig == nil {
		return 0
	}
	return C.int(currentConfig.General.MixedPort)
}

// ClashCore_shutdown stops all listeners and shuts down the core.
//
//export ClashCore_shutdown
func ClashCore_shutdown() {
	handleStopListener()
	handleShutdown()
}

// ClashCore_invoke dispatches a method call to the core and returns the result
// as a C string. The caller must free the returned pointer with ClashCore_free.
//
//export ClashCore_invoke
func ClashCore_invoke(method *C.char, data *C.char) *C.char {
	methodStr := C.GoString(method)
	var dataStr string
	if data != nil {
		dataStr = C.GoString(data)
	}

	// Build an Action and dispatch through handleAction
	action := &Action{
		Id:     "ios",
		Method: Method(methodStr),
	}
	if dataStr != "" {
		action.Data = dataStr
	}

	// Synchronous result channel
	ch := make(chan string, 1)
	result := ActionResult{
		Id:     action.Id,
		Method: action.Method,
		Port:   -1,
	}

	// Override the send method to capture the result synchronously
	go func() {
		switch action.Method {
		case initClashMethod:
			data, _ := json.Marshal(handleInitClash(dataStr))
			ch <- string(data)
		case getIsInitMethod:
			data, _ := json.Marshal(handleGetIsInit())
			ch <- string(data)
		case forceGcMethod:
			handleForceGc()
			ch <- "true"
		case shutdownMethod:
			data, _ := json.Marshal(handleShutdown())
			ch <- string(data)
		case validateConfigMethod:
			ch <- handleValidateConfig([]byte(dataStr))
		case updateConfigMethod:
			ch <- handleUpdateConfig([]byte(dataStr))
		case setupConfigMethod:
			ch <- handleSetupConfig([]byte(dataStr))
		case getProxiesMethod:
			data, _ := json.Marshal(handleGetProxies())
			ch <- string(data)
		case changeProxyMethod:
			handleChangeProxy(dataStr, func(value string) {
				ch <- value
			})
		case getTrafficMethod:
			ch <- handleGetTraffic()
		case getTotalTrafficMethod:
			ch <- handleGetTotalTraffic()
		case resetTrafficMethod:
			handleResetTraffic()
			ch <- "true"
		case asyncTestDelayMethod:
			handleAsyncTestDelay(dataStr, func(value string) {
				ch <- value
			})
		case getConnectionsMethod:
			ch <- handleGetConnections()
		case closeConnectionsMethod:
			data, _ := json.Marshal(handleCloseConnections())
			ch <- string(data)
		case resetConnectionsMethod:
			data, _ := json.Marshal(handleResetConnections())
			ch <- string(data)
		case closeConnectionMethod:
			data, _ := json.Marshal(handleCloseConnection(dataStr))
			ch <- string(data)
		case getExternalProvidersMethod:
			ch <- handleGetExternalProviders()
		case getExternalProviderMethod:
			ch <- handleGetExternalProvider(dataStr)
		case startLogMethod:
			handleStartLog()
			ch <- "true"
		case stopLogMethod:
			handleStopLog()
			ch <- "true"
		case startListenerMethod:
			data, _ := json.Marshal(handleStartListener())
			ch <- string(data)
		case stopListenerMethod:
			data, _ := json.Marshal(handleStopListener())
			ch <- string(data)
		case getConfigMethod:
			config, err := handleGetConfig(dataStr)
			if err != nil {
				ch <- ""
			} else {
				data, _ := json.Marshal(config)
				ch <- string(data)
			}
		case setStateMethod:
			handleSetState(dataStr)
			ch <- "true"
		case getMemoryMethod:
			handleGetMemory(func(value string) {
				ch <- value
			})
		case getCountryCodeMethod:
			handleGetCountryCode(dataStr, func(value string) {
				ch <- value
			})
		default:
			_ = result
			ch <- ""
		}
	}()

	resultStr := <-ch
	return C.CString(resultStr)
}

// ClashCore_free frees a C string returned by ClashCore_invoke.
//
//export ClashCore_free
func ClashCore_free(p *C.char) {
	if p != nil {
		C.free(unsafe.Pointer(p))
	}
}

// ClashCore_write_packet is a no-op on iOS.
// iOS uses proxy mode (mixed-port) instead of TUN packet forwarding.
// The NetworkExtension routes traffic to mihomo's local proxy via
// NEProxySettings; raw IP packet handling is not needed.
//
//export ClashCore_write_packet
func ClashCore_write_packet(data *C.uint8_t, length C.int) {
	// Intentionally empty — iOS proxy mode, no packet forwarding.
}

// sendMessage — iOS no-op: there is no Dart isolate port to send to.
// hub.go calls sendMessage for logs, delays, etc.; on iOS these are
// retrieved via ClashCore_invoke instead.
func sendMessage(message Message) {
	// Intentionally empty — iOS uses IPC, not Dart ports.
}

// send — iOS no-op for ActionResult.send(). On non-iOS platforms this
// sends the result back to the Dart isolate via dart-bridge; on iOS
// ClashCore_invoke uses Go channels directly.
func (result ActionResult) send() {
	// Intentionally empty.
}

// nextHandle — iOS doesn't have Android-specific actions
func nextHandle(action *Action, result ActionResult) bool {
	return false
}
