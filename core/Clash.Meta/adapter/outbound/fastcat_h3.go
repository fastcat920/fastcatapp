package outbound

import (
	"context"
	"fmt"
	"net"
	"net/netip"
	"strconv"
	"sync"
	"time"

	"github.com/metacubex/mihomo/component/fastcatentry"
	C "github.com/metacubex/mihomo/constant"
	h3client "github.com/metacubex/mihomo/transport/fastcath3"
)

type fastCatH3 struct {
	*Base
	owner   *FastCatAuto
	config  h3client.Config
	mu      sync.Mutex
	network context.Context
	client  *h3client.Client
	closed  bool
}

func newFastCatH3(o FastCatAutoOption) (*fastCatH3, error) {
	entry := o.FastCatHTTPSOption
	entry.Port, entry.Token = o.H3Port, o.H3Token
	if o.H3Server != "" && o.H3Server != entry.Server {
		entry.Server = o.H3Server
		entry.SNI = ""
	}
	if o.H3SNI != "" {
		entry.SNI = o.H3SNI
	}
	roots, err := entry.rootCAs()
	if err != nil {
		return nil, err
	}
	prepare, err := entry.entryResolver(roots)
	if err != nil {
		return nil, err
	}
	h := &fastCatH3{Base: entry.base(C.FastCatAuto)}
	h.config = h3client.Config{Endpoint: net.JoinHostPort(entry.Server, strconv.Itoa(entry.Port)), ServerName: entry.SNI, RootCAs: roots, Token: entry.Token, CurveMode: entry.KeyExchange, Prepare: prepare, OpenPacket: h.openPacket}
	_, _, err = h.session()
	return h, err
}

func (h *fastCatH3) openPacket(ctx context.Context, address string) (net.PacketConn, net.Addr, error) {
	raddr, err := resolveUDPAddr(ctx, "udp", address, h.prefer)
	if err != nil {
		return nil, nil, err
	}
	pc, err := h.dialer.ListenPacket(ctx, "udp", "", raddr.AddrPort())
	return pc, raddr, err
}

func (h *fastCatH3) session() (*h3client.Client, context.Context, error) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if h.closed {
		return nil, nil, net.ErrClosed
	}
	path := currentFastCatH2Network()
	if h.network != path {
		if h.client != nil {
			h.client.Close()
		}
		c, err := h3client.NewContext(path, h.config)
		if err != nil {
			return nil, nil, err
		}
		h.network, h.client = path, c
	}
	return h.client, path, nil
}
func (h *fastCatH3) DialContext(ctx context.Context, m *C.Metadata) (C.Conn, error) {
	c, _, err := h.session()
	if err != nil {
		return nil, err
	}
	stream, err := c.Dial(ctx, m.RemoteAddress())
	if err != nil {
		return nil, err
	}
	return NewConn(stream, h), nil
}

func (h *fastCatH3) ListenPacketContext(ctx context.Context, m *C.Metadata) (C.PacketConn, error) {
	if m == nil || m.NetWork != C.UDP || !m.Valid() || m.DstPort == 0 {
		return nil, fmt.Errorf("fastcat-auto requires a valid UDP destination")
	}
	if err := h.ResolveUDP(ctx, m); err != nil {
		return nil, fmt.Errorf("%w: %w", fastcatentry.ErrTarget, err)
	}
	c, path, err := h.session()
	if err != nil {
		return nil, err
	}
	pc := newFastCatPackets(path, c.DialUDP)
	// Open the first association synchronously so an unreachable UDP entry is
	// reported to the core before it declares the path usable.
	target := netip.AddrPortFrom(m.DstIP.Unmap(), m.DstPort)
	attempt, cancel := context.WithTimeout(ctx, 4*time.Second)
	defer cancel()
	if _, err = pc.target(attempt, target); err != nil {
		pc.Close()
		return nil, err
	}
	// Later destinations on this NAT socket require their own CONNECT-UDP.
	// Install the same policy before the socket is exposed to any writers.
	pc.open = func(ctx context.Context, target string) (net.Conn, error) {
		return openV2UDP(ctx, h.owner, path, func(attempt context.Context) (net.Conn, error) { return c.DialUDP(attempt, target) })
	}
	return NewPacketConn(pc, h), nil
}

func (h *fastCatH3) Close() error {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.closed = true
	if h.client != nil {
		return h.client.Close()
	}
	return nil
}

func (h *fastCatH3) Warm(ctx context.Context) error {
	c, _, err := h.session()
	if err != nil {
		return err
	}
	return c.Warm(ctx)
}
