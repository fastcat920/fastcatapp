package outbound

import (
	"context"
	"crypto/x509"
	"encoding/json"
	"errors"

	"github.com/metacubex/mihomo/component/fastcatentry"
)

type routeStatus struct {
	TCPProtocol string `json:"tcp-protocol,omitempty"`
	UDPStatus   string `json:"udp-status"`
	TCPError    string `json:"tcp-error,omitempty"`
	UDPError    string `json:"udp-error,omitempty"`
}

func routeError(err error, beforeConnect bool) string {
	var untrusted x509.UnknownAuthorityError
	var invalid x509.CertificateInvalidError
	var name x509.HostnameError
	var status fastcatentry.StatusError
	switch {
	case errors.As(err, &untrusted) || errors.As(err, &invalid) || errors.As(err, &name):
		return "certificate"
	case errors.Is(err, fastcatentry.ErrTarget):
		return "target"
	case errors.Is(err, fastcatentry.ErrProtocol):
		return "protocol"
	case errors.As(err, &status):
		switch status {
		case 401, 407:
			return "authentication"
		case 403, 502:
			return "target"
		case 429, 503:
			return "capacity"
		default:
			return "protocol"
		}
	case errors.Is(err, fastcatentry.ErrUnresponsive):
		return "entry"
	case beforeConnect && (fastCatEntryNetworkError(err) || errors.Is(err, context.Canceled)):
		return "entry"
	default:
		return ""
	}
}

func (a *FastCatAuto) status(network context.Context, udp bool, protocol, failure string) {
	a.mu.Lock()
	defer a.mu.Unlock()
	if a.routes.network != network || network.Err() != nil {
		return
	}
	s := &a.routes.status
	if udp {
		s.UDPError = failure
		if protocol != "" {
			s.UDPStatus = "available"
		} else {
			s.UDPStatus = "unavailable"
		}
	} else {
		s.TCPError = failure
		if protocol != "" {
			s.TCPProtocol = protocol
		}
	}
}
func (a *FastCatAuto) MarshalJSON() ([]byte, error) {
	if a.h3 == nil {
		return a.Base.MarshalJSON()
	}
	a.mu.Lock()
	s := routeStatus{}
	if a.routes.network != nil && a.routes.network.Err() == nil {
		s = a.routes.status
	}
	a.mu.Unlock()
	if !a.SupportUDP() {
		s.UDPStatus = "disabled"
	} else if s.UDPStatus == "" {
		s.UDPStatus = "unknown"
	}
	return json.Marshal(map[string]any{"id": a.Id(), "type": a.Type().String(), "fastcat-v2": s})
}
