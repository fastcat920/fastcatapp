package fastcatv3

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/tls"
	"encoding/binary"
	"errors"
	"io"
	"net"
	"net/http"
	"net/http/httptrace"
	"net/url"
	"sync"
	"sync/atomic"
	"time"

	qhttp "github.com/metacubex/http"
	quic "github.com/metacubex/quic-go"
	"github.com/metacubex/quic-go/http3"
	qtls "github.com/metacubex/tls"
)

type independentResponse struct {
	body    io.ReadCloser
	binding []byte
}

// IndependentClient authenticates once and opens independent HTTP streams on that
// TLS connection. A replacement TLS connection cannot reuse the old session proof.
type IndependentClient struct {
	ctx                context.Context
	cancel             context.CancelFunc
	mode               IndependentMode
	root, sid, binding []byte
	counter            atomic.Uint64
	roundTrip          func(context.Context, string, io.Reader) (independentResponse, error)
	closeTransport     func()
	closeAuth          func()
	once               sync.Once
	lifecycle          sync.Mutex
	authBody           io.ReadCloser
	expiry             *time.Timer
}

func DialIndependent(ctx context.Context, c DialConfig, carrier string, mode IndependentMode) (*IndependentClient, error) {
	if err := c.Config.validate(false); err != nil {
		return nil, err
	}
	if mode > IndependentPipelined {
		return nil, errProtocol
	}
	u, err := url.Parse("https://" + c.Endpoint)
	if err != nil || u.Hostname() == "" || u.Port() == "" || u.User != nil || u.RawQuery != "" || u.Fragment != "" || u.Path != "" {
		return nil, errors.New("invalid independent endpoint")
	}
	name := c.ServerName
	if name == "" {
		name = u.Hostname()
	}
	root, cancel := context.WithCancel(ctx)
	client := &IndependentClient{ctx: root, cancel: cancel, mode: mode}
	if carrier == "h2" {
		tr := &http.Transport{ForceAttemptHTTP2: true, MaxConnsPerHost: 1, DisableCompression: true, TLSHandshakeTimeout: 8 * time.Second, TLSClientConfig: &tls.Config{MinVersion: tls.VersionTLS13, ServerName: name, RootCAs: c.Roots, NextProtos: []string{"h2"}}}
		client.closeTransport = tr.CloseIdleConnections
		client.roundTrip = func(ctx context.Context, path string, body io.Reader) (independentResponse, error) {
			req, err := http.NewRequestWithContext(ctx, "POST", u.String()+path, body)
			if err != nil {
				return independentResponse{}, err
			}
			req.Header.Set("Content-Type", "application/octet-stream")
			req.Header.Set("X-Fastcat-Mode", mode.String())
			req.Header.Set("User-Agent", "")
			if path == independentAuthPath {
				trace := &httptrace.ClientTrace{GotConn: func(info httptrace.GotConnInfo) { go func() { <-root.Done(); info.Conn.Close() }() }}
				req = req.WithContext(httptrace.WithClientTrace(req.Context(), trace))
			}
			res, err := tr.RoundTrip(req)
			if err != nil {
				return independentResponse{}, err
			}
			if res.StatusCode != 200 || res.ProtoMajor != 2 || res.TLS == nil {
				res.Body.Close()
				return independentResponse{}, errors.New("independent H2 entry rejected")
			}
			binding, err := res.TLS.ExportKeyingMaterial("EXPORTER-FastCat-v3", nil, 32)
			if err != nil {
				res.Body.Close()
				return independentResponse{}, err
			}
			return independentResponse{res.Body, binding}, nil
		}
	} else if carrier == "h3" {
		tr := &http3.Transport{DisableCompression: true, TLSClientConfig: &qtls.Config{MinVersion: qtls.VersionTLS13, ServerName: name, RootCAs: c.Roots}, QUICConfig: &quic.Config{HandshakeIdleTimeout: 5 * time.Second, MaxIdleTimeout: 30 * time.Second}}
		client.closeTransport = func() { tr.Close() }
		client.roundTrip = func(ctx context.Context, path string, body io.Reader) (independentResponse, error) {
			req, err := qhttp.NewRequestWithContext(ctx, "POST", u.String()+path, body)
			if err != nil {
				return independentResponse{}, err
			}
			req.Header.Set("Content-Type", "application/octet-stream")
			req.Header.Set("X-Fastcat-Mode", mode.String())
			req.Header.Set("User-Agent", "")
			res, err := tr.RoundTrip(req)
			if err != nil {
				return independentResponse{}, err
			}
			if res.StatusCode != 200 || res.ProtoMajor != 3 || res.TLS == nil {
				res.Body.Close()
				return independentResponse{}, errors.New("independent H3 entry rejected")
			}
			binding, err := res.TLS.ExportKeyingMaterial("EXPORTER-FastCat-v3", nil, 32)
			if err != nil {
				res.Body.Close()
				return independentResponse{}, err
			}
			return independentResponse{res.Body, binding}, nil
		}
	} else {
		cancel()
		return nil, errors.New("independent profile supports h2 and h3")
	}
	config := independentConfig(c.Config, mode)
	carrierByte := byte(1)
	if carrier == "h3" {
		carrierByte = 2
	}
	pending, prefix, err := prepareClientHandshake(config, carrierByte)
	if err != nil {
		client.Close()
		return nil, err
	}
	reader, writer := io.Pipe()
	authContext, cancelAuth := context.WithCancel(root)
	client.closeAuth = func() { cancelAuth(); writer.Close(); reader.Close() }
	timer := time.AfterFunc(8*time.Second, func() { client.Close() })
	res, err := client.roundTrip(authContext, independentAuthPath, io.MultiReader(bytes.NewReader(prefix), reader))
	if err != nil {
		timer.Stop()
		client.Close()
		return nil, err
	}
	client.lifecycle.Lock()
	client.authBody = res.body
	client.lifecycle.Unlock()
	select {
	case <-root.Done():
		res.body.Close()
		timer.Stop()
		client.Close()
		return nil, root.Err()
	default:
	}
	records, err := pending.finish(res.body, writer, config, res.binding)
	if err != nil {
		timer.Stop()
		client.Close()
		return nil, err
	}
	var sid []byte
	ttl := uint32(independentTTL / time.Second)
	if mode == IndependentPipelined {
		sid = append([]byte(nil), records.handshakeID...)
		if len(sid) != 16 {
			timer.Stop()
			client.Close()
			return nil, errProtocol
		}
	} else {
		frames, e := records.read()
		if e != nil || len(frames) != 1 || frames[0].kind != 15 || frames[0].id != 0 || len(frames[0].body) != 21 {
			timer.Stop()
			client.Close()
			return nil, errors.New("invalid independent session readiness")
		}
		ready := frames[0].body
		ttl = binary.BigEndian.Uint32(ready[16:20])
		if IndependentMode(ready[20]) != mode || ttl == 0 || ttl > uint32(independentTTL/time.Second) {
			timer.Stop()
			client.Close()
			return nil, errProtocol
		}
		sid = append([]byte(nil), ready[:16]...)
	}
	timer.Stop()
	client.root = independentRoot(records, false)
	client.sid = sid
	client.binding = append([]byte(nil), res.binding...)
	client.lifecycle.Lock()
	if root.Err() != nil {
		client.lifecycle.Unlock()
		client.Close()
		return nil, root.Err()
	}
	client.expiry = time.AfterFunc(time.Duration(ttl)*time.Second, func() { client.Close() })
	client.lifecycle.Unlock()
	select {
	case <-root.Done():
		client.Close()
		return nil, root.Err()
	default:
	}
	go func() { var unexpected [1]byte; res.body.Read(unexpected[:]); client.Close() }()
	return client, nil
}
func (c *IndependentClient) Close() error {
	c.once.Do(func() {
		c.cancel()
		c.lifecycle.Lock()
		if c.expiry != nil {
			c.expiry.Stop()
		}
		body := c.authBody
		c.lifecycle.Unlock()
		if body != nil {
			body.Close()
		}
		if c.closeAuth != nil {
			c.closeAuth()
		}
		if c.closeTransport != nil {
			c.closeTransport()
		}
	})
	return nil
}
func (c *IndependentClient) Dial(ctx context.Context, target string) (net.Conn, error) {
	select {
	case <-c.ctx.Done():
		return nil, net.ErrClosed
	default:
	}
	id := c.counter.Add(1)
	prefix, err := flowPrefix(c.root, c.sid, c.binding, id, c.mode, target)
	if err != nil {
		return nil, err
	}
	flowCtx, cancel := context.WithCancel(ctx)
	stopParent := context.AfterFunc(c.ctx, cancel)
	reader, writer := io.Pipe()
	var once sync.Once
	closeFlow := func() { once.Do(func() { cancel(); stopParent(); writer.Close(); reader.Close() }) }
	res, err := c.roundTrip(flowCtx, independentFlowPath, io.MultiReader(bytes.NewReader(prefix), reader))
	if err != nil {
		closeFlow()
		return nil, err
	}
	// Explicitly close the response body on cancellation. Context cancellation
	// alone can leave a net/http HTTP/2 response-body read parked after the
	// physical connection has already gone away.
	stopBody := context.AfterFunc(flowCtx, func() { res.body.Close(); writer.Close(); reader.Close() })
	if !hmac.Equal(c.binding, res.binding) {
		c.Close()
		closeFlow()
		res.body.Close()
		return nil, errors.New("authentication connection changed; reauthenticate required")
	}
	p := &independentPayload{reader: res.body, writer: writer, id: id}
	var status []byte
	if c.mode == IndependentSealed {
		p.records = flowRecords(res.body, writer, c.root, prefix, c.binding, false)
		frames, e := p.records.read()
		if e != nil {
			closeFlow()
			res.body.Close()
			return nil, e
		}
		if len(frames) != 1 || frames[0].kind != 3 || frames[0].id != id || len(frames[0].body) != 2 {
			closeFlow()
			res.body.Close()
			return nil, errProtocol
		}
		status = frames[0].body
	} else {
		size := 2
		if c.mode == IndependentPipelined {
			size = 34
		}
		status = make([]byte, size)
		if _, err := io.ReadFull(res.body, status); err != nil {
			closeFlow()
			res.body.Close()
			return nil, err
		}
	}
	if c.mode == IndependentPipelined {
		if !validateFastOpenStatus(c.root, prefix, c.binding, status) {
			closeFlow()
			res.body.Close()
			return nil, errors.New("independent OPEN acknowledgement authentication failed")
		}
		status = status[:2]
	}
	if !bytes.Equal(status, []byte{0, 0}) {
		closeFlow()
		res.body.Close()
		return nil, errors.New("independent target rejected")
	}
	return &independentConn{independentPayload: p, closeFn: func() { closeFlow(); res.body.Close(); stopBody() }, halfClose: writer.Close}, nil
}

type independentConn struct {
	*independentPayload
	closeFn    func()
	halfClose  func() error
	once       sync.Once
	deadlineMu sync.Mutex
	timer      *time.Timer
	closed     bool
}

func (c *independentConn) Close() error {
	c.once.Do(func() {
		c.deadlineMu.Lock()
		c.closed = true
		if c.timer != nil {
			c.timer.Stop()
		}
		c.deadlineMu.Unlock()
		c.closeFn()
	})
	return nil
}
func (c *independentConn) CloseWrite() error {
	if err := c.independentPayload.CloseWrite(); err != nil {
		return err
	}
	return c.halfClose()
}
func (c *independentConn) LocalAddr() net.Addr  { return independentAddr("local") }
func (c *independentConn) RemoteAddr() net.Addr { return independentAddr("remote") }
func (c *independentConn) SetDeadline(t time.Time) error {
	c.deadlineMu.Lock()
	defer c.deadlineMu.Unlock()
	if c.timer != nil {
		c.timer.Stop()
	}
	if c.closed {
		return net.ErrClosed
	}
	if !t.IsZero() {
		c.timer = time.AfterFunc(time.Until(t), func() { c.Close() })
	}
	return nil
}
func (c *independentConn) SetReadDeadline(t time.Time) error  { return c.SetDeadline(t) }
func (c *independentConn) SetWriteDeadline(t time.Time) error { return c.SetDeadline(t) }

type independentAddr string

func (a independentAddr) Network() string { return "fastcat-independent" }
func (a independentAddr) String() string  { return string(a) }
