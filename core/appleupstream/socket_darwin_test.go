//go:build darwin

package appleupstream

import (
	"golang.org/x/sys/unix"
	"net"
	"syscall"
	"testing"
)

func TestMissingPathFailsClosedButPreservesLocalIPC(t *testing.T) {
	if BindSocket("tcp4", "192.0.2.1:443", nil, 0) == nil {
		t.Fatal("unbound upstream allowed")
	}
	for _, address := range []string{"127.0.0.1:7890", "[::1]:7890"} {
		if err := BindSocket("tcp", address, nil, 0); err != nil {
			t.Fatal(err)
		}
	}
}
func TestIPv4IPv6SocketReallyBindsAndErrorsAreReturned(t *testing.T) {
	iface, err := net.InterfaceByName("lo0")
	if err != nil {
		t.Fatal(err)
	}
	for _, network := range []string{"tcp4", "tcp6", "udp4", "udp6"} {
		t.Run(network, func(t *testing.T) {
			var c interface {
				Close() error
				SyscallConn() (syscall.RawConn, error)
			}
			if network[:3] == "tcp" {
				listener, e := net.Listen(network, ":0")
				if e != nil {
					t.Fatal(e)
				}
				c = listener.(interface {
					Close() error
					SyscallConn() (syscall.RawConn, error)
				})
			} else {
				packet, e := net.ListenPacket(network, ":0")
				if e != nil {
					t.Fatal(e)
				}
				c = packet.(interface {
					Close() error
					SyscallConn() (syscall.RawConn, error)
				})
			}
			defer c.Close()
			raw, err := c.SyscallConn()
			if err != nil {
				t.Fatal(err)
			}
			address := "192.0.2.1:53"
			level, option := unix.IPPROTO_IP, unix.IP_BOUND_IF
			if network == "udp6" || network == "tcp6" {
				address = "[2001:db8::1]:53"
				level, option = unix.IPPROTO_IPV6, unix.IPV6_BOUND_IF
			}
			if err := BindSocket(network, address, raw, uint32(iface.Index)); err != nil {
				t.Fatal(err)
			}
			var actual int
			raw.Control(func(fd uintptr) { actual, err = unix.GetsockoptInt(int(fd), level, option) })
			if err != nil || actual != iface.Index {
				t.Fatalf("binding=%d err=%v", actual, err)
			}
			if BindSocket(network, address, raw, 0x7fffffff) == nil {
				t.Fatal("invalid interface silently allowed")
			}
		})
	}
}
