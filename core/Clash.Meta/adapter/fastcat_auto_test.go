package adapter

import "testing"

func TestRetiredFastCatTransportTypesAreRejected(t *testing.T) {
	for _, proxyType := range []string{"fastcat-auto", "fastcat-auto-ech", "fastcat-https", "fastcat-h2"} {
		t.Run(proxyType, func(t *testing.T) {
			config := map[string]any{"name": "legacy", "type": proxyType}
			if !IsRetiredFastCatProxy(config) {
				t.Fatal("missed retired transport")
			}
			if proxy, err := ParseProxy(config); err == nil {
				proxy.Close()
				t.Fatal("loaded retired transport")
			}
		})
	}
}
