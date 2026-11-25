// Package fcnv3 implements the experimental FCN v3 HTTP/3 CONNECT protocol.
package fcnv3

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/binary"
	"encoding/hex"
	"errors"
	"net"
	"net/netip"
	"strconv"
	"strings"
	"time"

	"github.com/metacubex/quic-go"
)

const (
	authHeader      = "Proxy-Authorization"
	authPrefix      = "FCN3 "
	exporterLabel   = "EXPORTER-FCN-v3-CONNECT"
	setupTimeout    = 8 * time.Second
	earlyWriteLimit = 8 * 1024
	cancelCode      = quic.StreamErrorCode(0x10c) // H3_REQUEST_CANCELLED
)

var ErrRejected = errors.New("FCN v3 CONNECT rejected")

// CredentialFromUUID derives a version-specific proof key and a separate
// on-wire account identifier from an account subscription UUID.
func CredentialFromUUID(uuid string) (Credential, error) {
	uuid = strings.ToLower(uuid)
	if len(uuid) != 36 || uuid[8] != '-' || uuid[13] != '-' || uuid[18] != '-' || uuid[23] != '-' {
		return Credential{}, errors.New("invalid FCN v3 subscription UUID")
	}
	var raw [16]byte
	n, err := hex.Decode(raw[:], []byte(strings.ReplaceAll(uuid, "-", "")))
	if err != nil || n != len(raw) || raw == ([16]byte{}) {
		return Credential{}, errors.New("invalid FCN v3 subscription UUID")
	}
	id := sha256.Sum256([]byte("fastcat:fcn:v3:account-id:v1\x00" + uuid))
	key := sha256.Sum256([]byte("fastcat:fcn:v3:proof-key:v1\x00" + uuid))
	return Credential{ID: hex.EncodeToString(id[:16]), Secret: hex.EncodeToString(key[:])}, nil
}

func credentialKey(id, secret string) ([32]byte, error) {
	var k [32]byte
	if len(id) < 1 || len(id) > 48 || len(secret) != 64 {
		return k, errors.New("invalid FCN v3 credential")
	}
	for _, c := range id {
		if !(c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c >= '0' && c <= '9' || c == '_' || c == '-') {
			return k, errors.New("invalid FCN v3 account")
		}
	}
	if _, err := hex.Decode(k[:], []byte(secret)); err != nil {
		return k, errors.New("invalid FCN v3 secret encoding")
	}
	return k, nil
}

func authority(s string, numeric bool) (string, error) {
	invalid := errors.New("invalid FCN v3 authority")
	if len(s) > 255 {
		return "", invalid
	}
	host, port, err := net.SplitHostPort(s)
	if err != nil || host == "" {
		return "", invalid
	}
	for _, c := range port {
		if c < '0' || c > '9' {
			return "", invalid
		}
	}
	n, err := strconv.ParseUint(port, 10, 16)
	if err != nil || n == 0 {
		return "", invalid
	}
	if ip, err := netip.ParseAddr(host); err == nil && ip.Zone() == "" {
		return net.JoinHostPort(ip.Unmap().String(), strconv.Itoa(int(n))), nil
	}
	if numeric {
		return "", invalid
	}
	for _, label := range strings.Split(host, ".") {
		if len(label) == 0 || len(label) > 63 || label[0] == '-' || label[len(label)-1] == '-' {
			return "", invalid
		}
		for _, c := range label {
			if !(c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c >= '0' && c <= '9' || c == '-') {
				return "", invalid
			}
		}
	}
	return net.JoinHostPort(strings.ToLower(host), strconv.Itoa(int(n))), nil
}

func connectionBinding(c *quic.Conn) ([]byte, error) {
	state := c.ConnectionState()
	if state.Used0RTT || !state.TLS.HandshakeComplete || state.TLS.NegotiatedProtocol != "h3" {
		return nil, errors.New("FCN v3 requires a completed HTTP/3 handshake")
	}
	return state.TLS.ExportKeyingMaterial(exporterLabel, nil, 32)
}

func proof(key [32]byte, binding []byte, id, target string, stream quic.StreamID) []byte {
	return proofFor("CONNECT", key, binding, id, target, stream)
}

func proofFor(kind string, key [32]byte, binding []byte, id, target string, stream quic.StreamID) []byte {
	m := hmac.New(sha256.New, key[:])
	m.Write([]byte("FCN3\x00" + kind + "\x00"))
	m.Write(binding)
	var streamBytes [8]byte
	binary.BigEndian.PutUint64(streamBytes[:], uint64(stream))
	m.Write(streamBytes[:])
	m.Write([]byte{byte(len(id))})
	m.Write([]byte(id))
	m.Write([]byte{byte(len(target))})
	m.Write([]byte(target))
	return m.Sum(nil)
}

func authValue(key [32]byte, binding []byte, id, target string, stream quic.StreamID) string {
	return authValueFor("CONNECT", key, binding, id, target, stream)
}

func authValueFor(kind string, key [32]byte, binding []byte, id, target string, stream quic.StreamID) string {
	return authPrefix + id + "." + base64.RawURLEncoding.EncodeToString(proofFor(kind, key, binding, id, target, stream))
}

func verifyValue(value string, binding []byte, target string, stream quic.StreamID, credentials map[string][32]byte) (string, [32]byte, bool) {
	return verifyValueFor("CONNECT", value, binding, target, stream, credentials)
}

func verifyValueFor(kind, value string, binding []byte, target string, stream quic.StreamID, credentials map[string][32]byte) (string, [32]byte, bool) {
	var key [32]byte
	if len(value) > 100 || !strings.HasPrefix(value, authPrefix) {
		return "", key, false
	}
	id, encoded, ok := strings.Cut(strings.TrimPrefix(value, authPrefix), ".")
	if !ok || len(id) > 48 || len(encoded) != 43 {
		return "", key, false
	}
	received, e := base64.RawURLEncoding.Strict().DecodeString(encoded)
	if e != nil {
		return "", key, false
	}
	key, known := credentials[id]
	matched := hmac.Equal(received, proofFor(kind, key, binding, id, target, stream))
	return id, key, known && matched
}
