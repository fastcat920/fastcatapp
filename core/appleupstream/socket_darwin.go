//go:build darwin

package appleupstream

import (
	"errors"
	"golang.org/x/sys/unix"
	"net"
	"net/netip"
	"strings"
	"syscall"
)

func BindSocket(network, address string, raw syscall.RawConn, index uint32) error {
	host, _, _ := net.SplitHostPort(address)
	if ip, err := netip.ParseAddr(strings.Trim(host, "[]")); err == nil && ip.IsLoopback() {
		return nil
	}
	if index == 0 {
		return errors.New("underlying network interface unavailable")
	}
	var socketError error
	err := raw.Control(func(fd uintptr) {
		family, err := unix.Getsockname(int(fd))
		if err != nil {
			socketError = err
			return
		}
		switch family.(type) {
		case *unix.SockaddrInet6:
			socketError = unix.SetsockoptInt(int(fd), unix.IPPROTO_IPV6, unix.IPV6_BOUND_IF, int(index))
		case *unix.SockaddrInet4:
			socketError = unix.SetsockoptInt(int(fd), unix.IPPROTO_IP, unix.IP_BOUND_IF, int(index))
		default:
			socketError = errors.New("unsupported upstream socket family")
		}
	})
	if err != nil {
		return err
	}
	// Never silently retry unbound: that would reintroduce the packetFlow loop.
	return socketError
}
