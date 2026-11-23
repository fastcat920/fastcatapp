package h2client

import (
	"context"
	"crypto/x509"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/metacubex/mihomo/component/fastcatprobe"
	"github.com/metacubex/mihomo/component/fastcattls/quicprofile"
	qtls "github.com/metacubex/tls"
	"golang.org/x/net/http2"
)

// The QUIC TLS fork supports ML-KEM even when the host's crypto/tls defaults
// exclude it. Use an independent real TLS listener with both key exchanges.
func testExplicitGateway(t *testing.T, mode string) (string, *x509.CertPool) {
	t.Helper()
	template := httptest.NewTLSServer(http.NotFoundHandler())
	cert := template.TLS.Certificates[0]
	roots := x509.NewCertPool()
	roots.AddCert(template.Certificate())
	template.Close()
	cfg := &qtls.Config{NextProtos: []string{"h2"}, Certificates: []qtls.Certificate{{Certificate: cert.Certificate, PrivateKey: cert.PrivateKey}}}
	if err := quicprofile.ApplyQUIC(cfg, mode); err != nil {
		t.Fatal(err)
	}
	l, err := net.Listen("tcp4", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { l.Close() })
	go func() {
		for {
			raw, err := l.Accept()
			if err != nil {
				return
			}
			go func() {
				defer raw.Close()
				ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
				defer cancel()
				conn := qtls.Server(raw, cfg)
				if err := conn.HandshakeContext(ctx); err != nil {
					return
				}
				server := new(http2.Server)
				server.ServeConn(conn, &http2.ServeConnOpts{Handler: http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
					w.WriteHeader(http.StatusOK)
					w.(http.Flusher).Flush()
					io.Copy(io.Discard, r.Body)
				})})
			}()
		}
	}()
	return l.Addr().String(), roots
}

func TestExplicitTLSRecordsNegotiatedGroupOnReusedGateway(t *testing.T) {
	endpoint, roots := testExplicitGateway(t, "default")
	for mode, group := range map[string]string{"x25519": "X25519", "x25519mlkem768": "X25519MLKEM768"} {
		client, err := New(Config{Endpoint: endpoint, RootCAs: roots, CurveMode: mode, Token: strings.Repeat("x", 24)})
		if err != nil {
			t.Fatal(err)
		}
		defer client.Close()
		for i := 0; i < 2; i++ {
			timing := new(fastcatprobe.Timing)
			ctx, cancel := context.WithTimeout(timing.WithContext(context.Background()), 3*time.Second)
			conn, err := client.Dial(ctx, "test.example:80")
			cancel()
			if err != nil {
				t.Fatal(err)
			}
			conn.Close()
			meta := timing.Snapshot()
			if meta["gateway-group"] != group || meta["gateway-reused"] != (i > 0) || meta["gateway-tls-version"] != "TLS 1.3" || meta["gateway-cipher"] == nil {
				t.Fatalf("%s: %#v", mode, meta)
			}
		}
	}
}

func TestHybridRejectsWrongCertificateAndClassicalOnlyPeer(t *testing.T) {
	endpoint, roots := testExplicitGateway(t, "x25519")
	if _, err := New(Config{Endpoint: endpoint, Token: strings.Repeat("x", 24), CurveMode: "guess"}); err == nil {
		t.Fatal("accepted unknown curve mode")
	}
	for _, tc := range []struct{ name, mode string }{{"invalid.invalid", "x25519"}, {"", "x25519mlkem768"}} {
		client, err := New(Config{Endpoint: endpoint, RootCAs: roots, CurveMode: tc.mode, ServerName: tc.name, Token: strings.Repeat("x", 24)})
		if err != nil {
			t.Fatal(err)
		}
		ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
		conn, err := client.Dial(ctx, "test.example:80")
		cancel()
		if err == nil {
			conn.Close()
			t.Fatal("unsafe peer accepted")
		}
		client.Close()
	}
}
