package fastcatv3

import (
	"bytes"
	"crypto/subtle"
	"encoding/binary"
	"errors"
	"fmt"
	"io"
	"sync"
	"time"
)

const (
	streamCredit     = 262144
	connectionCredit = 4194304
	maxStreams       = 128
	maxDatagram      = 1024
)

type Config struct {
	Trace         func(string) `json:"-"`
	ServiceID     []byte
	ServerPublic  []byte
	ServerPrivate []byte
	Token         []byte
	// AllowPrivate is for isolated testing only. Public deployments resolve and
	// validate all target addresses before opening sockets.
	AllowPrivate bool
}

func (c Config) trace(event string) {
	if c.Trace != nil {
		c.Trace(event)
	}
}

func (c Config) validate(server bool) error {
	if len(c.ServiceID) != 16 || len(c.Token) < 32 || len(c.Token) > 1024 {
		return errors.New("service ID must be 16 bytes and credential 32–1024 bytes")
	}
	if server {
		if len(c.ServerPrivate) != 32 {
			return errors.New("server private key must be 32 bytes")
		}
	} else if len(c.ServerPublic) != 32 {
		return errors.New("server public key must be 32 bytes")
	}
	return nil
}
func params() []byte {
	b := binary.BigEndian.AppendUint32(nil, streamCredit)
	b = binary.BigEndian.AppendUint32(b, connectionCredit)
	b = binary.BigEndian.AppendUint32(b, 30000)
	b = binary.BigEndian.AppendUint16(b, maxStreams)
	b = binary.BigEndian.AppendUint16(b, maxDatagram)
	return binary.BigEndian.AppendUint16(b, 0)
}
func vector16(b []byte) []byte {
	return append(binary.BigEndian.AppendUint16(nil, uint16(len(b))), b...)
}
func readMessage(r io.Reader) ([]byte, error) {
	var h [2]byte
	if _, e := io.ReadFull(r, h[:]); e != nil {
		return nil, e
	}
	n := int(binary.BigEndian.Uint16(h[:]))
	if n < 16 || n > 4096 {
		return nil, errProtocol
	}
	b := make([]byte, n)
	_, e := io.ReadFull(r, b)
	return b, e
}
func writeMessage(w io.Writer, b []byte) error {
	if len(b) > 4096 {
		return errProtocol
	}
	return writeAll(w, vector16(b))
}

// replayCache is shared by all sessions on one prototype server.
type replayCache struct {
	mu      sync.Mutex
	entries map[string]time.Time
}

func (c *replayCache) accept(k string) bool {
	c.mu.Lock()
	defer c.mu.Unlock()
	now := time.Now()
	if c.entries == nil {
		c.entries = make(map[string]time.Time)
	}
	for k, t := range c.entries {
		if now.Sub(t) >= 10*time.Minute {
			delete(c.entries, k)
		}
	}
	if _, ok := c.entries[k]; ok {
		return false
	}
	if len(c.entries) >= 4096 {
		return false
	}
	c.entries[k] = now
	return true
}

func clientHandshake(r io.Reader, w io.Writer, c Config, carrier byte, binding []byte) (*records, error) {
	if e := c.validate(false); e != nil {
		return nil, e
	}
	if len(binding) != 32 {
		return nil, errProtocol
	}
	h, prefix, e := prepareClientHandshake(c, carrier)
	if e != nil {
		return nil, e
	}
	if e = writeAll(w, prefix); e != nil {
		return nil, e
	}
	return h.finish(r, w, c, binding)
}

type pendingClientHandshake struct {
	carrier          byte
	s                *noise
	prologue, si, ei []byte
}

// The first Noise message is independent of the TLS exporter. Send it with
// the HTTP request; bind the authenticated confirmation to TLS after headers.
func prepareClientHandshake(c Config, carrier byte) (*pendingClientHandshake, []byte, error) {
	c.trace("client noise_start")
	attempt := random(16)
	prologue := append([]byte{'F', 'C', 'V', '3', 1, carrier}, c.ServiceID...)
	prologue = append(prologue, attempt...)
	s := newNoise(prologue, c.ServerPublic)
	si, ei := random(32), random(32)
	payload := append([]byte{0}, attempt...)
	payload = append(payload, vector16(c.Token)...)
	payload = append(payload, params()...)
	payload = append(payload, 0, 0)
	msg, e := s.clientInit(si, ei, c.ServerPublic, payload)
	if e != nil {
		return nil, nil, e
	}
	return &pendingClientHandshake{carrier, s, prologue, si, ei}, append(prologue, vector16(msg)...), nil
}

func (h *pendingClientHandshake) finish(r io.Reader, w io.Writer, c Config, binding []byte) (*records, error) {
	if len(binding) != 32 {
		return nil, errProtocol
	}
	s, prologue, si, ei := h.s, h.prologue, h.si, h.ei
	c.trace("client init_sent")
	msg, e := readMessage(r)
	if e != nil {
		return nil, e
	}
	c.trace("client accept_received")
	reply, e := s.readAccept(ei, si, msg)
	if e != nil {
		return nil, fmt.Errorf("server identity authentication: %w", e)
	}
	if len(reply) != 41 {
		return nil, errProtocol
	}
	if reply[0] != 0 {
		return nil, errors.New("account authentication rejected")
	}
	if !bytes.Equal(reply[17:35], params()) || !bytes.Equal(reply[35:], make([]byte, 6)) {
		return nil, errors.New("unsupported negotiated parameters")
	}
	a, b := s.split()
	ctx := contextHash(prologue, s.h, binding)
	out := &records{r: r, w: w, send: newRecord(a, ctx, 0), receive: newRecord(b, ctx, 1), handshakeID: append([]byte(nil), reply[1:17]...)}
	out.setTrace(c.Trace, h.carrier, "client")
	if e = out.write(frame{1, 0, s.h}); e != nil {
		return nil, e
	}
	c.trace("client confirmed")
	return out, nil
}
func serverHandshake(r io.Reader, w io.Writer, c Config, carrier byte, binding []byte, replays *replayCache) (*records, error) {
	return serverHandshakePrepared(r, w, c, carrier, binding, replays, nil)
}

// prepare may publish provisional state before ACCEPT, but only the verified
// CLIENT_CONFIRM below authorizes business traffic. The caller owns cleanup.
func serverHandshakePrepared(r io.Reader, w io.Writer, c Config, carrier byte, binding []byte, replays *replayCache, prepare func(*records) error) (*records, error) {
	if e := c.validate(true); e != nil {
		return nil, e
	}
	var prologue [38]byte
	if _, e := io.ReadFull(r, prologue[:]); e != nil {
		return nil, e
	}
	if !bytes.Equal(prologue[:6], []byte{'F', 'C', 'V', '3', 1, carrier}) || !bytes.Equal(prologue[6:22], c.ServiceID) || len(binding) != 32 {
		return nil, errProtocol
	}
	c.trace("server prologue_received")
	pub, e := public(c.ServerPrivate)
	if e != nil {
		return nil, e
	}
	s := newNoise(prologue[:], pub)
	msg, e := readMessage(r)
	if e != nil {
		return nil, e
	}
	c.trace("server init_received")
	ep, sp, payload, e := s.readInit(c.ServerPrivate, msg)
	if e != nil {
		return nil, e
	}
	if len(payload) < 39 || payload[0] != 0 || !bytes.Equal(payload[1:17], prologue[22:]) {
		return nil, errProtocol
	}
	n := int(binary.BigEndian.Uint16(payload[17:19]))
	if n < 32 || n > 1024 || len(payload) != 39+n || !bytes.Equal(payload[19+n:37+n], params()) || !bytes.Equal(payload[37+n:], []byte{0, 0}) {
		return nil, errProtocol
	}
	result := byte(0)
	if subtle.ConstantTimeCompare(payload[19:19+n], c.Token) != 1 {
		result = 1
	}
	if !replays.accept(string(append(append([]byte(nil), prologue[:]...), sp...))) {
		return nil, errors.New("replayed handshake")
	}
	reply := make([]byte, 41)
	reply[0] = result
	if result == 0 {
		copy(reply[1:17], random(16))
		copy(reply[17:35], params())
	}
	msg, e = s.accept(random(32), ep, sp, reply)
	if e != nil {
		return nil, e
	}
	if result != 0 {
		if e = writeMessage(w, msg); e != nil {
			return nil, e
		}
		return nil, errors.New("account authentication rejected")
	}
	a, b := s.split()
	ctx := contextHash(prologue[:], s.h, binding)
	out := &records{r: r, w: w, send: newRecord(b, ctx, 1), receive: newRecord(a, ctx, 0), handshakeID: append([]byte(nil), reply[1:17]...)}
	out.setTrace(c.Trace, carrier, "server")
	if prepare != nil {
		if e := prepare(out); e != nil {
			return nil, e
		}
	}
	if e = writeMessage(w, msg); e != nil {
		return nil, e
	}
	c.trace("server accept_sent")
	frames, e := out.read()
	if e != nil {
		return nil, e
	}
	if len(frames) != 1 || frames[0].kind != 1 || frames[0].id != 0 || !bytes.Equal(frames[0].body, s.h) {
		return nil, errProtocol
	}
	return out, nil
}
