package outbound

import (
	"context"
	"fmt"
	"io"
	"net"
	"net/netip"
	"os"
	"sync"
	"time"

	"github.com/fastcat920/fcnv3"
	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/transport/tuic/common"
	"github.com/metacubex/quic-go"
)

type FCNV3Option struct {
	BasicOption
	Name   string `proxy:"name"`
	Server string `proxy:"server"`
	Port   int    `proxy:"port"`
	SNI    string `proxy:"sni,omitempty"`
	UUID   string `proxy:"uuid"`
	UDP    bool   `proxy:"udp,omitempty"`
	CAFile string `proxy:"ca-file,omitempty"`
}

type FCNV3 struct {
	*Base
	config      fcnv3.Config
	mu          sync.Mutex
	client      *fcnv3.Client
	network     context.Context
	stopNetwork func() bool
	closed      bool
}

func NewFCNV3(o FCNV3Option) (*FCNV3, error) {
	if o.Server == "" || o.Port < 1 || o.Port > 65535 {
		return nil, fmt.Errorf("FCN v3: invalid server or port")
	}
	credential, err := fcnv3.CredentialFromUUID(o.UUID)
	if err != nil {
		return nil, err
	}
	entry := FastCatHTTPSOption{BasicOption: o.BasicOption, Name: o.Name, Server: o.Server, Port: o.Port, CAFile: o.CAFile}
	roots, err := entry.rootCAs()
	if err != nil {
		return nil, err
	}
	n := &FCNV3{Base: entry.base(C.FCNv3)}
	n.udp = o.UDP
	n.config = fcnv3.Config{
		Endpoint: n.Addr(), ServerName: o.SNI, Account: credential.ID, Secret: credential.Secret,
		Roots: roots, EnableUDP: o.UDP, AllowDomainTargets: true, OpenPacket: n.openPacket,
		ConfigureQUIC: func(q *quic.Conn) { common.SetCongestionController(q, "bbr", 0, "") },
	}
	// Validate the node at parse time. The client opens no sockets until used.
	if _, _, err := n.session(); err != nil {
		return nil, err
	}
	return n, nil
}

func (n *FCNV3) openPacket(ctx context.Context, endpoint string) (net.PacketConn, net.Addr, error) {
	addr, err := resolveUDPAddr(ctx, "udp", endpoint, n.prefer)
	if err != nil {
		return nil, nil, err
	}
	packet, err := n.dialer.ListenPacket(ctx, "udp", "", addr.AddrPort())
	return packet, addr, err
}

func (n *FCNV3) session() (*fcnv3.Client, context.Context, error) {
	n.mu.Lock()
	defer n.mu.Unlock()
	if n.closed {
		return nil, nil, net.ErrClosed
	}
	path := currentFastCatH2Network()
	if n.network != path {
		n.closeClient()
		client, err := fcnv3.NewClient(n.config)
		if err != nil {
			return nil, nil, err
		}
		n.client, n.network = client, path
		// Retire the pool even if the adapter is idle and never dialed again.
		n.stopNetwork = context.AfterFunc(path, func() { client.Close() })
	}
	return n.client, path, nil
}

func (n *FCNV3) DialContext(ctx context.Context, m *C.Metadata) (C.Conn, error) {
	if m == nil || m.NetWork != C.TCP || !m.Valid() || m.DstPort == 0 {
		return nil, fmt.Errorf("FCN v3 requires a valid TCP destination")
	}
	client, _, err := n.session()
	if err != nil {
		return nil, err
	}
	stream, err := client.Dial(ctx, m.RemoteAddress())
	if err != nil {
		return nil, err
	}
	return NewConn(stream, n), nil
}

func (n *FCNV3) ListenPacketContext(ctx context.Context, m *C.Metadata) (C.PacketConn, error) {
	if !n.udp {
		return nil, C.ErrNotSupport
	}
	if m == nil || m.NetWork != C.UDP || !m.Valid() || m.DstPort == 0 {
		return nil, fmt.Errorf("FCN v3 requires a valid UDP destination")
	}
	if err := n.ResolveUDP(ctx, m); err != nil {
		return nil, err
	}
	client, path, err := n.session()
	if err != nil {
		return nil, err
	}
	packet := newFastCatPackets(path, func(ctx context.Context, target string) (*fcnV3PacketAssociation, error) {
		association, err := client.DialUDP(ctx, target)
		if err != nil {
			return nil, err
		}
		return &fcnV3PacketAssociation{UDPAssociation: association, network: path}, nil
	})
	if _, err := packet.target(ctx, netip.AddrPortFrom(m.DstIP.Unmap(), m.DstPort)); err != nil {
		packet.Close()
		return nil, err
	}
	return NewPacketConn(packet, n), nil
}

func (n *FCNV3) Warm(ctx context.Context) error {
	client, _, err := n.session()
	if err != nil {
		return err
	}
	return client.Warm(ctx)
}

func (n *FCNV3) closeClient() error {
	if n.stopNetwork != nil {
		n.stopNetwork()
		n.stopNetwork = nil
	}
	if n.client != nil {
		client := n.client
		n.client = nil
		return client.Close()
	}
	return nil
}

func (n *FCNV3) Close() error {
	n.mu.Lock()
	defer n.mu.Unlock()
	n.closed = true
	return n.closeClient()
}

type fcnV3PacketAssociation struct {
	*fcnv3.UDPAssociation
	network       context.Context
	mu            sync.Mutex
	writeDeadline time.Time
}

func (p *fcnV3PacketAssociation) Read(b []byte) (int, error) {
	payload, err := p.ReceiveDatagram(p.network)
	if err != nil {
		return 0, err
	}
	n := copy(b, payload)
	if n != len(payload) {
		return n, io.ErrShortBuffer
	}
	return n, nil
}

func (p *fcnV3PacketAssociation) Write(b []byte) (int, error) {
	p.mu.Lock()
	deadline := p.writeDeadline
	p.mu.Unlock()
	if !deadline.IsZero() && !time.Now().Before(deadline) {
		return 0, os.ErrDeadlineExceeded
	}
	if err := p.SendDatagram(b); err != nil {
		return 0, err
	}
	return len(b), nil
}

func (p *fcnV3PacketAssociation) SetWriteDeadline(t time.Time) error {
	p.mu.Lock()
	p.writeDeadline = t
	p.mu.Unlock()
	return nil
}
