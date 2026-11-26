//go:build !linux

package main

import "net"

func enableUDPRXQOverflow(*net.UDPConn) udpRXQMode { return udpRXQUnsupported }

func readUDPRXQOverflow([]byte) (uint32, bool) { return 0, false }
