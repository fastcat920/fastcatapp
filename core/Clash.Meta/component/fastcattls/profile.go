// Package fastcattls configures TLS for FastCat entry connections.
package fastcattls

import (
	"crypto/tls"
	"errors"
)

// The group identifiers are shared by the TLS implementations used by TCP and QUIC.
func Group(mode string, supportsHybrid bool) (uint16, error) {
	switch mode {
	case "", "default":
		return 0, nil
	case "x25519":
		return 29, nil
	case "x25519mlkem768":
		if !supportsHybrid {
			return 0, errors.New("X25519MLKEM768 requires a hybrid-capable TLS implementation")
		}
		return 4588, nil
	default:
		return 0, errors.New("unknown tls-key-exchange (use default, x25519 or x25519mlkem768)")
	}
}

// Apply preserves the caller's trust roots, certificate name and verification.
func Apply(config *tls.Config, mode string) error {
	group, err := Group(mode, nativeHybrid)
	if err != nil {
		return err
	}
	config.MinVersion = tls.VersionTLS13
	if group != 0 {
		config.CurvePreferences = []tls.CurveID{tls.CurveID(group)}
	}
	return nil
}

// Negotiated describes only what the library reported for a completed handshake.
// Group is empty on standard-library versions without a public negotiated group.
type Negotiated struct {
	Version string
	Cipher  string
	Group   string
}

func Security(state tls.ConnectionState) Negotiated {
	if !state.HandshakeComplete {
		return Negotiated{}
	}
	version := ""
	switch state.Version {
	case tls.VersionTLS13:
		version = "TLS 1.3"
	case tls.VersionTLS12:
		version = "TLS 1.2"
	}
	return Negotiated{Version: version, Cipher: tls.CipherSuiteName(state.CipherSuite), Group: negotiatedGroup(state)}
}
