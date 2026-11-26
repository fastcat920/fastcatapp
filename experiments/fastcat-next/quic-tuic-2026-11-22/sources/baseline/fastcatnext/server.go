package fastcatnext

import (
	"context"
	"crypto/tls"
	quic "github.com/metacubex/quic-go"
	qtls "github.com/metacubex/tls"
	"io"
	"net"
	"net/http"
	"sync"
	"time"
)

type Server struct {
	cfg   ServerConfig
	slots chan struct{}
}
type connState struct {
	mu   sync.Mutex
	seen map[[16]byte]bool
}
type stateKey struct{}

func NewServer(c ServerConfig) (*Server, error) {
	if len(c.Accounts) == 0 || len(c.Accounts) > 1024 {
		return nil, ErrAuth
	}
	accounts := make(map[string][]byte, len(c.Accounts))
	for a, k := range c.Accounts {
		if len(a) < 1 || len(a) > 64 || len(k) != 32 {
			return nil, ErrAuth
		}
		accounts[a] = append([]byte(nil), k...)
	}
	c.Accounts = accounts
	if c.Congestion != "" && c.Congestion != "reno" && c.Congestion != "bbr" {
		return nil, ErrProtocol
	}
	if c.IdleTimeout == 0 {
		c.IdleTimeout = 60 * time.Second
	}
	if c.Counters == nil {
		c.Counters = &Counters{}
	}
	return &Server{cfg: c, slots: make(chan struct{}, 256)}, nil
}
func (s *Server) Counters() *Counters { return s.cfg.Counters }
func (s *Server) ConnContext(ctx context.Context, c net.Conn) context.Context {
	s.cfg.Counters.Sessions.Add(1)
	return context.WithValue(ctx, stateKey{}, &connState{seen: make(map[[16]byte]bool)})
}
func (s *Server) authorize(h openHeader, binding []byte, st *connState) bool {
	ok := verifyHeader(h, s.cfg.Accounts[h.Account], binding)
	if ok {
		st.mu.Lock()
		if len(st.seen) >= maxRequests || st.seen[h.Nonce] {
			ok = false
		} else {
			st.seen[h.Nonce] = true
		}
		st.mu.Unlock()
	}
	if !ok {
		s.cfg.Counters.Rejected.Add(1)
	}
	return ok
}
func (s *Server) reserve() bool {
	select {
	case s.slots <- struct{}{}:
		return true
	default:
		return false
	}
}
func (s *Server) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" || r.URL.Path != "/session" || r.ProtoMajor != 2 || r.TLS == nil || r.TLS.Version != tls.VersionTLS13 {
		http.NotFound(w, r)
		return
	}
	st, ok := r.Context().Value(stateKey{}).(*connState)
	if !ok {
		http.Error(w, "unavailable", 503)
		return
	}
	if !s.reserve() {
		http.Error(w, "busy", 503)
		return
	}
	defer func() { <-s.slots }()
	ctl := http.NewResponseController(w)
	ctl.SetReadDeadline(time.Now().Add(5 * time.Second))
	h, e := readHeader(r.Body)
	ctl.SetReadDeadline(time.Time{})
	binding, e2 := r.TLS.ExportKeyingMaterial(exporterLabel, nil, 32)
	if e != nil || e2 != nil || h.Kind != 0 || !s.authorize(h, binding, st) {
		http.NotFound(w, r)
		return
	}
	ctx, stop := context.WithTimeout(r.Context(), 10*time.Minute)
	defer stop()
	dialctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	target, e := s.cfg.dial(dialctx, "tcp", h.Target)
	cancel()
	if e != nil {
		http.Error(w, "target unavailable", 502)
		return
	}
	defer target.Close()
	s.cfg.Counters.Accepted.Add(1)
	w.Header().Set("Content-Type", "application/octet-stream")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(200)
	if ctl.Flush() != nil {
		return
	}
	callbackDone := make(chan struct{})
	done := context.AfterFunc(ctx, func() { defer close(callbackDone); target.Close(); r.Body.Close(); ctl.SetWriteDeadline(time.Now()) })
	defer func() {
		if !done() {
			<-callbackDone
		}
	}()
	upload := make(chan struct{})
	go func() {
		n, _ := copyTrace(ctx, target, r.Body, s.cfg.Trace, "h2", "upload")
		s.cfg.Counters.Upload.Add(uint64(n))
		if c, ok := target.(interface{ CloseWrite() error }); ok {
			c.CloseWrite()
		}
		close(upload)
	}()
	n, _ := copyTrace(ctx, flusher{w, ctl}, target, s.cfg.Trace, "h2", "download")
	s.cfg.Counters.Download.Add(uint64(n))
	// Downstream completion releases the request reader. This does not replay data.
	r.Body.Close()
	<-upload
}

type flusher struct {
	w io.Writer
	c *http.ResponseController
}

func (f flusher) Write(p []byte) (int, error) {
	n, e := f.w.Write(p)
	if e == nil {
		e = f.c.Flush()
	}
	return n, e
}

func (s *Server) ServeQUIC(ctx context.Context, pc net.PacketConn, tc *qtls.Config) error {
	tc = tc.Clone()
	tc.MinVersion = qtls.VersionTLS13
	tc.NextProtos = []string{ALPN}
	listener, e := quic.Listen(pc, tc, quicConfig(s.cfg.IdleTimeout))
	if e != nil {
		return e
	}
	defer listener.Close()
	stop := context.AfterFunc(ctx, func() { listener.Close() })
	defer stop()
	sessions := make(chan struct{}, 128)
	var wg sync.WaitGroup
	defer wg.Wait()
	for {
		c, e := listener.Accept(ctx)
		if e != nil {
			if ctx.Err() != nil {
				return nil
			}
			return e
		}
		select {
		case sessions <- struct{}{}:
		default:
			c.CloseWithError(1, "")
			continue
		}
		wg.Add(1)
		go func() { defer wg.Done(); defer func() { <-sessions }(); s.serveConn(ctx, c) }()
	}
}
func (s *Server) serveConn(ctx context.Context, c *quic.Conn) {
	defer c.CloseWithError(0, "")
	stop := context.AfterFunc(ctx, func() { c.CloseWithError(0, "") })
	defer stop()
	setCC(c, s.cfg.Congestion)
	s.cfg.Counters.Sessions.Add(1)
	state := c.ConnectionState().TLS
	binding, e := state.ExportKeyingMaterial(exporterLabel, nil, 32)
	if e != nil {
		return
	}
	st := &connState{seen: make(map[[16]byte]bool)}
	assocs := newServerAssociations(c, s.cfg.Counters)
	go assocs.receive()
	defer assocs.close()
	var wg sync.WaitGroup
	defer wg.Wait()
	for {
		stream, e := c.AcceptStream(ctx)
		if e != nil {
			return
		}
		if !s.reserve() {
			stream.CancelRead(1)
			stream.CancelWrite(1)
			continue
		}
		wg.Add(1)
		go func() { defer wg.Done(); defer func() { <-s.slots }(); s.serveStream(c, stream, binding, st, assocs) }()
	}
}
func (s *Server) serveStream(c *quic.Conn, stream *quic.Stream, binding []byte, st *connState, assocs *serverAssociations) {
	defer stream.CancelRead(0)
	defer stream.Close()
	stream.SetDeadline(time.Now().Add(5 * time.Second))
	h, e := readHeader(stream)
	if e != nil || !s.authorize(h, binding, st) {
		stream.Write([]byte{1})
		return
	}
	ctx, stop := context.WithTimeout(c.Context(), 10*time.Minute)
	defer stop()
	dialctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	network := "tcp"
	if h.Kind == 1 {
		network = "udp"
	}
	target, e := s.cfg.dial(dialctx, network, h.Target)
	cancel()
	if e != nil {
		stream.Write([]byte{2})
		return
	}
	defer target.Close()
	stream.SetDeadline(time.Now().Add(10 * time.Minute))
	s.cfg.Counters.Accepted.Add(1)
	if h.Kind == 1 {
		assocs.add(uint64(stream.StreamID()), target)
		defer assocs.remove(uint64(stream.StreamID()))
		if _, e := stream.Write([]byte{0}); e != nil {
			return
		}
		var b [1]byte
		stream.Read(b[:])
		return
	}
	if _, e := stream.Write([]byte{0}); e != nil {
		return
	}
	done := context.AfterFunc(ctx, func() { target.Close(); stream.CancelRead(0); stream.CancelWrite(0) })
	defer done()
	up := make(chan struct{})
	go func() {
		n, _ := io.Copy(target, stream)
		s.cfg.Counters.Upload.Add(uint64(n))
		if cw, ok := target.(interface{ CloseWrite() error }); ok {
			cw.CloseWrite()
		}
		close(up)
	}()
	n, _ := io.Copy(stream, target)
	s.cfg.Counters.Download.Add(uint64(n))
	stream.Close()
	stream.CancelRead(0)
	<-up
}
