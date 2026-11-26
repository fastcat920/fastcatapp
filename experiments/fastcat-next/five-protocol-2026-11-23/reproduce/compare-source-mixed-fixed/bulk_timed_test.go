package main

import (
	"context"
	"io"
	"net"
	"net/netip"
	"testing"
	"time"
)

func TestTimedPayloadAcrossEchoReadBoundaries(t *testing.T) {
	c, r := net.Pipe()
	defer c.Close()
	defer r.Close()
	c.SetDeadline(time.Now().Add(3 * time.Second))
	go io.Copy(r, r)
	done := make(chan error, 1)
	go func() {
		b := make([]byte, 32768)
		for i := range b {
			b[i] = byte(i % 4)
		}
		for n := 0; n < 8; n++ {
			if _, err := c.Write(b); err != nil {
				done <- err
				return
			}
		}
		done <- nil
	}()
	var offset int64
	b := make([]byte, 4097)
	for offset < 8*32768 {
		n, err := c.Read(b)
		if err != nil {
			t.Fatal(err)
		}
		if !timedPatternValid(b[:n], offset) {
			t.Fatal("valid echo rejected at", offset)
		}
		offset += int64(n)
	}
	if err := <-done; err != nil {
		t.Fatal(err)
	}
	b[0] ^= 1
	if timedPatternValid(b[:1], offset) {
		t.Fatal("corrupt echo accepted")
	}
}

func TestFourWayCaseMatrix(t *testing.T) {
	versions := []string{"v2", "v3-light-fast", "vless-vision", "trojan"}
	expected := map[string]bool{"v2/h2": true, "v2/h3": true, "v3-light-fast/h2": true, "v3-light-fast/h3": true, "vless-vision/tcp-tls": true, "trojan/tcp-tls": true}
	for _, p := range comparisonProtocols(versions) {
		for _, v := range versions {
			if comparisonCase(v, p) {
				key := v + "/" + p
				if !expected[key] {
					t.Fatal("unexpected case", key)
				}
				delete(expected, key)
			}
		}
	}
	if len(expected) != 0 {
		t.Fatal("missing cases", expected)
	}
}

func TestSevenWayCaseMatrix(t *testing.T) {
	versions := []string{"v2", "v3-light-fast", "vless-vision", "trojan", "hysteria2", "tuic", "anytls"}
	expected := map[string]bool{"v2/h2": true, "v2/h3": true, "v3-light-fast/h2": true, "v3-light-fast/h3": true, "vless-vision/tcp-tls": true, "trojan/tcp-tls": true, "hysteria2/quic": true, "tuic/quic": true, "anytls/tcp-tls": true}
	for _, p := range comparisonProtocols(versions) {
		for _, v := range versions {
			if comparisonCase(v, p) {
				k := v + "/" + p
				if !expected[k] {
					t.Fatal("unexpected", k)
				}
				delete(expected, k)
			}
		}
	}
	if len(expected) > 0 {
		t.Fatal(expected)
	}
}
func TestTrackedDialerClosesPackets(t *testing.T) {
	d := new(trackedDialer)
	p, e := d.ListenPacket(context.Background(), "udp4", "127.0.0.1:0", netip.AddrPort{})
	if e != nil {
		t.Fatal(e)
	}
	d.Close()
	p.SetReadDeadline(time.Now().Add(time.Millisecond))
	if _, _, e = p.ReadFrom(make([]byte, 1)); e == nil {
		t.Fatal("socket retained")
	}
	if _, e = d.ListenPacket(context.Background(), "udp4", "127.0.0.1:0", netip.AddrPort{}); e == nil {
		t.Fatal("created socket after close")
	}
}
