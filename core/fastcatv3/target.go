package fastcatv3

import (
	"context"
	"errors"
	"fmt"
	"io"
	"net"
	"net/netip"
	"time"
)

func allowedIP(ip netip.Addr) bool {
	ip = ip.Unmap()
	if !ip.IsGlobalUnicast() || ip.IsPrivate() || ip.IsLoopback() || ip.IsLinkLocalUnicast() {
		return false
	}
	for _, cidr := range []string{"100.64.0.0/10", "192.0.0.0/24", "192.0.2.0/24", "198.18.0.0/15", "198.51.100.0/24", "203.0.113.0/24", "240.0.0.0/4", "2001:db8::/32"} {
		if netip.MustParsePrefix(cidr).Contains(ip) {
			return false
		}
	}
	return true
}
func (s *Session) dialTarget(ctx context.Context, network, address string) (net.Conn, error) {
	host, port, e := net.SplitHostPort(address)
	if e != nil {
		return nil, e
	}
	started := time.Now()
	ips, e := net.DefaultResolver.LookupNetIP(ctx, "ip", host)
	if s.config.Trace != nil {
		s.config.trace(fmt.Sprintf("target_dns elapsed_us=%d ok=%t", time.Since(started).Microseconds(), e == nil))
	}
	if e != nil {
		return nil, e
	}
	if len(ips) == 0 {
		return nil, errors.New("no target addresses")
	}
	for _, ip := range ips {
		if !s.config.AllowPrivate && !allowedIP(ip) {
			return nil, errors.New("target address denied")
		}
	}
	var last error
	for _, ip := range ips {
		conn, e := (&net.Dialer{Timeout: 5 * time.Second}).DialContext(ctx, network, net.JoinHostPort(ip.String(), port))
		if e == nil {
			return conn, nil
		}
		last = e
	}
	return nil, last
}
func (s *Session) serveTarget(t *Stream, address string) {
	ctx, cancel := context.WithTimeout(s.ctx, 5*time.Second)
	network := "tcp"
	if t.kind == 1 {
		network = "udp"
	}
	started := time.Now()
	conn, e := s.dialTarget(ctx, network, address)
	if s.config.Trace != nil {
		s.config.trace(fmt.Sprintf("target_open stream=%d elapsed_us=%d ok=%t", t.id, time.Since(started).Microseconds(), e == nil))
	}
	cancel()
	s.mu.Lock()
	if t.closed {
		s.mu.Unlock()
		if conn != nil {
			conn.Close()
		}
		return
	}
	t.ready = e == nil
	s.mu.Unlock()
	status := []byte{0, 0}
	if e != nil {
		status[1] = 1
	}
	if sendErr := s.send(frame{3, t.id, status}); sendErr != nil {
		if conn != nil {
			conn.Close()
		}
		return
	}
	if e != nil {
		t.Close()
		return
	}
	defer conn.Close()
	defer func() {
		s.mu.Lock()
		graceful := t.kind == 0 && t.localFIN && t.remoteFIN
		if graceful {
			t.closed = true
			t.closeDone.Do(func() { close(t.done) })
			s.signalLocked()
		}
		s.mu.Unlock()
		if !graceful {
			t.Close()
		}
	}()
	finished := make(chan struct{})
	defer close(finished)
	go func() {
		select {
		case <-s.ctx.Done():
			conn.Close()
		case <-t.done:
			conn.Close()
		case <-finished:
		}
	}()
	if t.kind == 0 {
		done := make(chan error, 2)
		go func() {
			_, e := io.Copy(conn, t)
			if tcp, ok := conn.(*net.TCPConn); ok {
				tcp.CloseWrite()
			}
			done <- e
		}()
		go func() { _, e := io.Copy(t, conn); t.CloseWrite(); done <- e }()
		if e := <-done; e != nil {
			conn.Close()
			t.Close()
		}
		<-done
		return
	}
	done := make(chan error, 2)
	go func() {
		for {
			b, e := t.ReceiveDatagram(s.ctx)
			if e != nil {
				done <- e
				return
			}
			conn.SetWriteDeadline(time.Now().Add(5 * time.Second))
			if _, e = conn.Write(b); e != nil {
				done <- e
				return
			}
		}
	}()
	go func() {
		buf := make([]byte, maxDatagram+1)
		for {
			conn.SetReadDeadline(time.Now().Add(30 * time.Second))
			n, e := conn.Read(buf)
			if e != nil {
				done <- e
				return
			}
			if n > maxDatagram {
				continue
			}
			if e = t.SendDatagram(buf[:n]); e != nil {
				done <- e
				return
			}
		}
	}()
	<-done
	conn.Close()
	t.Close()
	<-done
}
