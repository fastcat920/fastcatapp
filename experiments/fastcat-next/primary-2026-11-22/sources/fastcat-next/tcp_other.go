//go:build !linux

package main

import (
	"fmt"
	"net"
)

func listenTCP(address string, mss int) (net.Listener, error) {
	if mss != 0 {
		return nil, fmt.Errorf("TCP MSS experiment requires Linux")
	}
	return net.Listen("tcp", address)
}
