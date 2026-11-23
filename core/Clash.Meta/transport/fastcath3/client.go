// Package h3client opens independent TCP streams and UDP associations on an
// authenticated HTTP/3 gateway. Application data starts after a successful CONNECT.
package h3client

import (
	"context"
	"crypto/x509"
	"errors"
	"fmt"
	http "github.com/metacubex/http"
	"net"
	"net/url"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/metacubex/mihomo/component/fastcatentry"
	"github.com/metacubex/mihomo/component/fastcatprobe"
	"github.com/metacubex/mihomo/component/fastcattls/quicprofile"
	"github.com/metacubex/mihomo/transport/tuic/common"
	quic "github.com/metacubex/quic-go"
	"github.com/metacubex/quic-go/http3"
	tls "github.com/metacubex/tls"
)

type Config struct {
	// Congestion is an opt-in laboratory override; empty preserves the library default.
	Congestion                             string
	Prepare                                fastcatentry.Prepare
	Endpoint, ServerName, Token, CurveMode string
	RootCAs                                *x509.CertPool
	OpenPacket                             func(context.Context, string) (net.PacketConn, net.Addr, error)
}

type Client struct {
	cfg             Config
	tls             *tls.Config
	ctx             context.Context
	cancel          context.CancelFunc
	mu              sync.Mutex
	pending         chan struct{}
	pool            *session
	lastReplacement time.Time
}

type session struct {
	mu        sync.Mutex
	check     *gatewayCheck
	responses atomic.Uint64
	conn      *quic.Conn
	http      *http3.ClientConn
}

func NewContext(parent context.Context, cfg Config) (*Client, error) {
	host, _, err := splitAuthority(cfg.Endpoint)
	if err != nil {
		return nil, fmt.Errorf("invalid HTTP/3 gateway address")
	}
	if cfg.ServerName == "" {
		cfg.ServerName = host
	}
	if len(cfg.Token) < 24 || len(cfg.Token) > 512 || strings.IndexFunc(cfg.Token, func(r rune) bool { return r < '!' || r > '~' }) >= 0 {
		return nil, errors.New("invalid HTTP/3 credential")
	}
	if cfg.OpenPacket == nil {
		cfg.OpenPacket = openPacket
	}
	tc := &tls.Config{ServerName: cfg.ServerName, RootCAs: cfg.RootCAs, NextProtos: []string{"h3"}}
	if err = quicprofile.ApplyQUIC(tc, cfg.CurveMode); err != nil {
		return nil, err
	}
	ctx, cancel := context.WithCancel(parent)
	return &Client{cfg: cfg, tls: tc, ctx: ctx, cancel: cancel}, nil
}

func splitAuthority(s string) (string, string, error) {
	h, p, err := net.SplitHostPort(s)
	n, perr := strconv.ParseUint(p, 10, 16)
	if err != nil || h == "" || strings.ContainsAny(h, " \t\r\n%@/?#\\") || perr != nil || n == 0 {
		return "", "", errors.New("invalid target authority")
	}
	return h, p, nil
}

func openPacket(ctx context.Context, endpoint string) (net.PacketConn, net.Addr, error) {
	h, p, _ := net.SplitHostPort(endpoint)
	ips, err := net.DefaultResolver.LookupIPAddr(ctx, h)
	if err != nil {
		return nil, nil, err
	}
	if len(ips) == 0 {
		return nil, nil, errors.New("no gateway addresses")
	}
	port, _ := strconv.Atoi(p)
	family := "udp4"
	if ips[0].IP.To4() == nil {
		family = "udp6"
	}
	var lc net.ListenConfig
	pc, err := lc.ListenPacket(ctx, family, ":0")
	return pc, &net.UDPAddr{IP: ips[0].IP, Port: port}, err
}

func (c *Client) connect(ctx context.Context) (*session, error) {
	endpoint, tlsConfig := c.cfg.Endpoint, c.tls
	quicConfig := &quic.Config{
		EnableDatagrams: true, MaxIdleTimeout: 60 * time.Second,
		HandshakeIdleTimeout: 5 * time.Second, MaxIncomingStreams: -1,
	}
	if c.cfg.Prepare != nil {
		resolved, ech, err := c.cfg.Prepare(ctx, endpoint, c.cfg.ServerName)
		if err != nil {
			return nil, err
		}
		if len(ech) == 0 {
			return nil, errors.New("entry ECH configuration is empty")
		}
		endpoint, tlsConfig = resolved, tlsConfig.Clone()
		tlsConfig.EncryptedClientHelloConfigList = ech
		// The smaller initial datagram reduced macOS tail latency in repeated
		// tests. Android showed a higher P95, so keep its existing sizing.
		if runtime.GOOS == "darwin" {
			quicConfig.InitialPacketSize = 1200
		}
	}
	packet, addr, err := c.cfg.OpenPacket(ctx, endpoint)
	if err != nil {
		return nil, err
	}
	if packet == nil || addr == nil {
		if packet != nil {
			packet.Close()
		}
		return nil, errors.New("gateway UDP socket unavailable")
	}
	conn, err := quic.Dial(ctx, packet, addr, tlsConfig, quicConfig)
	if err != nil {
		packet.Close()
		return nil, err
	}
	if c.cfg.Congestion == "bbr" {
		common.SetCongestionController(conn, "bbr", 0, "")
	}
	if c.cfg.Prepare != nil && !conn.ConnectionState().TLS.ECHAccepted {
		conn.CloseWithError(0, "")
		packet.Close()
		return nil, errors.New("HTTP/3 gateway did not accept ECH")
	}
	transport := &http3.Transport{EnableDatagrams: true, DisableCompression: true, MaxResponseHeaderBytes: 16 << 10}
	s := &session{conn: conn, http: transport.NewClientConn(conn)}
	go func() {
		select {
		case <-c.ctx.Done():
			conn.CloseWithError(0, "")
		case <-conn.Context().Done():
		}
		packet.Close()
	}()
	return s, nil
}

func (c *Client) acquire(ctx context.Context) (*session, bool, error) {
	timing := fastcatprobe.From(ctx)
	for {
		c.mu.Lock()
		if c.ctx.Err() != nil {
			c.mu.Unlock()
			return nil, false, net.ErrClosed
		}
		if s := c.pool; s != nil && s.conn.Context().Err() == nil {
			c.mu.Unlock()
			return s, true, nil
		}
		pending := c.pending
		if pending != nil {
			c.mu.Unlock()
			select {
			case <-pending:
				continue
			case <-ctx.Done():
				return nil, false, ctx.Err()
			case <-c.ctx.Done():
				return nil, false, net.ErrClosed
			}
		}
		c.pending = make(chan struct{})
		c.mu.Unlock()
		timing.Mark(fastcatprobe.GatewayTLSStart)
		s, err := c.connect(ctx)
		c.mu.Lock()
		c.pool = s
		close(c.pending)
		c.pending = nil
		c.mu.Unlock()
		if err == nil {
			timing.Mark(fastcatprobe.GatewayTLSDone)
		}
		return s, false, err
	}
}

func (c *Client) Dial(ctx context.Context, target string) (net.Conn, error) {
	return c.dial(ctx, target, false)
}
func (c *Client) DialUDP(ctx context.Context, target string) (net.Conn, error) {
	return c.dial(ctx, target, true)
}
func (c *Client) Warm(ctx context.Context) error { _, _, err := c.acquire(ctx); return err }

func (c *Client) Close() error { c.cancel(); return nil }

func (c *Client) dial(parent context.Context, target string, udp bool) (net.Conn, error) {
	host, port, err := splitAuthority(target)
	if err != nil {
		return nil, err
	}
	ctx, cancel := context.WithTimeout(parent, 8*time.Second)
	defer cancel()
	stopClose := after(c.ctx, cancel)
	defer stopClose()
	s, reused, err := c.acquire(ctx)
	if err != nil {
		return nil, err
	}
	fastcatentry.Ready(parent)
	timing := fastcatprobe.From(parent)
	timing.GatewayAcquired(reused)
	timing.SetGatewaySecurity(quicprofile.Security(s.conn.ConnectionState().TLS))
	req := &http.Request{Method: "CONNECT", URL: &url.URL{Scheme: "https", Host: c.cfg.Endpoint}, Host: target, Header: http.Header{"Proxy-Authorization": {"Bearer " + c.cfg.Token}}}
	if udp {
		select {
		case <-s.http.ReceivedSettings():
		case <-ctx.Done():
			return nil, ctx.Err()
		case <-s.conn.Context().Done():
			return nil, net.ErrClosed
		}
		if !s.http.Settings().EnableExtendedConnect || !s.http.Settings().EnableDatagrams || !s.conn.ConnectionState().SupportsDatagrams.Remote {
			return nil, fmt.Errorf("%w: HTTP/3 gateway does not support CONNECT-UDP datagrams", fastcatentry.ErrProtocol)
		}
		req.Proto = "connect-udp"
		req.Host = c.cfg.Endpoint
		req.URL.Path = Prefix + host + "/" + port + "/"
		// RFC 6570 simple expansion percent-encodes colons in IPv6 literals.
		req.URL.RawPath = Prefix + strings.ReplaceAll(url.PathEscape(host), ":", "%3A") + "/" + port + "/"
		req.Header.Set(http3.CapsuleProtocolHeader, "?1")
	}
	str, err := s.http.OpenRequestStream(ctx)
	if err != nil {
		return nil, err
	}
	abort := func() {
		str.CancelRead(quic.StreamErrorCode(http3.ErrCodeRequestCanceled))
		str.CancelWrite(quic.StreamErrorCode(http3.ErrCodeRequestCanceled))
	}
	setup, stopSetup := context.WithCancelCause(ctx)
	defer stopSetup(nil)
	stop := after(setup, abort)
	received := false
	if err = str.SendRequestHeader(req); err == nil {
		var resp *http.Response
		if reused {
			watch := s.watch(setup, stopSetup, c.cfg.Endpoint)
			defer watch.Stop()
		}
		resp, err = str.ReadResponse()
		if err == nil {
			received = true
			s.responses.Add(1)
		}
		if err == nil && (resp.StatusCode < 200 || resp.StatusCode >= 300) {
			err = fastcatentry.StatusError(resp.StatusCode)
		}
		if err == nil && udp && resp.Header.Get(http3.CapsuleProtocolHeader) != "?1" {
			err = fmt.Errorf("%w: CONNECT-UDP capsule negotiation failed", fastcatentry.ErrProtocol)
		}
	}
	if !stop() || setup.Err() != nil {
		// A received policy or authentication decision takes priority over a
		// concurrent failed control exchange. Caller cancellation stays terminal.
		var status fastcatentry.StatusError
		if parent.Err() != nil {
			err = parent.Err()
		} else if !errors.As(err, &status) && !errors.Is(err, fastcatentry.ErrProtocol) {
			err = context.Cause(setup)
			if received && errors.Is(err, fastcatentry.ErrUnresponsive) {
				// The request was answered as its stream was being cancelled.
				// Returning it, or treating the gateway as dead, would be incorrect.
				err = net.ErrClosed
			}
		}
	}
	if err != nil {
		abort()
		if errors.Is(err, fastcatentry.ErrUnresponsive) {
			// Retry after cooldown with a new QUIC connection. Existing streams
			// retain their connection until normal close, network reset or idle expiry.
			c.mu.Lock()
			if c.pool == s && (c.lastReplacement.IsZero() || time.Since(c.lastReplacement) >= 30*time.Second) {
				c.lastReplacement = time.Now()
				c.pool = nil
			}
			c.mu.Unlock()
		}
		return nil, err
	}
	remote := targetAddr(target)
	if udp {
		return NewDatagramConn(str, s.conn.LocalAddr(), remote), nil
	}
	return &streamConn{RequestStream: str, local: s.conn.LocalAddr(), remote: remote}, nil
}

// after is equivalent to context.AfterFunc for builds with the Go 1.20 toolchain.
func after(ctx context.Context, fn func()) func() bool {
	var once sync.Once
	done := make(chan struct{})
	go func() {
		select {
		case <-ctx.Done():
			once.Do(fn)
		case <-done:
		}
	}()
	return func() (stopped bool) { once.Do(func() { close(done); stopped = true }); return }
}

type streamConn struct {
	*http3.RequestStream
	local, remote net.Addr
}

func (s *streamConn) LocalAddr() net.Addr  { return s.local }
func (s *streamConn) RemoteAddr() net.Addr { return s.remote }
func (s *streamConn) CloseWrite() error    { return s.RequestStream.Close() }
func (s *streamConn) Close() error {
	s.CancelRead(quic.StreamErrorCode(http3.ErrCodeRequestCanceled))
	return s.RequestStream.Close()
}

type targetAddr string

func (a targetAddr) Network() string { return "tcp" }
func (a targetAddr) String() string  { return string(a) }
