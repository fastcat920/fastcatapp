package fastcatv3

import (
	"context"
	"crypto/tls"
	"errors"
	"net"
	"net/http"
	"time"

	qhttp "github.com/metacubex/http"
	"github.com/metacubex/quic-go/http3"
	qtls "github.com/metacubex/tls"
)

// GenerateConfig creates separate service and account fixture material.
func GenerateConfig() Config {
	key := random(32)
	pub, _ := public(key)
	return Config{ServiceID: random(16), ServerPrivate: key, ServerPublic: pub, Token: random(32)}
}

// Serve runs the two standard carriers on the same TCP/UDP address.
func Serve(ctx context.Context, c Config, address, certFile, keyFile string) error {
	s, e := NewServer(c)
	if e != nil {
		return e
	}
	cert, e := tls.LoadX509KeyPair(certFile, keyFile)
	if e != nil {
		return e
	}
	s.OnError = func(e error) { c.trace("server session_end: " + e.Error()) }
	tcp, e := net.Listen("tcp", address)
	if e != nil {
		return e
	}
	defer tcp.Close()
	udp, e := net.ListenPacket("udp", tcp.Addr().String())
	if e != nil {
		return e
	}
	defer udp.Close()
	h2 := &http.Server{Handler: s, ReadHeaderTimeout: 5 * time.Second, MaxHeaderBytes: 16 << 10, TLSConfig: &tls.Config{MinVersion: tls.VersionTLS13, Certificates: []tls.Certificate{cert}}}
	h3 := &http3.Server{Handler: qhttp.HandlerFunc(s.ServeHTTP3), MaxHeaderBytes: 16 << 10, TLSConfig: &qtls.Config{MinVersion: qtls.VersionTLS13, NextProtos: []string{"h3"}, Certificates: []qtls.Certificate{{Certificate: cert.Certificate, PrivateKey: cert.PrivateKey}}}}
	done := make(chan error, 2)
	go func() { done <- h2.ServeTLS(tcp, "", "") }()
	go func() { done <- h3.Serve(udp) }()
	var first error
	consumed := false
	select {
	case <-ctx.Done():
	case first = <-done:
		consumed = true
	}
	h2.Close()
	h3.Close()
	tcp.Close()
	udp.Close()
	if !consumed {
		<-done
	}
	<-done
	if errors.Is(first, http.ErrServerClosed) || errors.Is(first, net.ErrClosed) {
		return nil
	}
	return first
}

// ServeIndependent runs the independent-stream prototype on a dedicated address.
func ServeIndependent(ctx context.Context, c Config, address, certFile, keyFile string) error {
	s, e := NewIndependentServer(c)
	if e != nil {
		return e
	}
	cert, e := tls.LoadX509KeyPair(certFile, keyFile)
	if e != nil {
		return e
	}
	tcp, e := net.Listen("tcp", address)
	if e != nil {
		return e
	}
	defer tcp.Close()
	udp, e := net.ListenPacket("udp", tcp.Addr().String())
	if e != nil {
		return e
	}
	defer udp.Close()
	h2 := &http.Server{Handler: s, ReadHeaderTimeout: 5 * time.Second, MaxHeaderBytes: 16 << 10, TLSConfig: &tls.Config{MinVersion: tls.VersionTLS13, Certificates: []tls.Certificate{cert}}}
	h3 := &http3.Server{Handler: qhttp.HandlerFunc(s.ServeHTTP3), MaxHeaderBytes: 16 << 10, TLSConfig: &qtls.Config{MinVersion: qtls.VersionTLS13, NextProtos: []string{"h3"}, Certificates: []qtls.Certificate{{Certificate: cert.Certificate, PrivateKey: cert.PrivateKey}}}}
	done := make(chan error, 2)
	go func() { done <- h2.ServeTLS(tcp, "", "") }()
	go func() { done <- h3.Serve(udp) }()
	consumed := false
	var first error
	select {
	case <-ctx.Done():
	case first = <-done:
		consumed = true
	}
	h2.Close()
	h3.Close()
	tcp.Close()
	udp.Close()
	if !consumed {
		<-done
	}
	<-done
	if errors.Is(first, http.ErrServerClosed) || errors.Is(first, net.ErrClosed) {
		return nil
	}
	return first
}
