//go:build android && cgo && (!with_gvisor || !cmfa)

package main

/*
#error "FastCat Android VPN core requires both build tags: cmfa,with_gvisor"
*/
import "C"
