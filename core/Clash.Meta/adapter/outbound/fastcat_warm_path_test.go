package outbound

import (
	"context"
	"encoding/pem"
	"errors"
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

	h3http "github.com/metacubex/http"
	"github.com/metacubex/mihomo/component/fastcatentry"
	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/quic-go/http3"
	qtls "github.com/metacubex/tls"
)

// Drop datagrams at a real loopback server, including packets on established sockets.
type warmPathPackets struct {
	net.PacketConn
	dropRead, dropWrite atomic.Bool
}

func (p *warmPathPackets) ReadFrom(buf []byte) (int, net.Addr, error) {
	for {
		n, addr, err := p.PacketConn.ReadFrom(buf)
		if err != nil || !p.dropRead.Load() {
			return n, addr, err
		}
	}
}
func (p *warmPathPackets) WriteTo(buf []byte, addr net.Addr) (int, error) {
	if p.dropWrite.Load() {
		return len(buf), nil
	}
	return p.PacketConn.WriteTo(buf, addr)
}

type warmPathFixture struct {
	a                    *FastCatAuto
	wire                 *warmPathPackets
	sockets              v2TestSockets
	h2, checks, requests atomic.Int32
	hold                 chan struct{}
}

func newWarmPathFixture(t *testing.T) *warmPathFixture {
	t.Helper()
	f := new(warmPathFixture)
	f.hold = make(chan struct{})
	h2 := httptest.NewUnstartedServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		f.h2.Add(1)
		w.WriteHeader(200)
		w.(http.Flusher).Flush()
		<-r.Context().Done()
	}))
	h2.EnableHTTP2 = true
	h2.StartTLS()
	t.Cleanup(h2.Close)
	ca := filepath.Join(t.TempDir(), "test.pem")
	if err := os.WriteFile(ca, pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: h2.Certificate().Raw}), 0600); err != nil {
		t.Fatal(err)
	}
	udp, err := net.ListenPacket("udp4", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	f.wire = &warmPathPackets{PacketConn: udp}
	cert := h2.TLS.Certificates[0]
	h3 := &http3.Server{EnableDatagrams: true, TLSConfig: &qtls.Config{Certificates: []qtls.Certificate{{Certificate: cert.Certificate, PrivateKey: cert.PrivateKey}}, NextProtos: []string{"h3"}},
		Handler: h3http.HandlerFunc(func(w h3http.ResponseWriter, r *h3http.Request) {
			if r.Method != "CONNECT" {
				if r.Method != "HEAD" || r.Header.Get("Proxy-Authorization") != "" || r.URL.Path != "/" || r.Host != udp.LocalAddr().String() {
					t.Error("gateway check carried unexpected request metadata")
				}
				f.checks.Add(1)
				w.WriteHeader(405)
				return
			}
			f.requests.Add(1)
			if strings.HasPrefix(r.Host, "slow.") {
				select {
				case <-f.hold:
				case <-r.Context().Done():
					return
				}
				if strings.HasPrefix(r.Host, "slow.auth") {
					w.WriteHeader(407)
				} else {
					w.WriteHeader(403)
				}
				return
			}
			if r.Proto == "connect-udp" {
				w.Header().Set(http3.CapsuleProtocolHeader, "?1")
			}
			w.WriteHeader(200)
			w.(h3http.Flusher).Flush()
			<-r.Context().Done()
		})}
	go h3.Serve(f.wire)
	t.Cleanup(func() { h3.Close(); udp.Close() })
	opt := FastCatAutoOption{FastCatHTTPSOption: FastCatHTTPSOption{Name: "loopback", Token: "test-only-credential-for-tcp", Server: "127.0.0.1", Port: h2.Listener.Addr().(*net.TCPAddr).Port, SNI: "example.com", CAFile: ca, UDP: true, BasicOption: BasicOption{DialerForAPI: &f.sockets}}, H3Token: "test-only-credential-for-udp", H3Port: udp.LocalAddr().(*net.UDPAddr).Port}
	f.a, err = NewFastCatAuto(opt)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { f.a.Close() })
	return f
}

func warmMetadata() *C.Metadata {
	return &C.Metadata{NetWork: C.UDP, DstIP: netip.MustParseAddr("192.0.2.7"), DstPort: 53}
}
func (f *warmPathFixture) warm(t *testing.T) {
	t.Helper()
	c, err := f.a.ListenPacketContext(context.Background(), warmMetadata())
	if err != nil {
		t.Fatal(err)
	}
	c.Close()
	f.a.mu.Lock()
	f.a.routes.paths[pathH2].lastAttempt = time.Now()
	f.a.mu.Unlock()
}

func TestFastCatWarmPathLoss(t *testing.T) {
	for _, mode := range []string{"upload", "download", "both"} {
		mode := mode
		t.Run(mode, func(t *testing.T) {
			t.Parallel()
			f := newWarmPathFixture(t)
			f.warm(t)
			f.wire.dropRead.Store(mode != "download")
			f.wire.dropWrite.Store(mode != "upload")
			type result struct {
				err     error
				elapsed time.Duration
			}
			tcp, udp := make(chan result, 1), make(chan result, 1)
			start := time.Now()
			go func() {
				c, err := f.a.DialContext(context.Background(), &C.Metadata{Host: "echo.test", DstPort: 443})
				if c != nil {
					c.Close()
				}
				tcp <- result{err, time.Since(start)}
			}()
			go func() {
				c, err := f.a.ListenPacketContext(context.Background(), warmMetadata())
				if c != nil {
					c.Close()
				}
				udp <- result{err, time.Since(start)}
			}()
			x, y := <-tcp, <-udp
			f.a.mu.Lock()
			blocked := time.Now().Before(f.a.routes.paths[pathH3].blockedUntil)
			state := f.a.routes.status
			f.a.mu.Unlock()
			t.Logf("tcp %s, error=%v; udp %s, error=%v; cooldown=%v h2=%d; UDP=%s/%s", x.elapsed, x.err, y.elapsed, y.err, blocked, f.h2.Load(), state.UDPStatus, state.UDPError)
			if x.err != nil || y.err == nil || f.h2.Load() != 1 || !blocked || state.TCPProtocol != "h2" || state.UDPError != "entry" || x.elapsed >= 4*time.Second || y.elapsed >= 4*time.Second {
				t.Fatal("warm blackhole did not recover cleanly")
			}
			timer := time.Now()
			c, err := f.a.ListenPacketContext(context.Background(), warmMetadata())
			if c != nil {
				c.Close()
			}
			if err == nil || time.Since(timer) > 200*time.Millisecond {
				t.Fatal("cooldown did not suppress UDP")
			}
			f.wire.dropRead.Store(false)
			f.wire.dropWrite.Store(false)
			f.a.mu.Lock()
			f.a.routes.paths[pathH3].blockedUntil = time.Time{}
			f.a.mu.Unlock()
			c, err = f.a.ListenPacketContext(context.Background(), warmMetadata())
			if err != nil {
				t.Fatal("failed to recover after cooldown", err)
			}
			c.Close()
			if f.sockets.sockets.Load() != 2 {
				t.Fatal("reused a previously unresponsive QUIC socket")
			}
		})
	}
}

func TestFastCatWarmSlowTarget(t *testing.T) {
	f := newWarmPathFixture(t)
	f.warm(t)
	const n = 6
	type result struct {
		code int
		err  error
	}
	results := make(chan result, n)
	for i := 0; i < n; i++ {
		host, code := "slow.denied", 403
		if i%2 == 0 {
			host, code = "slow.auth", 407
		}
		go func(host string, code int) {
			ctx, cancel := context.WithTimeout(context.Background(), 6*time.Second)
			defer cancel()
			c, err := f.a.DialContext(ctx, &C.Metadata{Host: host, DstPort: 443})
			if c != nil {
				c.Close()
			}
			results <- result{code, err}
		}(host, code)
	}
	// Delay the policy/credential reply past the blackhole decision time.
	time.Sleep(2800 * time.Millisecond)
	close(f.hold)
	for i := 0; i < n; i++ {
		r := <-results
		if !errors.Is(r.err, fastcatentry.StatusError(r.code)) {
			t.Fatalf("lost terminal response %d: %v", r.code, r.err)
		}
	}
	if f.h2.Load() != 0 || f.checks.Load() != 1 || f.requests.Load() != 1+n {
		t.Fatalf("unexpected fallback/check/request counts %d/%d/%d", f.h2.Load(), f.checks.Load(), f.requests.Load())
	}
	f.a.mu.Lock()
	blocked := time.Now().Before(f.a.routes.paths[pathH3].blockedUntil)
	f.a.mu.Unlock()
	if blocked {
		t.Fatal("slow targets put healthy gateway into cooldown")
	}
}

func TestFastCatWarmUDPAdditionalTarget(t *testing.T) {
	f := newWarmPathFixture(t)
	pc, err := f.a.ListenPacketContext(context.Background(), warmMetadata())
	if err != nil {
		t.Fatal(err)
	}
	defer pc.Close()
	f.wire.dropRead.Store(true)
	next := &net.UDPAddr{IP: net.IPv4(192, 0, 2, 9), Port: 53}
	n, err := pc.WriteTo([]byte{7}, next)
	if n != 0 || !errors.Is(err, fastcatentry.ErrUnresponsive) {
		t.Fatalf("payload accepted without live association: %d %v", n, err)
	}
	f.a.mu.Lock()
	blocked := time.Now().Before(f.a.routes.paths[pathH3].blockedUntil)
	status := f.a.routes.status
	f.a.mu.Unlock()
	if !blocked || status.UDPError != "entry" || f.h2.Load() != 0 {
		t.Fatal("secondary destination bypassed UDP policy", status)
	}
	next.Port++
	start := time.Now()
	if _, err = pc.WriteTo([]byte{8}, next); err == nil || time.Since(start) > 200*time.Millisecond {
		t.Fatal("another destination skipped cooldown", err)
	}
	c, err := f.a.DialContext(context.Background(), &C.Metadata{Host: "echo.test", DstPort: 80})
	if err != nil {
		t.Fatal(err)
	}
	c.Close()
	if f.h2.Load() != 1 {
		t.Fatal("TCP did not use surviving gateway")
	}
}
