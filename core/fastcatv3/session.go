package fastcatv3

import (
	"context"
	"encoding/binary"
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"
)

type Session struct {
	openMu          sync.Mutex
	failOnce        sync.Once
	lastActivity    atomic.Int64
	queuedDatagrams int
	creditPending   map[uint64]uint64
	creditWake      chan struct{}

	records                             *records
	ctx                                 context.Context
	cancel                              context.CancelFunc
	closeCarrier                        func()
	config                              Config
	server                              bool
	mu                                  sync.Mutex
	streams                             map[uint64]*Stream
	next                                uint64
	sent, received, consumed, sendLimit uint64
	wake                                chan struct{}
	err                                 error
}
type Stream struct {
	queuedDatagrams int

	ready                                     bool
	resultSeen                                bool
	session                                   *Session
	id                                        uint64
	kind                                      byte
	incoming                                  chan frame
	done                                      chan struct{}
	closeDone                                 sync.Once
	readEOF                                   bool
	opened                                    chan uint16
	writeMu, readMu                           sync.Mutex
	buffer                                    []byte
	sendOffset, recvOffset, readOffset, limit uint64
	localFIN, remoteFIN, closed               bool
	terminal                                  error
	datagramSend, datagramRecv                uint64
	datagramSeen                              bool
	deadline                                  time.Time
}

func newSession(ctx context.Context, r *records, c Config, server bool, closeCarrier func()) *Session {
	ctx, cancel := context.WithCancel(ctx)
	s := &Session{records: r, ctx: ctx, cancel: cancel, config: c, server: server, closeCarrier: closeCarrier, streams: make(map[uint64]*Stream), next: 1, sendLimit: connectionCredit, wake: make(chan struct{}), creditPending: make(map[uint64]uint64), creditWake: make(chan struct{}, 1)}
	s.lastActivity.Store(time.Now().UnixNano())
	go s.flushCredits()
	go s.watchIdle()
	go s.readLoop()
	return s
}
func (s *Session) watchIdle() {
	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()
	for {
		select {
		case <-s.ctx.Done():
			return
		case <-ticker.C:
			if time.Since(time.Unix(0, s.lastActivity.Load())) >= 30*time.Second {
				s.fail(errors.New("session idle timeout"))
				return
			}
		}
	}
}

func (s *Session) signalLocked() { close(s.wake); s.wake = make(chan struct{}) }
func (s *Session) fail(e error) {
	s.failOnce.Do(func() {
		s.mu.Lock()
		s.err = e
		s.signalLocked()
		s.mu.Unlock()
		s.closeCarrier()
		s.records.close()
		s.cancel()
	})
}
func (s *Session) Close() error { s.fail(net.ErrClosed); return nil }
func (s *Session) Err() error   { s.mu.Lock(); defer s.mu.Unlock(); return s.err }
func (s *Session) UpdateKeys() error {
	e := s.records.update()
	if e != nil {
		s.fail(e)
	}
	return e
}
func (s *Session) newStreamLocked(id uint64, kind byte) *Stream {
	t := &Stream{session: s, id: id, kind: kind, limit: streamCredit, incoming: make(chan frame, 256), done: make(chan struct{}), opened: make(chan uint16, 1)}
	s.streams[id] = t
	return t
}
func (s *Session) send(f frame) error { return s.sendFrames(f) }
func (s *Session) sendFrames(frames ...frame) error {
	if len(frames) == 0 {
		return errProtocol
	}
	select {
	case <-s.ctx.Done():
		return net.ErrClosed
	default:
	}
	if len(frames) != 1 || frames[0].kind != 13 {
		s.lastActivity.Store(time.Now().UnixNano())
	}
	var started time.Time
	if s.config.Trace != nil {
		started = time.Now()
	}
	e := s.records.writeFrames(frames...)
	if s.config.Trace != nil {
		s.config.trace(fmt.Sprintf("send frames=%d first_kind=%d stream=%d elapsed_us=%d", len(frames), frames[0].kind, frames[0].id, time.Since(started).Microseconds()))
	}
	if e != nil {
		s.fail(e)
	}
	return e
}

// Queue absolute limits immediately, without blocking the reader on a reverse
// carrier write. At most one latest limit per stream is retained; the session
// stream cap bounds this map. There is no timer or consumption threshold.
func (s *Session) queueCredits(limits ...frame) error {
	s.mu.Lock()
	if s.err != nil {
		s.mu.Unlock()
		return net.ErrClosed
	}
	for _, f := range limits {
		limit := binary.BigEndian.Uint64(f.body)
		if limit > s.creditPending[f.id] {
			s.creditPending[f.id] = limit
		}
	}
	s.mu.Unlock()
	select {
	case s.creditWake <- struct{}{}:
	default:
	}
	return nil
}
func (s *Session) flushCredits() {
	for {
		select {
		case <-s.ctx.Done():
			return
		case <-s.creditWake:
		}
		for {
			s.mu.Lock()
			frames := make([]frame, 0, 64)
			for id, limit := range s.creditPending {
				frames = append(frames, frame{6, id, binary.BigEndian.AppendUint64(nil, limit)})
				delete(s.creditPending, id)
				if len(frames) == 64 {
					break
				}
			}
			s.mu.Unlock()
			if len(frames) == 0 {
				break
			}
			if err := s.sendFrames(frames...); err != nil {
				return
			}
		}
	}
}
func (s *Session) Open(ctx context.Context, kind byte, address string) (*Stream, error) {
	if s.server || kind > 1 {
		return nil, errProtocol
	}
	body, e := encodeOpen(kind, address)
	if e != nil {
		return nil, e
	}
	s.openMu.Lock()
	s.mu.Lock()
	active := 0
	for _, t := range s.streams {
		if !t.closed {
			active++
		}
	}
	if active >= maxStreams || len(s.streams) >= 4096 || s.next > 1<<60 {
		s.mu.Unlock()
		s.openMu.Unlock()
		return nil, errors.New("stream capacity reached")
	}
	id := s.next
	s.next += 2
	t := s.newStreamLocked(id, kind)
	s.mu.Unlock()
	e = s.send(frame{2, id, body})
	s.openMu.Unlock()
	if e != nil {
		return nil, e
	}
	select {
	case status := <-t.opened:
		if status != 0 {
			t.Close()
			return nil, fmt.Errorf("target open rejected: %d", status)
		}
		return t, nil
	case <-ctx.Done():
		t.Close()
		return nil, ctx.Err()
	case <-s.ctx.Done():
		return nil, net.ErrClosed
	}
}
func encodeOpen(kind byte, address string) ([]byte, error) {
	host, port, e := net.SplitHostPort(address)
	n, pe := strconv.Atoi(port)
	if e != nil || pe != nil || n < 1 || n > 65535 {
		return nil, errors.New("invalid target address")
	}
	typ := byte(1)
	b := []byte(host)
	if ip := net.ParseIP(host); ip != nil {
		typ = 3
		b = ip.To16()
		if v4 := ip.To4(); v4 != nil {
			typ = 2
			b = v4
		}
	} else if !validDomain(host) {
		return nil, errors.New("invalid target domain")
	}
	out := []byte{kind, typ}
	out = binary.BigEndian.AppendUint16(out, uint16(len(b)))
	out = append(out, b...)
	out = binary.BigEndian.AppendUint16(out, uint16(n))
	return append(out, 1), nil
}
func validDomain(h string) bool {
	if len(h) == 0 || len(h) > 253 || strings.ToLower(h) != h {
		return false
	}
	for _, l := range strings.Split(h, ".") {
		if len(l) == 0 || len(l) > 63 || l[0] == '-' || l[len(l)-1] == '-' {
			return false
		}
		for _, c := range l {
			if !(c >= 'a' && c <= 'z' || c >= '0' && c <= '9' || c == '-') {
				return false
			}
		}
	}
	return true
}
func decodeOpen(b []byte) (byte, string, error) {
	if len(b) < 7 || b[0] > 1 {
		return 0, "", errProtocol
	}
	n := int(binary.BigEndian.Uint16(b[2:4]))
	if n == 0 || len(b) != n+7 || b[len(b)-1] > 2 {
		return 0, "", errProtocol
	}
	addr := b[4 : 4+n]
	var h string
	switch b[1] {
	case 1:
		h = string(addr)
		if !validDomain(h) {
			return 0, "", errProtocol
		}
	case 2:
		if n != 4 {
			return 0, "", errProtocol
		}
		h = net.IP(addr).String()
	case 3:
		if n != 16 {
			return 0, "", errProtocol
		}
		h = net.IP(addr).String()
	default:
		return 0, "", errProtocol
	}
	p := binary.BigEndian.Uint16(b[4+n:])
	if p == 0 {
		return 0, "", errProtocol
	}
	return b[0], net.JoinHostPort(h, strconv.Itoa(int(p))), nil
}

func (s *Session) readLoop() {
	defer s.Close()
	for {
		fs, e := s.records.read()
		if e != nil {
			s.fail(e)
			return
		}
		for _, f := range fs {
			if f.kind != 13 {
				s.lastActivity.Store(time.Now().UnixNano())
			}
			if e = s.dispatch(f); e != nil {
				s.fail(e)
				return
			}
		}
	}
}
func (s *Session) dispatch(f frame) error {
	if f.id == 0 {
		switch f.kind {
		case 6:
			if len(f.body) != 8 {
				return errProtocol
			}
			v := binary.BigEndian.Uint64(f.body)
			if v > 1<<60 {
				return errProtocol
			}
			s.mu.Lock()
			if v > s.sendLimit {
				s.sendLimit = v
				s.signalLocked()
			}
			s.mu.Unlock()
			return nil
		case 8:
			if len(f.body) != 8 {
				return errProtocol
			}
			return s.send(frame{9, 0, f.body})
		case 9:
			if len(f.body) != 8 {
				return errProtocol
			}
			return nil
		case 13:
			if len(f.body) > 256 {
				return errProtocol
			}
			return nil
		case 15:
			if len(f.body) != 2 {
				return errProtocol
			}
			return io.EOF
		default:
			return errProtocol
		}
	}
	if f.id%2 != 1 {
		return errProtocol
	}
	if f.kind == 2 {
		if !s.server {
			return errProtocol
		}
		kind, target, e := decodeOpen(f.body)
		if e != nil {
			return e
		}
		s.mu.Lock()
		if _, ok := s.streams[f.id]; ok || f.id < s.next || len(s.streams) >= 4096 {
			s.mu.Unlock()
			return errProtocol
		}
		s.next = f.id + 2
		active := 0
		for _, t := range s.streams {
			if !t.closed {
				active++
			}
		}
		if active >= maxStreams {
			s.mu.Unlock()
			return s.send(frame{3, f.id, []byte{0, 3}})
		}
		t := s.newStreamLocked(f.id, kind)
		s.mu.Unlock()
		go s.serveTarget(t, target)
		return nil
	}
	s.mu.Lock()
	t, ok := s.streams[f.id]
	if !ok {
		s.mu.Unlock()
		return errProtocol
	}
	switch f.kind {
	case 3:
		if s.server || t.resultSeen || len(f.body) != 2 || binary.BigEndian.Uint16(f.body) > 4 {
			s.mu.Unlock()
			return errProtocol
		}
		t.resultSeen = true
		t.ready = binary.BigEndian.Uint16(f.body) == 0
		select {
		case t.opened <- binary.BigEndian.Uint16(f.body):
		default:
			s.mu.Unlock()
			return errProtocol
		}
	case 4:
		if !t.ready || t.kind != 0 || len(f.body) < 9 {
			s.mu.Unlock()
			return errProtocol
		}
		offset := binary.BigEndian.Uint64(f.body)
		n := uint64(len(f.body) - 8)
		if t.remoteFIN || offset != t.recvOffset || offset+n > t.readOffset+streamCredit || s.received+n > s.consumed+connectionCredit {
			s.mu.Unlock()
			return errProtocol
		}
		t.recvOffset += n
		s.received += n
		if t.closed {
			t.readOffset += n
			s.consumed += n
			limit := s.consumed + connectionCredit
			s.mu.Unlock()
			return s.queueCredits(frame{6, 0, binary.BigEndian.AppendUint64(nil, limit)})
		}
	case 5:
		if !t.ready || t.kind != 1 || len(f.body) < 8 || len(f.body) > 8+maxDatagram {
			s.mu.Unlock()
			return errProtocol
		}
		seq := binary.BigEndian.Uint64(f.body)
		if t.datagramSeen && seq <= t.datagramRecv {
			s.mu.Unlock()
			return nil
		}
		t.datagramSeen = true
		t.datagramRecv = seq
	case 6:
		if len(f.body) != 8 {
			s.mu.Unlock()
			return errProtocol
		}
		v := binary.BigEndian.Uint64(f.body)
		if v > 1<<60 {
			s.mu.Unlock()
			return errProtocol
		}
		if v > t.limit {
			t.limit = v
			s.signalLocked()
		}
		s.mu.Unlock()
		return nil
	case 7:
		if !t.ready || t.kind != 0 || t.remoteFIN || len(f.body) != 8 || binary.BigEndian.Uint64(f.body) != t.recvOffset {
			s.mu.Unlock()
			return errProtocol
		}
		t.remoteFIN = true
	case 10:
		if len(f.body) != 10 || binary.BigEndian.Uint64(f.body[2:]) < t.recvOffset {
			s.mu.Unlock()
			return errProtocol
		}
		final := binary.BigEndian.Uint64(f.body[2:])
		if final > t.readOffset+streamCredit || s.received+(final-t.recvOffset) > s.consumed+connectionCredit {
			s.mu.Unlock()
			return errProtocol
		}
		s.received += final - t.recvOffset
		s.consumed += final - t.readOffset
		t.recvOffset = final
		t.readOffset = final
		t.terminal = errors.New("stream reset by peer")
		s.queuedDatagrams -= t.queuedDatagrams
		t.queuedDatagrams = 0
		t.closed = true
		t.closeDone.Do(func() { close(t.done) })
		s.signalLocked()
		limit := s.consumed + connectionCredit
		s.mu.Unlock()
		return s.queueCredits(frame{6, 0, binary.BigEndian.AppendUint64(nil, limit)})
	default:
		s.mu.Unlock()
		return errProtocol
	}
	if t.closed && f.kind != 10 && f.kind != 3 {
		s.mu.Unlock()
		return nil
	}
	if f.kind == 5 && s.queuedDatagrams >= 256 {
		s.mu.Unlock()
		return nil
	}
	select {
	case t.incoming <- f:
		if f.kind == 5 {
			s.queuedDatagrams++
			t.queuedDatagrams++
		}
		s.mu.Unlock()
		return nil
	default:
		if t.kind == 1 {
			s.mu.Unlock()
			return nil
		}
		s.mu.Unlock()
		return errors.New("stream receive queue exceeded")
	}
}
func (t *Stream) wait(ctx context.Context) (frame, error) {
	s := t.session
	for {
		s.mu.Lock()
		deadline, closed, terminal, wake := t.deadline, t.closed, t.terminal, s.wake
		s.mu.Unlock()
		if closed {
			if terminal != nil {
				return frame{}, terminal
			}
			return frame{}, net.ErrClosed
		}
		var timer *time.Timer
		var timeout <-chan time.Time
		if !deadline.IsZero() {
			remaining := time.Until(deadline)
			if remaining <= 0 {
				return frame{}, os.ErrDeadlineExceeded
			}
			timer = time.NewTimer(remaining)
			timeout = timer.C
		}
		select {
		case f := <-t.incoming:
			if timer != nil {
				timer.Stop()
			}
			return f, nil
		case <-wake:
			if timer != nil {
				timer.Stop()
			}
			continue
		case <-timeout:
			return frame{}, os.ErrDeadlineExceeded
		case <-ctx.Done():
			if timer != nil {
				timer.Stop()
			}
			return frame{}, ctx.Err()
		case <-s.ctx.Done():
			if timer != nil {
				timer.Stop()
			}
			return frame{}, net.ErrClosed
		}
	}
}
func (t *Stream) Read(p []byte) (int, error) {
	if len(p) == 0 {
		return 0, nil
	}
	if t.kind != 0 {
		return 0, errors.New("use ReceiveDatagram")
	}
	t.readMu.Lock()
	defer t.readMu.Unlock()
	if t.readEOF {
		return 0, io.EOF
	}
	for len(t.buffer) == 0 {
		f, e := t.wait(context.Background())
		if e != nil {
			return 0, e
		}
		switch f.kind {
		case 3:
			continue
		case 7:
			t.readEOF = true
			return 0, io.EOF
		case 10:
			return 0, errors.New("stream reset")
		case 4:
			t.buffer = f.body[8:]
		default:
			return 0, errProtocol
		}
	}
	n := copy(p, t.buffer)
	t.buffer = t.buffer[n:]
	s := t.session
	s.mu.Lock()
	if t.closed {
		s.mu.Unlock()
		return n, net.ErrClosed
	}
	t.readOffset += uint64(n)
	s.consumed += uint64(n)
	streamLimit, sessionLimit := t.readOffset+streamCredit, s.consumed+connectionCredit
	s.mu.Unlock()
	if e := s.queueCredits(
		frame{6, t.id, binary.BigEndian.AppendUint64(nil, streamLimit)},
		frame{6, 0, binary.BigEndian.AppendUint64(nil, sessionLimit)},
	); e != nil {
		return n, e
	}
	return n, nil
}
func (t *Stream) Write(p []byte) (int, error) {
	if t.kind != 0 {
		return 0, errors.New("use SendDatagram")
	}
	t.writeMu.Lock()
	defer t.writeMu.Unlock()
	total := 0
	for len(p) > 0 {
		s := t.session
		s.mu.Lock()
		if t.closed || t.localFIN {
			s.mu.Unlock()
			return total, net.ErrClosed
		}
		available := t.limit - t.sendOffset
		sessionAvail := s.sendLimit - s.sent
		if sessionAvail < available {
			available = sessionAvail
		}
		if available == 0 {
			wake, deadline := s.wake, t.deadline
			s.mu.Unlock()
			var timer *time.Timer
			var expired <-chan time.Time
			if !deadline.IsZero() {
				if time.Until(deadline) <= 0 {
					return total, os.ErrDeadlineExceeded
				}
				timer = time.NewTimer(time.Until(deadline))
				expired = timer.C
			}
			select {
			case <-wake:
				if timer != nil {
					timer.Stop()
				}
				continue
			case <-expired:
				return total, os.ErrDeadlineExceeded
			case <-s.ctx.Done():
				if timer != nil {
					timer.Stop()
				}
				return total, net.ErrClosed
			}
		}
		n := len(p)
		if n > 8192 {
			n = 8192
		}
		if uint64(n) > available {
			n = int(available)
		}
		body := binary.BigEndian.AppendUint64(nil, t.sendOffset)
		body = append(body, p[:n]...)
		t.sendOffset += uint64(n)
		s.sent += uint64(n)
		s.mu.Unlock()
		if e := s.send(frame{4, t.id, body}); e != nil {
			return total, e
		}
		total += n
		p = p[n:]
	}
	return total, nil
}
func (t *Stream) CloseWrite() error {
	t.writeMu.Lock()
	defer t.writeMu.Unlock()
	s := t.session
	s.mu.Lock()
	if t.closed || t.localFIN {
		s.mu.Unlock()
		return nil
	}
	t.localFIN = true
	offset := t.sendOffset
	s.mu.Unlock()
	return s.send(frame{7, t.id, binary.BigEndian.AppendUint64(nil, offset)})
}
func (t *Stream) Close() error {
	s := t.session
	s.mu.Lock()
	if t.closed {
		s.mu.Unlock()
		return nil
	}
	released := t.recvOffset - t.readOffset
	s.consumed += released
	t.queuedDatagrams, s.queuedDatagrams = 0, s.queuedDatagrams-t.queuedDatagrams
	t.readOffset = t.recvOffset
	t.closed = true
	t.closeDone.Do(func() { close(t.done) })
	t.terminal = net.ErrClosed
	offset := t.sendOffset
	limit := s.consumed + connectionCredit
	s.signalLocked()
	s.mu.Unlock()
	reset := frame{10, t.id, append([]byte{0, 0}, binary.BigEndian.AppendUint64(nil, offset)...)}
	if released > 0 {
		if err := s.queueCredits(frame{6, 0, binary.BigEndian.AppendUint64(nil, limit)}); err != nil {
			return err
		}
		return s.send(reset)
	}
	return s.send(reset)
}
func (t *Stream) SendDatagram(b []byte) error {
	if t.kind != 1 || len(b) > maxDatagram {
		return errors.New("invalid datagram")
	}
	t.writeMu.Lock()
	defer t.writeMu.Unlock()
	s := t.session
	s.mu.Lock()
	if t.closed {
		s.mu.Unlock()
		return net.ErrClosed
	}
	sequence := t.datagramSend
	t.datagramSend++
	s.mu.Unlock()
	return s.send(frame{5, t.id, append(binary.BigEndian.AppendUint64(nil, sequence), b...)})
}
func (t *Stream) ReceiveDatagram(ctx context.Context) ([]byte, error) {
	if t.kind != 1 {
		return nil, errProtocol
	}
	t.readMu.Lock()
	defer t.readMu.Unlock()
	for {
		f, e := t.wait(ctx)
		if e != nil {
			return nil, e
		}
		switch f.kind {
		case 3:
			continue
		case 5:
			t.session.mu.Lock()
			if t.queuedDatagrams > 0 {
				t.queuedDatagrams--
				t.session.queuedDatagrams--
			}
			t.session.mu.Unlock()
			return f.body[8:], nil
		case 10:
			return nil, net.ErrClosed
		default:
			return nil, errProtocol
		}
	}
}
func (t *Stream) LocalAddr() net.Addr  { return streamAddr("fastcat-v3-local") }
func (t *Stream) RemoteAddr() net.Addr { return streamAddr("fastcat-v3-target") }
func (t *Stream) SetDeadline(d time.Time) error {
	s := t.session
	s.mu.Lock()
	t.deadline = d
	s.signalLocked()
	s.mu.Unlock()
	return nil
}
func (t *Stream) SetReadDeadline(d time.Time) error  { return t.SetDeadline(d) }
func (t *Stream) SetWriteDeadline(d time.Time) error { return t.SetDeadline(d) }

type streamAddr string

func (a streamAddr) Network() string { return "fastcat-v3" }
func (a streamAddr) String() string  { return string(a) }
