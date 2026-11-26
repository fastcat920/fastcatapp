package config

import "testing"

func TestRetiredFastCatProxiesAreRemovedFromGroups(t *testing.T) {
	raw, err := UnmarshalRawConfig([]byte(`
proxies:
  - {name: retired, type: fastcat-auto}
  - {name: current, type: http, server: localhost, port: 8080}
proxy-groups:
  - {name: mixed, type: select, proxies: [retired, current]}
  - {name: retired-only, type: select, proxies: [retired]}
rules:
  - MATCH,mixed
`))
	if err != nil {
		t.Fatal(err)
	}
	proxies, _, err := parseProxies(raw)
	if err != nil {
		t.Fatal(err)
	}
	if proxies["retired"] != nil {
		t.Fatal("retired proxy still loaded")
	}
	for _, name := range []string{"current", "mixed", "retired-only"} {
		if proxies[name] == nil {
			t.Errorf("missing proxy or group %q", name)
		}
	}
}
