package adapter

import (
	"context"
	C "github.com/metacubex/mihomo/constant"
	"testing"
)

func TestFCNSubscriptionProfiles(t *testing.T) {
	for _, v := range []int{1, 2} {
		p, e := ParseProxy(map[string]any{"type": "fcn", "name": "FCN", "server": "node.example", "port": 443, "version": v, "uuid": "1ed909de-848b-41e7-943f-0f2d49b35f3a", "udp": true})
		if e != nil {
			t.Fatal(e)
		}
		expected := C.FCNv1
		if v == 2 {
			expected = C.FCNv2
		}
		if p.Type() != expected || !p.SupportUDP() {
			t.Fatal("wrong profile or UDP capability")
		}
		p.Close()
	}
	for _, v := range []int{0, 3} {
		if _, e := ParseProxy(map[string]any{"type": "fcn", "name": "bad", "server": "node.example", "port": 443, "version": v, "uuid": "1ed909de-848b-41e7-943f-0f2d49b35f3a"}); e == nil {
			t.Fatal("accepted unknown FCN version")
		}
	}
	p, e := ParseProxy(map[string]any{"type": "fcn", "name": "closed", "server": "node.example", "port": 443, "version": 1, "uuid": "1ed909de-848b-41e7-943f-0f2d49b35f3a"})
	if e != nil {
		t.Fatal(e)
	}
	p.Close()
	if c, e := p.DialContext(context.Background(), &C.Metadata{Host: "example.com", DstPort: 443}); e == nil {
		c.Close()
		t.Fatal("closed adapter dialed")
	}
}
