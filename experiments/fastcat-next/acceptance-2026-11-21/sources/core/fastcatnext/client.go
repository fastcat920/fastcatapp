package fastcatnext

import (
	"context"
	"crypto/tls"
	"errors"
	quic "github.com/metacubex/quic-go"
	qtls "github.com/metacubex/tls"
	"golang.org/x/net/http2"
	"io"
	"net"
	"net/http"
	"sync"
	"time"
)

type physical struct {
	q       *quic.Conn
	pc      net.PacketConn
	tcp     *tls.Conn
	h2      *http2.ClientConn
	binding []byte
	count   int
	packets *clientAssociations
}

func (p *physical) close() {
	if p.q != nil {
		p.q.CloseWithError(0, "")
		p.pc.Close()
	}
	if p.tcp != nil {
		p.tcp.Close()
	}
}
func (p *physical) alive() bool {
	if p.q != nil {
		return p.q.Context().Err() == nil
	}
	return p.h2.CanTakeNewRequest()
}

type Client struct {
	cfg     Config
	carrier string
	ctx     context.Context
	cancel  context.CancelFunc
	mu      sync.Mutex
	pool    *physical
	all     map[*physical]bool
	closed  bool
}

func NewClient(parent context.Context, c Config, carrier string) (*Client, error) {
	if e := c.validate(); e != nil {
		return nil, e
	}
	if carrier != "quic" && carrier != "h2" {
		return nil, ErrProtocol
	}
	c.Key = append([]byte(nil), c.Key...)
	ctx, cancel := context.WithCancel(parent)
	cl := &Client{cfg: c, carrier: carrier, ctx: ctx, cancel: cancel, all: make(map[*physical]bool)}
	go func() { <-ctx.Done(); cl.Close() }()
	return cl, nil
}
func (c *Client) Close() {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.closed {
		return
	}
	c.closed = true
	c.cancel()
	for p := range c.all {
		p.close()
	}
	c.all = nil
	c.pool = nil
}

// Reset retires the network generation. Existing streams terminate explicitly;
// no application bytes are replayed. Only later Dial calls obtain a new session.
func (c *Client) Reset() {
	c.mu.Lock()
	defer c.mu.Unlock()
	for p := range c.all {
		p.close()
		delete(c.all, p)
	}
	c.pool = nil
}
func (c *Client) acquire(ctx context.Context) (*physical, error) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.closed {
		return nil, net.ErrClosed
	}
	if c.pool != nil && c.pool.count < maxRequests && c.pool.alive() {
		c.pool.count++
		return c.pool, nil
	}
	for p := range c.all {
		if !p.alive() {
			p.close()
			delete(c.all, p)
		}
	}
	if len(c.all) >= 2 {
		return nil, errors.New("retired session limit reached")
	}
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	stop := context.AfterFunc(c.ctx, cancel)
	defer stop()
	p := &physical{count: 1}
	var e error
	if c.carrier == "quic" {
		addr, e2 := net.ResolveUDPAddr("udp", c.cfg.Endpoint)
		if e2 != nil {
			return nil, e2
		}
		family := "udp4"
		if addr.IP.To4() == nil {
			family = "udp6"
		}
		p.pc, e = net.ListenPacket(family, ":0")
		if e != nil {
			return nil, e
		}
		p.q, e = quic.Dial(ctx, p.pc, addr, &qtls.Config{ServerName: c.cfg.ServerName, RootCAs: c.cfg.Roots, MinVersion: qtls.VersionTLS13, NextProtos: []string{ALPN}}, quicConfig(c.cfg.idle()))
		if e != nil {
			p.pc.Close()
			return nil, e
		}
		setCC(p.q, c.cfg.Congestion)
		state := p.q.ConnectionState().TLS
		p.binding, e = state.ExportKeyingMaterial(exporterLabel, nil, 32)
		p.packets = newClientAssociations(p.q)
		go p.packets.receive()
	} else {
		raw, e2 := (&net.Dialer{}).DialContext(ctx, "tcp", c.cfg.Endpoint)
		if e2 != nil {
			return nil, e2
		}
		p.tcp = tls.Client(raw, &tls.Config{MinVersion: tls.VersionTLS13, ServerName: c.cfg.ServerName, RootCAs: c.cfg.Roots, NextProtos: []string{"h2"}})
		if e = p.tcp.HandshakeContext(ctx); e != nil {
			p.tcp.Close()
			return nil, e
		}
		state := p.tcp.ConnectionState()
		if state.NegotiatedProtocol != "h2" {
			p.tcp.Close()
			return nil, ErrProtocol
		}
		p.binding, e = state.ExportKeyingMaterial(exporterLabel, nil, 32)
		if e == nil {
			p.h2, e = (&http2.Transport{DisableCompression: true}).NewClientConn(p.tcp)
		}
	}
	if e != nil {
		p.close()
		return nil, e
	}
	c.pool = p
	c.all[p] = true
	return p, nil
}
func (c *Client) Warm(ctx context.Context) error { _, e := c.acquire(ctx); return e }
func (c *Client) Dial(ctx context.Context, target string) (net.Conn, error) {
	return c.dial(ctx, target, 0)
}
func (c *Client) dial(ctx context.Context, target string, kind byte) (net.Conn, error) {
	if !validTarget(target) || kind > 1 {
		return nil, ErrProtocol
	}
	if kind == 1 && c.carrier != "quic" {
		return nil, errors.New("UDP requires QUIC path")
	}
	p, e := c.acquire(ctx)
	if e != nil {
		return nil, e
	}
	head, e := encodeHeader(c.cfg.Account, target, kind, c.cfg.Key, p.binding)
	if e != nil {
		return nil, e
	}
	if p.q != nil {
		stream, e := p.q.OpenStreamSync(ctx)
		if e != nil {
			return nil, e
		}
		deadline, _ := ctx.Deadline()
		stream.SetWriteDeadline(deadline)
		if _, e = stream.Write(head); e != nil {
			stream.CancelRead(0)
			stream.CancelWrite(0)
			return nil, e
		}
		stream.SetWriteDeadline(time.Time{})
		return &quicConn{Stream: stream, local: p.q.LocalAddr(), remote: p.q.RemoteAddr()}, nil
	}
	// A fixed ClientConn cannot silently reconnect or replay a POST. Its exporter
	// always matches this exact TLS connection. Concurrent requests remain streams.
	reader, writer := io.Pipe()
	streamctx, cancel := context.WithCancel(ctx)
	req, e := http.NewRequestWithContext(streamctx, "POST", "https://"+c.cfg.Endpoint+"/session", reader)
	if e != nil {
		cancel()
		return nil, e
	}
	req.Header.Set("Content-Type", "application/octet-stream")
	req.Header.Set("User-Agent", "")
	headerDone := make(chan error, 1)
	go func() { _, e := writer.Write(head); headerDone <- e }()
	res, e := p.h2.RoundTrip(req)
	if e != nil {
		cancel()
		reader.Close()
		writer.Close()
		<-headerDone
		return nil, e
	}
	if res.StatusCode != 200 {
		res.Body.Close()
		cancel()
		reader.Close()
		writer.Close()
		<-headerDone
		if res.StatusCode == 502 {
			return nil, ErrTarget
		}
		return nil, ErrAuth
	}
	if e = <-headerDone; e != nil {
		res.Body.Close()
		cancel()
		return nil, e
	}
	return &httpConn{body: res.Body, w: writer, cancel: cancel, local: p.tcp.LocalAddr(), remote: p.tcp.RemoteAddr()}, nil
}

type quicConn struct {
	*quic.Stream
	once          sync.Once
	status        error
	local, remote net.Addr
}

func (c *quicConn) Read(b []byte) (int, error) {
	c.once.Do(func() {
		var status [1]byte
		_, c.status = io.ReadFull(c.Stream, status[:])
		if c.status == nil {
			switch status[0] {
			case 0:
			case 1:
				c.status = ErrAuth
			case 2:
				c.status = ErrTarget
			default:
				c.status = ErrProtocol
			}
		}
	})
	if c.status != nil {
		return 0, c.status
	}
	return c.Stream.Read(b)
}
func (c *quicConn) Close() error         { c.CancelRead(0); c.CancelWrite(0); return nil }
func (c *quicConn) CloseWrite() error    { return c.Stream.Close() }
func (c *quicConn) LocalAddr() net.Addr  { return c.local }
func (c *quicConn) RemoteAddr() net.Addr { return c.remote }

type httpConn struct {
	body          io.ReadCloser
	w             *io.PipeWriter
	cancel        context.CancelFunc
	local, remote net.Addr
	mu            sync.Mutex
	timer         *time.Timer
}

func (c *httpConn) Read(b []byte) (int, error)  { return c.body.Read(b) }
func (c *httpConn) Write(b []byte) (int, error) { return c.w.Write(b) }
func (c *httpConn) CloseWrite() error           { return c.w.Close() }
func (c *httpConn) Close() error {
	c.mu.Lock()
	if c.timer != nil {
		c.timer.Stop()
	}
	c.mu.Unlock()
	c.cancel()
	c.w.Close()
	return c.body.Close()
}
func (c *httpConn) LocalAddr() net.Addr  { return c.local }
func (c *httpConn) RemoteAddr() net.Addr { return c.remote }

// HTTP/2 cannot set per-stream socket deadlines. A stream deadline cancels only
// this request, preserving other streams and the physical connection.
func (c *httpConn) SetDeadline(t time.Time) error {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.timer != nil {
		c.timer.Stop()
	}
	if !t.IsZero() {
		c.timer = time.AfterFunc(time.Until(t), func() { c.cancel(); c.w.CloseWithError(context.DeadlineExceeded); c.body.Close() })
	}
	return nil
}
func (c *httpConn) SetReadDeadline(t time.Time) error  { return c.SetDeadline(t) }
func (c *httpConn) SetWriteDeadline(t time.Time) error { return c.SetDeadline(t) }
