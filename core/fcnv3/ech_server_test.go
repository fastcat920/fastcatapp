package fcnv3

import (
	"bytes"
	"crypto/x509"
	"encoding/pem"
	"testing"

	"github.com/metacubex/tls"
)

func TestReplaceECHKeys(t *testing.T) {
	const publicName = "public.fcn3.test"
	old := testServerECHKey(t, publicName)
	next := testServerECHKey(t, publicName)
	server, err := NewServer(ServerConfig{
		TLSConfig: &tls.Config{Certificates: []tls.Certificate{
			{Leaf: &x509.Certificate{DNSNames: []string{"inner.fcn3.test"}}},
			{Leaf: &x509.Certificate{DNSNames: []string{publicName}}},
		}},
		Targets: []string{"127.0.0.1:443"},
		ECHKeys: []tls.EncryptedClientHelloKey{old},
	})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { server.Close() })

	bad := []struct {
		name string
		keys []tls.EncryptedClientHelloKey
	}{
		{name: "empty key list"},
		{name: "mismatched private key", keys: []tls.EncryptedClientHelloKey{{Config: next.Config, PrivateKey: old.PrivateKey}}},
		{name: "trailing config bytes", keys: []tls.EncryptedClientHelloKey{{Config: append(bytes.Clone(next.Config), 0), PrivateKey: next.PrivateKey}}},
		{name: "uncovered public name", keys: []tls.EncryptedClientHelloKey{testServerECHKey(t, "other.fcn3.test")}},
	}
	for _, tc := range bad {
		t.Run(tc.name, func(t *testing.T) {
			if err := server.ReplaceECHKeys(tc.keys); err == nil {
				t.Fatal("accepted invalid key update")
			}
			keys, err := server.tls.GetEncryptedClientHelloKeys(nil)
			if err != nil || len(keys) != 1 || !bytes.Equal(keys[0].Config, old.Config) || !bytes.Equal(keys[0].PrivateKey, old.PrivateKey) {
				t.Fatal("invalid key update replaced the previous keys")
			}
		})
	}

	if err := server.ReplaceECHKeys([]tls.EncryptedClientHelloKey{next, old}); err != nil {
		t.Fatal(err)
	}
	keys, err := server.tls.GetEncryptedClientHelloKeys(nil)
	if err != nil || len(keys) != 2 || !bytes.Equal(keys[0].Config, next.Config) || !bytes.Equal(keys[1].Config, old.Config) {
		t.Fatal("expected new and previous ECH keys during rotation")
	}
	if err := server.ReplaceECHKeys([]tls.EncryptedClientHelloKey{next}); err != nil {
		t.Fatal(err)
	}
	next.PrivateKey[0] ^= 1
	keys, err = server.tls.GetEncryptedClientHelloKeys(nil)
	if err != nil || len(keys) != 1 || !bytes.Equal(keys[0].Config, next.Config) || bytes.Equal(keys[0].PrivateKey, next.PrivateKey) {
		t.Fatal("expected only the new key, copied independently of the caller")
	}
}

func TestECHStartupRequiresPublicCertificate(t *testing.T) {
	const publicName = "public.fcn3.test"
	config := ServerConfig{
		TLSConfig: &tls.Config{Certificates: []tls.Certificate{
			{Leaf: &x509.Certificate{DNSNames: []string{"inner.fcn3.test"}}},
		}},
		Targets: []string{"127.0.0.1:443"},
		ECHKeys: []tls.EncryptedClientHelloKey{testServerECHKey(t, publicName)},
	}
	if server, err := NewServer(config); err == nil {
		server.Close()
		t.Fatal("accepted a certificate missing the ECH public name")
	}
	config.TLSConfig.Certificates[0].Leaf.DNSNames = append(config.TLSConfig.Certificates[0].Leaf.DNSNames, publicName)
	server, err := NewServer(config)
	if err != nil {
		t.Fatal(err)
	}
	server.Close()
}

func testServerECHKey(t *testing.T, publicName string) tls.EncryptedClientHelloKey {
	t.Helper()
	_, keyPEM, err := genTestECHConfig(publicName)
	if err != nil {
		t.Fatal(err)
	}
	block, _ := pem.Decode([]byte(keyPEM))
	if block == nil {
		t.Fatal("invalid generated ECH key PEM")
	}
	keys, err := unmarshalTestECHKeys(block.Bytes)
	if err != nil || len(keys) != 1 {
		t.Fatalf("expected one generated ECH key: %v", err)
	}
	return keys[0]
}
