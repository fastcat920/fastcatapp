package h2server

import (
	"context"
	"errors"
	"net"
	"net/netip"
	"strconv"
	"strings"
)

var (
	errInvalidTarget = errors.New("invalid target")
	errDeniedTarget  = errors.New("target denied")
)

// Go's IsGlobalUnicast also includes documentation, shared, transition and
// some reserved ranges. Exclude them before opening a public tunnel.
var specialNetworks = [...]netip.Prefix{
	netip.MustParsePrefix("0.0.0.0/8"), netip.MustParsePrefix("100.64.0.0/10"),
	netip.MustParsePrefix("192.0.0.0/24"), netip.MustParsePrefix("192.0.2.0/24"),
	netip.MustParsePrefix("192.88.99.0/24"), netip.MustParsePrefix("198.18.0.0/15"),
	netip.MustParsePrefix("198.51.100.0/24"), netip.MustParsePrefix("203.0.113.0/24"),
	netip.MustParsePrefix("240.0.0.0/4"),
	netip.MustParsePrefix("2001::/23"), netip.MustParsePrefix("2001:db8::/32"),
	netip.MustParsePrefix("2002::/16"), netip.MustParsePrefix("3fff::/20"),
}

var ipv6Global = netip.MustParsePrefix("2000::/3")

func publicAddress(ip netip.Addr) bool {
	if ip.Zone() != "" {
		return false
	}
	ip = ip.Unmap()
	if !ip.IsGlobalUnicast() || ip.IsPrivate() || (ip.Is6() && !ipv6Global.Contains(ip)) {
		return false
	}
	for _, subnet := range specialNetworks {
		if subnet.Contains(ip) {
			return false
		}
	}
	return true
}

func dialTarget(ctx context.Context, authority string, allowPrivate bool) (*net.TCPConn, error) {
	conn, err := dialNetworkTarget(ctx, "tcp", authority, allowPrivate)
	if err != nil {
		return nil, err
	}
	return conn.(*net.TCPConn), nil
}

func dialNetworkTarget(ctx context.Context, network, authority string, allowPrivate bool) (net.Conn, error) {
	host, portText, err := net.SplitHostPort(authority)
	if err != nil || host == "" || strings.ContainsAny(host, "@/\\?# \t\r\n") {
		return nil, errInvalidTarget
	}
	port, err := strconv.ParseUint(portText, 10, 16)
	if err != nil || port == 0 {
		return nil, errInvalidTarget
	}

	addresses, err := net.DefaultResolver.LookupNetIP(ctx, "ip", host)
	if err != nil {
		return nil, err
	}
	if len(addresses) == 0 {
		return nil, errors.New("no target addresses")
	}
	// Validate every answer before dialing any. Pass only numeric addresses
	// to the dialer so a subsequent DNS change cannot alter the destination.
	for _, addr := range addresses {
		if !allowPrivate && !publicAddress(addr) {
			return nil, errDeniedTarget
		}
	}
	var dialer net.Dialer
	for _, addr := range addresses {
		endpoint := netip.AddrPortFrom(addr.Unmap(), uint16(port))
		conn, dialErr := dialer.DialContext(ctx, network, endpoint.String())
		if dialErr == nil {
			return conn, nil
		}
		err = dialErr
		if ctx.Err() != nil {
			break
		}
	}
	return nil, err
}
