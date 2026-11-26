package adapter

import (
	"github.com/metacubex/mihomo/adapter/outbound"
	"testing"
)

func TestFastCatHTTPSConstructor(t *testing.T) {
	option := outbound.FastCatHTTPSOption{Name: "lab", Server: "localhost", Port: 443, Token: "test-token-with-at-least-24-bytes"}
	p, e := outbound.NewFastCatHTTPS(option)
	if e != nil {
		t.Fatal(e)
	}
	if p.Type().String() != "FastCatHTTPS" || p.SupportUDP() {
		t.Fatal("incorrect capabilities")
	}
	defer p.Close()
	option.SkipCertVerify = true
	if _, e = outbound.NewFastCatHTTPS(option); e == nil {
		t.Fatal("accepted insecure certificate verification")
	}
}
