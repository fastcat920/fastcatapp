//go:build linux

package main

import (
	"context"
	"fmt"
	"golang.org/x/sys/unix"
	"net"
	"syscall"
)

// A listener-local experiment. It does not change host sysctls or other services.
func listenTCP(address string, mss int) (net.Listener, error) {
	if mss != 0 && (mss < 536 || mss > 1440) {
		return nil, fmt.Errorf("invalid TCP MSS")
	}
	var lc net.ListenConfig
	if mss != 0 {
		lc.Control = func(network, address string, c syscall.RawConn) error {
			var err error
			e := c.Control(func(fd uintptr) { err = unix.SetsockoptInt(int(fd), unix.IPPROTO_TCP, unix.TCP_MAXSEG, mss) })
			if e != nil {
				return e
			}
			return err
		}
	}
	return lc.Listen(context.Background(), "tcp", address)
}
