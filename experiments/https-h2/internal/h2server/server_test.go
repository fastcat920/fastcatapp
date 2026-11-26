package h2server_test

import (
	"context"
	"crypto/x509"
	"io"
	"net"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/metacubex/mihomo/transport/fastcath2"
	"fastcat.local/https-h2/internal/h2server"
)

func TestSessionTimeoutClosesIdleOriginAndReleasesQuota(t *testing.T) {
	const token = "local-session-timeout-test-only"
	handler, err := h2server.New(h2server.Config{
		Token: token, MaxTunnels: 1, AllowPrivateTargets: true, SessionTimeout: 180 * time.Millisecond,
	})
	if err != nil {
		t.Fatal(err)
	}
	s := httptest.NewUnstartedServer(handler)
	s.EnableHTTP2 = true
	s.StartTLS()
	defer s.Close()
	roots := x509.NewCertPool()
	roots.AddCert(s.Certificate())
	client, err := h2client.New(h2client.Config{
		Token: token, Endpoint: s.Listener.Addr().String(), ServerName: "example.com", RootCAs: roots,
	})
	if err != nil {
		t.Fatal(err)
	}
	defer client.Close()
	target, err := net.Listen("tcp4", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer target.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	for range 2 {
		start := time.Now()
		tunnel, err := client.Dial(ctx, target.Addr().String())
		if err != nil {
			t.Fatal(err)
		}
		origin, err := target.Accept()
		if err != nil {
			tunnel.Close()
			t.Fatal(err)
		}
		origin.SetReadDeadline(time.Now().Add(3 * time.Second))
		var b [1]byte
		_, err = origin.Read(b[:])
		origin.Close()
		tunnel.SetReadDeadline(time.Now().Add(time.Second))
		_, streamErr := tunnel.Read(b[:])
		tunnel.Close()
		if err != io.EOF || streamErr == nil || time.Since(start) < 150*time.Millisecond {
			t.Fatalf("timed session closed unexpectedly: origin=%v stream=%v duration=%v", err, streamErr, time.Since(start))
		}
	}
}
