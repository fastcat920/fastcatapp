package fcn

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
	cfg           ServerConfig
	traceSessions sync.Map
	slots         chan struct{}
}
type connState struct {
	mu   sync.Mutex
	seen map[[16]byte]bool
}
type stateKey struct{}

func NewServer(c ServerConfig) (*Server, error) {
	if len(c.TracePeerSalt) != 0 && len(c.TracePeerSalt) != 32 {
		return nil, ErrProtocol
	}
	c.TracePeerSalt = append([]byte(nil), c.TracePeerSalt...)
	if c.PrefixRedundancy && (c.DownstreamBudget || c.ReplyCoalesceDelay != 0) {
		return nil, ErrProtocol
	}
	if c.DownstreamBudget && c.ReplyCoalesceDelay != 0 {
		return nil, ErrProtocol
	}
	if c.ReplyCoalesceDelay < 0 || c.ReplyCoalesceDelay > 10*time.Millisecond {
		return nil, ErrProtocol
	}
	if c.FixedPacketSize != 0 && (c.FixedPacketSize < 1200 || c.FixedPacketSize > 1452) {
		return nil, ErrProtocol
	}
	if !validQUICProfile(c.QUICProfile) {
		return nil, ErrProtocol
	}
	if c.LookupKey == nil && (len(c.Accounts) == 0 || len(c.Accounts) > 1024) {
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
	key := s.cfg.Accounts[h.Account]
	if s.cfg.LookupKey != nil {
		key = s.cfg.LookupKey(h.Account)
	}
	ok := verifyHeader(h, key, binding)
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
	qc := s.quicConfig()
	attachServerQUICTrace(qc, s.cfg.Trace, &s.traceSessions, s.cfg.PrefixTrace)
	listener, e := quic.Listen(pc, tc, qc)
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
	setProfileCC(c, s.cfg.Congestion, s.cfg.QUICProfile)
	s.cfg.Counters.Sessions.Add(1)
	if s.cfg.Trace != nil {
		var session uint64
		if t, ok := s.traceSessions.Load(c.Context()); ok {
			session = t.(*quicTrace).session
		}
		gso := c.ConnectionState().GSO
		s.cfg.Trace(Event{AtUnixUS: time.Now().UnixMicro(), PeerTag: diagnosticPeerTag(s.cfg.TracePeerSalt, c.RemoteAddr().String()), Stage: "server_features", Carrier: "quic", OK: true, Session: session, GSO: &gso})
	}
	state := c.ConnectionState().TLS
	binding, e := state.ExportKeyingMaterial(exporterLabel, nil, 32)
	if e != nil {
		return
	}
	st := &connState{seen: make(map[[16]byte]bool)}
	var budget *downstreamBudget
	if s.cfg.DownstreamBudget {
		budget = newDownstreamBudget()
	}
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
		go func() {
			defer wg.Done()
			defer func() { <-s.slots }()
			s.serveStream(c, stream, binding, st, assocs, budget)
		}()
	}
}
func (s *Server) serveStream(c *quic.Conn, stream *quic.Stream, binding []byte, st *connState, assocs *serverAssociations, budget *downstreamBudget) {
	defer stream.CancelRead(0)
	defer stream.Close()
	stream.SetDeadline(time.Now().Add(5 * time.Second))
	h, e := readHeader(stream)
	if e != nil || !s.authorize(h, binding, st) {
		stream.Write([]byte{1})
		return
	}
	if h.Kind == 2 && (!s.cfg.PrefixRedundancy || !c.ConnectionState().SupportsDatagrams.Remote) {
		s.cfg.Counters.Rejected.Add(1)
		stream.Write([]byte{3})
		return
	}
	var budgetFlow *budgetFlow
	if budget != nil && h.Kind == 0 {
		budgetFlow = budget.open()
		defer budgetFlow.close()
	}
	trace := s.cfg.Trace
	if trace != nil {
		tag := diagnosticTag(h.Nonce)
		var session uint64
		if t, ok := s.traceSessions.Load(c.Context()); ok {
			session = t.(*quicTrace).session
		}
		base := trace
		trace = func(e Event) {
			e.AtUnixUS = time.Now().UnixMicro()
			e.RequestTag = tag
			e.Stream = uint64(stream.StreamID())
			e.Session = session
			base(e)
		}
		trace(Event{Stage: "server_open_received", Carrier: "quic", OK: true})
	}
	ctx, stop := context.WithCancel(c.Context())
	defer stop()
	if s.cfg.AuthorizeContext != nil {
		var release func()
		ctx, release, e = s.cfg.AuthorizeContext(ctx, h.Account, c.RemoteAddr())
		if e != nil {
			stream.Write([]byte{1})
			return
		}
		defer release()
	}
	dialctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	network := "tcp"
	if h.Kind == 1 {
		network = "udp"
	}
	dialStart := time.Now()
	target, e := s.cfg.dial(dialctx, network, h.Target)
	if trace != nil {
		trace(Event{Stage: "server_target_dial", Carrier: "quic", DurationUS: time.Since(dialStart).Microseconds(), OK: e == nil})
	}
	cancel()
	if e != nil {
		stream.Write([]byte{2})
		return
	}
	defer target.Close()
	stream.SetDeadline(time.Time{})
	s.cfg.Counters.Accepted.Add(1)
	done := context.AfterFunc(ctx, func() { target.Close(); stream.CancelRead(0); stream.CancelWrite(0) })
	defer done()
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
	var downstream io.Writer = stream
	var prefixCopy *prefixCopyWriter
	if h.Kind == 2 {
		prefixCopy = &prefixCopyWriter{stream: stream, q: c, id: uint64(stream.StreamID()), trace: trace}
	}
	var prefix *replyPrefix
	if s.cfg.ReplyCoalesceDelay > 0 {
		prefix = newReplyPrefix(stream, s.cfg.ReplyCoalesceDelay, trace)
		downstream = prefix
		defer prefix.Stop()
	} else {
		if _, e := stream.Write([]byte{0}); e != nil {
			return
		}
		if trace != nil {
			trace(Event{Stage: "server_ack_queued", Carrier: "quic", OK: true})
		}
		if prefixCopy != nil {
			prefixCopy.duplicate([]byte{0})
			downstream = prefixCopy
		}
	}
	up := make(chan struct{})
	go func() {
		n, _ := copyTrace(ctx, target, stream, trace, "quic", "upload")
		s.cfg.Counters.Upload.Add(uint64(n))
		if cw, ok := target.(interface{ CloseWrite() error }); ok {
			cw.CloseWrite()
		}
		close(up)
	}()
	if budgetFlow != nil {
		downstream = &budgetWriter{ctx: ctx, stream: stream, flow: budgetFlow, trace: trace}
	}
	n, _ := copyTrace(ctx, downstream, target, trace, "quic", "download")
	if w, ok := downstream.(*budgetWriter); ok && trace != nil {
		trace(Event{Stage: "download_budget", Carrier: "quic", WrittenBytes: n, BudgetWaitUS: w.wait.Microseconds(), BudgetYields: int64(w.limited), OK: true})
	}
	s.cfg.Counters.Download.Add(uint64(n))
	if prefixCopy != nil && trace != nil {
		trace(Event{Stage: "prefix_copy_summary", Carrier: "quic", WrittenBytes: int64(prefixCopy.bytes), PacketsSent: int64(prefixCopy.copies), OK: true})
	}
	if prefix != nil {
		_ = prefix.Flush()
	}
	stream.Close()
	stream.CancelRead(0)
	<-up
}

func (s *Server) quicConfig() *quic.Config {
	q := profileQUICConfig(s.cfg.IdleTimeout, s.cfg.QUICProfile)
	if s.cfg.FixedPacketSize != 0 {
		q.InitialPacketSize = s.cfg.FixedPacketSize
		q.DisablePathMTUDiscovery = true
	}
	return q
}
