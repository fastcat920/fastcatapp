package h2server

import (
	"context"
	"errors"
	"io"
	"net"
	"strings"
	"time"

	http "github.com/metacubex/http"
	h3client "github.com/metacubex/mihomo/transport/fastcath3"
	quic "github.com/metacubex/quic-go"
	"github.com/metacubex/quic-go/http3"
	tls "github.com/metacubex/tls"
)

type H3Handler struct{ *server }

func NewH3(cfg Config) (*H3Handler, error) {
	s, err := newServer(cfg)
	if err != nil {
		return nil, err
	}
	return &H3Handler{s}, nil
}
func (h *H3Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if r.ProtoMajor != 3 || r.TLS == nil || r.TLS.Version != tls.VersionTLS13 || r.TLS.NegotiatedProtocol != "h3" {
		http.Error(w, "HTTP/3 required", 505)
		return
	}
	if r.Method != "CONNECT" {
		w.Header().Set("Allow", "CONNECT")
		http.Error(w, "CONNECT required", 405)
		return
	}
	if !h.credentials.Authorized(r.Header.Values("Proxy-Authorization")) {
		w.Header().Set("Proxy-Authenticate", "Bearer")
		http.Error(w, "Proxy authentication required", 407)
		return
	}
	select {
	case h.slots <- struct{}{}:
		defer func() { <-h.slots }()
	default:
		http.Error(w, "Busy", 503)
		return
	}
	udp := r.Proto == "connect-udp"
	network, target := "tcp", r.Host
	if udp {
		if r.Header.Get(http3.CapsuleProtocolHeader) != "?1" || !strings.HasPrefix(r.URL.Path, h3client.Prefix) || r.URL.RawQuery != "" {
			http.Error(w, "Invalid UDP request", 400)
			return
		}
		parts := strings.Split(strings.TrimPrefix(r.URL.Path, h3client.Prefix), "/")
		if len(parts) != 3 || parts[2] != "" || strings.ContainsAny(parts[0], "%[]") {
			http.Error(w, "Invalid UDP target", 400)
			return
		}
		target = net.JoinHostPort(parts[0], parts[1])
		network = "udp"
		peer := w.(interface {
			ReceivedSettings() <-chan struct{}
			Settings() *http3.Settings
		})
		settingsCtx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
		defer cancel()
		select {
		case <-peer.ReceivedSettings():
		case <-settingsCtx.Done():
			http.Error(w, "Settings timeout", 408)
			return
		}
		if !peer.Settings().EnableDatagrams {
			http.Error(w, "HTTP/3 datagrams required", 400)
			return
		}
	} else if r.Proto != "HTTP/3.0" {
		http.Error(w, "Unsupported CONNECT protocol", 501)
		return
	}
	ctx, stop := context.WithTimeout(r.Context(), 5*time.Second)
	up, err := dialNetworkTarget(ctx, network, target, h.allowPrivateTargets)
	stop()
	if err != nil {
		status := 502
		if errors.Is(err, errInvalidTarget) {
			status = 400
		} else if errors.Is(err, errDeniedTarget) {
			status = 403
		}
		http.Error(w, "Target unavailable", status)
		return
	}
	defer up.Close()
	deadline := time.Now().Add(h.sessionTimeout)
	if err = up.SetDeadline(deadline); err != nil {
		http.Error(w, "Stream setup failed", 500)
		return
	}
	if udp {
		w.Header().Set(http3.CapsuleProtocolHeader, "?1")
	}
	w.WriteHeader(200)
	str := w.(http3.HTTPStreamer).HTTPStream()
	str.SetDeadline(deadline)
	if udp {
		peer := h3client.NewDatagramConn(str, up.LocalAddr(), up.RemoteAddr())
		defer peer.Close()
		// A single direction ending must wake the other, including idle UDP targets.
		done := make(chan struct{})
		go func() { defer close(done); relayPackets(up, peer); up.Close() }()
		relayPackets(peer, up)
		peer.Close()
		up.Close()
		<-done
		return
	}
	done := make(chan struct{})
	go func() {
		defer close(done)
		_, e := io.Copy(up, str)
		if e == nil {
			up.(*net.TCPConn).CloseWrite()
		} else {
			up.Close()
		}
	}()
	_, err = io.Copy(str, up)
	if err == nil {
		str.Close()
	} else {
		str.CancelWrite(quic.StreamErrorCode(http3.ErrCodeInternalError))
	}
	str.CancelRead(quic.StreamErrorCode(http3.ErrCodeRequestCanceled))
	up.Close()
	<-done
}

func relayPackets(dst, src net.Conn) {
	buf := make([]byte, 65535)
	for {
		n, err := src.Read(buf)
		if err != nil {
			return
		}
		_, err = dst.Write(buf[:n])
		if err != nil && !errors.Is(err, &quic.DatagramTooLargeError{}) {
			return
		}
	}
}
