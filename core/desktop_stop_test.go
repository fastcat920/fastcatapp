package main

import (
	"github.com/metacubex/mihomo/config"
	"github.com/metacubex/mihomo/listener"
	"github.com/metacubex/mihomo/tunnel"
	"net"
	"runtime"
	"testing"
	"time"
)

func TestDesktopStopReleasesLegacyMixedTCPAndUDP(t *testing.T) {
	if runtime.GOOS == "android" || runtime.GOOS == "ios" {
		t.Skip("desktop lifecycle")
	}
	reservation, err := net.Listen("tcp4", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	port := reservation.Addr().(*net.TCPAddr).Port
	address := reservation.Addr().String()
	reservation.Close()
	listener.ReCreateMixed(port, tunnel.Tunnel)
	defer listener.ReCreateMixed(0, tunnel.Tunnel)
	connection, err := net.DialTimeout("tcp4", address, time.Second)
	if err != nil {
		t.Fatal("listener did not start:", err)
	}
	connection.Close()
	stopListeners()
	connection, err = net.DialTimeout("tcp4", address, time.Second)
	if err == nil {
		connection.Close()
		t.Fatal("desktop stop left the HTTP/SOCKS port accepting")
	}
	udp, err := net.ListenPacket("udp4", address)
	if err != nil {
		t.Fatal("desktop stop left UDP port bound:", err)
	}
	udp.Close()
}

func TestOfflineDesktopConfigDoesNotInstallTunOrForgetUserIntent(t *testing.T) {
	if runtime.GOOS == "android" || runtime.GOOS == "ios" {
		t.Skip("desktop lifecycle")
	}
	previous := isRunning
	defer func() { isRunning = previous }()
	requested := &config.Config{General: &config.General{}}
	requested.General.Tun.Enable = true
	isRunning = false
	applied := runtimeConfigForApply(requested)
	if applied.General.Tun.Enable {
		t.Fatal("offline profile would install TUN routes")
	}
	if !requested.General.Tun.Enable {
		t.Fatal("user TUN choice was overwritten")
	}
	isRunning = true
	if runtimeConfigForApply(requested) != requested {
		t.Fatal("connected core lost requested routing configuration")
	}
}
