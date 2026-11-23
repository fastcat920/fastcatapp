package adapter

import (
	"encoding/json"
	"strings"
	"testing"

	C "github.com/metacubex/mihomo/constant"
)

func TestFastCatAutoConfig(t *testing.T) {
	node := map[string]any{"name": "Region", "type": "fastcat-auto", "server": "localhost", "port": 8444, "token": strings.Repeat("p", 32), "fallback-port": 8443, "fallback-token": strings.Repeat("b", 32)}
	p, err := ParseProxy(node, WithProviderName("subscription"))
	if err != nil {
		t.Fatal(err)
	}
	defer p.Close()
	if p.Type() != C.FastCatAuto || p.Name() != "Region" || p.ProxyInfo().ProviderName != "subscription" {
		t.Fatal("incorrect parsed identity")
	}
	data, err := json.Marshal(p)
	if err != nil || strings.Contains(string(data), node["token"].(string)) || strings.Contains(string(data), node["fallback-token"].(string)) {
		t.Fatal("unsafe public proxy serialization")
	}
	for _, key := range []string{"token", "fallback-token", "port", "fallback-port", "server"} {
		value := node[key]
		delete(node, key)
		if p, err := ParseProxy(node); err == nil {
			p.Close()
			t.Fatalf("accepted absent %s", key)
		}
		node[key] = value
	}
	for _, key := range []string{"udp", "skip-cert-verify"} {
		node[key] = true
		if p, err := ParseProxy(node); err == nil {
			p.Close()
			t.Fatalf("accepted %s", key)
		}
		delete(node, key)
	}
}

func TestFastCatAutoECHRequiresEncryptedResolver(t *testing.T) {
	node := map[string]any{
		"name": "ECH", "type": "fastcat-auto-ech", "server": "inner.example", "port": 443,
		"token": strings.Repeat("p", 32), "h3-port": 443, "h3-token": strings.Repeat("q", 32),
	}
	if p, err := ParseProxy(node); err == nil {
		p.Close()
		t.Fatal("accepted ECH node without encrypted resolver")
	}
	node["entry-doh"] = "https://outer.example/dns-query"
	node["entry-doh-ip"] = "192.0.2.1"
	p, err := ParseProxy(node)
	if err != nil {
		t.Fatal(err)
	}
	defer p.Close()
	if p.Type() != C.FastCatAuto {
		t.Fatal("ECH node did not retain the FastCat auto transport")
	}
}
