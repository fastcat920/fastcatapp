package outbound

import (
	"context"
	"encoding/json"
	"encoding/pem"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"net/netip"
	"os"
	"path/filepath"
	"strings"
	"sync/atomic"
	"syscall"
	"testing"
	"time"

	h3http "github.com/metacubex/http"
	"github.com/metacubex/mihomo/component/fastcatprobe"
	C "github.com/metacubex/mihomo/constant"
	h3client "github.com/metacubex/mihomo/transport/fastcath3"
	"github.com/metacubex/quic-go/http3"
	qtls "github.com/metacubex/tls"
)

type v2TestSockets struct {
	C.Dialer
	blocked atomic.Bool
	sockets atomic.Int32
}

func (d *v2TestSockets) DialContext(ctx context.Context, network, address string) (net.Conn, error) {
	return (&net.Dialer{}).DialContext(ctx, network, address)
}
func (d *v2TestSockets) ListenPacket(ctx context.Context, network, address string, peer netip.AddrPort) (net.PacketConn, error) {
	d.sockets.Add(1)
	if d.blocked.Load() {
		return nil, syscall.ENETUNREACH
	}
	if !peer.IsValid() {
		return nil, net.InvalidAddrError("missing peer")
	}
	return (&net.ListenConfig{}).ListenPacket(ctx, network, address)
}

func TestV2LiveAdapter(t *testing.T) {
	const token = "local-validated-example-device-token"
	h2 := httptest.NewUnstartedServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(200)
		w.(http.Flusher).Flush()
		var b [1]byte
		if _, err := io.ReadFull(r.Body, b[:]); err == nil {
			w.Write(b[:])
			w.(http.Flusher).Flush()
		}
	}))
	h2.EnableHTTP2 = true
	h2.StartTLS()
	defer h2.Close()
	ca := filepath.Join(t.TempDir(), "roots.pem")
	if err := os.WriteFile(ca, pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: h2.Certificate().Raw}), 0600); err != nil {
		t.Fatal(err)
	}
	pc, err := net.ListenPacket("udp4", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer pc.Close()
	cert := h2.TLS.Certificates[0]
	var reject atomic.Bool
	h3 := &http3.Server{EnableDatagrams: true, TLSConfig: &qtls.Config{Certificates: []qtls.Certificate{{Certificate: cert.Certificate, PrivateKey: cert.PrivateKey}}, NextProtos: []string{"h3"}},
		Handler: h3http.HandlerFunc(func(w h3http.ResponseWriter, r *h3http.Request) {
			if reject.Load() || r.Header.Get("Proxy-Authorization") != "Bearer "+token {
				w.WriteHeader(407)
				return
			}
			udp := r.Proto == "connect-udp"
			if udp {
				w.Header().Set(http3.CapsuleProtocolHeader, "?1")
			}
			w.WriteHeader(200)
			str := w.(http3.HTTPStreamer).HTTPStream()
			if udp {
				d := h3client.NewDatagramConn(str, pc.LocalAddr(), pc.LocalAddr())
				defer d.Close()
				buf := make([]byte, 2048)
				for {
					n, err := d.Read(buf)
					if err != nil {
						return
					}
					if _, err = d.Write(buf[:n]); err != nil {
						return
					}
				}
			} else {
				var b [1]byte
				if _, err := io.ReadFull(str, b[:]); err == nil {
					str.Write(b[:])
				}
				str.Close()
			}
		})}
	go h3.Serve(pc)
	defer h3.Close()
	sockets := new(v2TestSockets)
	opt := FastCatAutoOption{FastCatHTTPSOption: FastCatHTTPSOption{Name: "Sample", Server: "127.0.0.1", SNI: "example.com", Port: h2.Listener.Addr().(*net.TCPAddr).Port, CAFile: ca, Token: token, UDP: true, BasicOption: BasicOption{DialerForAPI: sockets}}, H3Port: pc.LocalAddr().(*net.UDPAddr).Port, H3Token: token}
	a, err := NewFastCatAuto(opt)
	if err != nil {
		t.Fatal(err)
	}
	defer a.Close()
	metadata := &C.Metadata{Host: "example.net", DstPort: 443}
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	status := func() routeStatus {
		var obj struct {
			V2 routeStatus `json:"fastcat-v2"`
		}
		data, err := a.MarshalJSON()
		if err != nil || strings.Contains(string(data), token) || json.Unmarshal(data, &obj) != nil {
			t.Fatal("bad status")
		}
		return obj.V2
	}
	echo := func(want string) {
		t.Helper()
		phase := new(fastcatprobe.Timing)
		c, err := a.DialContext(phase.WithContext(ctx), metadata)
		if err != nil {
			t.Fatal(err)
		}
		defer c.Close()
		c.SetDeadline(time.Now().Add(time.Second))
		var b [1]byte
		if _, err = c.Write([]byte{42}); err != nil {
			t.Fatal(err)
		}
		if _, err = io.ReadFull(c, b[:]); err != nil || b[0] != 42 {
			t.Fatal(b, err)
		}
		if phase.Snapshot()["used-protocol"] != want || status().TCPProtocol != want {
			t.Fatal("wrong path", phase.Snapshot(), status())
		}
	}
	echo("h3")
	udpMeta := &C.Metadata{NetWork: C.UDP, DstIP: netip.MustParseAddr("127.0.0.1"), DstPort: 3000}
	d, err := a.ListenPacketContext(ctx, udpMeta)
	if err != nil {
		t.Fatal(err)
	}
	d.SetDeadline(time.Now().Add(2 * time.Second))
	for _, port := range []uint16{3000, 3001, 3000} {
		addr := net.UDPAddrFromAddrPort(netip.AddrPortFrom(udpMeta.DstIP, port))
		if _, err = d.WriteTo([]byte{9}, addr); err != nil {
			t.Fatal(err)
		}
		var buf [1]byte
		n, from, err := d.ReadFrom(buf[:])
		if err != nil || n != 1 || buf[0] != 9 || from.String() != addr.String() {
			t.Fatal(n, from, err)
		}
	}
	d.Close()
	if sockets.sockets.Load() != 1 || status().UDPStatus != "available" {
		t.Fatal("did not reuse H3 gateway", status())
	}
	sockets.blocked.Store(true)
	ResetFastCatH2Connections()
	if status().UDPStatus != "unknown" || status().TCPProtocol != "" {
		t.Fatal("stale network state")
	}
	echo("h2")
	if _, err = a.ListenPacketContext(ctx, udpMeta); err == nil || status().UDPError != "entry" {
		t.Fatal("UDP silently fell back", err, status())
	}
	sockets.blocked.Store(false)
	ResetFastCatH2Connections()
	reject.Store(true)
	if _, err = a.DialContext(ctx, metadata); err == nil || status().TCPError != "authentication" {
		t.Fatal("credential error downgraded/misreported", err, status())
	}
	reject.Store(false)
	opt.H3SNI = "mismatch.invalid"
	bad, err := NewFastCatAuto(opt)
	if err != nil {
		t.Fatal(err)
	}
	defer bad.Close()
	if _, err = bad.DialContext(ctx, metadata); err == nil {
		t.Fatal("wrong certificate accepted")
	}
	a = bad
	if status().TCPError != "certificate" {
		t.Fatal("certificate error misreported", err, status())
	}

	opt.H3SNI = ""
	opt.V2Transport = "h3"
	ResetFastCatH2Connections()
	h3Only, err := NewFastCatAuto(opt)
	if err != nil {
		t.Fatal(err)
	}
	defer h3Only.Close()
	a = h3Only
	echo("h3")
	sockets.blocked.Store(true)
	ResetFastCatH2Connections()
	if _, err = h3Only.DialContext(ctx, metadata); err == nil {
		t.Fatal("HTTP/3-only node fell back to HTTP/2")
	}

}
