// Package quicprofile applies FastCat's TLS policy to the QUIC transport's TLS library.
package quicprofile

import (
	"crypto/x509"
	"errors"

	"github.com/metacubex/mihomo/component/fastcattls"
	tls "github.com/metacubex/tls"
)

func ApplyQUIC(config *tls.Config, mode string) error {
	group, err := fastcattls.Group(mode, true)
	if err != nil {
		return err
	}
	config.MinVersion = tls.VersionTLS13
	if group != 0 {
		config.CurvePreferences = []tls.CurveID{tls.CurveID(group)}
	}
	return nil
}
func Security(state tls.ConnectionState) fastcattls.Negotiated {
	if !state.HandshakeComplete {
		return fastcattls.Negotiated{}
	}
	s := fastcattls.Negotiated{Version: tls.VersionName(state.Version), Cipher: tls.CipherSuiteName(state.CipherSuite)}
	if state.CurveID != 0 {
		s.Group = state.CurveID.String()
	}
	return s
}

// ClientConfig uses the same TLS implementation for both explicit experiment
// modes. This avoids changing the module-wide Go TLS defaults of older apps.
func ClientConfig(name string, roots *x509.CertPool, alpn, mode string) (*tls.Config, error) {
	cfg := &tls.Config{ServerName: name, RootCAs: roots, NextProtos: []string{alpn}}
	if err := ApplyQUIC(cfg, mode); err != nil {
		return nil, err
	}
	cfg.VerifyConnection = func(state tls.ConnectionState) error {
		if state.NegotiatedProtocol != alpn {
			return errors.New("unexpected gateway ALPN")
		}
		return nil
	}
	return cfg, nil
}
