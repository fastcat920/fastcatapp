package fcn

import (
	"bytes"
	"context"
	"testing"
)

func TestDiagnosticPeerTag(t *testing.T) {
	salt := bytes.Repeat([]byte{7}, 32)
	addr := "192.0.2.1:30880"
	tag := diagnosticPeerTag(salt, addr)
	if len(tag) != 32 || tag != diagnosticPeerTag(salt, addr) || tag == diagnosticPeerTag(salt, "192.0.2.1:30881") || tag == diagnosticPeerTag(bytes.Repeat([]byte{8}, 32), addr) || diagnosticPeerTag(nil, addr) != "" {
		t.Fatal("unstable or unbounded private peer tag")
	}
}
func TestDiagnosticPortValidation(t *testing.T) {
	base := Config{Endpoint: "127.0.0.1:443", ServerName: "example.com", Account: "test", Key: bytes.Repeat([]byte{7}, 32), QUICLanes: 2}
	for _, port := range []int{0, 1024, 30880, 65534} {
		c := base
		c.LocalUDPPort = port
		cl, err := NewClient(context.Background(), c, "quic")
		if err != nil {
			t.Fatalf("valid port %d: %v", port, err)
		}
		if port > 0 && (cl.lanes[0].cfg.LocalUDPPort != port || cl.lanes[1].cfg.LocalUDPPort != port+1) {
			t.Fatal("lanes share diagnostic UDP port")
		}
		cl.Close()
	}
	for _, port := range []int{-1, 1, 1023, 65535, 65536} {
		c := base
		c.LocalUDPPort = port
		if _, err := NewClient(context.Background(), c, "quic"); err == nil {
			t.Fatalf("accepted port %d", port)
		}
	}
	c := base
	c.QUICLanes = 1
	c.LocalUDPPort = 30880
	if _, err := NewClient(context.Background(), c, "h2"); err == nil {
		t.Fatal("accepted UDP port for H2")
	}
	cfg := ServerConfig{Accounts: map[string][]byte{"test": base.Key}, TracePeerSalt: bytes.Repeat([]byte{7}, 32)}
	if _, err := NewServer(cfg); err != nil {
		t.Fatal(err)
	}
	cfg.TracePeerSalt = []byte{1}
	if _, err := NewServer(cfg); err == nil {
		t.Fatal("accepted short peer salt")
	}
}
