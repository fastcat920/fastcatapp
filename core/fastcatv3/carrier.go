package fastcatv3

import (
	"bytes"
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
	"sync"
	"time"

	qhttp "github.com/metacubex/http"
	quic "github.com/metacubex/quic-go"
	"github.com/metacubex/quic-go/http3"
	qtls "github.com/metacubex/tls"
)

type flushWriter struct {
	writer io.Writer
	flush  func() error
	trace  func(string)
}

func (w flushWriter) Write(b []byte) (int, error) {
	var start, flushStart time.Time
	if w.trace != nil {
		start = time.Now()
	}
	n, e := w.writer.Write(b)
	var buffered time.Duration
	if w.trace != nil {
		buffered = time.Since(start)
		flushStart = time.Now()
	}
	if e == nil {
		e = w.flush()
	}
	if w.trace != nil {
		flushed := time.Since(flushStart)
		w.trace(fmt.Sprintf("carrier_flush role=server carrier=h2 start_unix_us=%d bytes=%d buffer_us=%d flush_us=%d ok=%t", start.UnixMicro(), len(b), buffered.Microseconds(), flushed.Microseconds(), e == nil))
	}
	return n, e
}

type Server struct {
	Config  Config
	OnError func(error)
	replays replayCache
	slots   chan struct{}
}

func NewServer(c Config) (*Server, error) {
	if e := c.validate(true); e != nil {
		return nil, e
	}
	return &Server{Config: c, slots: make(chan struct{}, 64)}, nil
}
func (s *Server) serve(ctx context.Context, reader io.Reader, writer io.Writer, carrier byte, binding []byte, closeCarrier func()) error {
	ctx, cancel := context.WithCancel(ctx)
	defer cancel()
	timer := time.AfterFunc(8*time.Second, func() { cancel(); closeCarrier() })
	r, e := serverHandshake(reader, writer, s.Config, carrier, binding, &s.replays)
	timer.Stop()
	if e != nil {
		return e
	}
	session := newSession(ctx, r, s.Config, true, closeCarrier)
	defer session.Close()
	<-session.ctx.Done()
	return session.Err()
}
func (s *Server) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/fc-session" || r.Method != "POST" || r.Header.Get("Content-Type") != "application/octet-stream" || r.Header.Get("Content-Encoding") != "" {
		http.NotFound(w, r)
		return
	}
	if r.ProtoMajor != 2 || r.TLS == nil || r.TLS.Version != tls.VersionTLS13 {
		http.Error(w, "HTTP/2 TLS 1.3 required", 400)
		return
	}
	select {
	case s.slots <- struct{}{}:
		defer func() { <-s.slots }()
	default:
		http.Error(w, "busy", 503)
		return
	}
	binding, e := r.TLS.ExportKeyingMaterial("EXPORTER-FastCat-v3", nil, 32)
	if e != nil {
		http.Error(w, "unavailable", 503)
		return
	}
	w.Header().Set("Content-Type", "application/octet-stream")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(200)
	controller := http.NewResponseController(w)
	controller.Flush()
	var closeOnce sync.Once
	closeCarrier := func() {
		closeOnce.Do(func() {
			r.Body.Close()
			controller.SetReadDeadline(time.Now())
			controller.SetWriteDeadline(time.Now())
		})
	}
	if e := s.serve(r.Context(), r.Body, flushWriter{w, controller.Flush, s.Config.Trace}, 1, binding, closeCarrier); e != nil && s.OnError != nil {
		s.OnError(e)
	}
}
func (s *Server) ServeHTTP3(w qhttp.ResponseWriter, r *qhttp.Request) {
	if r.URL.Path != "/fc-session" || r.Method != "POST" || r.Header.Get("Content-Type") != "application/octet-stream" || r.Header.Get("Content-Encoding") != "" {
		qhttp.NotFound(w, r)
		return
	}
	if r.TLS == nil || r.TLS.Version != qtls.VersionTLS13 {
		qhttp.Error(w, "TLS 1.3 required", 400)
		return
	}
	select {
	case s.slots <- struct{}{}:
		defer func() { <-s.slots }()
	default:
		qhttp.Error(w, "busy", 503)
		return
	}
	binding, e := r.TLS.ExportKeyingMaterial("EXPORTER-FastCat-v3", nil, 32)
	if e != nil {
		qhttp.Error(w, "unavailable", 503)
		return
	}
	w.Header().Set("Content-Type", "application/octet-stream")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(200)
	stream := w.(http3.HTTPStreamer).HTTPStream()
	defer stream.Close()
	closeCarrier := func() {
		stream.CancelRead(quic.StreamErrorCode(http3.ErrCodeRequestCanceled))
		stream.CancelWrite(quic.StreamErrorCode(http3.ErrCodeRequestCanceled))
	}
	if e := s.serve(r.Context(), stream, stream, 2, binding, closeCarrier); e != nil && s.OnError != nil {
		s.OnError(e)
	}
}

type DialConfig struct {
	Config               Config
	Endpoint, ServerName string
	Roots                *x509.CertPool
}

func Dial(ctx context.Context, c DialConfig, carrier string) (*Session, error) {
	if e := c.Config.validate(false); e != nil {
		return nil, e
	}
	u, e := url.Parse("https://" + c.Endpoint + "/fc-session")
	if e != nil || u.Hostname() == "" || u.Port() == "" || u.User != nil || u.RawQuery != "" || u.Fragment != "" {
		return nil, errors.New("invalid entry endpoint")
	}
	name := c.ServerName
	if name == "" {
		name = u.Hostname()
	}
	if carrier == "h3" {
		return dialH3(ctx, c, u.String(), name)
	}
	if carrier != "h2" {
		return nil, errors.New("prototype supports h2 and h3")
	}
	pending, prefix, e := prepareClientHandshake(c.Config, 1)
	if e != nil {
		return nil, e
	}
	root, cancel := context.WithCancel(ctx)
	reader, writer := io.Pipe()
	tr := &http.Transport{ForceAttemptHTTP2: true, TLSClientConfig: &tls.Config{MinVersion: tls.VersionTLS13, ServerName: name, RootCAs: c.Roots, NextProtos: []string{"h2"}}, TLSHandshakeTimeout: 8 * time.Second}
	req, e := http.NewRequestWithContext(root, "POST", u.String(), io.MultiReader(bytes.NewReader(prefix), reader))
	if e != nil {
		cancel()
		return nil, e
	}
	req.Header.Set("Content-Type", "application/octet-stream")
	req.Header.Set("User-Agent", "")
	trace := &httptrace.ClientTrace{GotConn: func(info httptrace.GotConnInfo) {
		c.Config.trace("client tls_connected")
		if conn, ok := info.Conn.(*tls.Conn); ok {
			go func() { <-root.Done(); conn.Close() }()
		}
	}}
	req = req.WithContext(httptrace.WithClientTrace(req.Context(), trace))
	type result struct {
		response *http.Response
		err      error
	}
	done := make(chan result, 1)
	go func() { res, e := tr.RoundTrip(req); done <- result{res, e} }()
	var once sync.Once
	var response *http.Response
	closeCarrier := func() {
		once.Do(func() {
			cancel()
			writer.Close()
			reader.Close()
			tr.CloseIdleConnections()
		})
	}
	timer := time.AfterFunc(8*time.Second, closeCarrier)
	var res result
	select {
	case res = <-done:
	case <-root.Done():
		timer.Stop()
		closeCarrier()
		return nil, root.Err()
	}
	c.Config.trace("client carrier_response")
	response = res.response
	if res.err != nil {
		timer.Stop()
		closeCarrier()
		return nil, res.err
	}
	if response.StatusCode != 200 || response.ProtoMajor != 2 || response.TLS == nil {
		timer.Stop()
		closeCarrier()
		return nil, errors.New("entry rejected H2 carrier")
	}
	binding, e := response.TLS.ExportKeyingMaterial("EXPORTER-FastCat-v3", nil, 32)
	if e != nil {
		timer.Stop()
		closeCarrier()
		return nil, e
	}
	records, e := pending.finish(response.Body, writer, c.Config, binding)
	timer.Stop()
	if e != nil {
		closeCarrier()
		return nil, e
	}
	return newSession(root, records, c.Config, false, closeCarrier), nil
}
func dialH3(ctx context.Context, c DialConfig, address, name string) (*Session, error) {
	pending, prefix, e := prepareClientHandshake(c.Config, 2)
	if e != nil {
		return nil, e
	}
	root, cancel := context.WithCancel(ctx)
	reader, writer := io.Pipe()
	tr := &http3.Transport{TLSClientConfig: &qtls.Config{MinVersion: qtls.VersionTLS13, ServerName: name, RootCAs: c.Roots}, QUICConfig: &quic.Config{HandshakeIdleTimeout: 5 * time.Second, MaxIdleTimeout: 30 * time.Second}, DisableCompression: true}
	req, e := qhttp.NewRequestWithContext(root, "POST", address, io.MultiReader(bytes.NewReader(prefix), reader))
	if e != nil {
		cancel()
		return nil, e
	}
	req.Header.Set("Content-Type", "application/octet-stream")
	req.Header.Set("User-Agent", "")
	var response *qhttp.Response
	var once sync.Once
	closeCarrier := func() {
		once.Do(func() {
			cancel()
			writer.Close()
			reader.Close()
			tr.Close()
		})
	}
	timer := time.AfterFunc(8*time.Second, closeCarrier)
	response, e = tr.RoundTrip(req)
	c.Config.trace("client carrier_response")
	if e != nil {
		timer.Stop()
		closeCarrier()
		return nil, e
	}
	if response.StatusCode != 200 || response.ProtoMajor != 3 || response.TLS == nil {
		timer.Stop()
		closeCarrier()
		return nil, fmt.Errorf("entry rejected H3 carrier")
	}
	binding, e := response.TLS.ExportKeyingMaterial("EXPORTER-FastCat-v3", nil, 32)
	if e != nil {
		timer.Stop()
		closeCarrier()
		return nil, e
	}
	records, e := pending.finish(response.Body, writer, c.Config, binding)
	timer.Stop()
	if e != nil {
		closeCarrier()
		return nil, e
	}
	return newSession(root, records, c.Config, false, closeCarrier), nil
}

var _ net.Conn = (*Stream)(nil)
