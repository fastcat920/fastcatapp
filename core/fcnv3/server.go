package fcnv3

import (
	"context"
	"errors"
	"io"
	"net"
	"sync"
	"sync/atomic"
	"time"

	http "github.com/metacubex/http"
	"github.com/metacubex/quic-go"
	"github.com/metacubex/quic-go/http3"
	"github.com/metacubex/quic-go/qlogwriter"
	"github.com/metacubex/tls"
)

type Credential struct {
	ID     string `json:"id"`
	Secret string `json:"secret"`
}

// DispatchRequest describes an authenticated tunnel. Account is the opaque
// credential ID, never the subscriber's UUID or proof key.
type DispatchRequest struct {
	Account         string
	Peer            net.Addr
	Network, Target string
}

type ServerConfig struct {
	TLSConfig      *tls.Config
	Credentials    []Credential
	Targets        []string
	UDPTargets     []string
	UDPIdleTimeout time.Duration
	AdaptiveWrites bool
	Padding        bool
	QUICTrace      func(context.Context, bool, quic.ConnectionID) qlogwriter.Trace
	ConfigureQUIC  func(*quic.Conn)
	// Dispatch delegates dialing, egress policy and metering to the host.
	// TCP must support CloseWrite. UDP must be bound to Target and preserve
	// datagram boundaries. Close must unblock pending reads and writes.
	Dispatch  func(setupCtx, lifeCtx context.Context, request DispatchRequest) (net.Conn, error)
	EnableUDP bool // Enables UDP with Dispatch. Standalone uses UDPTargets.
	// ECHKeys enables both ECH key rotation and the ECH requirement for CONNECT.
	// A nil value leaves the phase-one TLS behavior in effect.
	ECHKeys []tls.EncryptedClientHelloKey
	// OnConnectRejected reports rate-limited categories without request data.
	// It may be called concurrently for different networks or reasons.
	OnConnectRejected func(network, reason string)
}

type Server struct {
	tls                 *tls.Config
	echKeys             atomic.Pointer[[]tls.EncryptedClientHelloKey]
	http                *http3.Server
	targets             map[string]struct{}
	udpTargets          map[string]struct{}
	udpIdleTimeout      time.Duration
	adaptiveWrites      bool
	padding             bool
	quicTrace           func(context.Context, bool, quic.ConnectionID) qlogwriter.Trace
	configureQUIC       func(*quic.Conn)
	dispatch            func(context.Context, context.Context, DispatchRequest) (net.Conn, error)
	enableUDP           bool
	ctx                 context.Context
	cancel              context.CancelFunc
	mu                  sync.Mutex
	keys                map[string][32]byte
	leases              map[*lease]struct{}
	listening           bool
	listener            *quic.Listener
	peers               chan struct{}
	addressPeers        map[string]int
	onConnectRejected   func(network, reason string)
	rejectionMu         sync.Mutex
	nextRejectionReport map[[2]string]time.Time
}

type lease struct {
	id     string
	key    [32]byte
	cancel context.CancelFunc
	conn   *serverConnection
	udp    bool
}

type serverConnectionKey struct{}
type serverConnection struct {
	conn    *quic.Conn
	binding []byte
	padding downlinkPaddingBudget
}

func NewServer(cfg ServerConfig) (*Server, error) {
	if cfg.TLSConfig == nil || len(cfg.TLSConfig.Certificates) == 0 && cfg.TLSConfig.GetCertificate == nil {
		return nil, errors.New("FCN v3 server certificate required")
	}
	if cfg.Dispatch == nil && (len(cfg.Targets) > 32 || len(cfg.Targets)+len(cfg.UDPTargets) == 0) {
		return nil, errors.New("FCN v3 requires an explicit target and supports at most 32 TCP targets")
	}
	if cfg.Dispatch != nil && len(cfg.Targets)+len(cfg.UDPTargets) != 0 {
		return nil, errors.New("FCN v3 dispatch and standalone targets cannot be combined")
	}
	targets := make(map[string]struct{}, len(cfg.Targets))
	for _, v := range cfg.Targets {
		target, e := authority(v, true)
		if e != nil {
			return nil, e
		}
		targets[target] = struct{}{}
	}
	udpTargets, udpIdle, err := normalizeUDPConfig(cfg.UDPTargets, cfg.UDPIdleTimeout)
	if err != nil {
		return nil, err
	}
	tc := cfg.TLSConfig.Clone()
	tc.MinVersion = tls.VersionTLS13
	tc.NextProtos = []string{"h3"}
	tc.SessionTicketsDisabled = true
	// A TLS callback could otherwise replace the enforced version and ALPN.
	if tc.GetConfigForClient != nil {
		return nil, errors.New("FCN v3 does not support dynamic TLS configuration")
	}
	var echKeys []tls.EncryptedClientHelloKey
	if cfg.ECHKeys != nil {
		if tc.EncryptedClientHelloKeys != nil || tc.GetEncryptedClientHelloKeys != nil {
			return nil, errors.New("FCN v3 ECH keys must have a single source")
		}
		var err error
		echKeys, err = prepareECHKeys(cfg.ECHKeys, tc)
		if err != nil {
			return nil, err
		}
	}
	ctx, cancel := context.WithCancel(context.Background())
	s := &Server{tls: tc, targets: targets, ctx: ctx, cancel: cancel, leases: make(map[*lease]struct{}), peers: make(chan struct{}, 64),
		addressPeers: make(map[string]int), udpTargets: udpTargets, udpIdleTimeout: udpIdle, adaptiveWrites: cfg.AdaptiveWrites, padding: cfg.Padding, quicTrace: cfg.QUICTrace,
		configureQUIC: cfg.ConfigureQUIC, dispatch: cfg.Dispatch, enableUDP: len(udpTargets) > 0 || cfg.Dispatch != nil && cfg.EnableUDP,
		onConnectRejected: cfg.OnConnectRejected}
	if s.onConnectRejected != nil {
		s.nextRejectionReport = make(map[[2]string]time.Time)
	}
	requireECH := echKeys != nil
	if requireECH {
		s.echKeys.Store(&echKeys)
		tc.GetEncryptedClientHelloKeys = func(*tls.ClientHelloInfo) ([]tls.EncryptedClientHelloKey, error) {
			return *s.echKeys.Load(), nil
		}
	}
	if e := s.ReplaceCredentials(cfg.Credentials); e != nil {
		cancel()
		return nil, e
	}
	s.http = &http3.Server{
		TLSConfig: tc, QUICConfig: s.quicOptions(), MaxHeaderBytes: 8192, EnableDatagrams: s.enableUDP,
		Handler: http.HandlerFunc(s.handle),
		ConnContext: func(ctx context.Context, q *quic.Conn) context.Context {
			if requireECH && !q.ConnectionState().TLS.ECHAccepted {
				return ctx
			}
			binding, e := connectionBinding(q)
			if e != nil {
				return ctx
			}
			return context.WithValue(ctx, serverConnectionKey{}, &serverConnection{conn: q, binding: binding})
		},
	}
	return s, nil
}

func (s *Server) quicOptions() *quic.Config {
	q := quicProfile()
	q.EnableDatagrams = s.enableUDP
	q.Tracer = s.quicTrace
	return q
}

func (s *Server) Serve(packet net.PacketConn) error {
	s.mu.Lock()
	if s.ctx.Err() != nil {
		s.mu.Unlock()
		return net.ErrClosed
	}
	if s.listening {
		s.mu.Unlock()
		return errors.New("FCN v3 server already started")
	}
	ln, e := quic.Listen(packet, s.tls, s.quicOptions())
	if e != nil {
		s.mu.Unlock()
		return e
	}
	s.listening = true
	s.listener = ln
	s.mu.Unlock()
	defer ln.Close()
	for {
		q, e := ln.Accept(s.ctx)
		if e != nil {
			return e
		}
		select {
		case s.peers <- struct{}{}:
		default:
			q.CloseWithError(0x107, "")
			continue
		}
		source, _, err := net.SplitHostPort(q.RemoteAddr().String())
		if err != nil || !s.reserveSource(source) {
			<-s.peers
			q.CloseWithError(0x107, "")
			continue
		}
		if s.configureQUIC != nil {
			s.configureQUIC(q)
		}
		go func() {
			defer func() { s.releaseSource(source); <-s.peers }()
			stop := context.AfterFunc(s.ctx, func() { q.CloseWithError(0, "") })
			defer stop()
			defer q.CloseWithError(0, "")
			_ = s.http.ServeQUICConn(q)
		}()
	}
}

const maxConnectionsPerAddress = 16

func (s *Server) reserveSource(source string) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.addressPeers[source] >= maxConnectionsPerAddress {
		return false
	}
	s.addressPeers[source]++
	return true
}

func (s *Server) releaseSource(source string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.addressPeers[source]--
	if s.addressPeers[source] == 0 {
		delete(s.addressPeers, source)
	}
}

func (s *Server) Close() error {
	s.cancel()
	s.mu.Lock()
	ln := s.listener
	for l := range s.leases {
		l.cancel()
	}
	s.mu.Unlock()
	if ln != nil {
		ln.Close()
	}
	return s.http.Close()
}

// ReplaceCredentials atomically publishes the new list. An empty list revokes
// all credentials. Removing or changing a key cancels every lease using it.
func (s *Server) ReplaceCredentials(creds []Credential) error {
	if s.dispatch == nil && len(creds) > 128 {
		return errors.New("FCN v3 credential limit exceeded")
	}
	next := make(map[string][32]byte, len(creds))
	used := make(map[[32]byte]struct{}, len(creds))
	for _, cred := range creds {
		key, e := credentialKey(cred.ID, cred.Secret)
		if e != nil {
			return e
		}
		if _, ok := next[cred.ID]; ok {
			return errors.New("duplicate FCN v3 account")
		}
		if _, ok := used[key]; ok {
			return errors.New("duplicate FCN v3 secret")
		}
		next[cred.ID] = key
		used[key] = struct{}{}
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.ctx.Err() != nil {
		return net.ErrClosed
	}
	s.keys = next
	for l := range s.leases {
		if key, ok := next[l.id]; !ok || key != l.key {
			l.cancel()
		}
	}
	return nil
}

func (s *Server) authenticateFor(kind string, sc *serverConnection, value, target string, id quic.StreamID) (accountID string, life context.Context, release func(), rejection string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	name, key, ok := verifyValueFor(kind, value, sc.binding, target, id, s.keys)
	switch {
	case !ok:
		return "", nil, nil, "authentication_failed"
	case s.ctx.Err() != nil:
		return "", nil, nil, "server_closing"
	case len(s.leases) >= 128:
		return "", nil, nil, "global_stream_limit"
	}
	isUDP := kind == udpAuthKind
	account, connection, udp, connectionUDP := 0, 0, 0, 0
	for active := range s.leases {
		if active.id == name {
			account++
		}
		if active.conn == sc {
			connection++
		}
		if active.udp {
			udp++
			if active.conn == sc {
				connectionUDP++
			}
		}
	}
	switch {
	case account >= 32:
		return "", nil, nil, "account_stream_limit"
	case connection >= 16:
		return "", nil, nil, "connection_stream_limit"
	case isUDP && udp >= 32:
		return "", nil, nil, "udp_stream_limit"
	case isUDP && connectionUDP >= 8:
		return "", nil, nil, "udp_connection_stream_limit"
	}
	var ctx context.Context
	var cancel context.CancelFunc
	if s.dispatch == nil {
		ctx, cancel = context.WithTimeout(sc.conn.Context(), 5*time.Minute)
	} else {
		ctx, cancel = context.WithCancel(sc.conn.Context())
	}
	l := &lease{id: name, key: key, cancel: cancel, conn: sc, udp: isUDP}
	s.leases[l] = struct{}{}
	return name, ctx, func() {
		s.mu.Lock()
		delete(s.leases, l)
		s.mu.Unlock()
		cancel()
	}, ""
}

func (s *Server) rejectConnect(w http.ResponseWriter, network, reason string) {
	if s.onConnectRejected != nil {
		key := [2]string{network, reason}
		s.rejectionMu.Lock()
		now := time.Now()
		report := !now.Before(s.nextRejectionReport[key])
		if report {
			s.nextRejectionReport[key] = now.Add(10 * time.Second)
		}
		s.rejectionMu.Unlock()
		if report {
			s.onConnectRejected(network, reason)
		}
	}
	http.Error(w, "Forbidden", http.StatusForbidden)
}

func (s *Server) dialTarget(setup, lifetime context.Context, sc *serverConnection, account, network, target string) (net.Conn, error) {
	if s.dispatch == nil {
		return (&net.Dialer{}).DialContext(setup, network, target)
	}
	conn, err := s.dispatch(setup, lifetime, DispatchRequest{Account: account, Peer: sc.conn.RemoteAddr(), Network: network, Target: target})
	if err != nil {
		if conn != nil {
			conn.Close()
		}
		return nil, err
	}
	if conn == nil {
		return nil, errors.New("FCN v3 dispatch returned no target connection")
	}
	return conn, nil
}

func (s *Server) handle(w http.ResponseWriter, r *http.Request) {
	if r.Method != "CONNECT" {
		if (r.Method == "GET" || r.Method == "HEAD") && r.URL.Path == "/" {
			w.Header().Set("Content-Type", "text/html; charset=utf-8")
			io.WriteString(w, "<!doctype html><html lang=\"en\"><meta charset=\"utf-8\"><title>FastCat</title><h1>FastCat</h1><p>HTTP/3 service is available.</p></html>")
			return
		}
		http.NotFound(w, r)
		return
	}
	if r.Proto == udpProtocol {
		s.handleUDP(w, r)
		return
	}
	target, e := authority(r.Host, s.dispatch == nil)
	_, allowed := s.targets[target]
	sc, known := r.Context().Value(serverConnectionKey{}).(*serverConnection)
	body, streamID := r.Body.(interface{ StreamID() quic.StreamID })
	writer, canRelay := w.(http3.HTTPStreamer)
	auth := r.Header.Values(authHeader)
	switch {
	case !known:
		s.rejectConnect(w, "tcp", "binding_unavailable")
		return
	case e != nil || target != r.Host || !streamID || !canRelay || len(auth) != 1 || r.Proto != "HTTP/3.0":
		s.rejectConnect(w, "tcp", "invalid_request")
		return
	case !allowed && s.dispatch == nil:
		s.rejectConnect(w, "tcp", "target_not_allowed")
		return
	}
	account, ctx, release, rejection := s.authenticateFor("CONNECT", sc, auth[0], target, body.StreamID())
	if rejection != "" {
		s.rejectConnect(w, "tcp", rejection)
		return
	}
	defer release()

	// CONNECT setup also follows request cancellation. Once the tunnel starts,
	// a QUIC FIN only closes its sending half and must not cancel its other half.
	dialCtx, stopDial := context.WithTimeout(ctx, 4*time.Second)
	stopRequest := context.AfterFunc(r.Context(), stopDial)
	up, e := s.dialTarget(dialCtx, ctx, sc, account, "tcp", target)
	stopRequest()
	stopDial()
	if e != nil {
		http.Error(w, "Bad Gateway", http.StatusBadGateway)
		return
	}
	defer up.Close()
	if ctx.Err() != nil {
		s.rejectConnect(w, "tcp", "lease_canceled")
		return
	}
	tcp, halfClose := up.(halfCloseConn)
	if !halfClose {
		http.Error(w, "Bad Gateway", http.StatusBadGateway)
		return
	}
	w.WriteHeader(200)
	if e := http.NewResponseController(w).Flush(); e != nil {
		return
	}
	stream := writer.HTTPStream()
	var downlink io.Writer = stream
	if s.padding {
		downlink = sc.padding.wrap(stream)
	}
	relay(ctx, stream, tcp, downlink, s.adaptiveWrites)
}

const relayBufferSize = 64 * 1024

var downlinkBuffers = sync.Pool{New: func() any {
	return new([relayBufferSize]byte)
}}

type halfCloseConn interface {
	net.Conn
	CloseWrite() error
}

func relay(ctx context.Context, stream *http3.Stream, tcp halfCloseConn, downlink io.Writer, adaptive bool) {
	var once sync.Once
	abort := func() {
		once.Do(func() {
			stream.CancelRead(cancelCode)
			stream.CancelWrite(cancelCode)
			tcp.Close()
		})
	}
	stop := context.AfterFunc(ctx, abort)
	defer stop()
	// A peer cancellation must close the upstream even when neither relay
	// direction is currently blocked on QUIC. Local FIN preserves the upload.
	sendContext := stream.Context()
	stopRemoteCancel := context.AfterFunc(sendContext, func() {
		var streamError *quic.StreamError
		if errors.As(context.Cause(sendContext), &streamError) && streamError.Remote && streamError.ErrorCode == cancelCode {
			abort()
		}
	})
	defer stopRemoteCancel()
	upload := make(chan error, 1)
	go func() {
		_, e := io.Copy(tcp, stream)
		if e == nil {
			e = tcp.CloseWrite()
		}
		if e != nil {
			abort()
		}
		upload <- e
	}()
	// A recycled buffer reduces allocation and the number of DATA writes in
	// bulk transfers. Reads still forward immediately, including small replies.
	var e error
	if adaptive {
		e = copyAdaptiveDownlink(downlink, tcp)
	} else {
		buffer := downlinkBuffers.Get().(*[relayBufferSize]byte)
		_, e = io.CopyBuffer(downlink, struct{ io.Reader }{tcp}, buffer[:])
		downlinkBuffers.Put(buffer)
	}
	if e == nil {
		e = stream.Close()
	}
	if e != nil {
		abort()
	}
	<-upload
}
