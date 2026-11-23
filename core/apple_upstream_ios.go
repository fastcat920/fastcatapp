//go:build ios && cgo

package main

/*
#include <stdint.h>
*/
import "C"

import (
	"core/appleupstream"
	"sync"
	"sync/atomic"
	"syscall"

	"github.com/metacubex/mihomo/adapter/outbound"
	"github.com/metacubex/mihomo/component/dialer"
	"github.com/metacubex/mihomo/component/resolver"
)

var appleUpstreamIndex atomic.Uint32
var appleUpstreamHook sync.Once

// Only the extension enables this policy. The main application's isolated
// latency core retains its normal socket behavior.
//
//export ClashCore_set_upstream_interface
func ClashCore_set_upstream_interface(index C.uint) {
	appleUpstreamHook.Do(func() { dialer.DefaultSocketHook = bindAppleUpstreamSocket })
	previous := appleUpstreamIndex.Swap(uint32(index))
	if previous != uint32(index) {
		applePhysicalPathGeneration.Add(1)
		outbound.ResetFastCatH2Connections()
	}
	if previous != 0 && previous != uint32(index) {
		resolver.ResetConnection()
		handleCloseConnections()
	}
}

func bindAppleUpstreamSocket(network, address string, raw syscall.RawConn) error {
	return appleupstream.BindSocket(network, address, raw, appleUpstreamIndex.Load())
}
