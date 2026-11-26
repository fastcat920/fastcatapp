package main

import (
	"context"
	"fmt"
	"net"
	"net/netip"
	"strconv"
	"strings"
	"syscall"
)

// Explicit narrow public-host allowlist. DNS results are checked at the actual
// connect boundary, retaining Dialer's normal dual-stack selection and pinning
// the approved resolved address. Exact numeric admin targets are unchanged.
func publicTargetName(value string) (string, error) {
	host, port, e := net.SplitHostPort(value)
	if e != nil {
		return "", e
	}
	n, e := strconv.Atoi(port)
	if e != nil || n < 1 || n > 65535 {
		return "", fmt.Errorf("invalid port")
	}
	host = strings.TrimSuffix(strings.ToLower(host), ".")
	if host == "" || len(host) > 253 || net.ParseIP(host) != nil {
		return "", fmt.Errorf("expected bounded DNS host")
	}
	for _, label := range strings.Split(host, ".") {
		if len(label) < 1 || len(label) > 63 || label[0] == '-' || label[len(label)-1] == '-' {
			return "", fmt.Errorf("invalid DNS label")
		}
		for _, r := range label {
			if !(r >= 'a' && r <= 'z' || r >= '0' && r <= '9' || r == '-') {
				return "", fmt.Errorf("invalid DNS character")
			}
		}
	}
	return net.JoinHostPort(host, strconv.Itoa(n)), nil
}
func publicAddressAllowed(address string) bool {
	host, _, e := net.SplitHostPort(address)
	if e != nil {
		return false
	}
	a, e := netip.ParseAddr(host)
	if e != nil {
		return false
	}
	a = a.Unmap()
	if !a.IsGlobalUnicast() || a.IsPrivate() || a.IsLoopback() || a.IsLinkLocalUnicast() {
		return false
	}
	for _, s := range []string{"0.0.0.0/8", "100.64.0.0/10", "192.0.0.0/24", "192.0.2.0/24", "198.18.0.0/15", "198.51.100.0/24", "203.0.113.0/24", "240.0.0.0/4", "64:ff9b::/96", "64:ff9b:1::/48", "2001:db8::/32", "2001::/32", "2002::/16", "::/96", "fec0::/10"} {
		if netip.MustParsePrefix(s).Contains(a) {
			return false
		}
	}
	return true
}
func dialPublic(ctx context.Context, target string, resolver *net.Resolver) (net.Conn, error) {
	d := net.Dialer{Resolver: resolver, ControlContext: func(ctx context.Context, network, address string, c syscall.RawConn) error {
		if !publicAddressAllowed(address) {
			return fmt.Errorf("nonpublic DNS result denied")
		}
		return nil
	}}
	return d.DialContext(ctx, "tcp", target)
}
