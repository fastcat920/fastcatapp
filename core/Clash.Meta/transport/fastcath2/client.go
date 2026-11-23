// Package h2client opens independent TCP tunnels over a shared TLS connection.
package h2client

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httptrace"
	"net/url"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/metacubex/mihomo/component/fastcatentry"
	"github.com/metacubex/mihomo/component/fastcatprobe"
	"github.com/metacubex/mihomo/component/fastcattls"
)

type Config struct {
	Prepare     fastcatentry.Prepare
	Endpoint    string // Proxy host:port.
	ServerName  string // Defaults to the host in Endpoint.
	Token       string
	CurveMode   string
	RootCAs     *x509.CertPool                                          // nil uses the system trust store.
	DialContext func(context.Context, string, string) (net.Conn, error) // optional network-specific socket dialer
}

type transport interface {
	http.RoundTripper
	CloseIdleConnections()
}

type Client struct {
	config          Config
	transport       transport
	mu              sync.Mutex
	generation      *generation
	newTransport    func() (transport, error)
	lastReplacement time.Time
	ctx             context.Context
	cancel          context.CancelFunc
}

func New(config Config) (*Client, error) {
	return NewContext(context.Background(), config)
}

// NewContext ties the pool and its physical connections to the given network lifetime.
func NewContext(parent context.Context, config Config) (*Client, error) {
	host, err := authorityHost(config.Endpoint)
	if err != nil {
		return nil, fmt.Errorf("proxy endpoint: %w", err)
	}
	if config.ServerName == "" {
		config.ServerName = host
	}
	if len(config.Token) < 24 || len(config.Token) > 512 || strings.IndexFunc(config.Token, func(r rune) bool { return r < '!' || r > '~' }) >= 0 {
		return nil, errors.New("invalid token: expected 24 to 512 visible ASCII characters")
	}
	ctx, cancel := context.WithCancel(parent)
	dial := config.DialContext
	if dial == nil {
		dial = (&net.Dialer{Timeout: 8 * time.Second}).DialContext
	}
	boundDial := func(dialCtx context.Context, network, address string) (net.Conn, error) {
		// net/http can detach a TCP dial from the original request. Keep it
		// bounded even with an externally supplied platform dialer.
		timeout, stop := context.WithTimeout(dialCtx, 8*time.Second)
		defer stop()
		stopNetwork := afterFunc(ctx, stop)
		defer stopNetwork()
		timing := fastcatprobe.From(dialCtx)
		timing.Mark(fastcatprobe.GatewayTCPStart)
		raw, err := dial(timeout, network, address)
		if err != nil {
			return nil, err
		}
		timing.Mark(fastcatprobe.GatewayTCPDone)
		return &transportConn{Conn: raw, stop: afterFunc(ctx, func() { raw.Close() })}, nil
	}
	tlsConfig := &tls.Config{
		MinVersion: tls.VersionTLS13, ServerName: config.ServerName, RootCAs: config.RootCAs,
		NextProtos: []string{"h2"},
		VerifyConnection: func(state tls.ConnectionState) error {
			if state.NegotiatedProtocol != "h2" {
				return fmt.Errorf("%w: proxy did not negotiate HTTP/2", fastcatentry.ErrProtocol)
			}
			return nil
		},
	}
	build := func() (transport, error) {
		if config.Prepare == nil && (config.CurveMode == "" || config.CurveMode == "default") {
			return newTransport(tlsConfig, boundDial), nil
		}
		return explicitTransport(config, boundDial)
	}
	transport, err := build()
	if err != nil {
		cancel()
		return nil, err
	}
	return &Client{config: config, transport: transport, generation: &generation{transport: transport}, newTransport: build, ctx: ctx, cancel: cancel}, nil
}

type transportConn struct {
	net.Conn
	stop func() bool
}

func (c *transportConn) Close() error {
	c.stop()
	return c.Conn.Close()
}

func authorityHost(address string) (string, error) {
	host, port, err := net.SplitHostPort(address)
	if err != nil || host == "" || strings.ContainsAny(host, "/@?#\\\t\r\n ") {
		return "", errors.New("expected host:port")
	}
	n, err := strconv.ParseUint(port, 10, 16)
	if err != nil || n == 0 {
		return "", errors.New("expected a numeric port between 1 and 65535")
	}
	return host, nil
}

// Dial uses ctx for setup only. Once CONNECT succeeds, Close releases the
// stream, and CloseWrite finishes its upload while leaving the response open.
func (c *Client) Dial(ctx context.Context, target string) (net.Conn, error) {
	if _, err := authorityHost(target); err != nil {
		return nil, fmt.Errorf("CONNECT target: %w", err)
	}
	if c.ctx.Err() != nil {
		return nil, net.ErrClosed
	}
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	setup, endSetup := context.WithTimeout(ctx, 8*time.Second)
	defer endSetup()
	lifetime, cancelCause := context.WithCancelCause(c.ctx)
	cancel := func() { cancelCause(context.Canceled) }
	stopSetup := afterFunc(setup, cancel)
	upload, requestBody := net.Pipe()
	c.mu.Lock()
	generation := c.generation
	c.mu.Unlock()
	var local net.Addr
	var watch *time.Timer
	timing := fastcatprobe.From(ctx)
	trace := &httptrace.ClientTrace{GotConn: func(info httptrace.GotConnInfo) {
		fastcatentry.Ready(ctx)
		local = info.Conn.LocalAddr()
		if info.Reused {
			watch = c.watchGeneration(lifetime, cancelCause, generation, info.Conn)
		}
		timing.GatewayAcquired(info.Reused)
		if selected, ok := info.Conn.(*explicitConn); timing != nil && ok {
			timing.SetGatewaySecurity(selected.security)
		}
	}}
	if timing != nil {
		// Copy only FastCat's diagnostic clock. The origin's HTTP trace must
		// not receive the encrypted proxy connection's TLS and HTTP events.
		lifetime = timing.WithContext(lifetime)
		trace.TLSHandshakeStart = func() { timing.Mark(fastcatprobe.GatewayTLSStart) }
		trace.TLSHandshakeDone = func(_ tls.ConnectionState, err error) {
			if err == nil {
				timing.Mark(fastcatprobe.GatewayTLSDone)
			}
		}
	}
	req := (&http.Request{
		Method: http.MethodConnect,
		// Pool connections by the proxy address while sending the target in
		// the HTTP/2 :authority pseudo-header.
		URL:           &url.URL{Scheme: "https", Host: c.config.Endpoint},
		Host:          target,
		Header:        http.Header{"Proxy-Authorization": {"Bearer " + c.config.Token}},
		Body:          requestBody,
		ContentLength: -1,
	}).WithContext(httptrace.WithClientTrace(lifetime, trace))
	resp, err := generation.transport.RoundTrip(req)
	if watch != nil {
		watch.Stop()
	}
	if resp != nil {
		generation.responses.Add(1)
	}
	if context.Cause(lifetime) != nil && errors.Is(context.Cause(lifetime), fastcatentry.ErrUnresponsive) {
		err = fastcatentry.ErrUnresponsive
	}
	if timing != nil && resp != nil && resp.TLS != nil {
		timing.SetGatewaySecurity(fastcattls.Security(*resp.TLS))
	}
	if !stopSetup() || setup.Err() != nil {
		err = setup.Err()
	}
	if resp != nil && resp.StatusCode != http.StatusOK && setup.Err() == nil {
		err = fastcatentry.StatusError(resp.StatusCode)
	}
	if err != nil {
		cancel()
		upload.Close()
		requestBody.Close()
		if resp != nil {
			resp.Body.Close()
		}
		return nil, err
	}
	download, writer := net.Pipe()
	s := &stream{
		upload: upload, download: download, body: resp.Body, ctx: lifetime, cancel: cancel,
		local: local, remote: targetAddr(target),
	}
	afterFunc(lifetime, func() {
		upload.Close()
		download.Close()
	})
	go func() {
		_, err := io.Copy(writer, resp.Body)
		s.errMu.Lock()
		s.readErr = err
		s.errMu.Unlock()
		writer.Close()
	}()
	return s, nil
}

func (c *Client) Close() error {
	c.cancel()
	c.mu.Lock()
	c.transport.CloseIdleConnections()
	c.mu.Unlock()
	return nil
}

type targetAddr string

func (a targetAddr) Network() string { return "tcp" }
func (a targetAddr) String() string  { return string(a) }

type stream struct {
	upload, download net.Conn
	body             io.ReadCloser
	ctx              context.Context
	cancel           context.CancelFunc
	local, remote    net.Addr
	errMu            sync.Mutex
	readErr          error
	once             sync.Once
}

func (s *stream) Read(p []byte) (int, error) {
	n, err := s.download.Read(p)
	if err == io.EOF {
		s.errMu.Lock()
		if s.readErr != nil {
			err = s.readErr
		}
		s.errMu.Unlock()
	}
	return n, err
}

func (s *stream) Write(p []byte) (int, error) { return s.upload.Write(p) }
func (s *stream) CloseWrite() error           { return s.upload.Close() }
func (s *stream) LocalAddr() net.Addr         { return s.local }
func (s *stream) RemoteAddr() net.Addr        { return s.remote }

func (s *stream) SetReadDeadline(t time.Time) error {
	return s.deadlineError(s.download.SetReadDeadline(t))
}
func (s *stream) SetWriteDeadline(t time.Time) error {
	return s.deadlineError(s.upload.SetWriteDeadline(t))
}

// The peer can finish a direction before the caller receives the stream.
// A deadline on that half has no effect, but the other half can still be live.
func (s *stream) deadlineError(err error) error {
	if s.ctx.Err() != nil {
		return net.ErrClosed
	}
	if errors.Is(err, io.ErrClosedPipe) {
		return nil
	}
	return err
}

func (s *stream) SetDeadline(t time.Time) error {
	return errors.Join(s.SetReadDeadline(t), s.SetWriteDeadline(t))
}

func (s *stream) Close() error {
	s.once.Do(func() {
		s.cancel()
		s.upload.Close()
		s.download.Close()
		s.body.Close()
	})
	return nil
}
