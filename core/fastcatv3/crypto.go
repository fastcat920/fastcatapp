// Package fastcatv3 implements the experimental FastCat v3 standard carrier.
package fastcatv3

import (
	"bytes"
	"crypto/cipher"
	"crypto/ecdh"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/binary"
	"errors"
	"fmt"
	"io"
	"sync"
	"sync/atomic"
	"time"

	"golang.org/x/crypto/chacha20poly1305"
)

var errProtocol = errors.New("fastcat-v3 protocol violation")

func hash(b []byte) []byte { h := sha256.Sum256(b); return h[:] }
func extract(salt, ikm []byte) []byte {
	m := hmac.New(sha256.New, salt)
	m.Write(ikm)
	return m.Sum(nil)
}
func expand(key []byte, label string, n int) []byte {
	var out, block []byte
	for i := byte(1); len(out) < n; i++ {
		m := hmac.New(sha256.New, key)
		m.Write(block)
		m.Write([]byte(label))
		m.Write([]byte{i})
		block = m.Sum(nil)
		out = append(out, block...)
	}
	return out[:n]
}
func public(key []byte) ([]byte, error) {
	p, e := ecdh.X25519().NewPrivateKey(key)
	if e != nil {
		return nil, e
	}
	return p.PublicKey().Bytes(), nil
}
func exchange(key, pub []byte) ([]byte, error) {
	p, e := ecdh.X25519().NewPrivateKey(key)
	if e != nil {
		return nil, e
	}
	q, e := ecdh.X25519().NewPublicKey(pub)
	if e != nil {
		return nil, e
	}
	return p.ECDH(q)
}
func random(n int) []byte {
	b := make([]byte, n)
	if _, e := rand.Read(b); e != nil {
		panic(e)
	}
	return b
}
func writeAll(w io.Writer, b []byte) error {
	for len(b) > 0 {
		n, e := w.Write(b)
		if e != nil {
			return e
		}
		if n == 0 {
			return io.ErrShortWrite
		}
		b = b[n:]
	}
	return nil
}

type noise struct {
	h, ck, key []byte
	nonce      uint64
}

func newNoise(prologue, responder []byte) *noise {
	name := []byte("Noise_IK_25519_ChaChaPoly_SHA256")
	h := make([]byte, 32)
	if len(name) > 32 {
		h = hash(name)
	} else {
		copy(h, name)
	}
	s := &noise{h: h, ck: append([]byte(nil), h...)}
	s.mixHash(prologue)
	s.mixHash(responder)
	return s
}
func (s *noise) mixHash(b []byte) { s.h = hash(append(append([]byte(nil), s.h...), b...)) }
func (s *noise) mixKey(b []byte) {
	material := expand(extract(s.ck, b), "", 64)
	s.ck, s.key, s.nonce = material[:32], material[32:], 0
}
func (s *noise) dh(key, pub []byte) error {
	b, e := exchange(key, pub)
	if e == nil {
		s.mixKey(b)
	}
	return e
}
func (s *noise) crypt(b []byte, decrypt bool) ([]byte, error) {
	a, e := chacha20poly1305.New(s.key)
	if e != nil {
		return nil, e
	}
	nonce := make([]byte, 12)
	binary.LittleEndian.PutUint64(nonce[4:], s.nonce)
	var out []byte
	if decrypt {
		out, e = a.Open(nil, nonce, b, s.h)
	} else {
		out = a.Seal(nil, nonce, b, s.h)
	}
	if e != nil {
		return nil, e
	}
	s.nonce++
	if decrypt {
		s.mixHash(b)
	} else {
		s.mixHash(out)
	}
	return out, nil
}
func (s *noise) split() ([]byte, []byte) {
	b := expand(extract(s.ck, nil), "", 64)
	return b[:32], b[32:]
}
func (s *noise) clientInit(si, ei, rs, payload []byte) ([]byte, error) {
	ep, e := public(ei)
	if e != nil {
		return nil, e
	}
	s.mixHash(ep)
	if e = s.dh(ei, rs); e != nil {
		return nil, e
	}
	sp, e := public(si)
	if e != nil {
		return nil, e
	}
	enc, e := s.crypt(sp, false)
	if e != nil {
		return nil, e
	}
	if e = s.dh(si, rs); e != nil {
		return nil, e
	}
	body, e := s.crypt(payload, false)
	return append(append(ep, enc...), body...), e
}
func (s *noise) readInit(sr, message []byte) (ep, sp, payload []byte, err error) {
	if len(message) < 96 {
		return nil, nil, nil, errProtocol
	}
	ep = message[:32]
	s.mixHash(ep)
	if err = s.dh(sr, ep); err != nil {
		return
	}
	sp, err = s.crypt(message[32:80], true)
	if err != nil {
		return
	}
	if err = s.dh(sr, sp); err != nil {
		return
	}
	payload, err = s.crypt(message[80:], true)
	return
}
func (s *noise) accept(er, ep, sp, payload []byte) ([]byte, error) {
	erp, e := public(er)
	if e != nil {
		return nil, e
	}
	s.mixHash(erp)
	if e = s.dh(er, ep); e != nil {
		return nil, e
	}
	if e = s.dh(er, sp); e != nil {
		return nil, e
	}
	b, e := s.crypt(payload, false)
	return append(erp, b...), e
}
func (s *noise) readAccept(ei, si, message []byte) ([]byte, error) {
	if len(message) < 48 {
		return nil, errProtocol
	}
	p := message[:32]
	s.mixHash(p)
	if e := s.dh(ei, p); e != nil {
		return nil, e
	}
	if e := s.dh(si, p); e != nil {
		return nil, e
	}
	return s.crypt(message[32:], true)
}

// Record numbers and epochs are independent in each direction.
type recordCipher struct {
	secret, ctx, iv []byte
	aead            cipher.AEAD
	direction       byte
	epoch           uint32
	number, bytes   uint64
}

func newRecord(seed, ctx []byte, direction byte) *recordCipher {
	r := &recordCipher{secret: extract(ctx, seed), ctx: append([]byte(nil), ctx...), direction: direction}
	r.keys()
	return r
}
func (r *recordCipher) keys() {
	r.aead, _ = chacha20poly1305.New(expand(r.secret, "FCV3 key", 32))
	r.iv = expand(r.secret, "FCV3 iv", 12)
	r.number, r.bytes = 0, 0
}
func (r *recordCipher) update() error {
	if r.epoch == ^uint32(0) {
		return errProtocol
	}
	r.secret = expand(r.secret, "FCV3 update", 32)
	r.epoch++
	r.keys()
	return nil
}
func (r *recordCipher) nonceAAD(n int) ([]byte, []byte) {
	nonce := append([]byte(nil), r.iv...)
	for i := 0; i < 8; i++ {
		nonce[11-i] ^= byte(r.number >> uint(8*i))
	}
	aad := append(append([]byte(nil), r.ctx...), r.direction)
	aad = binary.BigEndian.AppendUint32(aad, r.epoch)
	aad = binary.BigEndian.AppendUint64(aad, r.number)
	aad = binary.BigEndian.AppendUint16(aad, uint16(n))
	return nonce, aad
}
func (r *recordCipher) seal(plain []byte) ([]byte, error) {
	n := len(plain) + 16
	if n < 30 || n > 16384 || r.number >= 1<<24 || r.bytes+uint64(len(plain)) > 1<<30 {
		return nil, errProtocol
	}
	nonce, aad := r.nonceAAD(n)
	out := binary.BigEndian.AppendUint16(nil, uint16(n))
	out = r.aead.Seal(out, nonce, plain, aad)
	r.number++
	r.bytes += uint64(len(plain))
	return out, nil
}
func (r *recordCipher) read(reader io.Reader) ([]byte, error) {
	var h [2]byte
	if _, e := io.ReadFull(reader, h[:]); e != nil {
		return nil, e
	}
	n := int(binary.BigEndian.Uint16(h[:]))
	if n < 30 || n > 16384 || r.number >= 1<<24 {
		return nil, errProtocol
	}
	b := make([]byte, n)
	if _, e := io.ReadFull(reader, b); e != nil {
		return nil, e
	}
	nonce, aad := r.nonceAAD(n)
	plain, e := r.aead.Open(nil, nonce, b, aad)
	if e != nil {
		return nil, fmt.Errorf("record authentication failed: %w", e)
	}
	if r.bytes+uint64(len(plain)) > 1<<30 {
		return nil, errProtocol
	}
	r.number++
	r.bytes += uint64(len(plain))
	return plain, nil
}

type frame struct {
	kind byte
	id   uint64
	body []byte
}

func (f frame) encode() []byte { return f.appendTo(nil) }
func (f frame) appendTo(b []byte) []byte {
	b = append(b, f.kind, 0)
	b = binary.BigEndian.AppendUint64(b, f.id)
	b = binary.BigEndian.AppendUint32(b, uint32(len(f.body)))
	return append(b, f.body...)
}
func parseFrames(b []byte) ([]frame, error) {
	var out []frame
	for len(b) > 0 {
		if len(b) < 14 || b[1] != 0 {
			return nil, errProtocol
		}
		n := uint64(binary.BigEndian.Uint32(b[10:14]))
		if n > uint64(len(b)-14) {
			return nil, errProtocol
		}
		f := frame{b[0], binary.BigEndian.Uint64(b[2:10]), append([]byte(nil), b[14:14+int(n)]...)}
		if f.kind < 1 || f.kind > 15 {
			return nil, errProtocol
		}
		out = append(out, f)
		b = b[14+int(n):]
	}
	return out, nil
}

type recordWriteTiming struct {
	Start                                    time.Time
	Encode, Lock, Rotate, Seal, Write, Total time.Duration
	Frames, Kind, Bytes                      int
	Stream                                   uint64
	OK                                       bool
}

var traceSessions atomic.Uint64

type records struct {
	handshakeID   []byte
	trace         func(recordWriteTiming)
	closed        bool
	r             io.Reader
	w             io.Writer
	send, receive *recordCipher
	mu            sync.Mutex
}

func (r *records) setTrace(trace func(string), carrier byte, role string) {
	if trace == nil {
		return
	}
	session := traceSessions.Add(1)
	r.trace = func(t recordWriteTiming) {
		trace(fmt.Sprintf("record_send role=%s carrier=h%d session=%d stream=%d kind=%d frames=%d bytes=%d start_unix_us=%d encode_us=%d lock_us=%d rotate_us=%d seal_us=%d write_us=%d total_us=%d ok=%t", role, carrier+1, session, t.Stream, t.Kind, t.Frames, t.Bytes, t.Start.UnixMicro(), t.Encode.Microseconds(), t.Lock.Microseconds(), t.Rotate.Microseconds(), t.Seal.Microseconds(), t.Write.Microseconds(), t.Total.Microseconds(), t.OK))
	}
}

func (r *records) write(f frame) error { return r.writeFrames(f) }

// Combine related control frames into one record without delaying their delivery.
// The record limit and key-update boundary apply to the complete plaintext.
func (r *records) writeFrames(frames ...frame) error {
	if len(frames) == 0 {
		return errProtocol
	}
	var timing recordWriteTiming
	if r.trace != nil {
		timing.Start = time.Now()
		timing.Frames, timing.Kind, timing.Stream = len(frames), int(frames[0].kind), frames[0].id
		// Registered before unlocking: callbacks run outside the record mutex and
		// their logging time is excluded from all measured stages.
		defer func() { timing.Total = time.Since(timing.Start); r.trace(timing) }()
	}
	total := 0
	for _, f := range frames {
		if len(f.body) > 16354 || total+14+len(f.body) > 16368 || (f.kind == 11 && len(frames) != 1) {
			return errProtocol
		}
		total += 14 + len(f.body)
	}
	plain := make([]byte, 0, total)
	for _, f := range frames {
		plain = f.appendTo(plain)
	}
	var stage time.Time
	if r.trace != nil {
		timing.Encode = time.Since(timing.Start)
		stage = time.Now()
	}
	r.mu.Lock()
	if r.trace != nil {
		timing.Lock = time.Since(stage)
	}
	defer r.mu.Unlock()
	if r.closed {
		return io.ErrClosedPipe
	}
	if r.send.number >= (1<<24)-1 || r.send.bytes+(16384) > 1<<30 {
		if r.trace != nil {
			stage = time.Now()
		}
		e := r.rotate()
		if r.trace != nil {
			timing.Rotate = time.Since(stage)
		}
		if e != nil {
			return e
		}
	}
	if r.trace != nil {
		stage = time.Now()
	}
	wire, e := r.send.seal(plain)
	if r.trace != nil {
		timing.Seal = time.Since(stage)
	}
	if e != nil {
		return e
	}
	if r.trace != nil {
		timing.Bytes = len(wire)
		stage = time.Now()
	}
	e = writeAll(r.w, wire)
	if r.trace != nil {
		timing.Write = time.Since(stage)
		timing.OK = e == nil
	}
	return e
}
func (r *records) rotate() error {
	if r.send.epoch == ^uint32(0) {
		return errProtocol
	}
	body := binary.BigEndian.AppendUint32(nil, r.send.epoch+1)
	wire, e := r.send.seal((frame{11, 0, body}).encode())
	if e != nil {
		return e
	}
	if e = writeAll(r.w, wire); e != nil {
		return e
	}
	return r.send.update()
}
func (r *records) update() error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if r.closed {
		return io.ErrClosedPipe
	}
	return r.rotate()
}
func (r *records) close() { r.mu.Lock(); r.closed = true; r.mu.Unlock() }
func (r *records) read() ([]frame, error) {
	b, e := r.receive.read(r.r)
	if e != nil {
		return nil, e
	}
	frames, e := parseFrames(b)
	if e != nil {
		return nil, e
	}
	for _, f := range frames {
		if f.kind == 11 {
			if len(frames) != 1 || f.id != 0 || len(f.body) != 4 || r.receive.epoch == ^uint32(0) || binary.BigEndian.Uint32(f.body) != r.receive.epoch+1 {
				return nil, errProtocol
			}
			return nil, r.receive.update()
		}
	}
	return frames, nil
}
func contextHash(prologue, h, binding []byte) []byte {
	return hash(bytes.Join([][]byte{prologue, h, binding}, nil))
}
