package fcnv3

import (
	"context"
	"crypto/x509"
	"errors"
	"fmt"
	"io"
	"net"
	"net/url"
	"os"
	"sync"
	"time"

	http "github.com/metacubex/http"
	"github.com/metacubex/quic-go"
	"github.com/metacubex/quic-go/http3"
	"github.com/metacubex/tls"
)

type Config struct {
	Endpoint   string
	ServerName string
	Account    string
	Secret     string
	Roots      *x509.CertPool
	// EntryDNS enables strict ECH. Only encrypted DNS answers supply dial addresses.
	EntryDNS           EntryDNSResolver
	EnableUDP          bool
	AllowDomainTargets bool
	ConfigureQUIC      func(*quic.Conn)
	// OpenPacket allows a VPN to protect and bind the socket before dialing.
	OpenPacket func(context.Context, string) (net.PacketConn, net.Addr, error)
	// WrapPacketConn optionally wraps a new UDP socket before QUIC uses it.
	// The wrapper must preserve packet I/O and close the underlying socket.
	WrapPacketConn func(*net.UDPConn) net.PacketConn
}

type session struct {
	quic    *quic.Conn
	http    *http3.ClientConn
	binding []byte
}

type Client struct {
	cfg          Config
	key          [32]byte
	ctx          context.Context
	cancel       context.CancelFunc
	mu           sync.Mutex
	current      *session
	pending      *connectionAttempt
	network      string
	refreshEntry bool
}

type connectionAttempt struct {
	done    chan struct{}
	cancel  context.CancelFunc
	session *session
	err     error
}

func NewClient(cfg Config) (*Client, error) {
	if cfg.OpenPacket != nil && cfg.WrapPacketConn != nil {
		return nil, errors.New("FCN v3 requires a single UDP socket provider")
	}
	endpoint, e := authority(cfg.Endpoint, false)
	if e != nil {
		return nil, e
	}
	cfg.Endpoint = endpoint
	if cfg.ServerName == "" {
		cfg.ServerName, _, _ = net.SplitHostPort(endpoint)
	}
	if cfg.EntryDNS != nil {
		name, err := normalizeEntryDNSName(cfg.ServerName)
		if err != nil {
			return nil, errors.New("FCN v3 ECH requires an entry hostname")
		}
		cfg.ServerName = name
	}
	key, e := credentialKey(cfg.Account, cfg.Secret)
	if e != nil {
		return nil, e
	}
	cfg.Secret = ""
	if cfg.Roots != nil {
		cfg.Roots = cfg.Roots.Clone()
	}
	ctx, cancel := context.WithCancel(context.Background())
	return &Client{cfg: cfg, key: key, ctx: ctx, cancel: cancel}, nil
}

func quicProfile() *quic.Config {
	const streamWindow, connectionWindow = 15 << 20, 64 << 20
	return &quic.Config{
		HandshakeIdleTimeout: 5 * time.Second, MaxIdleTimeout: 45 * time.Second,
		InitialStreamReceiveWindow:     streamWindow,
		MaxStreamReceiveWindow:         streamWindow,
		InitialConnectionReceiveWindow: connectionWindow,
		MaxConnectionReceiveWindow:     connectionWindow,
		MaxIncomingStreams:             32, MaxIncomingUniStreams: 8, Allow0RTT: false,
	}
}

func (c *Client) quicOptions() *quic.Config {
	q := quicProfile()
	q.EnableDatagrams = c.cfg.EnableUDP
	return q
}

func (c *Client) dialAddr(ctx context.Context, address string, tc *tls.Config) (*quic.Conn, error) {
	if c.cfg.OpenPacket != nil {
		packet, remote, err := c.cfg.OpenPacket(ctx, address)
		if err != nil {
			return nil, err
		}
		if packet == nil || remote == nil {
			if packet != nil {
				packet.Close()
			}
			return nil, errors.New("FCN v3 socket provider returned no endpoint")
		}
		return c.dialPacket(ctx, packet, remote, tc)
	}
	if c.cfg.WrapPacketConn == nil {
		return quic.DialAddr(ctx, address, tc, c.quicOptions())
	}
	remote, err := net.ResolveUDPAddr("udp", address)
	if err != nil {
		return nil, err
	}
	socket, err := net.ListenUDP("udp", &net.UDPAddr{IP: net.IPv4zero})
	if err != nil {
		return nil, err
	}
	wrapped := c.cfg.WrapPacketConn(socket)
	if wrapped == nil {
		socket.Close()
		return nil, errors.New("FCN v3 UDP socket wrapper returned nil")
	}
	return c.dialPacket(ctx, wrapped, remote, tc)
}

func (c *Client) dialPacket(ctx context.Context, packet net.PacketConn, remote net.Addr, tc *tls.Config) (*quic.Conn, error) {
	transport := &quic.Transport{Conn: packet}
	transport.SetCreatedConn(true)
	transport.SetSingleUse(true)
	conn, err := transport.Dial(ctx, remote, tc, c.quicOptions())
	if err != nil {
		transport.Close()
	}
	return conn, err
}

func (c *Client) connect(ctx context.Context, refreshEntry bool) (*session, error) {
	tc := &tls.Config{ServerName: c.cfg.ServerName, RootCAs: c.cfg.Roots, MinVersion: tls.VersionTLS13, NextProtos: []string{"h3"}}
	q, e := c.dialQUIC(ctx, tc, refreshEntry)
	if e != nil {
		return nil, e
	}
	binding, e := connectionBinding(q)
	if e != nil {
		q.CloseWithError(0, "")
		return nil, e
	}
	if c.cfg.ConfigureQUIC != nil {
		c.cfg.ConfigureQUIC(q)
	}
	h := (&http3.Transport{DisableCompression: true, MaxResponseHeaderBytes: 8192, EnableDatagrams: c.cfg.EnableUDP}).NewClientConn(q)
	return &session{quic: q, http: h, binding: binding}, nil
}

// Warm establishes the same pooled QUIC connection that Dial will use.
// It starts no CONNECT, holds no target open, and is never an automatic retry.
func (c *Client) Warm(ctx context.Context) error {
	_, err := c.acquire(ctx)
	return err
}

func (c *Client) acquire(ctx context.Context) (*session, error) {
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	c.mu.Lock()
	if c.ctx.Err() != nil {
		c.mu.Unlock()
		return nil, net.ErrClosed
	}
	if s := c.current; s != nil && s.quic.Context().Err() == nil {
		c.mu.Unlock()
		return s, nil
	}
	attempt := c.pending
	if attempt == nil {
		connectCtx, cancel := context.WithTimeout(c.ctx, setupTimeout)
		attempt = &connectionAttempt{done: make(chan struct{}), cancel: cancel}
		c.pending = attempt
		go c.completeConnection(connectCtx, attempt, c.refreshEntry)
	}
	c.mu.Unlock()
	select {
	case <-ctx.Done():
		return nil, ctx.Err()
	case <-c.ctx.Done():
		return nil, net.ErrClosed
	case <-attempt.done:
		return attempt.session, attempt.err
	}
}

func (c *Client) completeConnection(ctx context.Context, attempt *connectionAttempt, refreshEntry bool) {
	// The shared handshake is bounded by the client rather than a caller.
	defer attempt.cancel()
	s, err := c.connect(ctx, refreshEntry)
	c.mu.Lock()
	defer c.mu.Unlock()
	switch {
	case c.pending != attempt:
		err = ErrNetworkChanged
	case c.ctx.Err() != nil:
		c.pending = nil
		err = net.ErrClosed
	default:
		c.pending = nil
		if err == nil {
			c.current = s
			c.refreshEntry = false
		}
	}
	if err != nil && s != nil {
		s.quic.CloseWithError(0, "")
		s = nil
	}
	attempt.session, attempt.err = s, err
	close(attempt.done)
}

func (c *Client) Close() error {
	c.cancel()
	c.mu.Lock()
	s := c.current
	c.current = nil
	c.mu.Unlock()
	if s != nil {
		return s.quic.CloseWithError(0, "")
	}
	return nil
}

// Dial opens one CONNECT stream. Up to 8 KiB can be written after the TLS
// handshake while the server's CONNECT decision is pending. Read and subsequent
// writes surface rejection. A stream or its application bytes are never replayed.
func (c *Client) Dial(ctx context.Context, target string) (net.Conn, error) {
	target, e := authority(target, !c.cfg.AllowDomainTargets)
	if e != nil {
		return nil, e
	}
	setup, cancel := context.WithTimeout(ctx, setupTimeout)
	defer cancel()
	stopClient := context.AfterFunc(c.ctx, cancel)
	defer stopClient()
	s, e := c.acquire(setup)
	if e != nil {
		return nil, e
	}
	stream, e := s.http.OpenRequestStream(setup)
	if e != nil {
		return nil, e
	}
	abort := func() { stream.CancelRead(cancelCode); stream.CancelWrite(cancelCode) }
	stop := context.AfterFunc(setup, abort)
	req := &http.Request{Method: "CONNECT", Host: target, URL: &url.URL{Host: target}, Header: make(http.Header)}
	req.Header.Set(authHeader, authValue(c.key, s.binding, c.cfg.Account, target, stream.StreamID()))
	e = stream.SendRequestHeader(req)
	stopped := stop()
	if e != nil || !stopped || setup.Err() != nil {
		abort()
		if e != nil {
			return nil, e
		}
		if e := setup.Err(); e != nil {
			return nil, e
		}
		return nil, context.Canceled
	}
	conn := &streamConn{stream: stream, local: s.quic.LocalAddr(), remote: s.quic.RemoteAddr(), ready: make(chan struct{})}
	go conn.readDecision()
	return conn, nil
}

type streamConn struct {
	stream                      *http3.RequestStream
	local, remote               net.Addr
	ready                       chan struct{}
	result                      error // published by closing ready
	writeMu                     sync.Mutex
	earlyBytes                  int
	writeClosed                 bool
	deadlineMu                  sync.Mutex
	readDeadline, writeDeadline time.Time
	deadlineChanged             chan struct{}
	closeOnce                   sync.Once
}

func (c *streamConn) readDecision() {
	timer := time.AfterFunc(setupTimeout, func() { c.stream.CancelRead(cancelCode); c.stream.CancelWrite(cancelCode) })
	defer timer.Stop()
	response, e := c.stream.ReadResponse()
	if e == nil && response.StatusCode != 200 {
		e = fmt.Errorf("%w (HTTP %d)", ErrRejected, response.StatusCode)
	}
	if e != nil {
		c.stream.CancelRead(cancelCode)
		c.stream.CancelWrite(cancelCode)
	}
	c.result = e
	close(c.ready)
}

func (c *streamConn) decision(read bool) error {
	for {
		select {
		case <-c.ready:
			return c.result
		default:
		}
		c.deadlineMu.Lock()
		if c.deadlineChanged == nil {
			c.deadlineChanged = make(chan struct{})
		}
		changed := c.deadlineChanged
		deadline := c.writeDeadline
		if read {
			deadline = c.readDeadline
		}
		c.deadlineMu.Unlock()
		var timeout <-chan time.Time
		var timer *time.Timer
		if !deadline.IsZero() {
			timer = time.NewTimer(time.Until(deadline))
			timeout = timer.C
		}
		select {
		case <-c.ready:
			if timer != nil {
				timer.Stop()
			}
			return c.result
		case <-changed:
			if timer != nil {
				timer.Stop()
			}
		case <-timeout:
			return os.ErrDeadlineExceeded
		}
	}
}

func (c *streamConn) Read(p []byte) (int, error) {
	if e := c.decision(true); e != nil {
		return 0, e
	}
	return c.stream.Read(p)
}

func (c *streamConn) Write(p []byte) (int, error) {
	c.writeMu.Lock()
	defer c.writeMu.Unlock()
	if c.writeClosed {
		return 0, io.ErrClosedPipe
	}
	if len(p) == 0 {
		return 0, nil
	}
	select {
	case <-c.ready:
		if c.result != nil {
			return 0, c.result
		}
		return c.stream.Write(p)
	default:
	}
	n := 0
	if remaining := earlyWriteLimit - c.earlyBytes; remaining > 0 {
		nEarly := min(len(p), remaining)
		wrote, e := c.stream.Write(p[:nEarly])
		n = wrote
		c.earlyBytes += wrote
		if e != nil {
			return n, e
		}
		if wrote != nEarly {
			return n, io.ErrShortWrite
		}
	}
	if n == len(p) {
		return n, nil
	}
	if e := c.decision(false); e != nil {
		return n, e
	}
	rest, e := c.stream.Write(p[n:])
	return n + rest, e
}

func (c *streamConn) CloseWrite() error {
	c.writeMu.Lock()
	defer c.writeMu.Unlock()
	if c.writeClosed {
		return nil
	}
	c.writeClosed = true
	return c.stream.Close()
}

func (c *streamConn) Close() error {
	c.closeOnce.Do(func() { c.stream.CancelRead(cancelCode); c.stream.CancelWrite(cancelCode) })
	return nil
}

func (c *streamConn) LocalAddr() net.Addr  { return c.local }
func (c *streamConn) RemoteAddr() net.Addr { return c.remote }
func (c *streamConn) updateDeadline(t time.Time, read, write bool) error {
	c.deadlineMu.Lock()
	defer c.deadlineMu.Unlock()
	var first, second error
	if read {
		c.readDeadline = t
		first = c.stream.SetReadDeadline(t)
	}
	if write {
		c.writeDeadline = t
		second = c.stream.SetWriteDeadline(t)
	}
	if c.deadlineChanged != nil {
		close(c.deadlineChanged)
		c.deadlineChanged = nil
	}
	return errors.Join(first, second)
}
func (c *streamConn) SetDeadline(t time.Time) error      { return c.updateDeadline(t, true, true) }
func (c *streamConn) SetReadDeadline(t time.Time) error  { return c.updateDeadline(t, true, false) }
func (c *streamConn) SetWriteDeadline(t time.Time) error { return c.updateDeadline(t, false, true) }
