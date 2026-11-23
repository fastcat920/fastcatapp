package fastcatv3

import (
	"bytes"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/binary"
	"errors"
	"io"
	"net"
	"strconv"
	"sync"
	"time"

	"golang.org/x/crypto/chacha20poly1305"
)

// IndependentMode selects the payload protection for the experimental independent-stream profile.
type IndependentMode byte

const (
	IndependentLight IndependentMode = iota
	IndependentSealed
	// IndependentPipelined pipelines OPEN behind CLIENT_CONFIRM; payload stays light.
	IndependentPipelined
	independentTTL      = 10 * time.Minute
	independentMaxFlows = 4096
	independentAuthPath = "/fc-independent/1/auth"
	independentFlowPath = "/fc-independent/1/flow"
)

func (m IndependentMode) String() string {
	if m == IndependentLight {
		return "light"
	}
	if m == IndependentSealed {
		return "sealed"
	}
	if m == IndependentPipelined {
		return "light-fast"
	}
	return "invalid"
}
func independentConfig(c Config, m IndependentMode) Config {
	id := hash(append(append([]byte("FastCat independent/v1/"), byte(m)), c.ServiceID...))
	c.ServiceID = append([]byte(nil), id[:16]...)
	return c
}
func independentRoot(r *records, server bool) []byte {
	a, b := r.send.secret, r.receive.secret
	if server {
		a, b = b, a
	}
	material := append(append([]byte(nil), a...), b...)
	return expand(extract(r.send.ctx, material), "FastCat independent/v1/session", 32)
}
func flowMagic(mode IndependentMode) string {
	if mode == IndependentPipelined {
		return "FCI2"
	}
	return "FCI1"
}
func flowTagSize(mode IndependentMode) int {
	if mode == IndependentPipelined {
		return 16
	}
	return 32
}
func validateFlowTarget(target string) error {
	host, port, err := net.SplitHostPort(target)
	if err != nil || host == "" {
		return errProtocol
	}
	number, err := strconv.ParseUint(port, 10, 16)
	if err != nil || number == 0 {
		return errProtocol
	}
	return nil
}
func decryptFastTarget(root, prefix, binding []byte) (string, error) {
	if len(root) != 32 || len(binding) != 32 || len(prefix) < 48 {
		return "", errProtocol
	}
	cipher, err := chacha20poly1305.New(expand(root, "FastCat independent/v1/fast-open", 32))
	if err != nil {
		return "", err
	}
	var nonce [12]byte
	binary.BigEndian.PutUint64(nonce[4:], binary.BigEndian.Uint64(prefix[20:28]))
	aad := append(append([]byte(nil), prefix[:31]...), binding...)
	plain, err := cipher.Open(nil, nonce[:], prefix[31:], aad)
	if err != nil {
		return "", err
	}
	if len(plain) != int(binary.BigEndian.Uint16(prefix[29:31])) {
		return "", errProtocol
	}
	target := string(plain)
	return target, validateFlowTarget(target)
}
func fastOpenStatus(root, prefix, binding, status []byte) []byte {
	mac := hmac.New(sha256.New, expand(root, "FastCat independent/v1/fast-ack", 32))
	mac.Write([]byte("FastCat independent/v1/OPEN_RESULT"))
	mac.Write(prefix)
	mac.Write(binding)
	mac.Write(status)
	return append(append([]byte(nil), status...), mac.Sum(nil)...)
}
func validateFastOpenStatus(root, prefix, binding, status []byte) bool {
	return len(status) == 34 && hmac.Equal(status, fastOpenStatus(root, prefix, binding, status[:2]))
}
func flowPrefix(root, sid, binding []byte, counter uint64, mode IndependentMode, target string) ([]byte, error) {
	if len(root) != 32 || len(sid) != 16 || len(binding) != 32 || counter == 0 || counter > independentMaxFlows || mode > IndependentPipelined || len(target) == 0 || len(target) > 512 {
		return nil, errProtocol
	}
	if err := validateFlowTarget(target); err != nil {
		return nil, err
	}
	p := append([]byte(flowMagic(mode)), sid...)
	p = binary.BigEndian.AppendUint64(p, counter)
	p = append(p, byte(mode))
	p = binary.BigEndian.AppendUint16(p, uint16(len(target)))
	if mode == IndependentPipelined {
		cipher, err := chacha20poly1305.New(expand(root, "FastCat independent/v1/fast-open", 32))
		if err != nil {
			return nil, err
		}
		var nonce [12]byte
		binary.BigEndian.PutUint64(nonce[4:], counter)
		aad := append(append([]byte(nil), p...), binding...)
		return cipher.Seal(p, nonce[:], []byte(target), aad), nil
	}
	p = append(p, []byte(target)...)
	mac := hmac.New(sha256.New, root)
	mac.Write([]byte("FastCat independent/v1/flow"))
	mac.Write(p)
	mac.Write(binding)
	return append(p, mac.Sum(nil)...), nil
}
func readFlowPrefix(r io.Reader) ([]byte, error) {
	p := make([]byte, 31)
	if _, err := io.ReadFull(r, p); err != nil {
		return nil, err
	}
	mode := IndependentMode(p[28])
	if mode > IndependentPipelined || !bytes.Equal(p[:4], []byte(flowMagic(mode))) {
		return nil, errProtocol
	}
	n := int(binary.BigEndian.Uint16(p[29:31]))
	if n < 1 || n > 512 {
		return nil, errProtocol
	}
	rest := make([]byte, n+flowTagSize(mode))
	if _, err := io.ReadFull(r, rest); err != nil {
		return nil, err
	}
	return append(p, rest...), nil
}
func flowRecords(reader io.Reader, writer io.Writer, root, prefix, binding []byte, server bool) *records {
	context := hash(append(append([]byte("FastCat independent/v1/stream"), prefix[:len(prefix)-32]...), binding...))
	material := expand(extract(context, root), "FastCat independent/v1/traffic", 64)
	a, b := material[:32], material[32:]
	if server {
		return &records{r: reader, w: writer, send: newRecord(b, context, 1), receive: newRecord(a, context, 0)}
	}
	return &records{r: reader, w: writer, send: newRecord(a, context, 0), receive: newRecord(b, context, 1)}
}

// independentPayload preserves authenticated half-close in sealed mode. HTTP/QUIC
// supply transport flow control; there is no shared v3 record lock or credit queue.
type independentPayload struct {
	reader                              io.Reader
	writer                              io.Writer
	records                             *records
	id                                  uint64
	readMu, writeMu                     sync.Mutex
	buffer                              []byte
	lightReadHeader                     [11]byte
	lightReadStorage, lightWriteStorage []byte
	readOffset, writeOffset             uint64
	readFIN, writeFIN                   bool
}

func (p *independentPayload) Read(b []byte) (int, error) {
	if len(b) == 0 {
		return 0, nil
	}
	p.readMu.Lock()
	defer p.readMu.Unlock()
	if p.records == nil {
		if p.readFIN {
			return 0, io.EOF
		}
		if len(p.buffer) == 0 {
			h := p.lightReadHeader[:]
			if _, err := io.ReadFull(p.reader, h); err != nil {
				if errors.Is(err, io.EOF) {
					err = io.ErrUnexpectedEOF
				}
				return 0, err
			}
			n := int(binary.BigEndian.Uint16(h[1:3]))
			if binary.BigEndian.Uint64(h[3:]) != p.readOffset || n > 16346 {
				return 0, errProtocol
			}
			if h[0] == 7 && n == 0 {
				p.readFIN = true
				return 0, io.EOF
			}
			if h[0] != 4 || n == 0 {
				return 0, errProtocol
			}
			if cap(p.lightReadStorage) < n {
				p.lightReadStorage = make([]byte, n)
			}
			p.buffer = p.lightReadStorage[:n]
			if _, err := io.ReadFull(p.reader, p.buffer); err != nil {
				return 0, err
			}
			p.readOffset += uint64(n)
		}
		n := copy(b, p.buffer)
		p.buffer = p.buffer[n:]
		return n, nil
	}
	if p.readFIN {
		return 0, io.EOF
	}
	for len(p.buffer) == 0 {
		frames, err := p.records.read()
		if err != nil {
			if errors.Is(err, io.EOF) {
				err = io.ErrUnexpectedEOF
			}
			return 0, err
		}
		if len(frames) == 0 {
			continue
		}
		if len(frames) != 1 {
			return 0, errProtocol
		}
		f := frames[0]
		if f.id != p.id || len(f.body) < 8 || binary.BigEndian.Uint64(f.body) != p.readOffset {
			return 0, errProtocol
		}
		switch f.kind {
		case 4:
			if len(f.body) == 8 {
				return 0, errProtocol
			}
			p.buffer = f.body[8:]
			p.readOffset += uint64(len(p.buffer))
		case 7:
			if len(f.body) != 8 {
				return 0, errProtocol
			}
			p.readFIN = true
			return 0, io.EOF
		default:
			return 0, errProtocol
		}
	}
	n := copy(b, p.buffer)
	p.buffer = p.buffer[n:]
	return n, nil
}
func (p *independentPayload) Write(b []byte) (int, error) {
	p.writeMu.Lock()
	defer p.writeMu.Unlock()
	if p.writeFIN {
		return 0, io.ErrClosedPipe
	}
	if p.records == nil {
		total := 0
		for len(b) > 0 {
			n := len(b)
			if n > 16346 {
				n = 16346
			}
			if cap(p.lightWriteStorage) < 11+n {
				p.lightWriteStorage = make([]byte, 11+n)
			}
			wire := p.lightWriteStorage[:11+n]
			wire[0] = 4
			binary.BigEndian.PutUint16(wire[1:3], uint16(n))
			binary.BigEndian.PutUint64(wire[3:11], p.writeOffset)
			copy(wire[11:], b[:n])
			if err := writeAll(p.writer, wire); err != nil {
				return total, err
			}
			p.writeOffset += uint64(n)
			total += n
			b = b[n:]
		}
		return total, nil
	}
	total := 0
	for len(b) > 0 {
		n := len(b)
		if n > 16346 {
			n = 16346
		}
		body := binary.BigEndian.AppendUint64(nil, p.writeOffset)
		body = append(body, b[:n]...)
		if err := p.records.write(frame{4, p.id, body}); err != nil {
			return total, err
		}
		p.writeOffset += uint64(n)
		total += n
		b = b[n:]
	}
	return total, nil
}
func (p *independentPayload) CloseWrite() error {
	p.writeMu.Lock()
	defer p.writeMu.Unlock()
	if p.writeFIN {
		return nil
	}
	p.writeFIN = true
	if p.records != nil {
		return p.records.write(frame{7, p.id, binary.BigEndian.AppendUint64(nil, p.writeOffset)})
	}
	wire := []byte{7, 0, 0}
	wire = binary.BigEndian.AppendUint64(wire, p.writeOffset)
	return writeAll(p.writer, wire)
}
