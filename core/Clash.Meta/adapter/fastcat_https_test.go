package adapter

import "testing"

func TestParseFastCatHTTPS(t *testing.T) {
	m := map[string]any{"name": "lab", "type": "fastcat-https", "server": "localhost", "port": 443, "token": "test-token-with-at-least-24-bytes"}
	p, e := ParseProxy(m)
	if e != nil {
		t.Fatal(e)
	}
	if p.Type().String() != "FastCatHTTPS" || p.SupportUDP() {
		t.Fatal("incorrect capabilities")
	}
	m["skip-cert-verify"] = true
	if _, e = ParseProxy(m); e == nil {
		t.Fatal("accepted insecure certificate verification")
	}
}
