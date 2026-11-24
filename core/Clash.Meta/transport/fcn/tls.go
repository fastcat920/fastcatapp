package fcn

import (
	"crypto/sha256"
	"crypto/subtle"
	"crypto/tls"
	"crypto/x509"
	"encoding/base64"
	"errors"
	"fmt"
	qtls "github.com/metacubex/tls"
	"strings"
	"time"
)

var ErrServerIdentity = errors.New("FCN server identity verification failed")

// PublicKeyPin hashes DER SubjectPublicKeyInfo; certificate renewal can retain it.
func PublicKeyPin(cert *x509.Certificate) string {
	sum := sha256.Sum256(cert.RawSubjectPublicKeyInfo)
	return "sha256/" + base64.StdEncoding.EncodeToString(sum[:])
}
func decodePins(pins []string) ([][32]byte, error) {
	if len(pins) < 1 || len(pins) > 2 {
		return nil, fmt.Errorf("%w: one or two SPKI pins required", ErrServerIdentity)
	}
	out := make([][32]byte, 0, len(pins))
	for _, pin := range pins {
		if !strings.HasPrefix(pin, "sha256/") {
			return nil, fmt.Errorf("%w: invalid SPKI pin format", ErrServerIdentity)
		}
		b, e := base64.StdEncoding.Strict().DecodeString(strings.TrimPrefix(pin, "sha256/"))
		if e != nil || len(b) != 32 {
			return nil, fmt.Errorf("%w: invalid SPKI SHA256", ErrServerIdentity)
		}
		var value [32]byte
		copy(value[:], b)
		out = append(out, value)
	}
	return out, nil
}
func (c Config) validateTrust() error {
	switch c.TrustMode {
	case "", "ca":
		if len(c.PublicKeyPins) != 0 {
			return fmt.Errorf("%w: pins require explicit spki mode", ErrServerIdentity)
		}
	case "spki":
		if c.Roots != nil {
			return fmt.Errorf("%w: CA overrides cannot combine with spki mode", ErrServerIdentity)
		}
		_, e := decodePins(c.PublicKeyPins)
		return e
	default:
		return fmt.Errorf("%w: unknown trust mode", ErrServerIdentity)
	}
	return nil
}
func (c Config) pinnedVerifier() func([]*x509.Certificate) error {
	pins, parseErr := decodePins(c.PublicKeyPins)
	return func(chain []*x509.Certificate) error {
		if parseErr != nil || len(chain) == 0 {
			return ErrServerIdentity
		}
		leaf := chain[0]
		sum := sha256.Sum256(leaf.RawSubjectPublicKeyInfo)
		match := 0
		for _, pin := range pins {
			match |= subtle.ConstantTimeCompare(sum[:], pin[:])
		}
		if match != 1 {
			return fmt.Errorf("%w: SPKI pin mismatch", ErrServerIdentity)
		}
		now := time.Now()
		if now.Before(leaf.NotBefore) || now.After(leaf.NotAfter) {
			return fmt.Errorf("%w: certificate time invalid", ErrServerIdentity)
		}
		if err := leaf.VerifyHostname(c.ServerName); err != nil {
			return fmt.Errorf("%w: certificate name mismatch", ErrServerIdentity)
		}
		if len(leaf.ExtKeyUsage) > 0 {
			valid := false
			for _, usage := range leaf.ExtKeyUsage {
				if usage == x509.ExtKeyUsageServerAuth || usage == x509.ExtKeyUsageAny {
					valid = true
				}
			}
			if !valid {
				return fmt.Errorf("%w: server authentication not permitted", ErrServerIdentity)
			}
		}
		return nil
	}
}
func (c Config) quicTLS() *qtls.Config {
	tc := &qtls.Config{ServerName: c.ServerName, RootCAs: c.Roots, MinVersion: qtls.VersionTLS13, NextProtos: []string{ALPN}}
	if c.TrustMode == "spki" {
		verify := c.pinnedVerifier()
		// CA verification is replaced by explicit pin, hostname, time and EKU checks.
		// No insecure option, TOFU, or network-triggered trust fallback is provided.
		tc.InsecureSkipVerify = true
		tc.VerifyConnection = func(cs qtls.ConnectionState) error { return verify(cs.PeerCertificates) }
	}
	return tc
}
func (c Config) httpTLS() *tls.Config {
	tc := &tls.Config{ServerName: c.ServerName, RootCAs: c.Roots, MinVersion: tls.VersionTLS13, NextProtos: []string{"h2"}}
	if c.TrustMode == "spki" {
		verify := c.pinnedVerifier()
		tc.InsecureSkipVerify = true
		tc.VerifyConnection = func(cs tls.ConnectionState) error { return verify(cs.PeerCertificates) }
	}
	return tc
}
