package adapter

import (
	"context"
	"crypto/tls"
	"encoding/pem"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"net/netip"
	"os"
	"path/filepath"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/metacubex/mihomo/adapter/outbound"
	C "github.com/metacubex/mihomo/constant"
)

type fastCatEntryDialer struct {
	C.Dialer
	addr  string
	count atomic.Int32
}

func (d *fastCatEntryDialer) DialContext(ctx context.Context, network, address string) (net.Conn, error) {
	if address != "test-gateway.invalid:8443" || network != "tcp" {
		return nil, fmt.Errorf("unexpected dial %s %s", network, address)
	}
	d.count.Add(1)
	var dialer net.Dialer
	return dialer.DialContext(ctx, network, d.addr)
}

func TestFastCatH2PlatformDialAndInterfaceChange(t *testing.T) {
	token := strings.Repeat("z", 32)
	server := httptest.NewUnstartedServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.TLS == nil || r.TLS.Version != tls.VersionTLS13 || r.TLS.NegotiatedProtocol != "h2" || r.ProtoMajor != 2 || r.Method != http.MethodConnect || r.Header.Get("Proxy-Authorization") != "Bearer "+token {
			http.Error(w, "authentication/transport failed", 407)
			return
		}
		w.WriteHeader(200)
		fmt.Fprintln(w, r.Host)
		w.(http.Flusher).Flush()
		<-r.Context().Done()
	}))
	server.EnableHTTP2 = true
	server.StartTLS()
	defer server.Close()
	file := filepath.Join(t.TempDir(), "ca.pem")
	if err := os.WriteFile(file, pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: server.Certificate().Raw}), 0600); err != nil {
		t.Fatal(err)
	}
	entry := &fastCatEntryDialer{addr: server.Listener.Addr().String()}
	p, err := ParseProxy(map[string]any{"name": "h2-test", "type": "fastcat-h2", "server": "test-gateway.invalid", "port": 8443, "sni": "example.com", "token": token, "ca-file": file}, WithDialerForAPI(entry))
	if err != nil {
		t.Fatal(err)
	}
	defer p.Close()
	if p.SupportUDP() || p.Type() != C.FastCatH2 {
		t.Fatal("incorrect advertised type/capabilities")
	}
	if p.Addr() != "test-gateway.invalid:8443" {
		t.Fatalf("invalid server %q", p.Addr())
	}
	open := func(m *C.Metadata) C.Conn {
		t.Helper()
		ctx, cancel := context.WithTimeout(context.Background(), time.Second*3)
		defer cancel()
		c, err := p.DialContext(ctx, m)
		if err != nil {
			t.Fatal(err)
		}
		t.Cleanup(func() { c.Close() })
		expected := m.RemoteAddress() + "\n"
		buf := make([]byte, len(expected))
		c.SetReadDeadline(time.Now().Add(time.Second * 3))
		if _, err := io.ReadFull(c, buf); err != nil || string(buf) != expected {
			t.Fatalf("expected %s, got %q: %v", expected, buf, err)
		}
		return c
	}
	m := &C.Metadata{Host: "destination.invalid", DstPort: 443}
	c := open(m)
	open(&C.Metadata{DstIP: netip.MustParseAddr("2001:db8::1"), DstPort: 80}).Close()
	if got := entry.count.Load(); got != 1 {
		t.Fatalf("entry dials before interface change: %d", got)
	}
	outbound.ResetFastCatH2Connections()
	if _, err := c.Read(make([]byte, 1)); err == nil || errors.Is(err, os.ErrDeadlineExceeded) {
		t.Fatalf("old stream survived network change: %v", err)
	}
	open(m).Close()
	if got := entry.count.Load(); got != 2 {
		t.Fatalf("entry dials after interface change: %d", got)
	}
	// Also cover an interface change while the physical pool has no active streams.
	outbound.ResetFastCatH2Connections()
	open(m).Close()
	if got := entry.count.Load(); got != 3 {
		t.Fatalf("stale idle connection reused: %d physical dials", got)
	}
	p.Close()
	outbound.ResetFastCatH2Connections()
	if _, err := p.DialContext(context.Background(), m); !errors.Is(err, net.ErrClosed) {
		t.Fatalf("closed node resurrected: %v", err)
	}
}

func TestFastCatH2RejectsInvalidOptions(t *testing.T) {
	for _, overrides := range []map[string]any{{"udp": true}, {"skip-cert-verify": true}, {"port": 0}, {"port": 65536}, {"token": "bad"}, {"server": ""}} {
		t.Run(fmt.Sprint(overrides), func(t *testing.T) {
			m := map[string]any{"name": "test", "type": "fastcat-h2", "server": "example.net", "port": 443, "token": strings.Repeat("t", 24)}
			for key, value := range overrides {
				m[key] = value
			}
			if _, err := ParseProxy(m); err == nil {
				t.Fatalf("invalid options accepted")
			}
		})
	}
}
