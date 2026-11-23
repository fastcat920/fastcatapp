// Package fcn implements the FCN tunnel using standard TLS and QUIC cryptography.
package fcn

import (
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/binary"
	"errors"
	"io"
	"net"
	"strconv"
	"strings"
)

const ALPN = "fcn/1"
const exporterLabel = "EXPORTER-FCN-1"
const maxHeader = 512
const maxRequests = 4096

var ErrAuth = errors.New("entry authorization rejected")
var ErrTarget = errors.New("target connection failed")
var ErrProtocol = errors.New("invalid FCN message")

type openHeader struct {
	Account, Target string
	Kind            byte
	Nonce           [16]byte
	raw             []byte
}

func validTarget(s string) bool {
	h, p, e := net.SplitHostPort(s)
	n, pe := strconv.ParseUint(p, 10, 16)
	return e == nil && pe == nil && n > 0 && h != "" && len(s) <= 255 && !strings.ContainsAny(h, " \r\n\t/%@?#\\")
}

// Header is length-prefixed and authenticated together with the TLS exporter.
// The credential itself never crosses the connection. Nonces are per-connection.
func encodeHeader(account, target string, kind byte, key, binding []byte) ([]byte, error) {
	if len(account) < 1 || len(account) > 64 || !validTarget(target) || kind > 2 || len(key) < 32 || len(binding) != 32 {
		return nil, ErrProtocol
	}
	b := make([]byte, 0, maxHeader)
	b = append(b, 1, kind, byte(len(account)))
	b = append(b, account...)
	b = binary.BigEndian.AppendUint16(b, uint16(len(target)))
	b = append(b, target...)
	nonce := make([]byte, 16)
	if _, e := rand.Read(nonce); e != nil {
		return nil, e
	}
	b = append(b, nonce...)
	m := hmac.New(sha256.New, key)
	m.Write([]byte(exporterLabel))
	m.Write(binding)
	m.Write(b)
	b = append(b, m.Sum(nil)...)
	return append(binary.BigEndian.AppendUint16(nil, uint16(len(b))), b...), nil
}
func readHeader(r io.Reader) (openHeader, error) {
	var h openHeader
	var n [2]byte
	if _, e := io.ReadFull(r, n[:]); e != nil {
		return h, e
	}
	size := int(binary.BigEndian.Uint16(n[:]))
	if size < 55 || size > maxHeader {
		return h, ErrProtocol
	}
	b := make([]byte, size)
	if _, e := io.ReadFull(r, b); e != nil {
		return h, e
	}
	a := int(b[2])
	if b[0] != 1 || b[1] > 2 || a < 1 || a > 64 || 3+a+2+16+32 > len(b) {
		return h, ErrProtocol
	}
	t := int(binary.BigEndian.Uint16(b[3+a:]))
	off := 5 + a
	if off+t+16+32 != len(b) {
		return h, ErrProtocol
	}
	h.Account = string(b[3 : 3+a])
	h.Target = string(b[off : off+t])
	h.Kind = b[1]
	copy(h.Nonce[:], b[off+t:])
	h.raw = b
	if !validTarget(h.Target) {
		return h, ErrProtocol
	}
	return h, nil
}
func verifyHeader(h openHeader, key, binding []byte) bool {
	if len(key) < 32 || len(binding) != 32 || len(h.raw) < 32 {
		return false
	}
	m := hmac.New(sha256.New, key)
	m.Write([]byte(exporterLabel))
	m.Write(binding)
	m.Write(h.raw[:len(h.raw)-32])
	return hmac.Equal(m.Sum(nil), h.raw[len(h.raw)-32:])
}
