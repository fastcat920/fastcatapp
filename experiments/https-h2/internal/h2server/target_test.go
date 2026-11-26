package h2server

import (
	"context"
	"errors"
	"net/netip"
	"testing"
)

func TestPublicAddresses(t *testing.T) {
	for _, raw := range []string{
		"0.1.2.3", "127.0.0.1", "10.0.0.1", "192.168.0.1", "::1", "::",
		"100.100.100.200", "169.254.169.254", "224.0.0.1", "240.0.0.1",
		"::ffff:127.0.0.1", "64:ff9b::a00:1", "2002:7f00:1::", "2001:db8::1",
		"fe80::1%lo0", "fd00::1", "2001:4860:4860::8888%lo0",
	} {
		if publicAddress(netip.MustParseAddr(raw)) {
			t.Errorf("allowed special address %s", raw)
		}
	}
	for _, raw := range []string{"1.1.1.1", "2001:4860:4860::8888", "::ffff:1.1.1.1"} {
		if !publicAddress(netip.MustParseAddr(raw)) {
			t.Errorf("denied public address %s", raw)
		}
	}
}

func TestInvalidAuthorityBeforeDial(t *testing.T) {
	for _, authority := range []string{"", "host", ":80", "host:65536", "host:-1", "host:0", "host/path:443", "user@host:80"} {
		if _, err := dialTarget(context.Background(), authority, false); !errors.Is(err, errInvalidTarget) {
			t.Errorf("%q: want invalid target, got %v", authority, err)
		}
	}
}
