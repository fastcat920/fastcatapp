package adapter

import (
	"context"
	"encoding/pem"
	"errors"
	"fmt"
	"net"
	"net/http"
	"net/http/httptest"
	"net/netip"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/fastcat920/fcnv3"
	"github.com/metacubex/mihomo/adapter/outbound"
	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/tls"
)

const fcnV3TestUUID = "76f9ebbd-a6e3-476f-ad7b-a622a478c08a"

func TestParseFCNV3PanelNode(t *testing.T) {
	mapping := map[string]any{
		"type": "fcn-v3", "name": "FCN v3 panel node", "server": "example.net",
		"port": 443, "sni": "example.net", "uuid": fcnV3TestUUID, "udp": true,
	}
	proxy, err := ParseProxy(mapping)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { proxy.Close() })
	if proxy.Type() != C.FCNv3 || proxy.Type().String() != "FCN v3" || !proxy.SupportUDP() {
		t.Fatalf("unexpected FCN v3 proxy: type=%s, udp=%t", proxy.Type(), proxy.SupportUDP())
	}
	mapping["uuid"] = "not-an-account"
	if _, err := ParseProxy(mapping); err == nil {
		t.Fatal("invalid account passed validation")
	}
}

type fcnV3TestDialer struct {
	C.Dialer
	entry   netip.AddrPort
	sockets chan net.PacketConn
}

func (d *fcnV3TestDialer) ListenPacket(ctx context.Context, network, address string, remote netip.AddrPort) (net.PacketConn, error) {
	if network != "udp" || remote != d.entry {
		return nil, fmt.Errorf("unexpected FCN v3 socket %s %s", network, remote)
	}
	pc, err := (&net.ListenConfig{}).ListenPacket(ctx, network, address)
	if err == nil {
		d.sockets <- pc
	}
	return pc, err
}

func TestFCNV3ProtectedUDPAndNetworkChange(t *testing.T) {
	certFixture := httptest.NewTLSServer(http.NotFoundHandler())
	t.Cleanup(certFixture.Close)
	ca := filepath.Join(t.TempDir(), "ca.pem")
	if err := os.WriteFile(ca, pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: certFixture.Certificate().Raw}), 0600); err != nil {
		t.Fatal(err)
	}
	cert := certFixture.TLS.Certificates[0]
	entry := fcnV3TestSocket(t)
	first, second := fcnV3TestEcho(t), fcnV3TestEcho(t)
	credential, err := fcnv3.CredentialFromUUID(fcnV3TestUUID)
	if err != nil {
		t.Fatal(err)
	}
	server, err := fcnv3.NewServer(fcnv3.ServerConfig{
		TLSConfig:   &tls.Config{Certificates: []tls.Certificate{{Certificate: cert.Certificate, PrivateKey: cert.PrivateKey}}},
		Credentials: []fcnv3.Credential{credential}, UDPTargets: []string{first.String(), second.String()},
	})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { server.Close() })
	go func() { _ = server.Serve(entry) }()
	entryAddr := entry.LocalAddr().(*net.UDPAddr).AddrPort()
	entryAddr = netip.AddrPortFrom(entryAddr.Addr().Unmap(), entryAddr.Port())
	dialer := &fcnV3TestDialer{entry: entryAddr, sockets: make(chan net.PacketConn, 3)}
	proxy, err := ParseProxy(map[string]any{
		"type": "fcn-v3", "name": "FCN v3 loopback", "server": entryAddr.Addr().String(), "port": int(entryAddr.Port()),
		"sni": "example.com", "uuid": fcnV3TestUUID, "udp": true, "ca-file": ca,
	}, WithDialerForAPI(dialer))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { proxy.Close() })
	if len(dialer.sockets) != 0 {
		t.Fatal("parsing opened an entry socket")
	}
	ctx, cancel := context.WithTimeout(t.Context(), 5*time.Second)
	defer cancel()
	open := func() C.PacketConn {
		t.Helper()
		ap := first.AddrPort()
		pc, err := proxy.ListenPacketContext(ctx, &C.Metadata{NetWork: C.UDP, DstIP: ap.Addr(), DstPort: ap.Port()})
		if err != nil {
			t.Fatal(err)
		}
		t.Cleanup(func() { pc.Close() })
		return pc
	}
	probe := func(pc net.PacketConn, addr *net.UDPAddr) {
		t.Helper()
		const payload = "FCN v3 UDP"
		if n, err := pc.WriteTo([]byte(payload), addr); err != nil || n != len(payload) {
			t.Fatalf("send = %d, %v", n, err)
		}
		pc.SetReadDeadline(time.Now().Add(time.Second))
		buffer := make([]byte, 64)
		n, source, err := pc.ReadFrom(buffer)
		if err != nil || source == nil || source.String() != addr.String() || string(buffer[:n]) != payload {
			t.Fatalf("echo = %q, %v, %v", buffer[:n], source, err)
		}
	}
	old := open()
	probe(old, first)
	probe(old, second)
	if len(dialer.sockets) != 1 {
		t.Fatalf("expected one protected socket, got %d", len(dialer.sockets))
	}
	socket := <-dialer.sockets
	raw, err := socket.(*net.UDPConn).SyscallConn()
	if err != nil {
		t.Fatal(err)
	}
	outbound.ResetFastCatH2Connections()
	for raw.Control(func(uintptr) {}) == nil {
		select {
		case <-ctx.Done():
			t.Fatal("old protected socket remained open after network reset")
		case <-time.After(5 * time.Millisecond):
		}
	}
	if _, _, err := old.ReadFrom(make([]byte, 1)); !errors.Is(err, net.ErrClosed) {
		t.Fatalf("old association survived network reset: %v", err)
	}
	probe(open(), first)
	if len(dialer.sockets) != 1 {
		t.Fatalf("new network used %d protected sockets", len(dialer.sockets))
	}
}

func fcnV3TestSocket(t *testing.T) *net.UDPConn {
	t.Helper()
	pc, err := net.ListenUDP("udp4", &net.UDPAddr{IP: net.IPv4(127, 0, 0, 1)})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { pc.Close() })
	return pc
}

func fcnV3TestEcho(t *testing.T) *net.UDPAddr {
	t.Helper()
	pc := fcnV3TestSocket(t)
	go func() {
		var buffer [1200]byte
		for {
			n, from, err := pc.ReadFromUDP(buffer[:])
			if err != nil {
				return
			}
			pc.WriteToUDP(buffer[:n], from)
		}
	}()
	return pc.LocalAddr().(*net.UDPAddr)
}
