package main

import (
	"context"
	"fmt"
	"net"
	"net/netip"
	"strconv"
)

var deniedTargetPrefixes = []netip.Prefix{
	netip.MustParsePrefix("100.64.0.0/10"), netip.MustParsePrefix("192.0.0.0/24"),
	netip.MustParsePrefix("198.18.0.0/15"), netip.MustParsePrefix("64:ff9b::/96"),
	netip.MustParsePrefix("64:ff9b:1::/48"), netip.MustParsePrefix("2002::/16"),
	netip.MustParsePrefix("2001::/32"),
}

func deniedTargetIP(ip net.IP) bool {
	addr, ok := netip.AddrFromSlice(ip)
	if !ok {
		return true
	}
	addr = addr.Unmap()
	for _, prefix := range deniedTargetPrefixes {
		if prefix.Contains(addr) {
			return true
		}
	}
	return !ip.IsGlobalUnicast() || ip.IsPrivate() || ip.IsLoopback() || ip.IsLinkLocalUnicast()
}

// Resolve once, validate every answer, then dial the validated IP to avoid DNS rebinding.
func resolveTarget(ctx context.Context, authority string, allowPrivate bool) (string, error) {
	host, port, e := net.SplitHostPort(authority)
	if e != nil {
		return "", fmt.Errorf("invalid target")
	}
	n, e := strconv.Atoi(port)
	if e != nil || n < 1 || n > 65535 || host == "" {
		return "", fmt.Errorf("invalid target")
	}
	ips, e := net.DefaultResolver.LookupIPAddr(ctx, host)
	if e != nil {
		return "", e
	}
	if len(ips) == 0 {
		return "", fmt.Errorf("no target addresses")
	}
	for _, ip := range ips {
		if !allowPrivate && (deniedTargetIP(ip.IP) || ip.Zone != "") {
			return "", fmt.Errorf("target address denied")
		}
	}
	return net.JoinHostPort(ips[0].IP.String(), port), nil
}
