package h2server

import (
	"fastcat/https-tcp/entryauth"

	"context"
	"crypto/tls"
	"errors"
	"io"
	"net/http"
	"time"
)

type Config struct {
	Token               string
	TokensFile          string // Newline-separated device tokens; mutually exclusive with Token.
	MaxTunnels          int
	AllowPrivateTargets bool
	SessionTimeout      time.Duration
}

type server struct {
	credentials         *entryauth.Store
	slots               chan struct{}
	allowPrivateTargets bool
	sessionTimeout      time.Duration
}

func New(cfg Config) (http.Handler, error) {
	s, err := newServer(cfg)
	if err != nil {
		return nil, err
	}
	return s, nil
}

func newServer(cfg Config) (*server, error) {
	if cfg.MaxTunnels < 0 || cfg.SessionTimeout < 0 {
		return nil, errors.New("invalid tunnel limits")
	}
	if cfg.MaxTunnels == 0 {
		cfg.MaxTunnels = 128
	}
	if cfg.SessionTimeout == 0 {
		cfg.SessionTimeout = 30 * time.Minute
	}
	creds, err := entryauth.New(cfg.Token, cfg.TokensFile)
	if err != nil {
		return nil, err
	}
	return &server{
		credentials:         creds,
		slots:               make(chan struct{}, cfg.MaxTunnels),
		allowPrivateTargets: cfg.AllowPrivateTargets,
		sessionTimeout:      cfg.SessionTimeout,
	}, nil
}

func (s *server) ReloadTokens() error {
	return s.credentials.Reload()
}

func (s *server) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if r.ProtoMajor != 2 || r.TLS == nil || r.TLS.Version != tls.VersionTLS13 || r.TLS.NegotiatedProtocol != "h2" {
		http.Error(w, "HTTP/2 over TLS 1.3 required", http.StatusHTTPVersionNotSupported)
		return
	}
	if r.Method != http.MethodConnect {
		w.Header().Set("Allow", http.MethodConnect)
		http.Error(w, "CONNECT required", http.StatusMethodNotAllowed)
		return
	}
	if !s.credentials.Authorized(r.Header.Values("Proxy-Authorization")) {
		w.Header().Set("Proxy-Authenticate", "Bearer")
		http.Error(w, "Proxy authentication required", http.StatusProxyAuthRequired)
		return
	}
	select {
	case s.slots <- struct{}{}:
		defer func() { <-s.slots }()
	default:
		http.Error(w, "Busy", http.StatusServiceUnavailable)
		return
	}

	dialCtx, cancelDial := context.WithTimeout(r.Context(), 5*time.Second)
	upstream, err := dialTarget(dialCtx, r.Host, s.allowPrivateTargets)
	cancelDial()
	if err != nil {
		switch {
		case errors.Is(err, errInvalidTarget):
			http.Error(w, "Invalid target authority", http.StatusBadRequest)
		case errors.Is(err, errDeniedTarget):
			http.Error(w, "Target denied", http.StatusForbidden)
		default:
			http.Error(w, "Target unavailable", http.StatusBadGateway)
		}
		return
	}
	defer upstream.Close()
	stopCancel := context.AfterFunc(r.Context(), func() { upstream.Close() })
	defer stopCancel()

	// The HTTP/2 response controller sets a deadline only on this stream.
	ctrl := http.NewResponseController(w)
	deadline := time.Now().Add(s.sessionTimeout)
	if err := ctrl.SetWriteDeadline(deadline); err != nil {
		http.Error(w, "Stream setup failed", http.StatusInternalServerError)
		return
	}
	if err := upstream.SetDeadline(deadline); err != nil {
		http.Error(w, "Target unavailable", http.StatusBadGateway)
		return
	}
	w.WriteHeader(http.StatusOK)
	if err := ctrl.Flush(); err != nil {
		return
	}

	uploadDone := make(chan struct{})
	go func() {
		defer close(uploadDone)
		_, err := io.Copy(upstream, r.Body)
		if err == nil {
			// Propagate request END_STREAM to targets that wait for a FIN
			// before producing their reply.
			err = upstream.CloseWrite()
		}
		if err != nil {
			upstream.Close()
		}
	}()
	_, err = io.Copy(streamWriter{ResponseWriter: w, ctrl: ctrl}, upstream)
	// A net/http handler can only send response END_STREAM by returning.
	// End an unfinished upload when the destination finishes sending.
	r.Body.Close()
	upstream.Close()
	<-uploadDone
	if err != nil {
		// Reset this stream so an upstream read error is not reported as
		// a successfully completed, possibly truncated download.
		panic(http.ErrAbortHandler)
	}
}

type streamWriter struct {
	http.ResponseWriter
	ctrl *http.ResponseController
}

func (w streamWriter) Write(p []byte) (int, error) {
	n, err := w.ResponseWriter.Write(p)
	if err == nil {
		err = w.ctrl.Flush()
	}
	return n, err
}
