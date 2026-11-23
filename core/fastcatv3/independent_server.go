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
	"sync"
	"time"

	qhttp "github.com/metacubex/http"
	quic "github.com/metacubex/quic-go"
	"github.com/metacubex/quic-go/http3"
	qtls "github.com/metacubex/tls"
)

type independentAuth struct {
	root, binding []byte
	mode          IndependentMode
	expires       time.Time
	ctx           context.Context
	cancel        context.CancelFunc
	seen          map[uint64]struct{}
	active        int
	confirmed     chan struct{}
}

// IndependentServer is an isolated experimental profile, separate from legacy v3.
type IndependentServer struct {
	Config   Config
	mu       sync.Mutex
	sessions map[string]*independentAuth
	replays  replayCache
	slots    chan struct{}
}

func NewIndependentServer(c Config) (*IndependentServer, error) {
	if err := c.validate(true); err != nil {
		return nil, err
	}
	return &IndependentServer{Config: c, sessions: make(map[string]*independentAuth), slots: make(chan struct{}, 256)}, nil
}
func independentMode(s string) (IndependentMode, error) {
	switch s {
	case "light":
		return IndependentLight, nil
	case "sealed":
		return IndependentSealed, nil
	case "light-fast":
		return IndependentPipelined, nil
	}
	return 0, errProtocol
}
func (s *IndependentServer) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	mode, err := independentMode(r.Header.Get("X-Fastcat-Mode"))
	if err != nil || r.Method != "POST" || (r.URL.Path != independentAuthPath && r.URL.Path != independentFlowPath) || r.Header.Get("Content-Type") != "application/octet-stream" || r.Header.Get("Content-Encoding") != "" {
		http.NotFound(w, r)
		return
	}
	if r.ProtoMajor != 2 || r.TLS == nil || r.TLS.Version != tls.VersionTLS13 {
		http.Error(w, "unavailable", 400)
		return
	}
	select {
	case s.slots <- struct{}{}:
		defer func() { <-s.slots }()
	default:
		http.Error(w, "busy", 503)
		return
	}
	binding, err := r.TLS.ExportKeyingMaterial("EXPORTER-FastCat-v3", nil, 32)
	if err != nil {
		http.Error(w, "unavailable", 503)
		return
	}
	w.Header().Set("Content-Type", "application/octet-stream")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(200)
	ctl := http.NewResponseController(w)
	// The request prefix is already queued by the client. Flush headers with
	// SERVER_ACCEPT/OPEN_RESULT rather than sending an empty response first.
	var guard sync.Mutex
	finished, closed := false, false
	closeCarrier := func() {
		guard.Lock()
		defer guard.Unlock()
		if finished || closed {
			return
		}
		closed = true
		r.Body.Close()
		ctl.SetReadDeadline(time.Now())
		ctl.SetWriteDeadline(time.Now())
	}
	// A canceled AfterFunc may already be running. Join it before ResponseWriter
	// is returned to net/http; later callbacks must never touch that writer.
	defer func() { guard.Lock(); finished = true; guard.Unlock() }()
	s.handle(r.Context(), r.URL.Path, mode, r.Body, flushWriter{w, ctl.Flush, nil}, 1, binding, closeCarrier)
}
func (s *IndependentServer) ServeHTTP3(w qhttp.ResponseWriter, r *qhttp.Request) {
	mode, err := independentMode(r.Header.Get("X-Fastcat-Mode"))
	if err != nil || r.Method != "POST" || (r.URL.Path != independentAuthPath && r.URL.Path != independentFlowPath) || r.Header.Get("Content-Type") != "application/octet-stream" || r.Header.Get("Content-Encoding") != "" {
		qhttp.NotFound(w, r)
		return
	}
	if r.TLS == nil || r.TLS.Version != qtls.VersionTLS13 {
		qhttp.Error(w, "unavailable", 400)
		return
	}
	select {
	case s.slots <- struct{}{}:
		defer func() { <-s.slots }()
	default:
		qhttp.Error(w, "busy", 503)
		return
	}
	binding, err := r.TLS.ExportKeyingMaterial("EXPORTER-FastCat-v3", nil, 32)
	if err != nil {
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
	s.handle(r.Context(), r.URL.Path, mode, stream, stream, 2, binding, closeCarrier)
}
func (s *IndependentServer) handle(ctx context.Context, path string, mode IndependentMode, reader io.Reader, writer io.Writer, carrier byte, binding []byte, closeCarrier func()) {
	stopContext := context.AfterFunc(ctx, closeCarrier)
	defer stopContext()
	timeout := time.AfterFunc(8*time.Second, closeCarrier)
	defer timeout.Stop()
	if path == independentAuthPath {
		s.authenticate(ctx, mode, reader, writer, carrier, binding, closeCarrier, timeout)
		return
	}
	prefix, err := readFlowPrefix(reader)
	if err != nil {
		return
	}
	auth, id, target, err := s.claim(prefix, binding, mode)
	if err != nil {
		return
	}
	defer func() { s.mu.Lock(); auth.active--; s.mu.Unlock() }()
	// Proof validation/reservation can precede confirmation. Dialing cannot.
	if err := awaitIndependentConfirmation(ctx, auth); err != nil {
		return
	}
	flowCtx, cancel := context.WithCancel(ctx)
	defer cancel()
	stop := context.AfterFunc(auth.ctx, func() { cancel(); closeCarrier() })
	defer stop()
	dialCtx, stopDial := context.WithTimeout(flowCtx, 5*time.Second)
	conn, err := (&Session{config: s.Config}).dialTarget(dialCtx, "tcp", target)
	stopDial()
	p := &independentPayload{reader: reader, writer: writer, id: id}
	if mode == IndependentSealed {
		p.records = flowRecords(reader, writer, auth.root, prefix, binding, true)
	}
	status := []byte{0, 0}
	if err != nil {
		status[1] = 1
	}
	var ackErr error
	if p.records != nil {
		ackErr = p.records.write(frame{3, id, status})
	} else {
		if mode == IndependentPipelined {
			status = fastOpenStatus(auth.root, prefix, binding, status)
		}
		ackErr = writeAll(writer, status)
	}
	if err != nil || ackErr != nil {
		if conn != nil {
			conn.Close()
		}
		return
	}
	timeout.Stop()
	defer conn.Close()
	stopConn := context.AfterFunc(flowCtx, func() { conn.Close(); closeCarrier() })
	defer stopConn()
	done := make(chan error, 2)
	go func() {
		_, e := io.Copy(conn, p)
		if tcp, ok := conn.(*net.TCPConn); ok {
			tcp.CloseWrite()
		}
		done <- e
	}()
	go func() {
		_, e := io.Copy(p, conn)
		if e == nil {
			e = p.CloseWrite()
		}
		done <- e
	}()
	if e := <-done; e != nil {
		conn.Close()
		closeCarrier()
	}
	// A peer which has finished reading may still need to finish its upload.
	select {
	case <-done:
	case <-flowCtx.Done():
		conn.Close()
		closeCarrier()
		<-done
	}
}
func (s *IndependentServer) authenticate(ctx context.Context, mode IndependentMode, reader io.Reader, writer io.Writer, carrier byte, binding []byte, closeCarrier func(), timeout *time.Timer) {
	if mode == IndependentPipelined {
		s.authenticatePipelined(ctx, mode, reader, writer, carrier, binding, closeCarrier, timeout)
		return
	}
	c := independentConfig(s.Config, mode)
	r, err := serverHandshake(reader, writer, c, carrier, binding, &s.replays)
	if err != nil {
		return
	}
	sid := random(16)
	authCtx, cancel := context.WithCancel(ctx)
	defer cancel()
	a := &independentAuth{root: independentRoot(r, true), binding: append([]byte(nil), binding...), mode: mode, expires: time.Now().Add(independentTTL), ctx: authCtx, cancel: cancel, seen: make(map[uint64]struct{})}
	s.mu.Lock()
	if len(s.sessions) >= 64 {
		s.mu.Unlock()
		return
	}
	s.sessions[string(sid)] = a
	s.mu.Unlock()
	defer func() { s.mu.Lock(); delete(s.sessions, string(sid)); s.mu.Unlock(); cancel() }()
	ready := append([]byte(nil), sid...)
	ready = binary.BigEndian.AppendUint32(ready, uint32(independentTTL/time.Second))
	ready = append(ready, byte(mode))
	if err := r.write(frame{15, 0, ready}); err != nil {
		return
	}
	timeout.Stop()
	expiry := time.AfterFunc(independentTTL, closeCarrier)
	defer expiry.Stop()
	// The authentication stream remains open. Closing it revokes all derived flows.
	var unexpected [1]byte
	reader.Read(unexpected[:])
}
func (s *IndependentServer) claim(prefix, binding []byte, mode IndependentMode) (*independentAuth, uint64, string, error) {
	if len(prefix) < 48 || len(binding) != 32 || !bytes.Equal(prefix[:4], []byte(flowMagic(mode))) {
		return nil, 0, "", errProtocol
	}
	n := int(binary.BigEndian.Uint16(prefix[29:31]))
	if len(prefix) != 31+n+flowTagSize(mode) || n == 0 || n > 512 {
		return nil, 0, "", errProtocol
	}
	id := binary.BigEndian.Uint64(prefix[20:28])
	if id == 0 || id > independentMaxFlows || IndependentMode(prefix[28]) != mode {
		return nil, 0, "", errProtocol
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	a := s.sessions[string(prefix[4:20])]
	if a == nil || a.mode != mode || !time.Now().Before(a.expires) || !hmac.Equal(a.binding, binding) || a.active >= 128 {
		return nil, 0, "", errProtocol
	}
	var target string
	if mode == IndependentPipelined {
		var err error
		target, err = decryptFastTarget(a.root, prefix, binding)
		if err != nil {
			return nil, 0, "", errProtocol
		}
	} else {
		target = string(prefix[31 : 31+n])
		expected, err := flowPrefix(a.root, prefix[4:20], binding, id, mode, target)
		if err != nil || !hmac.Equal(prefix, expected) {
			return nil, 0, "", errProtocol
		}
	}
	if _, seen := a.seen[id]; seen {
		return nil, 0, "", errors.New("replayed flow")
	}
	select {
	case <-a.ctx.Done():
		return nil, 0, "", errProtocol
	default:
	}
	a.seen[id] = struct{}{}
	a.active++
	return a, id, target, nil
}

func awaitIndependentConfirmation(ctx context.Context, a *independentAuth) error {
	if a.confirmed == nil {
		if a.mode == IndependentPipelined {
			return errProtocol
		}
		if err := ctx.Err(); err != nil {
			return err
		}
		return a.ctx.Err()
	}
	gate, cancel := context.WithTimeout(ctx, 8*time.Second)
	defer cancel()
	select {
	case <-a.confirmed:
	case <-a.ctx.Done():
		return a.ctx.Err()
	case <-gate.Done():
		return gate.Err()
	}
	if err := ctx.Err(); err != nil {
		return err
	}
	if !time.Now().Before(a.expires) {
		return errProtocol
	}
	return a.ctx.Err()
}
func (s *IndependentServer) authenticatePipelined(ctx context.Context, mode IndependentMode, reader io.Reader, writer io.Writer, carrier byte, binding []byte, closeCarrier func(), timeout *time.Timer) {
	deadline := time.Now().Add(8 * time.Second)
	authCtx, cancel := context.WithCancel(ctx)
	var sid []byte
	var auth *independentAuth
	defer func() {
		cancel()
		if auth != nil {
			s.mu.Lock()
			if s.sessions[string(sid)] == auth {
				delete(s.sessions, string(sid))
			}
			s.mu.Unlock()
		}
	}()
	_, err := serverHandshakePrepared(reader, writer, independentConfig(s.Config, mode), carrier, binding, &s.replays, func(r *records) error {
		sid = append([]byte(nil), r.handshakeID...)
		auth = &independentAuth{root: independentRoot(r, true), binding: append([]byte(nil), binding...), mode: mode, expires: time.Now().Add(independentTTL), ctx: authCtx, cancel: cancel, seen: make(map[uint64]struct{}), confirmed: make(chan struct{})}
		s.mu.Lock()
		defer s.mu.Unlock()
		if len(s.sessions) >= 64 || s.sessions[string(sid)] != nil {
			return errors.New("authentication capacity reached")
		}
		s.sessions[string(sid)] = auth
		return nil
	})
	if err != nil || authCtx.Err() != nil || !time.Now().Before(deadline) {
		return
	}
	// Closing this gate is the only transition which permits target dialing.
	close(auth.confirmed)
	timeout.Stop()
	expiry := time.AfterFunc(time.Until(auth.expires), closeCarrier)
	defer expiry.Stop()
	var unexpected [1]byte
	io.ReadFull(reader, unexpected[:])
}
