package outbound

import (
	"context"
	"encoding/pem"
	"io"
	"net"
	"net/http/httptest"
	"net/netip"
	"os"
	"path/filepath"
	"strconv"
	"testing"
	"time"

	"github.com/fastcat920/fcn"
	C "github.com/metacubex/mihomo/constant"
	tls "github.com/metacubex/tls"
)

func TestFCNAdapterTCPUDP(t *testing.T) {
	for _, version := range []int{1, 2} {
		t.Run(strconv.Itoa(version), func(t *testing.T) {
			identity := httptest.NewTLSServer(nil)
			identity.Close()
			cert := identity.TLS.Certificates[0]
			ca := filepath.Join(t.TempDir(), "ca.pem")
			if err := os.WriteFile(ca, pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: cert.Certificate[0]}), 0600); err != nil {
				t.Fatal(err)
			}
			uuid := "1ed909de-848b-41e7-943f-0f2d49b35f3a"
			account, key, _ := fcn.AccountCredentials(uuid)
			server, err := fcn.NewServer(fcn.ServerConfig{Accounts: map[string][]byte{account: key}, AllowPrivate: true, Congestion: "bbr"})
			if err != nil {
				t.Fatal(err)
			}
			socket, _ := net.ListenPacket("udp4", "127.0.0.1:0")
			defer socket.Close()
			ctx, cancel := context.WithCancel(context.Background())
			defer cancel()
			done := make(chan struct{})
			go func() {
				defer close(done)
				server.ServeQUIC(ctx, socket, &tls.Config{Certificates: []tls.Certificate{{Certificate: cert.Certificate, PrivateKey: cert.PrivateKey}}})
			}()
			defer func() {
				cancel()
				socket.Close()
				select {
				case <-done:
				case <-time.After(3 * time.Second):
					t.Error("FCN listener did not stop")
				}
			}()
			proxy, err := NewFCN(FCNOption{Name: "FCN", Server: "127.0.0.1", Port: socket.LocalAddr().(*net.UDPAddr).Port, SNI: "example.com", UUID: uuid, Version: version, UDP: true, CAFile: ca})
			if err != nil {
				t.Fatal(err)
			}
			defer proxy.Close()
			tcp, _ := net.Listen("tcp4", "127.0.0.1:0")
			defer tcp.Close()
			go func() {
				for {
					c, e := tcp.Accept()
					if e != nil {
						return
					}
					go func() { defer c.Close(); io.Copy(c, c) }()
				}
			}()
			meta := &C.Metadata{NetWork: C.TCP, DstIP: netip.MustParseAddr("127.0.0.1"), DstPort: uint16(tcp.Addr().(*net.TCPAddr).Port)}
			conn, err := proxy.DialContext(ctx, meta)
			if err != nil {
				t.Fatal(err)
			}
			defer conn.Close()
			conn.SetDeadline(time.Now().Add(3 * time.Second))
			conn.Write([]byte("FCN-TCP"))
			b := make([]byte, 7)
			if _, err := io.ReadFull(conn, b); err != nil || string(b) != "FCN-TCP" {
				t.Fatalf("TCP: %q %v", b, err)
			}
			udp, _ := net.ListenPacket("udp4", "127.0.0.1:0")
			defer udp.Close()
			go func() {
				b := make([]byte, 2048)
				for {
					n, a, e := udp.ReadFrom(b)
					if e != nil {
						return
					}
					udp.WriteTo(b[:n], a)
				}
			}()
			meta = &C.Metadata{NetWork: C.UDP, DstIP: netip.MustParseAddr("127.0.0.1"), DstPort: uint16(udp.LocalAddr().(*net.UDPAddr).Port)}
			pc, err := proxy.ListenPacketContext(ctx, meta)
			if err != nil {
				t.Fatal(err)
			}
			defer pc.Close()
			pc.SetDeadline(time.Now().Add(3 * time.Second))
			if _, err = pc.WriteTo([]byte("FCN-UDP"), udp.LocalAddr()); err != nil {
				t.Fatal(err)
			}
			reply := make([]byte, 2048)
			n, addr, err := pc.ReadFrom(reply)
			if err != nil || string(reply[:n]) != "FCN-UDP" || addr.String() != udp.LocalAddr().String() {
				t.Fatalf("UDP: %q %v %v", reply[:n], addr, err)
			}
			// The adapter never disables certificate verification.
			bad, err := NewFCN(FCNOption{Name: "bad", Server: "127.0.0.1", Port: socket.LocalAddr().(*net.UDPAddr).Port, SNI: "wrong.example", UUID: uuid, Version: version, CAFile: ca})
			if err != nil {
				t.Fatal(err)
			}
			defer bad.Close()
			if c, err := bad.DialContext(ctx, &C.Metadata{Host: "example.com", DstPort: 443}); err == nil {
				c.Close()
				t.Fatal("accepted wrong certificate hostname")
			}
		})
	}
}
