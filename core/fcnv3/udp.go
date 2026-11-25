package fcnv3

import (
	"context"
	"errors"
	"fmt"
	"io"
	"net"
	"net/netip"
	"net/url"
	"strings"
	"sync"
	"time"

	"github.com/dunglas/httpsfv"
	http "github.com/metacubex/http"
	"github.com/metacubex/quic-go"
	"github.com/metacubex/quic-go/http3"
	"github.com/metacubex/quic-go/quicvarint"
)

const (
	udpProtocol = "connect-udp"
	udpAuthKind = "CONNECT-UDP"
	udpPrefix   = "/.well-known/masque/udp/"

	// MaxUDPPayload leaves room for the QUIC and HTTP Datagram framing
	// within a 1200-byte QUIC packet. A path may impose a lower limit.
	MaxUDPPayload = 1150

	// DefaultUDPIdleTimeout is used when the server has no explicit UDP timeout.
	DefaultUDPIdleTimeout = 30 * time.Second
)

var (
	ErrUDPUnavailable     = errors.New("FCN v3 HTTP/3 datagrams unavailable")
	ErrUDPPayloadTooLarge = errors.New("FCN v3 UDP payload too large")
)

func normalizeUDPConfig(targets []string, idle time.Duration) (map[string]struct{}, time.Duration, error) {
	if len(targets) > 32 {
		return nil, 0, errors.New("FCN v3 permits up to 32 explicit numeric UDP targets")
	}
	if idle < 0 || idle > 5*time.Minute {
		return nil, 0, errors.New("invalid FCN v3 UDP idle timeout")
	}
	if idle == 0 {
		idle = DefaultUDPIdleTimeout
	}
	allowed := make(map[string]struct{}, len(targets))
	for _, value := range targets {
		target, err := authority(value, true)
		if err != nil {
			return nil, 0, err
		}
		address := netip.MustParseAddrPort(target).Addr()
		if address.IsUnspecified() || address.IsMulticast() || address == netip.AddrFrom4([4]byte{255, 255, 255, 255}) {
			return nil, 0, errors.New("FCN v3 UDP targets must be unicast")
		}
		allowed[target] = struct{}{}
	}
	return allowed, idle, nil
}

func udpRequest(endpoint, target string) *http.Request {
	host, port, _ := net.SplitHostPort(target)
	return &http.Request{
		Method: http.MethodConnect,
		Proto:  udpProtocol,
		Host:   endpoint,
		URL: &url.URL{
			Scheme:  "https",
			Host:    endpoint,
			Path:    udpPrefix + host + "/" + port + "/",
			RawPath: udpPrefix + strings.ReplaceAll(host, ":", "%3A") + "/" + port + "/",
		},
		Header: http.Header{http3.CapsuleProtocolHeader: {"?1"}},
	}
}

func udpRequestTarget(u *url.URL, numeric bool) (string, error) {
	invalid := errors.New("invalid FCN v3 CONNECT-UDP URI")
	if u.Scheme != "https" || u.ForceQuery || u.RawQuery != "" || u.Fragment != "" {
		return "", invalid
	}
	suffix, ok := strings.CutPrefix(u.EscapedPath(), udpPrefix)
	if !ok || !strings.HasSuffix(suffix, "/") {
		return "", invalid
	}
	host, port, ok := strings.Cut(strings.TrimSuffix(suffix, "/"), "/")
	if !ok || strings.Contains(host, ":") || strings.Contains(port, "/") {
		return "", invalid
	}
	host, err := url.PathUnescape(host)
	if err != nil {
		return "", invalid
	}
	port, err = url.PathUnescape(port)
	if err != nil {
		return "", invalid
	}
	return authority(net.JoinHostPort(host, port), numeric)
}

func validUDPCapsuleHeaders(h http.Header) bool {
	item, err := httpsfv.UnmarshalItem(h.Values(http3.CapsuleProtocolHeader))
	enabled, _ := item.Value.(bool)
	return err == nil && enabled && len(h.Values("Content-Length")) == 0 &&
		len(h.Values("Content-Type")) == 0 && len(h.Values("Transfer-Encoding")) == 0
}

func requireUDPSettings(ctx context.Context, q *quic.Conn, peer http3.Settingser, client bool) error {
	state := q.ConnectionState().SupportsDatagrams
	if !state.Local || !state.Remote {
		return ErrUDPUnavailable
	}
	select {
	case <-ctx.Done():
		return ctx.Err()
	case <-q.Context().Done():
		return net.ErrClosed
	case <-peer.ReceivedSettings():
		settings := peer.Settings()
		if !settings.EnableDatagrams || (client && !settings.EnableExtendedConnect) {
			return ErrUDPUnavailable
		}
		return nil
	}
}

// DialUDP establishes an authorized CONNECT-UDP association on the pooled
// HTTP/3 connection. The context bounds setup, and Close tears down the association.
func (c *Client) DialUDP(ctx context.Context, target string) (*UDPAssociation, error) {
	if !c.cfg.EnableUDP {
		return nil, ErrUDPUnavailable
	}
	target, err := authority(target, !c.cfg.AllowDomainTargets)
	if err != nil {
		return nil, err
	}
	setup, cancel := context.WithTimeout(ctx, setupTimeout)
	defer cancel()
	stopClient := context.AfterFunc(c.ctx, cancel)
	defer stopClient()
	s, err := c.acquire(setup)
	if err != nil {
		return nil, err
	}
	if err := requireUDPSettings(setup, s.quic, s.http, true); err != nil {
		return nil, err
	}
	stream, err := s.http.OpenRequestStream(setup)
	if err != nil {
		return nil, err
	}
	association := &UDPAssociation{stream: stream}
	stop := context.AfterFunc(setup, func() { association.Close() })
	req := udpRequest(c.cfg.Endpoint, target)
	req.Header.Set(authHeader, authValueFor(udpAuthKind, c.key, s.binding, c.cfg.Account, target, stream.StreamID()))
	err = stream.SendRequestHeader(req)
	if err == nil {
		var response *http.Response
		response, err = stream.ReadResponse()
		if err == nil {
			switch {
			case response.StatusCode < 200 || response.StatusCode >= 300:
				err = fmt.Errorf("%w (HTTP %d)", ErrRejected, response.StatusCode)
			case response.StatusCode >= 204 && response.StatusCode <= 206, !validUDPCapsuleHeaders(response.Header):
				err = ErrUDPUnavailable
			}
		}
	}
	stop()
	if setupErr := setup.Err(); setupErr != nil {
		err = setupErr
	}
	if err != nil {
		association.Close()
		return nil, err
	}
	go func() {
		watchUDPCapsules(stream)
		association.Close()
	}()
	return association, nil
}

// UDPAssociation carries individual UDP payloads on an HTTP/3 request stream
// using QUIC DATAGRAM frames.
type UDPAssociation struct {
	stream    *http3.RequestStream
	closeOnce sync.Once
}

// SendDatagram submits one UDP payload. QUIC may discard it after submission.
func (a *UDPAssociation) SendDatagram(payload []byte) error {
	if a.stream.Context().Err() != nil {
		return net.ErrClosed
	}
	return sendUDPPayload(a.stream, payload)
}

// ReceiveDatagram returns one UDP payload or an error when ctx or the
// association ends. Use one receiver at a time.
func (a *UDPAssociation) ReceiveDatagram(ctx context.Context) ([]byte, error) {
	ctx, cancel := context.WithCancel(ctx)
	defer cancel()
	streamCtx := a.stream.Context()
	stop := context.AfterFunc(streamCtx, cancel)
	defer stop()
	if streamCtx.Err() != nil {
		return nil, net.ErrClosed
	}
	payload, err := receiveUDPPayload(ctx, a.stream)
	if streamCtx.Err() != nil {
		return nil, net.ErrClosed
	}
	return payload, err
}

func (a *UDPAssociation) Close() error {
	a.closeOnce.Do(func() {
		a.stream.CancelRead(cancelCode)
		a.stream.CancelWrite(cancelCode)
	})
	return nil
}

func sendUDPPayload(stream interface{ SendDatagram([]byte) error }, payload []byte) error {
	if len(payload) > MaxUDPPayload {
		return ErrUDPPayloadTooLarge
	}
	var wire [1 + MaxUDPPayload]byte // RFC 9298 Context ID 0, then the UDP payload.
	copy(wire[1:], payload)
	return stream.SendDatagram(wire[:1+len(payload)])
}

func receiveUDPPayload(ctx context.Context, stream interface {
	ReceiveDatagram(context.Context) ([]byte, error)
}) ([]byte, error) {
	for ctx.Err() == nil {
		wire, err := stream.ReceiveDatagram(ctx)
		if err != nil {
			return nil, err
		}
		if id, n, err := quicvarint.Parse(wire); err == nil && id == 0 && len(wire)-n <= MaxUDPPayload {
			return wire[n:], nil
		}
	}
	return nil, ctx.Err()
}

// Watch for FIN, reset, and capsules. Unknown capsules are discarded per RFC
// 9297. A DATAGRAM capsule ends this datagram-only association.
func watchUDPCapsules(stream io.Reader) {
	reader := http3.NewCapsuleParser(stream)
	for {
		kind, body, err := reader.Next()
		if err != nil || kind == 0 || body.Discard() != nil {
			return
		}
	}
}

func (s *Server) handleUDP(w http.ResponseWriter, r *http.Request) {
	target, err := udpRequestTarget(r.URL, s.dispatch == nil)
	_, allowed := s.udpTargets[target]
	sc, bound := r.Context().Value(serverConnectionKey{}).(*serverConnection)
	body, streamID := r.Body.(interface{ StreamID() quic.StreamID })
	writer, canRelay := w.(http3.HTTPStreamer)
	settings, hasSettings := w.(http3.Settingser)
	auth := r.Header.Values(authHeader)
	if err != nil || !s.enableUDP || (!allowed && s.dispatch == nil) || !bound || !streamID || !canRelay || !hasSettings ||
		r.ProtoMajor != 3 || len(auth) != 1 || !validUDPCapsuleHeaders(r.Header) {
		http.Error(w, "Forbidden", http.StatusForbidden)
		return
	}
	account, lease, release, ok := s.authenticateFor(udpAuthKind, sc, auth[0], target, body.StreamID())
	if !ok {
		http.Error(w, "Forbidden", http.StatusForbidden)
		return
	}
	defer release()

	// The association ends if either the lease or the HTTP request ends.
	ctx, cancel := context.WithCancel(lease)
	defer cancel()
	stop := context.AfterFunc(r.Context(), cancel)
	defer stop()
	setup, cancelSetup := context.WithTimeout(ctx, 4*time.Second)
	defer cancelSetup()
	if err := requireUDPSettings(setup, sc.conn, settings, false); err != nil {
		http.Error(w, "Forbidden", http.StatusForbidden)
		return
	}
	up, err := s.dialTarget(setup, ctx, sc, account, "udp", target)
	if err != nil {
		http.Error(w, "Bad Gateway", http.StatusBadGateway)
		return
	}
	defer up.Close()
	if setup.Err() != nil {
		http.Error(w, "Forbidden", http.StatusForbidden)
		return
	}
	controller := http.NewResponseController(w)
	deadline, _ := setup.Deadline()
	if err := controller.SetWriteDeadline(deadline); err != nil {
		return
	}
	w.Header().Set(http3.CapsuleProtocolHeader, "?1")
	w.WriteHeader(http.StatusOK)
	if err := controller.Flush(); err != nil {
		return
	}
	stream := writer.HTTPStream()
	relayUDP(ctx, stream, up, s.udpIdleTimeout)
}

func relayUDP(ctx context.Context, stream *http3.Stream, udp net.Conn, idle time.Duration) {
	ctx, cancel := context.WithCancel(ctx)
	abort := func() {
		cancel()
		stream.CancelRead(cancelCode)
		stream.CancelWrite(cancelCode)
		udp.Close()
	}
	stop := context.AfterFunc(ctx, abort)
	defer stop()

	var activityMu sync.Mutex
	lastActivity := time.Now()
	touch := func() {
		activityMu.Lock()
		lastActivity = time.Now()
		activityMu.Unlock()
	}
	var relays sync.WaitGroup
	relays.Go(func() {
		defer cancel()
		watchUDPCapsules(stream)
	})
	relays.Go(func() {
		defer cancel()
		for {
			payload, err := receiveUDPPayload(ctx, stream)
			if err != nil || ctx.Err() != nil {
				return
			}
			if n, err := udp.Write(payload); err != nil || n != len(payload) {
				return
			}
			touch()
		}
	})
	relays.Go(func() {
		defer cancel()
		var packet [1 + MaxUDPPayload]byte
		for ctx.Err() == nil {
			n, err := udp.Read(packet[:])
			if err != nil || ctx.Err() != nil {
				return
			}
			if n > MaxUDPPayload {
				continue
			}
			if err := sendUDPPayload(stream, packet[:n]); err != nil {
				if _, tooLarge := errors.AsType[*quic.DatagramTooLargeError](err); tooLarge {
					continue
				}
				return
			}
			touch()
		}
	})

	timer := time.NewTimer(idle)
	defer timer.Stop()
	for ctx.Err() == nil {
		select {
		case <-ctx.Done():
		case <-timer.C:
			activityMu.Lock()
			remaining := idle - time.Since(lastActivity)
			activityMu.Unlock()
			if remaining <= 0 {
				cancel()
			} else {
				timer.Reset(remaining)
			}
		}
	}
	// Keep the lease while any in-progress submission to QUIC's bounded
	// send queue exits. Revocation closes the UDP socket and stream promptly.
	relays.Wait()
}
