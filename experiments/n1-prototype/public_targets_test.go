package main

import (
	"context"
	"encoding/binary"
	"net"
	"strings"
	"testing"
	"time"
)

func TestPublicTargetsCannotNamePrivateOrMalformedDestinations(t *testing.T) {
	for _, bad := range []string{"127.0.0.1:443", "a:0", "a:65536", "a:-1", "a:foo", "a..b:443", "a\nb:443", "-a.test:443", "a_.test:443"} {
		if _, e := publicTargetName(bad); e == nil {
			t.Fatal(bad)
		}
	}
	if s, e := publicTargetName("Example.COM.:443"); e != nil || s != "example.com:443" {
		t.Fatal(s, e)
	}
	for _, bad := range []string{"127.0.0.1:443", "10.1.1.1:443", "172.16.0.1:443", "192.168.0.1:443", "169.254.169.254:80", "100.64.0.1:443", "[::1]:443", "[::ffff:127.0.0.1]:443", "[fe80::1]:443", "[fc00::1]:443", "[64:ff9b::7f00:1]:443"} {
		if publicAddressAllowed(bad) {
			t.Fatal(bad)
		}
	}
	for _, good := range []string{"1.1.1.1:443", "8.8.8.8:443", "[2606:4700:4700::1111]:443"} {
		if !publicAddressAllowed(good) {
			t.Fatal(good)
		}
	}
}

func TestPublicDNSRebindingIsRejectedBeforeConnect(t *testing.T) {
	dns, e := net.ListenPacket("udp", "127.0.0.1:0")
	if e != nil {
		t.Fatal(e)
	}
	defer dns.Close()
	go func() {
		buf := make([]byte, 1024)
		for {
			n, addr, e := dns.ReadFrom(buf)
			if e != nil {
				return
			}
			req := append([]byte(nil), buf[:n]...)
			if len(req) < 17 {
				continue
			}
			end := 12
			for end < len(req) && req[end] != 0 {
				end += int(req[end]) + 1
			}
			end += 5
			if end > len(req) {
				continue
			}
			qtype := binary.BigEndian.Uint16(req[end-4:])
			ans := append([]byte(nil), req[:end]...)
			binary.BigEndian.PutUint16(ans[2:], 0x8180)
			binary.BigEndian.PutUint16(ans[6:], 0)
			binary.BigEndian.PutUint16(ans[8:], 0)
			binary.BigEndian.PutUint16(ans[10:], 0)
			if qtype == 1 {
				binary.BigEndian.PutUint16(ans[6:], 1)
				ans = append(ans, 0xc0, 0x0c, 0, 1, 0, 1, 0, 0, 0, 0, 0, 4, 127, 0, 0, 1)
			}
			dns.WriteTo(ans, addr)
		}
	}()
	listener, e := net.Listen("tcp4", "127.0.0.1:0")
	if e != nil {
		t.Fatal(e)
	}
	defer listener.Close()
	_, port, _ := net.SplitHostPort(listener.Addr().String())
	resolver := &net.Resolver{PreferGo: true, Dial: func(ctx context.Context, network, address string) (net.Conn, error) {
		return (&net.Dialer{}).DialContext(ctx, "udp", dns.LocalAddr().String())
	}}
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	if c, e := dialPublic(ctx, "n1-rebind.test:"+port, resolver); e == nil {
		c.Close()
		t.Fatal("private DNS target reached")
	} else if !strings.Contains(e.Error(), "nonpublic DNS result denied") {
		t.Fatal(e)
	}
}
