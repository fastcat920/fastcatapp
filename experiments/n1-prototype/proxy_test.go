package main

import (
	"bufio"
	"fmt"
	"io"
	"net"
	"net/http/httptest"
	"testing"
	"time"
)

func TestLocalProxyPreservesReverseUploadAfterTargetFIN(t *testing.T) {
	cfg, n, _ := fixtureWithEmission(t, "coalesced")
	cfg.ClientEmission = "coalesced"
	n.writeLimit = 16384
	target, e := net.Listen("tcp4", "127.0.0.1:0")
	if e != nil {
		t.Fatal(e)
	}
	defer target.Close()
	n.targets[target.Addr().String()] = true
	done := make(chan []byte, 1)
	go func() {
		c, e := target.Accept()
		if e != nil {
			done <- nil
			return
		}
		defer c.Close()
		c.SetDeadline(time.Now().Add(3 * time.Second))
		io.WriteString(c, "ready")
		c.(*net.TCPConn).CloseWrite()
		b, _ := io.ReadAll(c)
		done <- b
	}()
	proxy := httptest.NewServer(makeProxyHandler(cfg, ""))
	defer proxy.Close()
	peer, e := net.Dial("tcp", proxy.Listener.Addr().String())
	if e != nil {
		t.Fatal(e)
	}
	defer peer.Close()
	peer.SetDeadline(time.Now().Add(3 * time.Second))
	fmt.Fprintf(peer, "CONNECT %s HTTP/1.1\r\nHost: %s\r\n\r\n", target.Addr(), target.Addr())
	r := bufio.NewReader(peer)
	line, e := r.ReadString('\n')
	if e != nil || line != "HTTP/1.1 200 Connection Established\r\n" {
		t.Fatal(line, e)
	}
	if line, e = r.ReadString('\n'); e != nil || line != "\r\n" {
		t.Fatal(line, e)
	}
	greeting, e := io.ReadAll(r)
	if e != nil || string(greeting) != "ready" {
		t.Fatal(string(greeting), e)
	}
	if _, e = io.WriteString(peer, "after-fin"); e != nil {
		t.Fatal(e)
	}
	peer.(*net.TCPConn).CloseWrite()
	if got := <-done; string(got) != "after-fin" {
		t.Fatal("proxy truncated reverse upload", string(got))
	}
}
