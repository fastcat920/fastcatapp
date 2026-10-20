//go:build with_gvisor

// Package applepacket connects Apple's public packetFlow API to Mihomo without
// opening a utun device or accessing private NetworkExtension file descriptors.
package applepacket

import (
	"context"
	"errors"
	"github.com/metacubex/gvisor/pkg/buffer"
	"github.com/metacubex/gvisor/pkg/tcpip"
	"github.com/metacubex/gvisor/pkg/tcpip/header"
	"github.com/metacubex/gvisor/pkg/tcpip/link/channel"
	"github.com/metacubex/gvisor/pkg/tcpip/stack"
	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/listener/sing"
	"github.com/metacubex/mihomo/listener/sing_tun"
	"github.com/metacubex/mihomo/log"
	"github.com/metacubex/mihomo/tunnel"
	tun "github.com/metacubex/sing-tun"
	"io"
	"net/netip"
	"sync"
	"time"
)

const MTU = 1500

type Bridge struct {
	endpoint *channel.Endpoint
	stack    tun.Stack
	ctx      context.Context
	cancel   context.CancelFunc
	once     sync.Once
}

func New() (*Bridge, error) {
	h, err := sing.NewListenerHandler(sing.ListenerConfig{Tunnel: tunnel.Tunnel, Type: C.TUN})
	if err != nil {
		return nil, err
	}
	v4 := []netip.Prefix{netip.MustParsePrefix("198.18.0.1/30")}
	v6 := []netip.Prefix{netip.MustParsePrefix("fdfe:dcba:9876::1/126")}
	handler := &sing_tun.ListenerHandler{ListenerHandler: h,
		DnsAddrPorts: []netip.AddrPort{netip.MustParseAddrPort("0.0.0.0:53"), netip.MustParseAddrPort("[::]:53")},
		Inet4Address: v4, Inet6Address: v6, DisableICMPForwarding: true}
	return newWithHandler(handler)
}

func newWithHandler(handler tun.Handler) (*Bridge, error) {
	ctx, cancel := context.WithCancel(context.Background())
	b := &Bridge{endpoint: channel.New(256, MTU, ""), ctx: ctx, cancel: cancel}
	v4 := []netip.Prefix{netip.MustParsePrefix("198.18.0.1/30")}
	v6 := []netip.Prefix{netip.MustParsePrefix("fdfe:dcba:9876::1/126")}
	var err error
	b.stack, err = tun.NewStack("gvisor", tun.StackOptions{Context: ctx, Tun: b,
		TunOptions: tun.Options{MTU: MTU, Inet4Address: v4, Inet6Address: v6},
		Handler:    handler, Logger: log.SingLogger, UDPTimeout: time.Minute, ICMPTimeout: time.Second * 10})
	if err == nil {
		err = b.stack.Start()
	}
	if err != nil {
		b.Close()
		return nil, err
	}
	return b, nil
}

func (b *Bridge) NewEndpoint() (stack.LinkEndpoint, stack.NICOptions, error) {
	return b.endpoint, stack.NICOptions{}, nil
}

// Inject copies the caller's bytes before returning across the C boundary.
func (b *Bridge) Inject(data []byte) error {
	select {
	case <-b.ctx.Done():
		return io.ErrClosedPipe
	default:
	}
	if len(data) == 0 || len(data) > 65535 {
		return errors.New("invalid IP packet size")
	}
	var protocol tcpip.NetworkProtocolNumber
	switch data[0] >> 4 {
	case 4:
		if len(data) < 20 {
			return errors.New("short IPv4 packet")
		}
		protocol = header.IPv4ProtocolNumber
	case 6:
		if len(data) < 40 {
			return errors.New("short IPv6 packet")
		}
		protocol = header.IPv6ProtocolNumber
	default:
		return errors.New("invalid IP version")
	}
	p := stack.NewPacketBuffer(stack.PacketBufferOptions{Payload: buffer.MakeWithData(append([]byte(nil), data...))})
	defer p.DecRef()
	b.endpoint.InjectInbound(protocol, p)
	return nil
}

// Receive blocks until a reply arrives or Close cancels the reader.
func (b *Bridge) Receive(dst []byte) (int, error) {
	p := b.endpoint.ReadContext(b.ctx)
	if p == nil {
		return 0, io.EOF
	}
	defer p.DecRef()
	v := p.ToView()
	defer v.Release()
	if v.Size() > len(dst) {
		return 0, io.ErrShortBuffer
	}
	return copy(dst, v.AsSlice()), nil
}

func (b *Bridge) WritePacket(p *stack.PacketBuffer) (int, error) {
	var packets stack.PacketBufferList
	packets.PushBack(p)
	_, err := b.endpoint.WritePackets(packets)
	if err != nil {
		return 0, errors.New(err.String())
	}
	return p.Size(), nil
}

func (b *Bridge) Read([]byte) (int, error)  { return 0, errors.New("use packetFlow Inject") }
func (b *Bridge) Write([]byte) (int, error) { return 0, errors.New("use channel endpoint") }

func (b *Bridge) Close() error {
	b.once.Do(func() {
		b.cancel()
		if b.stack != nil {
			_ = b.stack.Close()
		}
		b.endpoint.Close()
		for p := b.endpoint.Read(); p != nil; p = b.endpoint.Read() {
			p.DecRef()
		}
	})
	return nil
}
