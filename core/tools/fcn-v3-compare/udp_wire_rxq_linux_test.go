//go:build linux

package main

import (
	"encoding/binary"
	"testing"

	"golang.org/x/sys/unix"
)

func TestUDPRXQOverflowReadsCumulativeNotice(t *testing.T) {
	// UnixRights supplies a socket-level cmsg with a four-byte payload.
	// Keep the level and length and substitute the RXQ overflow message type.
	control := unix.UnixRights(19)
	binary.NativeEndian.PutUint32(control[unix.SizeofCmsghdr-4:unix.SizeofCmsghdr], unix.SO_RXQ_OVFL)
	other := unix.UnixRights(3)
	if count, ok := readUDPRXQOverflow(append(other, control...)); !ok || count != 19 {
		t.Fatalf("RXQ overflow cmsg = (%d, %t), want (19, true)", count, ok)
	}
	if count, ok := readUDPRXQOverflow(other); ok {
		t.Fatalf("unrelated cmsg treated as RXQ overflow count %d", count)
	}
	if count, ok := readUDPRXQOverflow(control[:unix.SizeofCmsghdr+3]); ok {
		t.Fatalf("truncated cmsg treated as RXQ overflow count %d", count)
	}
}
