package fcn

import (
	"context"
	"encoding/binary"
	"errors"
	quic "github.com/metacubex/quic-go"
	"io"
	"net"
	"sync"
	"time"
)

const MaxDatagramPayload = 1100

type serverAssociations struct {
	q     *quic.Conn
	mu    sync.RWMutex
	conns map[uint64]net.Conn
	meter *Counters
}

func newServerAssociations(q *quic.Conn, meter *Counters) *serverAssociations {
	return &serverAssociations{q: q, conns: make(map[uint64]net.Conn), meter: meter}
}
func (s *serverAssociations) add(id uint64, c net.Conn) {
	s.mu.Lock()
	s.conns[id] = c
	s.mu.Unlock()
	go func() {
		b := make([]byte, MaxDatagramPayload+1)
		for {
			n, e := c.Read(b)
			if e != nil {
				return
			}
			if n > MaxDatagramPayload {
				continue
			}
			frame := binary.BigEndian.AppendUint64(nil, id)
			frame = append(frame, b[:n]...)
			if s.q.SendDatagram(frame) == nil {
				s.meter.Download.Add(uint64(n))
			}
		}
	}()
}
func (s *serverAssociations) remove(id uint64) {
	s.mu.Lock()
	c := s.conns[id]
	delete(s.conns, id)
	s.mu.Unlock()
	if c != nil {
		c.Close()
	}
}
func (s *serverAssociations) close() {
	s.mu.Lock()
	defer s.mu.Unlock()
	for id, c := range s.conns {
		c.Close()
		delete(s.conns, id)
	}
}
func (s *serverAssociations) receive() {
	for {
		b, e := s.q.ReceiveDatagram(s.q.Context())
		if e != nil {
			return
		}
		if len(b) < 8 || len(b) > 8+MaxDatagramPayload {
			continue
		}
		id := binary.BigEndian.Uint64(b)
		s.mu.RLock()
		c := s.conns[id]
		s.mu.RUnlock()
		if c != nil {
			c.SetWriteDeadline(time.Now().Add(time.Second))
			n, e := c.Write(b[8:])
			if e == nil {
				s.meter.Upload.Add(uint64(n))
			}
		}
	}
}

type clientAssociations struct {
	q        *quic.Conn
	mu       sync.RWMutex
	flows    map[uint64]*PacketConn
	prefixes map[uint64]*prefixCopyReader
}

func newClientAssociations(q *quic.Conn) *clientAssociations {
	return &clientAssociations{q: q, flows: make(map[uint64]*PacketConn)}
}
func (s *clientAssociations) receive() {
	for {
		b, e := s.q.ReceiveDatagram(s.q.Context())
		if e != nil {
			return
		}
		if len(b) < 8 || len(b) > 8+MaxDatagramPayload {
			continue
		}
		s.mu.RLock()
		id := binary.BigEndian.Uint64(b)
		p := s.flows[id]
		if prefix := s.prefixes[id]; prefix != nil {
			s.mu.RUnlock()
			prefix.offer(b[8:])
			continue
		}
		if p != nil {
			payload := append([]byte(nil), b[8:]...)
			select {
			case p.in <- payload:
			default:
			}
		}
		s.mu.RUnlock()
	}
}

type PacketConn struct {
	q                           *quic.Conn
	control                     *quicConn
	owner                       *clientAssociations
	id                          uint64
	target                      net.Addr
	in                          chan []byte
	done                        chan struct{}
	once                        sync.Once
	mu                          sync.Mutex
	readDeadline, writeDeadline time.Time
	changed                     chan struct{}
}

func (c *Client) DialPacket(ctx context.Context, target string) (*PacketConn, error) {
	if len(c.lanes) != 0 {
		return c.lanes[0].DialPacket(ctx, target)
	}
	conn, e := c.dial(ctx, target, 1)
	if e != nil {
		return nil, e
	}
	control := conn.(*quicConn)
	// Validate the association's status without consuming a datagram.
	control.SetReadDeadline(time.Now().Add(5 * time.Second))
	control.once.Do(func() {
		var b [1]byte
		_, control.status = io.ReadFull(control.Stream, b[:])
		if control.status == nil && b[0] != 0 {
			control.status = ErrAuth
		}
	})
	control.SetReadDeadline(time.Time{})
	if control.status != nil {
		control.Close()
		return nil, control.status
	}
	c.mu.Lock()
	var owner *clientAssociations
	for p := range c.all {
		if p.q != nil && p.q.LocalAddr().String() == control.local.String() {
			owner = p.packets
			break
		}
	}
	c.mu.Unlock()
	if owner == nil {
		control.Close()
		return nil, net.ErrClosed
	}
	addr := packetAddress(target)
	p := &PacketConn{q: owner.q, owner: owner, control: control, id: uint64(control.StreamID()), target: addr, in: make(chan []byte, 64), done: make(chan struct{}), changed: make(chan struct{})}
	owner.mu.Lock()
	owner.flows[p.id] = p
	owner.mu.Unlock()
	go func() { var b [1]byte; control.Stream.Read(b[:]); p.Close() }()
	return p, nil
}
func (p *PacketConn) ReadFrom(b []byte) (int, net.Addr, error) {
	for {
		p.mu.Lock()
		deadline, changed := p.readDeadline, p.changed
		p.mu.Unlock()
		var timer *time.Timer
		var timeout <-chan time.Time
		if !deadline.IsZero() {
			timer = time.NewTimer(time.Until(deadline))
			timeout = timer.C
		}
		select {
		case payload := <-p.in:
			if timer != nil {
				timer.Stop()
			}
			n := copy(b, payload)
			if n < len(payload) {
				return n, p.target, io.ErrShortBuffer
			}
			return n, p.target, nil
		case <-p.done:
			if timer != nil {
				timer.Stop()
			}
			return 0, nil, net.ErrClosed
		case <-p.q.Context().Done():
			if timer != nil {
				timer.Stop()
			}
			return 0, nil, net.ErrClosed
		case <-timeout:
			return 0, nil, &net.OpError{Op: "read", Net: "fcn-datagram", Err: timeoutError{}}
		case <-changed:
			if timer != nil {
				timer.Stop()
			}
		}
	}
}
func (p *PacketConn) WriteTo(b []byte, addr net.Addr) (int, error) {
	if len(b) > MaxDatagramPayload {
		return 0, errors.New("datagram exceeds negotiated payload limit")
	}
	if addr != nil && addr.String() != p.target.String() {
		return 0, ErrTarget
	}
	select {
	case <-p.done:
		return 0, net.ErrClosed
	default:
	}
	p.mu.Lock()
	expired := !p.writeDeadline.IsZero() && time.Now().After(p.writeDeadline)
	p.mu.Unlock()
	if expired {
		return 0, timeoutError{}
	}
	frame := binary.BigEndian.AppendUint64(nil, p.id)
	frame = append(frame, b...)
	if e := p.q.SendDatagram(frame); e != nil {
		return 0, e
	}
	return len(b), nil
}
func (p *PacketConn) Close() error {
	p.once.Do(func() {
		close(p.done)
		p.owner.mu.Lock()
		delete(p.owner.flows, p.id)
		p.owner.mu.Unlock()
		p.control.Close()
	})
	return nil
}
func (p *PacketConn) LocalAddr() net.Addr { return p.q.LocalAddr() }
func (p *PacketConn) SetDeadline(t time.Time) error {
	p.SetReadDeadline(t)
	return p.SetWriteDeadline(t)
}
func (p *PacketConn) SetReadDeadline(t time.Time) error {
	p.mu.Lock()
	p.readDeadline = t
	close(p.changed)
	p.changed = make(chan struct{})
	p.mu.Unlock()
	return nil
}
func (p *PacketConn) SetWriteDeadline(t time.Time) error {
	p.mu.Lock()
	p.writeDeadline = t
	p.mu.Unlock()
	return nil
}

type packetAddress string

func (a packetAddress) Network() string { return "udp" }
func (a packetAddress) String() string  { return string(a) }

type timeoutError struct{}

func (timeoutError) Error() string   { return "deadline exceeded" }
func (timeoutError) Timeout() bool   { return true }
func (timeoutError) Temporary() bool { return true }

func (s *clientAssociations) addPrefix(id uint64, raw io.Reader, trace Trace) *prefixCopyReader {
	p := newPrefixCopyReader(raw, func() { s.mu.Lock(); delete(s.prefixes, id); s.mu.Unlock() }, trace)
	s.mu.Lock()
	if s.prefixes == nil {
		s.prefixes = make(map[uint64]*prefixCopyReader)
	}
	s.prefixes[id] = p
	s.mu.Unlock()
	return p
}
