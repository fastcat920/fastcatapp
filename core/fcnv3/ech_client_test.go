package fcnv3

import (
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"crypto/x509"
	"encoding/binary"
	"errors"
	"math/big"
	"net"
	"net/http"
	"sync/atomic"
	"testing"
	"time"

	"github.com/metacubex/tls"
	D "github.com/miekg/dns"
)

func TestHTTP3StrictECHRotation(t *testing.T) {
	const publicName = "outer.example"
	oldKey := testServerECHKey(t, publicName)
	newKey := testServerECHKey(t, publicName)
	newKey.SendAsRetry = true
	oldList := binary.BigEndian.AppendUint16(nil, uint16(len(oldKey.Config)))
	oldList = append(oldList, oldKey.Config...)
	newList := binary.BigEndian.AppendUint16(nil, uint16(len(newKey.Config)))
	newList = append(newList, newKey.Config...)
	const (
		serveOld int32 = iota
		serveNew
		serveMalformed
		serveUnavailable
	)
	var dnsMode, httpsQueries atomic.Int32
	dnsConfig := newEntryDNSTestConfig(t, func(w http.ResponseWriter, r *http.Request) {
		query := testEntryDNSQuery(t, r)
		if query == nil {
			return
		}
		if query.Question[0].Qtype == D.TypeHTTPS {
			httpsQueries.Add(1)
		}
		list := oldList
		switch dnsMode.Load() {
		case serveNew:
			list = newList
		case serveMalformed:
			list = []byte{0, 2, 1, 2}
		case serveUnavailable:
			w.WriteHeader(http.StatusServiceUnavailable)
			return
		}
		reply := testEntryDNSReply(query, list)
		switch query.Question[0].Qtype {
		case D.TypeA:
			reply.Answer[0].(*D.A).A = net.IPv4(127, 0, 0, 1)
		case D.TypeAAAA:
			reply.Answer = nil
		}
		writeEntryDNSReply(t, w, reply)
	})
	resolver, err := NewEntryDNSResolver(dnsConfig)
	if err != nil {
		t.Fatal(err)
	}
	target, accepts := startTestEcho(t)
	server, config := startStrictECHTestServer(t, target, publicName, oldKey)
	config.EntryDNS = resolver
	ctx, cancel := context.WithTimeout(t.Context(), 12*time.Second)
	defer cancel()
	initial := newTestClient(t, config)
	pooled, err := initial.acquire(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if !pooled.quic.ConnectionState().TLS.ECHAccepted || httpsQueries.Load() != 1 {
		t.Fatal("the initial encrypted DNS and ECH handshake did not complete")
	}
	stream := dialTestStream(t, ctx, initial, target)
	checkEcho(t, stream, []byte("before rotation"))

	if err := server.ReplaceECHKeys([]tls.EncryptedClientHelloKey{newKey, oldKey}); err != nil {
		t.Fatal(err)
	}
	dnsMode.Store(serveNew)
	overlap := newTestClient(t, config)
	if err := overlap.Warm(ctx); err != nil || httpsQueries.Load() != 1 {
		t.Fatalf("server rejected the cached previous key during overlap: %v", err)
	}
	if err := server.ReplaceECHKeys([]tls.EncryptedClientHelloKey{newKey}); err != nil {
		t.Fatal(err)
	}
	checkEcho(t, stream, []byte("after rotation"))
	checkEchoAndHalfClose(t, dialTestStream(t, ctx, initial, target), []byte("new stream on original connection"))
	if current, err := initial.acquire(ctx); current != pooled || err != nil || httpsQueries.Load() != 1 {
		t.Fatalf("rotation disrupted the pooled connection: %v", err)
	}

	fresh := newTestClient(t, config)
	rotated, err := fresh.acquire(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if !rotated.quic.ConnectionState().TLS.ECHAccepted || httpsQueries.Load() != 2 {
		t.Fatalf("fresh client needed %d DoH HTTPS requests, want one refresh after rejection", httpsQueries.Load()-1)
	}
	checkEchoAndHalfClose(t, dialTestStream(t, ctx, fresh, target), []byte("fresh connection using rotated key"))

	for _, test := range []struct {
		name     string
		mode     int32
		want     error
		requests int32
	}{
		{"unchanged after rejection", serveOld, ErrECHRejected, 2},
		{"malformed ECH", serveMalformed, ErrEntryDNS, 1},
		{"unavailable DoH", serveUnavailable, ErrEntryDNS, 1},
	} {
		t.Run(test.name, func(t *testing.T) {
			before, beforeAccepts := httpsQueries.Load(), accepts.Load()
			dnsMode.Store(test.mode)
			resolver.Invalidate(testEntryDNSName)
			client := newTestClient(t, config)
			conn, err := client.Dial(ctx, target)
			if conn != nil {
				conn.Close()
			}
			if conn != nil || !errors.Is(err, test.want) || httpsQueries.Load()-before != test.requests || accepts.Load() != beforeAccepts {
				t.Fatalf("Dial returned %v after %d DoH HTTPS queries, want %v after %d with no upstream connection", err, httpsQueries.Load()-before, test.want, test.requests)
			}
		})
	}
}

func startStrictECHTestServer(t *testing.T, target, publicName string, key tls.EncryptedClientHelloKey, options ...func(*ServerConfig)) (*Server, Config) {
	t.Helper()
	public, private, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	now := time.Now()
	template := &x509.Certificate{
		SerialNumber: big.NewInt(1), NotBefore: now.Add(-time.Minute), NotAfter: now.Add(time.Hour),
		DNSNames: []string{testEntryDNSName, publicName}, KeyUsage: x509.KeyUsageDigitalSignature,
		ExtKeyUsage: []x509.ExtKeyUsage{x509.ExtKeyUsageServerAuth},
	}
	der, err := x509.CreateCertificate(rand.Reader, template, template, public, private)
	if err != nil {
		t.Fatal(err)
	}
	certificate, err := x509.ParseCertificate(der)
	if err != nil {
		t.Fatal(err)
	}
	roots := x509.NewCertPool()
	roots.AddCert(certificate)
	packet, err := net.ListenPacket("udp4", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { packet.Close() })
	serverConfig := ServerConfig{
		TLSConfig:   &tls.Config{Certificates: []tls.Certificate{{Certificate: [][]byte{der}, PrivateKey: private, Leaf: certificate}}},
		Credentials: []Credential{{ID: testAccount, Secret: testSecret}},
		Targets:     []string{target},
		ECHKeys:     []tls.EncryptedClientHelloKey{key},
	}
	for _, option := range options {
		option(&serverConfig)
	}
	server, err := NewServer(serverConfig)
	if err != nil {
		t.Fatal(err)
	}
	done := make(chan error, 1)
	go func() { done <- server.Serve(packet) }()
	t.Cleanup(func() {
		server.Close()
		if err := <-done; err != nil && !errors.Is(err, net.ErrClosed) && !errors.Is(err, context.Canceled) {
			t.Errorf("serve: %v", err)
		}
	})
	return server, Config{Endpoint: packet.LocalAddr().String(), ServerName: testEntryDNSName, Account: testAccount, Secret: testSecret, Roots: roots}
}
