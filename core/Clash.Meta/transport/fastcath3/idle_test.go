package h3client

import (
	"context"
	"crypto/x509"
	"net"
	"net/http/httptest"
	"sync"
	"testing"
	"time"

	quic "github.com/metacubex/quic-go"
	"github.com/metacubex/quic-go/http3"
	tls "github.com/metacubex/tls"
)

type idlePacket struct {
	net.PacketConn
	once   sync.Once
	closed chan struct{}
}

func (p *idlePacket) Close() error {
	p.once.Do(func() { close(p.closed) })
	return p.PacketConn.Close()
}
func TestPrewarmedH3IdleSocketReclaimed(t *testing.T) {
	certServer := httptest.NewTLSServer(nil)
	defer certServer.Close()
	cert := certServer.TLS.Certificates[0]
	udp, err := net.ListenPacket("udp4", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer udp.Close()
	server := &http3.Server{TLSConfig: &tls.Config{Certificates: []tls.Certificate{{Certificate: cert.Certificate, PrivateKey: cert.PrivateKey}}, NextProtos: []string{"h3"}}, QUICConfig: &quic.Config{MaxIdleTimeout: 60 * time.Second}}
	go server.Serve(udp)
	defer server.Close()
	roots := x509.NewCertPool()
	roots.AddCert(certServer.Certificate())
	closed := make(chan struct{})
	c, err := NewContext(context.Background(), Config{Endpoint: udp.LocalAddr().String(), ServerName: "example.com", RootCAs: roots, Token: "test-only-credential-for-idle", OpenPacket: func(ctx context.Context, address string) (net.PacketConn, net.Addr, error) {
		p, a, e := openPacket(ctx, address)
		if e != nil {
			return nil, nil, e
		}
		return &idlePacket{PacketConn: p, closed: closed}, a, nil
	}})
	if err != nil {
		t.Fatal(err)
	}
	defer c.Close()
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	if err = c.Warm(ctx); err != nil {
		t.Fatal(err)
	}
	select {
	case <-closed:
	case <-time.After(65 * time.Second):
		t.Fatal("idle prewarm QUIC socket retained")
	}
}
