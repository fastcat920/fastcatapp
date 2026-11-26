package verify

import (
	"context"
	"crypto/x509"
	"fmt"
	"io"
	"net"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"fastcat.local/https-h2/internal/h2server"
	"github.com/metacubex/mihomo/component/fastcatprobe"
	h3client "github.com/metacubex/mihomo/transport/fastcath3"
	quic "github.com/metacubex/quic-go"
	"github.com/metacubex/quic-go/http3"
	tls "github.com/metacubex/tls"
)

func TestH3Gateway(t *testing.T) {
	const a, b = "alpha-device-credential-000000000", "bravo-device-credential-000000000"
	file := filepath.Join(t.TempDir(), "grants")
	write := func(data string) {
		t.Helper()
		if err := os.WriteFile(file, []byte(data), 0600); err != nil {
			t.Fatal(err)
		}
	}
	write(a + "\n" + b + "\n")
	h, err := h2server.NewH3(h2server.Config{TokensFile: file, AllowPrivateTargets: true, SessionTimeout: 3 * time.Second})
	if err != nil {
		t.Fatal(err)
	}
	certSource := httptest.NewTLSServer(nil)
	src := certSource.TLS.Certificates[0]
	root := certSource.Certificate()
	certSource.Close()
	roots := x509.NewCertPool()
	roots.AddCert(root)
	pc, err := net.ListenPacket("udp4", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer pc.Close()
	var count atomic.Int32
	srv := &http3.Server{EnableDatagrams: true, Handler: h, TLSConfig: &tls.Config{Certificates: []tls.Certificate{{Certificate: src.Certificate, PrivateKey: src.PrivateKey}}, NextProtos: []string{"h3"}}, ConnContext: func(ctx context.Context, c *quic.Conn) context.Context { count.Add(1); return ctx }}
	go srv.Serve(pc)
	defer srv.Close()
	client := func(token, mode string, ca *x509.CertPool) *h3client.Client {
		t.Helper()
		c, err := h3client.NewContext(context.Background(), h3client.Config{Endpoint: pc.LocalAddr().String(), RootCAs: ca, Token: token, CurveMode: mode})
		if err != nil {
			t.Fatal(err)
		}
		t.Cleanup(func() { c.Close() })
		return c
	}
	c := client(a, "x25519mlkem768", roots)
	udp, err := net.ListenPacket("udp4", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer udp.Close()
	go func() {
		buf := make([]byte, 65535)
		for {
			n, addr, err := udp.ReadFrom(buf)
			if err != nil {
				return
			}
			udp.WriteTo(buf[:n], addr)
		}
	}()
	tcp, err := net.Listen("tcp4", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer tcp.Close()
	go func() {
		for {
			conn, err := tcp.Accept()
			if err != nil {
				return
			}
			go func() { defer conn.Close(); b, _ := io.ReadAll(conn); conn.Write(b) }()
		}
	}()
	ctx, cancel := context.WithTimeout(context.Background(), 12*time.Second)
	defer cancel()
	timing := new(fastcatprobe.Timing)
	packet, err := c.DialUDP(timing.WithContext(ctx), udp.LocalAddr().String())
	if err != nil {
		t.Fatal(err)
	}
	defer packet.Close()
	if snap := timing.Snapshot(); !strings.Contains(fmt.Sprint(snap), "X25519MLKEM768") {
		t.Fatalf("no actual hybrid handshake: %v", snap)
	}
	packet.SetDeadline(time.Now().Add(2 * time.Second))
	checkPacket := func(p []byte) {
		t.Helper()
		if _, err := packet.Write(p); err != nil {
			t.Fatal(err)
		}
		buf := make([]byte, len(p)+2)
		n, err := packet.Read(buf)
		if err != nil || string(buf[:n]) != string(p) {
			t.Fatalf("UDP echo %d bytes: %v", n, err)
		}
	}
	checkPacket([]byte("one"))
	checkPacket(nil)
	var wg sync.WaitGroup
	for i := 0; i < 5; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			c, err := c.Dial(ctx, tcp.Addr().String())
			if err != nil {
				t.Error(err)
				return
			}
			defer c.Close()
			c.SetDeadline(time.Now().Add(2 * time.Second))
			if _, err = c.Write([]byte("after-fin")); err != nil {
				t.Error(err)
				return
			}
			c.(interface{ CloseWrite() error }).CloseWrite()
			reply, err := io.ReadAll(c)
			if err != nil || string(reply) != "after-fin" {
				t.Errorf("TCP echo %q %v", reply, err)
			}
		}()
	}
	wg.Wait()
	if count.Load() != 1 {
		t.Fatalf("connections for TCP+UDP: %d", count.Load())
	}
	write(b + "\n")
	if err := h.ReloadTokens(); err != nil {
		t.Fatal(err)
	}
	for _, dial := range []func(context.Context, string) (net.Conn, error){c.Dial, c.DialUDP} {
		if conn, err := dial(ctx, udp.LocalAddr().String()); err == nil {
			conn.Close()
			t.Fatal("revoked credential accepted")
		} else if !strings.Contains(err.Error(), "407") {
			t.Fatal(err)
		}
	}
	checkPacket([]byte("already-authorized"))
	if conn, err := client(b, "x25519", x509.NewCertPool()).Dial(ctx, tcp.Addr().String()); err == nil {
		conn.Close()
		t.Fatal("untrusted certificate accepted")
	}
}
