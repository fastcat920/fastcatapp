package outbound

import (
	"bufio"
	"context"
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"net"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/metacubex/mihomo/component/fastcatentry"
	"github.com/metacubex/mihomo/component/fastcatprobe"
	"github.com/metacubex/mihomo/component/fastcattls"
	"github.com/metacubex/mihomo/component/fastcattls/quicprofile"
	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/dns"
	qtls "github.com/metacubex/tls"
)

// FastCatHTTPS v1 is authenticated HTTPS CONNECT, TCP only.
type FastCatHTTPS struct {
	*Base
	config      *tls.Config
	token       string
	explicitTLS *qtls.Config
}
type FastCatHTTPSOption struct {
	UDP            bool `proxy:"udp,omitempty"`
	SkipCertVerify bool `proxy:"skip-cert-verify,omitempty"`
	BasicOption
	Name        string `proxy:"name"`
	Server      string `proxy:"server"`
	Port        int    `proxy:"port"`
	SNI         string `proxy:"sni,omitempty"`
	Token       string `proxy:"token"`
	CAFile      string `proxy:"ca-file,omitempty"`
	KeyExchange string `proxy:"tls-key-exchange,omitempty"`
	EntryDoH    string `proxy:"entry-doh,omitempty"`
	EntryDoHIP  string `proxy:"entry-doh-ip,omitempty"`
}

func (o FastCatHTTPSOption) entryResolver(roots *x509.CertPool) (fastcatentry.Prepare, error) {
	if o.EntryDoH == "" && o.EntryDoHIP == "" {
		return nil, nil
	}
	name := o.SNI
	if name == "" {
		name = o.Server
	}
	if addr := net.ParseIP(name); addr != nil || name == "" || !strings.Contains(name, ".") {
		return nil, fmt.Errorf("FastCat ECH requires a DNS hostname for the inner TLS name")
	}
	return dns.NewFastCatEntryResolver(o.EntryDoH, o.EntryDoHIP, name, roots)
}

func NewFastCatHTTPS(o FastCatHTTPSOption) (*FastCatHTTPS, error) {
	if o.EntryDoH != "" || o.EntryDoHIP != "" {
		return nil, fmt.Errorf("FastCat HTTPS v1 does not support entry ECH")
	}
	if o.UDP || o.SkipCertVerify {
		return nil, fmt.Errorf("fastcat-https v1 requires certificate verification and TCP only")
	}
	if o.Server == "" || o.Port < 1 || o.Port > 65535 {
		return nil, fmt.Errorf("fastcat-https: invalid server or port")
	}
	if len(o.Token) < 24 || strings.ContainsAny(o.Token, "\r\n") {
		return nil, fmt.Errorf("fastcat-https: token must contain at least 24 bytes without line breaks")
	}
	name := o.SNI
	if name == "" {
		name = o.Server
	}
	roots, err := o.rootCAs()
	if err != nil {
		return nil, err
	}
	cfg := &tls.Config{ServerName: name, MinVersion: tls.VersionTLS12, NextProtos: []string{"http/1.1"}, RootCAs: roots}
	node := &FastCatHTTPS{Base: o.base(C.FastCatHTTPS), config: cfg, token: o.Token}
	if o.KeyExchange != "" && o.KeyExchange != "default" {
		node.explicitTLS, err = quicprofile.ClientConfig(name, roots, "http/1.1", o.KeyExchange)
		if err != nil {
			return nil, err
		}
	} else if o.KeyExchange == "default" {
		cfg.MinVersion = tls.VersionTLS13
	}
	return node, nil
}

func (o FastCatHTTPSOption) rootCAs() (*x509.CertPool, error) {
	if o.CAFile == "" {
		return nil, nil
	}
	pem, err := os.ReadFile(o.CAFile)
	if err != nil {
		return nil, err
	}
	pool := x509.NewCertPool()
	if !pool.AppendCertsFromPEM(pem) {
		return nil, fmt.Errorf("invalid FastCat CA file")
	}
	return pool, nil
}

func (o FastCatHTTPSOption) base(typ C.AdapterType) *Base {
	b := NewBase(BaseOption{Name: o.Name, Addr: net.JoinHostPort(o.Server, strconv.Itoa(o.Port)), Type: typ, ProviderName: o.ProviderName, TFO: o.TFO, MPTCP: o.MPTCP, Interface: o.Interface, RoutingMark: o.RoutingMark, Prefer: o.IPVersion})
	b.dialer = o.NewDialer(b.DialOptions())
	return b
}
func (h *FastCatHTTPS) DialContext(ctx context.Context, m *C.Metadata) (_ C.Conn, err error) {
	timing := fastcatprobe.From(ctx)
	timing.Mark(fastcatprobe.GatewayTCPStart)
	c, err := h.dialer.DialContext(ctx, "tcp", h.addr)
	if err != nil {
		return nil, fmt.Errorf("fastcat-https entry_tcp: %w", err)
	}
	timing.Mark(fastcatprobe.GatewayTCPDone)
	defer func() {
		if err != nil {
			c.Close()
		}
	}()
	conn, err := h.StreamConnContext(ctx, c, m)
	if err != nil {
		return nil, err
	}
	return NewConn(conn, h), nil
}
func (h *FastCatHTTPS) StreamConnContext(ctx context.Context, c net.Conn, m *C.Metadata) (net.Conn, error) {
	addr := m.RemoteAddress()
	if strings.ContainsAny(addr, "\r\n") {
		return nil, fmt.Errorf("fastcat-https: invalid target")
	}
	deadline := time.Now().Add(8 * time.Second)
	if d, ok := ctx.Deadline(); ok && d.Before(deadline) {
		deadline = d
	}
	c.SetDeadline(deadline)
	// Act on cancellation even when the caller supplied no deadline.
	done := make(chan struct{})
	exited := make(chan struct{})
	go func() {
		defer close(exited)
		select {
		case <-ctx.Done():
			c.SetDeadline(time.Now())
		case <-done:
		}
	}()
	defer func() { close(done); <-exited; c.SetDeadline(time.Time{}) }()
	timing := fastcatprobe.From(ctx)
	timing.Mark(fastcatprobe.GatewayTLSStart)
	t, security, err := h.handshake(ctx, c)
	if err != nil {
		return nil, fmt.Errorf("fastcat-https tls: %w", err)
	}
	timing.Mark(fastcatprobe.GatewayTLSDone)
	timing.SetGatewaySecurity(security)
	fastcatentry.Ready(ctx)
	timing.GatewayAcquired(false)
	req := &http.Request{Method: "CONNECT", Host: addr}
	if _, e := fmt.Fprintf(t, "CONNECT %s HTTP/1.1\r\nHost: %s\r\nAuthorization: Bearer %s\r\nFastCat-Version: 1\r\n\r\n", addr, addr, h.token); e != nil {
		return nil, fmt.Errorf("fastcat-https request: %w", e)
	}
	br := bufio.NewReader(t)
	resp, e := http.ReadResponse(br, req)
	if e != nil {
		return nil, fmt.Errorf("fastcat-https response: %w", e)
	}
	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("fastcat-https response status=%d", resp.StatusCode)
	}
	if e = ctx.Err(); e != nil {
		return nil, e
	}
	return &fastCatBufferedConn{Conn: t, reader: br}, nil
}

type fastCatTLSConn interface {
	net.Conn
	CloseWrite() error
}

func (h *FastCatHTTPS) handshake(ctx context.Context, raw net.Conn) (fastCatTLSConn, fastcattls.Negotiated, error) {
	if h.explicitTLS != nil {
		t := qtls.Client(raw, h.explicitTLS)
		err := t.HandshakeContext(ctx)
		return t, quicprofile.Security(t.ConnectionState()), err
	}
	t := tls.Client(raw, h.config)
	err := t.HandshakeContext(ctx)
	return t, fastcattls.Security(t.ConnectionState()), err
}

type fastCatBufferedConn struct {
	net.Conn
	reader *bufio.Reader
}

func (c *fastCatBufferedConn) Read(p []byte) (int, error) { return c.reader.Read(p) }
func (c *fastCatBufferedConn) CloseWrite() error          { return c.Conn.(fastCatTLSConn).CloseWrite() }
