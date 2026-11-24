package fcn

import (
	"bytes"
	"context"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/tls"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/json"
	qtls "github.com/metacubex/tls"
	"math/big"
	"net"
	"os"
	"testing"
	"time"
)

func pinCert(t *testing.T, key *ecdsa.PrivateKey) (qtls.Certificate, *x509.Certificate, *ecdsa.PrivateKey) {
	t.Helper()
	var err error
	if key == nil {
		key, err = ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
		if err != nil {
			t.Fatal(err)
		}
	}
	serial, _ := rand.Int(rand.Reader, new(big.Int).Lsh(big.NewInt(1), 120))
	template := &x509.Certificate{SerialNumber: serial, Subject: pkix.Name{CommonName: "www.bing.com"}, DNSNames: []string{"www.bing.com"}, NotBefore: time.Now().Add(-time.Minute), NotAfter: time.Now().Add(time.Hour), KeyUsage: x509.KeyUsageDigitalSignature, ExtKeyUsage: []x509.ExtKeyUsage{x509.ExtKeyUsageServerAuth}}
	der, err := x509.CreateCertificate(rand.Reader, template, template, &key.PublicKey, key)
	if err != nil {
		t.Fatal(err)
	}
	leaf, err := x509.ParseCertificate(der)
	if err != nil {
		t.Fatal(err)
	}
	return qtls.Certificate{Certificate: [][]byte{der}, PrivateKey: key}, leaf, key
}
func pinnedEndpoint(t *testing.T, cert qtls.Certificate) string {
	t.Helper()
	key := bytes.Repeat([]byte{7}, 32)
	server, err := NewServer(ServerConfig{Accounts: map[string][]byte{"test": key}, AllowPrivate: true})
	if err != nil {
		t.Fatal(err)
	}
	pc, err := net.ListenPacket("udp4", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	go func() {
		defer close(done)
		server.ServeQUIC(ctx, pc, &qtls.Config{Certificates: []qtls.Certificate{cert}})
	}()
	t.Cleanup(func() {
		cancel()
		pc.Close()
		select {
		case <-done:
		case <-time.After(3 * time.Second):
			t.Error("pinned server did not stop")
		}
	})
	return pc.LocalAddr().String()
}
func TestPinnedQUICIdentityAndRenewal(t *testing.T) {
	cert, leaf, key := pinCert(t, nil)
	renewed, renewLeaf, _ := pinCert(t, key)
	other, otherLeaf, _ := pinCert(t, nil)
	if PublicKeyPin(leaf) != PublicKeyPin(renewLeaf) || PublicKeyPin(leaf) == PublicKeyPin(otherLeaf) {
		t.Fatal("SPKI renewal invariant failed")
	}
	target, _ := echoTarget(t)
	for _, version := range []int{1, 2} {
		cases := []struct {
			name string
			cert qtls.Certificate
			pins []string
			mode string
			ok   bool
		}{
			{"first", cert, []string{PublicKeyPin(leaf)}, "spki", true},
			{"renewed-same-key", renewed, []string{PublicKeyPin(leaf)}, "spki", true},
			{"wrong-key", other, []string{PublicKeyPin(leaf)}, "spki", false},
			{"explicit-overlap", other, []string{PublicKeyPin(leaf), PublicKeyPin(otherLeaf)}, "spki", true},
			{"no-ca-bypass", cert, nil, "ca", false},
		}
		for _, test := range cases {
			t.Run(test.name+string(rune('0'+version)), func(t *testing.T) {
				cfg := Config{Endpoint: pinnedEndpoint(t, test.cert), ServerName: "www.bing.com", Account: "test", Key: bytes.Repeat([]byte{7}, 32), TrustMode: test.mode, PublicKeyPins: test.pins}
				if version == 2 {
					cfg.QUICLanes = 2
					cfg.AdaptiveLanes = true
					cfg.RecoveryAware = true
				}
				ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
				defer cancel()
				client, err := NewClient(ctx, cfg, "quic")
				if err != nil {
					t.Fatal(err)
				}
				defer client.Close()
				err = checkEcho(ctx, client, target, []byte("authenticated pinned FCN payload"))
				if (err == nil) != test.ok {
					t.Fatalf("success=%v want=%v error=%v", err == nil, test.ok, err)
				}
			})
		}
	}
}
func TestPinValidationFailsClosed(t *testing.T) {
	_, leaf, _ := pinCert(t, nil)
	pin := PublicKeyPin(leaf)
	c := Config{TrustMode: "spki", PublicKeyPins: []string{pin}, ServerName: "www.bing.com"}
	if err := c.pinnedVerifier()([]*x509.Certificate{leaf}); err != nil {
		t.Fatal(err)
	}
	for _, bad := range []Config{{TrustMode: "spki"}, {TrustMode: "spki", PublicKeyPins: []string{""}}, {TrustMode: "spki", PublicKeyPins: []string{"sha256/AA=="}}, {TrustMode: "unknown"}, {TrustMode: "ca", PublicKeyPins: []string{pin}}, {TrustMode: "spki", PublicKeyPins: []string{pin}, Roots: x509.NewCertPool()}} {
		if err := bad.validateTrust(); err == nil {
			t.Fatal("accepted malformed trust policy")
		}
	}
	for _, name := range []string{"wrong-host", "expired", "future", "client-only", "missing-peer", "intermediate-only"} {
		t.Run(name, func(t *testing.T) {
			cfg := c
			copy := *leaf
			chain := []*x509.Certificate{&copy}
			switch name {
			case "wrong-host":
				cfg.ServerName = "other.example"
			case "expired":
				copy.NotAfter = time.Now().Add(-time.Second)
			case "future":
				copy.NotBefore = time.Now().Add(time.Hour)
			case "client-only":
				copy.ExtKeyUsage = []x509.ExtKeyUsage{x509.ExtKeyUsageClientAuth}
			case "missing-peer":
				chain = nil
			case "intermediate-only":
				_, wrong, _ := pinCert(t, nil)
				chain = []*x509.Certificate{wrong, leaf}
			}
			if err := cfg.pinnedVerifier()(chain); err == nil {
				t.Fatal("invalid peer accepted")
			}
		})
	}
	if err := c.httpTLS().VerifyConnection(tls.ConnectionState{PeerCertificates: []*x509.Certificate{leaf}}); err != nil {
		t.Fatal(err)
	}
}

func TestPHPManagedCertificateInteroperability(t *testing.T) {
	path := os.Getenv("FCN_PHP_CERT_FIXTURE")
	if path == "" {
		t.Skip("PHP fixture not supplied")
	}
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	var fixture map[string]any
	if err = json.Unmarshal(data, &fixture); err != nil {
		t.Fatal(err)
	}
	cert, err := qtls.X509KeyPair([]byte(fixture["tls_cert"].(string)), []byte(fixture["tls_key"].(string)))
	if err != nil {
		t.Fatal(err)
	}
	leaf, err := x509.ParseCertificate(cert.Certificate[0])
	if err != nil {
		t.Fatal(err)
	}
	pin := fixture["fcn_spki_sha256"].(string)
	if PublicKeyPin(leaf) != pin {
		t.Fatal("PHP and Go SPKI digests differ")
	}
	cfg := Config{Endpoint: pinnedEndpoint(t, cert), ServerName: "www.bing.com", Account: "test", Key: bytes.Repeat([]byte{7}, 32), TrustMode: "spki", PublicKeyPins: []string{pin}}
	target, _ := echoTarget(t)
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	client, err := NewClient(ctx, cfg, "quic")
	if err != nil {
		t.Fatal(err)
	}
	defer client.Close()
	if err := checkEcho(ctx, client, target, []byte("PHP managed certificate to Go FCN client")); err != nil {
		t.Fatal(err)
	}
}
