// N1 is an isolated protocol experiment, not a production or stealth claim.
package main

import (
	"bufio"
	"context"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"crypto/tls"
	"encoding/base64"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"sort"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"
)

const route = "/api/events"
const maxPayload = 16384

type settings struct {
	NativeUUID       string   `json:"native_uuid"`
	NativePassword   string   `json:"native_password"`
	Server           string   `json:"server"`
	Name             string   `json:"name"`
	Key              string   `json:"key"`
	CAFile           string   `json:"ca_file,omitempty"`
	ClientEmission   string   `json:"client_emission,omitempty"`
	TestCurve        string   `json:"test_curve,omitempty"`
	SetupAttempts    int      `json:"setup_attempts,omitempty"`
	SessionCacheSize int      `json:"session_cache_size,omitempty"`
	NetworkEpoch     string   `json:"network_epoch,omitempty"`
	PACHosts         []string `json:"pac_hosts,omitempty"`
}

func keyBytes(s string) ([]byte, error) {
	b, e := hex.DecodeString(s)
	if e != nil || len(b) != 32 {
		return nil, errors.New("key must be 32 random bytes in hex")
	}
	return b, nil
}

// Capability binds the destination, request path, timestamp and random nonce
// to the current TLS exporter. It cannot be moved to another TLS connection.
func capability(state *tls.ConnectionState, key []byte, target string) (string, error) {
	if len(target) > 255 {
		return "", errors.New("target too long")
	}
	b := make([]byte, 8+16+1+len(target))
	binary.BigEndian.PutUint64(b, uint64(time.Now().Unix()))
	if _, e := rand.Read(b[8:24]); e != nil {
		return "", e
	}
	b[24] = byte(len(target))
	copy(b[25:], target)
	exporter, e := state.ExportKeyingMaterial("EXPORTER-FastCat-N1-Prototype", nil, 32)
	if e != nil {
		return "", e
	}
	m := hmac.New(sha256.New, key)
	m.Write([]byte("POST " + route + "\x00"))
	m.Write(exporter)
	m.Write(b)
	return base64.RawURLEncoding.EncodeToString(append(b, m.Sum(nil)...)), nil
}

func verify(state *tls.ConnectionState, key []byte, token string, now time.Time) (string, error) {
	if state == nil || len(token) > 512 {
		return "", errors.New("invalid capability")
	}
	b, e := base64.RawURLEncoding.DecodeString(token)
	if e != nil || len(b) < 57 || len(b) != 57+int(b[24]) {
		return "", errors.New("invalid capability")
	}
	ts := int64(binary.BigEndian.Uint64(b))
	if ts < now.Unix()-30 || ts > now.Unix()+30 {
		return "", errors.New("expired capability")
	}
	exporter, e := state.ExportKeyingMaterial("EXPORTER-FastCat-N1-Prototype", nil, 32)
	if e != nil {
		return "", e
	}
	m := hmac.New(sha256.New, key)
	m.Write([]byte("POST " + route + "\x00"))
	m.Write(exporter)
	m.Write(b[:len(b)-32])
	if !hmac.Equal(b[len(b)-32:], m.Sum(nil)) {
		return "", errors.New("invalid capability")
	}
	target := string(b[25 : len(b)-32])
	host, port, e := net.SplitHostPort(target)
	if e != nil || host == "" || port == "" {
		return "", errors.New("invalid target")
	}
	return target, nil
}

// Record: body-size:u16, sequence:u32, payload-size:u16, payload, padding.
// Empty payload means FIN. Sequence, sizes and FIN are TLS protected.
type records struct {
	r            io.Reader
	w            io.Writer
	flush        func()
	rx, tx       uint32
	payloadLimit int
	rxFin, txFin atomic.Bool
}

func (s *records) write(p []byte) error {
	if s.txFin.Load() {
		if len(p) == 0 {
			return nil
		}
		return io.ErrClosedPipe
	}
	if len(p) > maxPayload {
		return errors.New("payload too large")
	}
	var random [32]byte
	if _, e := rand.Read(random[:]); e != nil {
		return e
	}
	pad := int(random[0] & 31)
	size := 6 + len(p) + pad
	b := make([]byte, 2+size)
	binary.BigEndian.PutUint16(b, uint16(size))
	binary.BigEndian.PutUint32(b[2:], s.tx)
	binary.BigEndian.PutUint16(b[6:], uint16(len(p)))
	copy(b[8:], p)
	copy(b[8+len(p):], random[:pad])
	if s.tx == ^uint32(0) {
		return errors.New("sequence exhausted")
	}
	s.tx++
	for len(b) > 0 {
		n, e := s.w.Write(b)
		if e != nil {
			return e
		}
		if n == 0 {
			return io.ErrShortWrite
		}
		b = b[n:]
	}
	if s.flush != nil {
		s.flush()
	}
	if len(p) == 0 {
		s.txFin.Store(true)
	}
	return nil
}
func (s *records) read() ([]byte, error) {
	if s.rxFin.Load() {
		return nil, io.EOF
	}
	var h [2]byte
	if _, e := io.ReadFull(s.r, h[:]); e != nil {
		if e == io.EOF {
			return nil, io.ErrUnexpectedEOF
		}
		return nil, e
	}
	n := int(binary.BigEndian.Uint16(h[:]))
	if n < 6 || n > 6+maxPayload+31 {
		return nil, errors.New("invalid record length")
	}
	b := make([]byte, n)
	if _, e := io.ReadFull(s.r, b); e != nil {
		return nil, e
	}
	seq := binary.BigEndian.Uint32(b)
	length := int(binary.BigEndian.Uint16(b[4:]))
	if seq != s.rx || s.rx == ^uint32(0) || length > maxPayload || 6+length > n || n-6-length > 31 {
		return nil, errors.New("invalid record")
	}
	s.rx++
	if length == 0 {
		s.rxFin.Store(true)
		return nil, io.EOF
	}
	return b[6 : 6+length], nil
}
func sendRecords(s *records, src io.Reader) error {
	size := maxPayload
	if s.payloadLimit > 0 {
		size = s.payloadLimit
	}
	b := make([]byte, size)
	for {
		n, e := src.Read(b)
		if n > 0 {
			if x := s.write(b[:n]); x != nil {
				return x
			}
		}
		if e == io.EOF {
			return s.write(nil)
		}
		if e != nil {
			return e
		}
	}
}
func receiveRecords(dst io.Writer, s *records) error {
	for {
		b, e := s.read()
		if e == io.EOF {
			return nil
		}
		if e != nil {
			return e
		}
		if _, e = io.Copy(dst, strings.NewReader(string(b))); e != nil {
			return e
		}
	}
}

type connectionContextKey struct{}

func withServerConnection(ctx context.Context, c net.Conn) context.Context {
	return context.WithValue(ctx, connectionContextKey{}, c)
}

type node struct {
	credentials   *credentialStore
	publicTargets map[string]bool
	emission      string
	controls      bool
	traceWrites   bool
	writeLimit    int
	key           []byte
	targets       map[string]bool
	mu            sync.Mutex
	seen          map[string]time.Time
	slots         chan struct{}
}

func unavailable(w http.ResponseWriter, r *http.Request) {
	// A streaming client waits for response headers before sending records.
	// Do not let net/http drain that unknown-length body before emitting 404.
	w.Header().Set("Connection", "close")
	http.NotFound(w, r)
}

// Bound unauthenticated connections as well as authenticated sessions.
type boundedListener struct {
	net.Listener
	slots   chan struct{}
	mu      sync.Mutex
	peers   map[string]int
	perPeer int
}
type boundedConn struct {
	net.Conn
	release func()
	once    sync.Once
}

func (c *boundedConn) CloseWrite() error {
	if half, ok := c.Conn.(interface{ CloseWrite() error }); ok {
		return half.CloseWrite()
	}
	return fmt.Errorf("half-close unavailable")
}
func (c *boundedConn) Close() error { e := c.Conn.Close(); c.once.Do(c.release); return e }
func (l *boundedListener) Accept() (net.Conn, error) {
	for {
		c, e := l.Listener.Accept()
		if e != nil {
			return nil, e
		}
		select {
		case l.slots <- struct{}{}:
			host, _, err := net.SplitHostPort(c.RemoteAddr().String())
			if err != nil {
				host = c.RemoteAddr().String()
			}
			if ip := net.ParseIP(host); ip != nil {
				host = ip.String()
			}
			l.mu.Lock()
			if l.peers == nil {
				l.peers = make(map[string]int)
			}
			if l.perPeer > 0 && l.peers[host] >= l.perPeer {
				l.mu.Unlock()
				<-l.slots
				c.Close()
				continue
			}
			l.peers[host]++
			l.mu.Unlock()
			return &boundedConn{Conn: c, release: func() {
				l.mu.Lock()
				l.peers[host]--
				if l.peers[host] == 0 {
					delete(l.peers, host)
				}
				l.mu.Unlock()
				<-l.slots
			}}, nil
		default:
			c.Close()
		}
	}
}

func (n *node) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if n.controls && r.URL.Path == "/j" {
		if err := serveMatchedRPC(w, r, n.newWriteTrace("rpc")); err != nil {
			log.Print("matched RPC transport failure")
		}
		return
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	if r.Method == "GET" && r.URL.Path == "/" {
		io.WriteString(w, "<!doctype html><title>Network laboratory</title><h1>Network laboratory</h1><p>Service information and connectivity experiments.</p><a href=\"/assets/sample.bin\">32 KiB test sample</a>\n")
		return
	}
	if r.Method == "GET" && r.URL.Path == "/assets/sample.bin" {
		if !n.controls && (r.URL.Query().Get("n") != "" || r.URL.Query().Get("chunk") != "" || r.URL.Query().Get("gap_ms") != "") {
			unavailable(w, r)
			return
		}
		s, e := parseWorkload(r.URL.Query())
		if e != nil {
			unavailable(w, r)
			return
		}
		servePattern(w, r, s, r.URL.Query().Get("stream") == "1")
		return
	}
	if n.controls && r.URL.Path == "/api/sample-stream" {
		publicRPC(w, r)
		return
	}
	if r.Method != "POST" || r.URL.Path != route {
		unavailable(w, r)
		return
	}
	cookie, e := r.Cookie("session")
	if e != nil {
		unavailable(w, r)
		return
	}
	var target string
	var identity [32]byte
	if n.credentials != nil {
		target, identity, e = n.credentials.verify(r.TLS, cookie.Value, time.Now())
	} else {
		target, e = verify(r.TLS, n.key, cookie.Value, time.Now())
	}
	publicName, publicErr := publicTargetName(target)
	isPublic := publicErr == nil && n.publicTargets[publicName]
	if e != nil || (!n.targets[target] && !isPublic) {
		unavailable(w, r)
		return
	}
	n.mu.Lock()
	now := time.Now()
	for k, t := range n.seen {
		if now.Sub(t) > time.Minute {
			delete(n.seen, k)
		}
	}
	_, duplicate := n.seen[cookie.Value]
	full := len(n.seen) >= 8192
	if !duplicate && !full {
		n.seen[cookie.Value] = now
	}
	n.mu.Unlock()
	if duplicate || full {
		unavailable(w, r)
		return
	}
	select {
	case n.slots <- struct{}{}:
		defer func() { <-n.slots }()
	default:
		http.Error(w, "Service unavailable", 503)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 2*time.Minute)
	defer cancel()
	var lease *credentialLease
	if n.credentials != nil {
		var release func()
		ctx, lease, release, e = n.credentials.lease(ctx, identity, func() {
			if c, ok := r.Context().Value(connectionContextKey{}).(net.Conn); ok {
				c.Close()
			}
		})
		if e != nil {
			unavailable(w, r)
			return
		}
		defer release()
	}
	var up net.Conn
	if isPublic {
		dialCtx, stop := context.WithTimeout(ctx, 5*time.Second)
		up, e = dialPublic(dialCtx, publicName, nil)
		stop()
	} else {
		up, e = (&net.Dialer{Timeout: 5 * time.Second}).DialContext(ctx, "tcp", target)
	}
	if e != nil {
		http.Error(w, "Upstream unavailable", 502)
		return
	}
	defer up.Close()
	if lease != nil && !lease.bind(up) {
		return
	}
	up.SetDeadline(time.Now().Add(2 * time.Minute))
	rc := http.NewResponseController(w)
	if e = rc.EnableFullDuplex(); e != nil {
		http.Error(w, "Service unavailable", 503)
		return
	}
	rc.SetReadDeadline(time.Now().Add(2 * time.Minute))
	rc.SetWriteDeadline(time.Now().Add(2 * time.Minute))
	if n.emission == "coalesced" {
		if e := serveCoalescedLimited(w, r, up, n.writeLimit, n.newWriteTrace("n1")); e != nil {
			log.Print("coalesced session ended with transport error")
		}
		return
	}
	w.Header().Set("Content-Type", "application/octet-stream")
	w.WriteHeader(200)
	rc.Flush()
	s := &records{r: r.Body, w: w, flush: func() { rc.Flush() }}
	done := make(chan error, 1)
	go func() {
		e := receiveRecords(up, s)
		if tcp, ok := up.(*net.TCPConn); ok {
			tcp.CloseWrite()
		}
		if e != nil {
			up.Close()
		}
		done <- e
	}()
	e = sendRecords(s, up)
	if e != nil {
		up.Close()
		rc.SetReadDeadline(time.Now())
	}
	// A target may close its sending direction and still accept an upload.
	// Keep that direction alive until the peer FIN or the session deadline.
	<-done
	r.Body.Close()
	if e != nil {
		log.Print("session ended with transport error")
	}
}

type tunnel struct {
	tcpMS, tlsMS, openMS float64
	conn                 net.Conn
	writer               *io.PipeWriter
	body                 io.ReadCloser
	record               *records
	pending              []byte
	once                 sync.Once
	finishOnce           sync.Once
	finishErr            error
	requestDone          <-chan error
	writeFinished        atomic.Bool
	shutdownErr          error
	deadline             time.Time
	trace                *entryTrace
	outerVerified        bool
	tlsEOF               bool
}

func (t *tunnel) Read(b []byte) (int, error) {
	if len(b) == 0 {
		return 0, nil
	}
	if len(t.pending) == 0 {
		p, e := t.record.read()
		if e != nil {
			return 0, e
		}
		t.pending = p
	}
	n := copy(b, t.pending)
	t.pending = t.pending[n:]
	return n, nil
}
func (t *tunnel) Write(b []byte) (int, error) {
	total := 0
	for len(b) > 0 {
		n := len(b)
		if n > maxPayload {
			n = maxPayload
		}
		if e := t.record.write(b[:n]); e != nil {
			return total, e
		}
		total += n
		b = b[n:]
	}
	return total, nil
}
func (t *tunnel) CloseWrite() error {
	t.finishOnce.Do(func() {
		t.finishErr = t.record.write(nil)
		if t.writer != nil {
			t.writer.CloseWithError(t.finishErr)
			if e := <-t.requestDone; t.finishErr == nil {
				t.finishErr = e
			}
		}
		t.writeFinished.Store(true)
	})
	return t.finishErr
}
func (t *tunnel) Close() error {
	t.once.Do(func() {
		if t.writeFinished.Load() && t.finishErr == nil && t.record.rxFin.Load() {
			deadline := time.Now().Add(5 * time.Second)
			if !t.deadline.IsZero() && deadline.After(t.deadline) {
				deadline = t.deadline
			}
			t.conn.SetDeadline(deadline)
			t.trace.begin("outer_http_eof")
			phaseStart := time.Now()
			var extra [1]byte
			if n, e := io.ReadFull(t.body, extra[:]); n != 0 || e != io.EOF {
				t.shutdownErr = endingError("outer HTTP ending", n, e)
			} else {
				t.outerVerified = true
			}
			t.trace.elapsed("outer_http_eof", time.Since(phaseStart))
			if t.shutdownErr == nil {
				t.trace.begin("tls_close_send")
				phaseStart = time.Now()
				if closer, ok := t.conn.(interface{ CloseWrite() error }); ok {
					t.shutdownErr = closer.CloseWrite()
				}
				t.trace.elapsed("tls_close_send", time.Since(phaseStart))
			}
			if t.shutdownErr == nil {
				t.trace.begin("tls_close_receive")
				phaseStart = time.Now()
				if n, e := io.ReadFull(t.conn, extra[:]); n != 0 || e != io.EOF {
					t.shutdownErr = endingError("TLS ending", n, e)
				} else {
					t.tlsEOF = true
				}
				t.trace.elapsed("tls_close_receive", time.Since(phaseStart))
			}
		}
		if t.shutdownErr != nil {
			t.trace.fail()
		}
		t.conn.Close()
		if t.writer != nil {
			t.writer.Close()
		}
		t.body.Close()
	})
	return t.shutdownErr
}

func dial(ctx context.Context, cfg settings, target string) (*tunnel, error) {
	return dialObserved(ctx, cfg, target, nil)
}
func dialObserved(ctx context.Context, cfg settings, target string, observe func(writeEvent)) (*tunnel, error) {
	if cfg.ClientEmission != "" && cfg.ClientEmission != "legacy" && cfg.ClientEmission != "coalesced" {
		return nil, fmt.Errorf("invalid client emission")
	}
	started := time.Now()
	key, e := keyBytes(cfg.Key)
	if e != nil {
		return nil, e
	}
	trace := traceFrom(ctx)
	c, tcpDone, tlsDone, e := connectTLS(ctx, cfg, trace)
	if e != nil {
		return nil, e
	}
	stopCancellation := context.AfterFunc(ctx, func() { c.Close() })
	defer stopCancellation()
	c.SetDeadline(phaseDeadline(ctx, 5*time.Second))
	trace.begin("entry_auth_headers")
	state := c.ConnectionState()
	proof, e := capability(&state, key, target)
	if e != nil {
		c.Close()
		return nil, e
	}
	reader, writer := io.Pipe()
	req, e := http.NewRequest("POST", "https://"+cfg.Name+route, reader)
	if e != nil {
		c.Close()
		return nil, e
	}
	req.Header.Set("Content-Type", "application/octet-stream")
	req.AddCookie(&http.Cookie{Name: "session", Value: proof})
	var requestDone chan error
	output := &observedWriter{destination: c, observe: observe}
	if cfg.ClientEmission == "coalesced" {
		headers, err := streamingRequestHeaders(req)
		if err == nil {
			_, err = output.Write(headers)
		}
		if err != nil {
			c.Close()
			reader.Close()
			writer.Close()
			return nil, err
		}
		reader.Close()
		writer.Close()
		writer = nil
	} else {
		requestDone = make(chan error, 1)
		go func() {
			err := req.Write(output)
			if err != nil {
				writer.CloseWithError(err)
				c.Close()
			}
			requestDone <- err
		}()
	}
	response, e := http.ReadResponse(bufio.NewReader(c), req)
	if e != nil {
		c.Close()
		if writer != nil {
			writer.Close()
		}
		return nil, fmt.Errorf("entry_response: %w", e)
	}
	if response.StatusCode != 200 {
		c.Close()
		if writer != nil {
			writer.Close()
		}
		response.Body.Close()
		return nil, entryStatusError{response.StatusCode}
	}
	trace.elapsed("entry_auth_headers", time.Since(tlsDone))
	stopCancellation()
	if e = ctx.Err(); e != nil {
		c.Close()
		return nil, e
	}
	// The caller context bounds setup only. Workload callers explicitly set
	// their own whole-request deadline after Dial; proxy streams retain 2min.
	deadline := time.Now().Add(2 * time.Minute)
	c.SetDeadline(deadline)
	t := &tunnel{conn: c, writer: writer, body: response.Body, requestDone: requestDone, deadline: deadline, trace: trace, tcpMS: float64(tcpDone.Sub(started).Microseconds()) / 1000, tlsMS: float64(tlsDone.Sub(tcpDone).Microseconds()) / 1000, openMS: float64(time.Since(tlsDone).Microseconds()) / 1000}
	t.record = &records{r: response.Body, w: writer}
	if cfg.ClientEmission == "coalesced" {
		t.record.w = &chunkBatchWriter{destination: output}
	}
	return t, nil
}

func proxy(cfg settings, listen string) error {
	host, _, e := net.SplitHostPort(listen)
	if e != nil || !net.ParseIP(host).IsLoopback() {
		return fmt.Errorf("proxy must bind loopback")
	}
	pac, err := makePAC(cfg.PACHosts, listen)
	if err != nil {
		return err
	}
	handler := makeProxyHandler(cfg, pac)
	listener, e := net.Listen("tcp", listen)
	if e != nil {
		return e
	}
	server := &http.Server{ReadHeaderTimeout: 5 * time.Second, ReadTimeout: 20 * time.Second, WriteTimeout: 20 * time.Second, MaxHeaderBytes: 8192, Handler: handler}
	return server.Serve(&boundedListener{Listener: listener, slots: make(chan struct{}, 32), perPeer: 32})
}
func makeProxyHandler(cfg settings, pac string) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method == "GET" && r.URL.Path == "/proxy.pac" && pac != "" {
			w.Header().Set("Content-Type", "application/x-ns-proxy-autoconfig")
			w.Header().Set("Cache-Control", "no-store")
			io.WriteString(w, pac)
			return
		}
		if r.Method != "CONNECT" {
			http.Error(w, "CONNECT required", 405)
			return
		}
		if len(cfg.PACHosts) > 0 {
			host, _, err := net.SplitHostPort(r.Host)
			allowed := false
			for _, h := range cfg.PACHosts {
				if strings.EqualFold(host, h) {
					allowed = true
				}
			}
			if err != nil || !allowed {
				http.Error(w, "Target unavailable", 403)
				return
			}
		}
		ctx, cancel := context.WithTimeout(r.Context(), 15*time.Second)
		defer cancel()
		t, e := dial(ctx, cfg, r.Host)
		if e != nil {
			http.Error(w, "Tunnel unavailable", 502)
			return
		}
		defer t.Close()
		local, rw, e := w.(http.Hijacker).Hijack()
		if e != nil {
			return
		}
		defer local.Close()
		local.SetDeadline(time.Now().Add(2 * time.Minute))
		rw.WriteString("HTTP/1.1 200 Connection Established\r\n\r\n")
		rw.Flush()
		done := make(chan struct{})
		go func() { io.Copy(t, rw); t.CloseWrite(); close(done) }()
		_, downErr := io.Copy(local, t)
		if downErr != nil {
			local.Close()
		} else if half, ok := local.(interface{ CloseWrite() error }); ok {
			half.CloseWrite()
		} else {
			local.Close()
		}
		<-done
	})
}

func probe(cfg settings, target string, count, size int) error {
	if size < 1 || size > 32*1024*1024 || count < 1 || count > 1000 {
		return errors.New("invalid probe size or sample count")
	}
	times := []float64{}
	failed := 0
	for i := 0; i < count; i++ {
		started := time.Now()
		var firstHeaders time.Duration
		ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
		t, e := dial(ctx, cfg, target)
		if e == nil {
			_, e = t.Write([]byte(fmt.Sprintf("GET /bytes?n=%d HTTP/1.1\r\nHost: origin\r\nConnection: close\r\n\r\n", size)))
			if e == nil {
				e = t.CloseWrite()
			}
			if e == nil {
				var r *http.Response
				responseReader := bufio.NewReader(t)
				r, e = http.ReadResponse(responseReader, nil)
				firstHeaders = time.Since(started)
				if e == nil {
					var b []byte
					b, e = io.ReadAll(r.Body)
					r.Body.Close()
					if e == nil && (r.StatusCode != 200 || len(b) != size) {
						e = errors.New("invalid origin response")
					}
					for j, v := range b {
						if v != byte(j%251) {
							e = errors.New("integrity mismatch")
							break
						}
					}
					if e == nil {
						var extra [1]byte
						if n, end := io.ReadFull(responseReader, extra[:]); n != 0 || end != io.EOF {
							e = fmt.Errorf("N1 FIN not verified: bytes=%d error=%v", n, end)
						}
						if e == nil {
							if n, end := io.ReadFull(t.body, extra[:]); n != 0 || end != io.EOF {
								e = fmt.Errorf("HTTP response EOF not verified: bytes=%d error=%v", n, end)
							}
						}
					}
				}
			}
			if closeError := t.Close(); e == nil {
				e = closeError
			}
		}
		cancel()
		if e != nil {
			failed++
			fmt.Printf("{\"sample\":%d,\"error\":%q}\n", i+1, e.Error())
		} else {
			ms := float64(time.Since(started).Microseconds()) / 1000
			times = append(times, ms)
			fmt.Printf("{\"sample\":%d,\"tcp_ms\":%.3f,\"tls_ms\":%.3f,\"open_ms\":%.3f,\"first_response_headers_ms\":%.3f,\"full_request_ms\":%.3f,\"bytes\":%d,\"end_to_end_mbps\":%.3f,\"stream_fin_verified\":true,\"outer_response_eof_verified\":true,\"tls_shutdown_eof_observed\":true}\n", i+1, t.tcpMS, t.tlsMS, t.openMS, float64(firstHeaders.Microseconds())/1000, ms, size, float64(size)*8/(ms*1000))
		}
	}
	sort.Float64s(times)
	result := map[string]any{"success": len(times), "failed": failed, "bytes_each": size, "scope": "fresh TCP + TLS + authenticated tunnel + verified payload + N1 FIN + HTTP EOF + TLS shutdown; speed includes setup, verification and shutdown"}
	if len(times) > 0 {
		result["p50_ms"] = times[(len(times)-1)/2]
		result["p95_ms"] = times[(len(times)*95+99)/100-1]
	}
	b, _ := json.Marshal(result)
	fmt.Println(string(b))
	if failed > 0 {
		return errors.New("probe failures")
	}
	return nil
}

func main() {
	benchPhase := flag.String("bench-phase", "warm", "cold,warm,concurrent,download,upload")
	mode := flag.String("mode", "probe", "server, proxy, probe, workload, inspect, baseline, baseline-stream, hold, origin, keygen")
	listen := flag.String("listen", "127.0.0.1:18091", "listen address")
	config := flag.String("config", "", "private JSON config")
	cert := flag.String("cert", "", "certificate path")
	private := flag.String("cert-key", "", "certificate key path")
	target := flag.String("target", "", "probe destination or comma-separated server allowlist")
	count := flag.Int("count", 10, "probe samples")
	size := flag.Int("bytes", 32768, "verified probe payload bytes")
	kind := flag.String("kind", "n1", "workload kind: n1, get, rpc")
	chunk := flag.Int("chunk", 16384, "workload source chunk bytes")
	gap := flag.Int("gap-ms", 0, "workload source inter-chunk gap")
	perPeer := flag.Int("per-peer", 8, "maximum concurrent TCP connections per source IP; 0 disables")
	emission := flag.String("emission", "legacy", "legacy or coalesced response framing; same N1 wire format")
	browserTokenFile := flag.String("browser-token-file", "", "private temporary browser job token")
	credentialsFile := flag.String("credentials-file", "", "private revisioned credential ring; SIGHUP reload")
	publicTargets := flag.String("public-targets", "", "explicit comma-separated public DNS host:port allowlist")
	headerSeconds := flag.Int("header-budget", 10, "bounded TLS/header server seconds 5..20")
	metricsFile := flag.String("metrics-file", "", "private bounded runtime JSONL path")
	runSeconds := flag.Int("run-seconds", 0, "bounded diagnostic schedule up to900s")
	intervalMS := flag.Int("interval-ms", 0, "diagnostic start spacing0..10000ms")
	workers := flag.Int("workers", 1, "bounded diagnostic concurrency 1..8")
	budgetSeconds := flag.Int("budget", 30, "diagnostic end-to-end seconds 1..120")
	writeLimit := flag.Int("data-write-limit", 0, "coalesced downlink complete write cap: 0 or 16384")
	traceWrites := flag.Bool("trace-writes", false, "bounded lab write metadata; requires workload-controls")
	matchShape := flag.String("match-shape", "", "diagnostic header,data,FIN body byte counts")
	controls := flag.Bool("workload-controls", false, "temporarily enable bounded diagnostic HTTP controls")
	flag.Parse()
	if *perPeer < 0 || *perPeer > 64 {
		log.Fatal("per-peer must be between 0 and 64")
	}
	if *emission != "legacy" && *emission != "coalesced" {
		log.Fatal("invalid emission profile")
	}
	if *mode == "keygen" {
		var b [32]byte
		rand.Read(b[:])
		fmt.Println(hex.EncodeToString(b[:]))
		return
	}
	var cfg settings
	if *mode != "origin" && *mode != "web" {
		b, e := readPrivateConfig(*config)
		if e != nil {
			log.Fatal(e)
		}
		if e = json.Unmarshal(b, &cfg); e != nil {
			log.Fatal(e)
		}
		if _, e = keyBytes(cfg.Key); e != nil && !(*mode == "server" && *credentialsFile != "") {
			log.Fatal(e)
		}
	}
	if *writeLimit != 0 && (*writeLimit != 16384 || *emission != "coalesced") {
		log.Fatal("write cap requires coalesced and value 16384")
	}
	if *headerSeconds < 5 || *headerSeconds > 20 {
		log.Fatal("header budget out of bounds")
	}
	var err error
	switch *mode {
	case "compare":
		stop, e := startRuntimeMetrics(*metricsFile, nil, nil)
		if e != nil {
			log.Fatal(e)
		}
		defer stop()
		err = compareBench(cfg, *kind, *target, *benchPhase, *size, *count, *workers)
	case "web":
		err = serveBrowserLab(*listen, *cert, *private, *browserTokenFile)
	case "server":
		key, _ := keyBytes(cfg.Key)
		n := &node{key: key, targets: map[string]bool{}, seen: map[string]time.Time{}, slots: make(chan struct{}, 32), emission: *emission, controls: *controls, traceWrites: *traceWrites && *controls, writeLimit: *writeLimit}
		if *credentialsFile != "" {
			n.credentials = &credentialStore{}
			if e := n.credentials.reload(*credentialsFile); e != nil {
				log.Fatal(e)
			}
			stopCredentials := n.credentials.watch(*credentialsFile)
			defer stopCredentials()
		}
		for _, v := range strings.Split(*target, ",") {
			host, port, e := net.SplitHostPort(v)
			p, pe := strconv.Atoi(port)
			if e != nil || net.ParseIP(host) == nil || pe != nil || p < 1 || p > 65535 {
				log.Fatal("prototype allowlist requires numeric IP:port")
			}
			n.targets[v] = true
		}
		if *publicTargets != "" {
			n.publicTargets = map[string]bool{}
			list := strings.Split(*publicTargets, ",")
			if len(list) > 16 {
				log.Fatal("public target limit16")
			}
			for _, v := range list {
				name, e := publicTargetName(v)
				if e != nil {
					log.Fatal("invalid public target")
				}
				n.publicTargets[name] = true
			}
		}
		s := &http.Server{ConnContext: withServerConnection, Addr: *listen, Handler: n, ReadHeaderTimeout: time.Duration(*headerSeconds) * time.Second, IdleTimeout: 15 * time.Second, MaxHeaderBytes: 8192, TLSConfig: &tls.Config{MinVersion: tls.VersionTLS13, NextProtos: []string{"http/1.1"}}, TLSNextProto: map[string]func(*http.Server, *tls.Conn, http.Handler){}}
		var listener net.Listener
		listener, err = net.Listen("tcp", *listen)
		if err == nil {
			bounded := &boundedListener{Listener: listener, slots: make(chan struct{}, 64), perPeer: *perPeer}
			stop, e := startRuntimeMetrics(*metricsFile, n, bounded.slots)
			if e != nil {
				listener.Close()
				log.Fatal(e)
			}
			defer stop()
			err = s.ServeTLS(bounded, *cert, *private)
		}
	case "proxy":
		err = proxy(cfg, *listen)
	case "revocation-probe":
		err = revocationProbe(cfg, *target)
	case "probe":
		err = probe(cfg, *target, *count, *size)
	case "matched-rpc":
		err = runMatchedRPC(cfg, workload{N: *size, Chunk: *chunk, GapMS: *gap}, *matchShape)
	case "diagnose":
		stop, e := startRuntimeMetrics(*metricsFile, nil, nil)
		if e != nil {
			log.Fatal(e)
		}
		defer stop()
		err = diagnose(cfg, *target, *kind, workload{N: *size, Chunk: *chunk, GapMS: *gap}, *count, *workers, time.Duration(*budgetSeconds)*time.Second, *runSeconds, *intervalMS)
	case "workload":
		err = runWorkload(cfg, *target, *kind, workload{N: *size, Chunk: *chunk, GapMS: *gap})
	case "inspect":
		err = inspect(cfg, *target, *count)
	case "baseline":
		err = baseline(cfg, *count, false)
	case "baseline-stream":
		err = baseline(cfg, *count, true)
	case "hold":
		err = hold(cfg, *count)
	case "origin":
		err = http.ListenAndServe(*listen, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			s, e := parseWorkloadLimit(r.URL.Query(), 32*1024*1024)
			if r.URL.Path != "/bytes" || e != nil {
				http.NotFound(w, r)
				return
			}
			servePattern(w, r, s, false)
		}))
	default:
		err = errors.New("unknown mode")
	}
	if err != nil {
		log.Fatal(err)
	}
}
