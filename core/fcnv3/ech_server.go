package fcnv3

import (
	"bytes"
	"crypto/x509"
	"errors"
	"fmt"
	"net"
	"strings"

	"github.com/fastcat920/fcnv3/internal/echparser"
	"github.com/metacubex/hpke"
	"github.com/metacubex/tls"
)

const (
	maxECHKeys        = 8
	maxECHConfigBytes = 65535
)

// ReplaceECHKeys publishes a validated key set for new handshakes. It requires
// ECH to have been enabled at startup. Existing connections keep their state.
func (s *Server) ReplaceECHKeys(keys []tls.EncryptedClientHelloKey) error {
	if s.echKeys.Load() == nil {
		return errors.New("FCN v3 ECH was not enabled at startup")
	}
	next, err := prepareECHKeys(keys, s.tls)
	if err != nil {
		return err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.ctx.Err() != nil {
		return net.ErrClosed
	}
	s.echKeys.Store(&next)
	return nil
}

func prepareECHKeys(keys []tls.EncryptedClientHelloKey, tc *tls.Config) ([]tls.EncryptedClientHelloKey, error) {
	if len(keys) == 0 || len(keys) > maxECHKeys {
		return nil, fmt.Errorf("FCN v3 requires 1–%d ECH keys", maxECHKeys)
	}
	next := make([]tls.EncryptedClientHelloKey, 0, len(keys))
	seen := make(map[string]struct{}, len(keys))
	configBytes := 0
	for i, key := range keys {
		configBytes += len(key.Config)
		if configBytes > maxECHConfigBytes {
			return nil, errors.New("FCN v3 ECH config list is too large")
		}
		publicName, err := validateECHKey(key)
		if err != nil {
			return nil, fmt.Errorf("FCN v3 ECH key %d: %w", i+1, err)
		}
		if _, duplicate := seen[string(key.Config)]; duplicate {
			return nil, errors.New("duplicate FCN v3 ECH config")
		}
		seen[string(key.Config)] = struct{}{}
		if tc.GetCertificate == nil && !coversECHPublicName(tc.Certificates, publicName) {
			return nil, fmt.Errorf("no FCN v3 TLS certificate covers ECH public name %q", publicName)
		}
		next = append(next, tls.EncryptedClientHelloKey{
			Config: bytes.Clone(key.Config), PrivateKey: bytes.Clone(key.PrivateKey), SendAsRetry: key.SendAsRetry,
		})
	}
	return next, nil
}

func validateECHKey(key tls.EncryptedClientHelloKey) (string, error) {
	skip, config, err := echparser.ParseECHConfig(key.Config)
	if err != nil || skip {
		return "", errors.New("unsupported or malformed ECH config")
	}
	// The shared parser also accepts a config prefix from a list. Check that
	// every byte of this standalone config was consumed.
	length := 1 + 2 + 2 + len(config.PublicKey) + 2 + 4*len(config.SymmetricCipherSuite) + 1 + 1 + len(config.PublicName) + 2
	for _, extension := range config.Extensions {
		if extension.Type&0x8000 != 0 {
			return "", errors.New("unsupported mandatory ECH extension")
		}
		length += 4 + len(extension.Data)
	}
	if int(config.Length) != length || len(key.Config) != length+4 {
		return "", errors.New("invalid ECH config length")
	}
	publicName := string(config.PublicName)
	if _, err := authority(net.JoinHostPort(publicName, "1"), false); err != nil || !strings.Contains(publicName, ".") || net.ParseIP(publicName) != nil {
		return "", errors.New("invalid ECH public name")
	}
	kem, err := hpke.NewKEM(config.KemID)
	if err != nil {
		return "", errors.New("unsupported ECH key algorithm")
	}
	privateKey, err := kem.NewPrivateKey(key.PrivateKey)
	if err != nil || !bytes.Equal(privateKey.PublicKey().Bytes(), config.PublicKey) {
		return "", errors.New("ECH private key does not match the config")
	}
	usableCipher := false
	for _, cipher := range config.SymmetricCipherSuite {
		if cipher.AEADID == 0xffff {
			return "", errors.New("export-only HPKE is not an ECH cipher suite")
		}
		_, kdfErr := hpke.NewKDF(cipher.KDFID)
		_, aeadErr := hpke.NewAEAD(cipher.AEADID)
		usableCipher = usableCipher || kdfErr == nil && aeadErr == nil
	}
	if !usableCipher {
		return "", errors.New("no supported ECH cipher suite")
	}
	return publicName, nil
}

func coversECHPublicName(certificates []tls.Certificate, name string) bool {
	for _, pair := range certificates {
		leaf := pair.Leaf
		if leaf == nil && len(pair.Certificate) > 0 {
			leaf, _ = x509.ParseCertificate(pair.Certificate[0])
		}
		if leaf != nil && leaf.VerifyHostname(name) == nil {
			return true
		}
	}
	return false
}
