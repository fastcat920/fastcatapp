package outbound

import (
	"context"
	"fmt"
	"github.com/fastcat920/fcn"
	C "github.com/metacubex/mihomo/constant"
	"net"
	"net/netip"
	"strconv"
	"sync"
	"time"
)

type FCNOption struct {
	TrustMode     string   `proxy:"tls-trust,omitempty"`
	PublicKeyPins []string `proxy:"server-public-key-pins,omitempty"`
	BasicOption
	Name    string `proxy:"name"`
	Server  string `proxy:"server"`
	Port    int    `proxy:"port"`
	SNI     string `proxy:"sni,omitempty"`
	UUID    string `proxy:"uuid"`
	Version int    `proxy:"version"`
	UDP     bool   `proxy:"udp,omitempty"`
	CAFile  string `proxy:"ca-file,omitempty"`
}
type FCN struct {
	*Base
	config  fcn.Config
	mu      sync.Mutex
	network context.Context
	client  *fcn.Client
	closed  bool
}

func NewFCN(o FCNOption) (*FCN, error) {
	if o.Server == "" || o.Port < 1 || o.Port > 65535 {
		return nil, fmt.Errorf("FCN: invalid server or port")
	}
	sni := o.SNI
	if sni == "" {
		sni = o.Server
	}
	cfg, err := fcn.AccountConfig(o.Version, net.JoinHostPort(o.Server, strconv.Itoa(o.Port)), sni, o.UUID)
	if err != nil {
		return nil, err
	}
	cfg.TrustMode = o.TrustMode
	cfg.PublicKeyPins = append([]string(nil), o.PublicKeyPins...)
	entry := FastCatHTTPSOption{BasicOption: o.BasicOption, Name: o.Name, Server: o.Server, Port: o.Port, CAFile: o.CAFile}
	cfg.Roots, err = entry.rootCAs()
	if err != nil {
		return nil, err
	}
	if err := cfg.Validate(); err != nil {
		return nil, err
	}
	typ := C.FCNv1
	if o.Version == 2 {
		typ = C.FCNv2
	}
	n := &FCN{Base: entry.base(typ), config: cfg}
	n.udp = o.UDP
	n.config.OpenPacket = n.openPacket
	return n, nil
}
func (n *FCN) openPacket(ctx context.Context, address string) (net.PacketConn, net.Addr, error) {
	addr, err := resolveUDPAddr(ctx, "udp", address, n.prefer)
	if err != nil {
		return nil, nil, err
	}
	pc, err := n.dialer.ListenPacket(ctx, "udp", "", addr.AddrPort())
	return pc, addr, err
}
func (n *FCN) session() (*fcn.Client, context.Context, error) {
	n.mu.Lock()
	defer n.mu.Unlock()
	if n.closed {
		return nil, nil, net.ErrClosed
	}
	path := currentFastCatH2Network()
	if n.client == nil || n.network != path {
		if n.client != nil {
			n.client.Close()
		}
		c, err := fcn.NewClient(path, n.config, "quic")
		if err != nil {
			return nil, nil, err
		}
		n.client = c
		n.network = path
	}
	return n.client, path, nil
}
func (n *FCN) DialContext(ctx context.Context, m *C.Metadata) (C.Conn, error) {
	c, _, err := n.session()
	if err != nil {
		return nil, err
	}
	stream, err := c.Dial(ctx, m.RemoteAddress())
	if err != nil {
		return nil, err
	}
	return NewConn(stream, n), nil
}
func (n *FCN) ListenPacketContext(ctx context.Context, m *C.Metadata) (C.PacketConn, error) {
	if !n.udp {
		return nil, C.ErrNotSupport
	}
	if err := n.ResolveUDP(ctx, m); err != nil {
		return nil, err
	}
	c, path, err := n.session()
	if err != nil {
		return nil, err
	}
	pc := newFastCatPackets(path, func(ctx context.Context, target string) (net.Conn, error) {
		p, err := c.DialPacket(ctx, target)
		if err != nil {
			return nil, err
		}
		return &fcnDatagramConn{PacketConn: p}, nil
	})
	attempt, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	if _, err := pc.target(attempt, netip.AddrPortFrom(m.DstIP.Unmap(), m.DstPort)); err != nil {
		pc.Close()
		return nil, err
	}
	return NewPacketConn(pc, n), nil
}
func (n *FCN) Close() error {
	n.mu.Lock()
	defer n.mu.Unlock()
	n.closed = true
	if n.client != nil {
		n.client.Close()
		return nil
	}
	return nil
}

type fcnDatagramConn struct{ *fcn.PacketConn }

func (c *fcnDatagramConn) Read(b []byte) (int, error)  { n, _, e := c.ReadFrom(b); return n, e }
func (c *fcnDatagramConn) Write(b []byte) (int, error) { return c.WriteTo(b, nil) }
func (c *fcnDatagramConn) RemoteAddr() net.Addr        { return nil }

var _ net.Conn = (*fcnDatagramConn)(nil)
