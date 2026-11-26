//go:build linux

package main

import (
	"encoding/binary"
	"errors"
	"net"

	"golang.org/x/sys/unix"
)

func enableUDPRXQOverflow(socket *net.UDPConn) udpRXQMode {
	raw, err := socket.SyscallConn()
	if err != nil {
		return udpRXQUnavailable
	}
	var socketErr error
	if err := raw.Control(func(fd uintptr) {
		socketErr = unix.SetsockoptInt(int(fd), unix.SOL_SOCKET, unix.SO_RXQ_OVFL, 1)
	}); err != nil {
		return udpRXQUnavailable
	}
	if socketErr == nil {
		return udpRXQEnabled
	}
	if errors.Is(socketErr, unix.ENOPROTOOPT) || errors.Is(socketErr, unix.EOPNOTSUPP) || errors.Is(socketErr, unix.ENOSYS) {
		return udpRXQUnsupported
	}
	return udpRXQUnavailable
}

func readUDPRXQOverflow(oob []byte) (uint32, bool) {
	for len(oob) > 0 {
		header, data, remainder, err := unix.ParseOneSocketControlMessage(oob)
		if err != nil {
			break
		}
		if header.Level == unix.SOL_SOCKET && header.Type == unix.SO_RXQ_OVFL && len(data) == 4 {
			return binary.NativeEndian.Uint32(data), true
		}
		oob = remainder
	}
	return 0, false
}
