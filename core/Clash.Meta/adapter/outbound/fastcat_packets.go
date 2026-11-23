package outbound

import (
	"context"
	"errors"
	"net"
	"net/netip"
	"os"
	"sync"
	"time"

	"github.com/metacubex/mihomo/common/net/deadline"
)

// A Mihomo UDP NAT entry is keyed by source. Each destination of that same
// socket needs its own RFC 9298 association, with the original address on reply.
type datagramTarget struct {
	ready     chan struct{}
	stream    net.Conn
	err       error
	lastWrite time.Time
}
type targetReply struct {
	body []byte
	addr *net.UDPAddr
}
type fastCatPackets struct {
	ctx           context.Context
	stop          context.CancelFunc
	open          func(context.Context, string) (net.Conn, error)
	readDeadline  deadline.PipeDeadline
	replies       chan targetReply
	mu            sync.Mutex
	targets       map[netip.AddrPort]*datagramTarget
	writeDeadline time.Time
}

func newFastCatPackets(network context.Context, open func(context.Context, string) (net.Conn, error)) *fastCatPackets {
	ctx, cancel := context.WithCancel(network)
	return &fastCatPackets{ctx: ctx, stop: cancel, open: open, readDeadline: deadline.MakePipeDeadline(), replies: make(chan targetReply, 8), targets: make(map[netip.AddrPort]*datagramTarget)}
}
func (p *fastCatPackets) target(ctx context.Context, addr netip.AddrPort) (net.Conn, error) {
	p.mu.Lock()
	if p.ctx.Err() != nil {
		p.mu.Unlock()
		return nil, net.ErrClosed
	}
	ent := p.targets[addr]
	if ent != nil {
		ent.lastWrite = time.Now()
		p.mu.Unlock()
		select {
		case <-ent.ready:
			return ent.stream, ent.err
		case <-ctx.Done():
			return nil, ctx.Err()
		case <-p.ctx.Done():
			return nil, net.ErrClosed
		}
	}
	// Bound per-source associations. Only reclaim completed, inactive streams.
	if len(p.targets) >= 16 {
		for k, e := range p.targets {
			if e.stream != nil && time.Since(e.lastWrite) > 30*time.Second {
				delete(p.targets, k)
				e.stream.Close()
				break
			}
		}
		if len(p.targets) >= 16 {
			p.mu.Unlock()
			return nil, errors.New("CONNECT-UDP destination limit reached")
		}
	}
	ent = &datagramTarget{ready: make(chan struct{}), lastWrite: time.Now()}
	p.targets[addr] = ent
	p.mu.Unlock()
	stream, err := p.open(ctx, addr.String())
	p.mu.Lock()
	if p.ctx.Err() != nil {
		if stream != nil {
			stream.Close()
		}
		err = net.ErrClosed
	}
	if err != nil {
		delete(p.targets, addr)
	} else {
		stream.SetWriteDeadline(p.writeDeadline)
	}
	ent.stream, ent.err = stream, err
	close(ent.ready)
	p.mu.Unlock()
	if err != nil {
		return nil, err
	}
	go p.readTarget(addr, ent)
	return stream, nil
}
func (p *fastCatPackets) readTarget(addr netip.AddrPort, ent *datagramTarget) {
	defer func() {
		ent.stream.Close()
		p.mu.Lock()
		if p.targets[addr] == ent {
			delete(p.targets, addr)
		}
		p.mu.Unlock()
	}()
	source := net.UDPAddrFromAddrPort(addr)
	buf := make([]byte, 65535)
	for {
		n, err := ent.stream.Read(buf)
		if err != nil {
			return
		}
		reply := targetReply{body: append([]byte(nil), buf[:n]...), addr: source}
		select {
		case p.replies <- reply:
		case <-p.ctx.Done():
			return
		default: // A slow reader drops excess datagrams instead of retaining closed associations.
		}
	}
}
func (p *fastCatPackets) WriteTo(b []byte, dst net.Addr) (int, error) {
	addr, ok := dst.(*net.UDPAddr)
	if !ok || addr == nil || !addr.AddrPort().IsValid() || addr.Port < 1 || addr.Port > 65535 {
		return 0, errors.New("invalid CONNECT-UDP destination")
	}
	ap := addr.AddrPort()
	ap = netip.AddrPortFrom(ap.Addr().Unmap(), ap.Port())
	p.mu.Lock()
	until := p.writeDeadline
	existing := p.targets[ap]
	if existing != nil && existing.stream != nil && p.ctx.Err() == nil {
		existing.lastWrite = time.Now()
		stream := existing.stream
		p.mu.Unlock()
		return stream.Write(b)
	}
	p.mu.Unlock()
	if !until.IsZero() && !time.Now().Before(until) {
		return 0, os.ErrDeadlineExceeded
	}
	if until.IsZero() || time.Until(until) > 4*time.Second {
		until = time.Now().Add(4 * time.Second)
	}
	ctx, cancel := context.WithDeadline(p.ctx, until)
	defer cancel()
	stream, err := p.target(ctx, ap)
	if err != nil {
		return 0, err
	}
	return stream.Write(b)
}
func (p *fastCatPackets) ReadFrom(b []byte) (int, net.Addr, error) {
	select {
	case d := <-p.replies:
		return copy(b, d.body), d.addr, nil
	case <-p.readDeadline.Wait():
		return 0, nil, os.ErrDeadlineExceeded
	case <-p.ctx.Done():
		return 0, nil, net.ErrClosed
	}
}
func (p *fastCatPackets) LocalAddr() net.Addr { return &net.UDPAddr{} }
func (p *fastCatPackets) Close() error {
	p.stop()
	p.mu.Lock()
	defer p.mu.Unlock()
	for _, e := range p.targets {
		if e.stream != nil {
			e.stream.Close()
		}
	}
	return nil
}
func (p *fastCatPackets) SetDeadline(t time.Time) error {
	p.SetReadDeadline(t)
	return p.SetWriteDeadline(t)
}
func (p *fastCatPackets) SetReadDeadline(t time.Time) error { p.readDeadline.Set(t); return nil }
func (p *fastCatPackets) SetWriteDeadline(t time.Time) error {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.writeDeadline = t
	for _, e := range p.targets {
		if e.stream != nil {
			e.stream.SetWriteDeadline(t)
		}
	}
	return nil
}
