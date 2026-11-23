package outbound

import (
	"context"
	"fmt"
	"net"
	"sync"

	C "github.com/metacubex/mihomo/constant"
	h2client "github.com/metacubex/mihomo/transport/fastcath2"
)

// All physical entry connections belong to the current network. Apple changes
// the context when sockets must bind to a new Wi-Fi/cellular interface.
var fastCatH2Network = struct {
	sync.Mutex
	ctx    context.Context
	cancel context.CancelFunc
}{}

// ResetFastCatH2Connections invalidates active and idle pools without retaining
// a registry of adapters. New streams create a pool bound to the new network.
func ResetFastCatH2Connections() {
	fastCatH2Network.Lock()
	defer fastCatH2Network.Unlock()
	if fastCatH2Network.cancel != nil {
		fastCatH2Network.cancel()
	}
	fastCatH2Network.ctx, fastCatH2Network.cancel = context.WithCancel(context.Background())
}

func currentFastCatH2Network() context.Context {
	fastCatH2Network.Lock()
	defer fastCatH2Network.Unlock()
	if fastCatH2Network.ctx == nil {
		fastCatH2Network.ctx, fastCatH2Network.cancel = context.WithCancel(context.Background())
	}
	return fastCatH2Network.ctx
}

type FastCatH2 struct {
	*Base
	config  h2client.Config
	mu      sync.Mutex
	client  *h2client.Client
	network context.Context
	closed  bool
}

func NewFastCatH2(o FastCatHTTPSOption) (*FastCatH2, error) {
	if o.UDP || o.SkipCertVerify {
		return nil, fmt.Errorf("fastcat-h2 requires certificate verification and TCP only")
	}
	roots, err := o.rootCAs()
	if err != nil {
		return nil, err
	}
	prepare, err := o.entryResolver(roots)
	if err != nil {
		return nil, err
	}
	b := o.base(C.FastCatH2)
	h := &FastCatH2{Base: b, config: h2client.Config{
		Endpoint: b.Addr(), ServerName: o.SNI, Token: o.Token, RootCAs: roots,
		CurveMode: o.KeyExchange, Prepare: prepare, DialContext: b.dialer.DialContext,
	}}
	// Validate the node at parse time. No sockets open until the first Dial.
	if _, err = h.currentClient(); err != nil {
		return nil, fmt.Errorf("fastcat-h2: %w", err)
	}
	return h, nil
}

func (h *FastCatH2) currentClient() (*h2client.Client, error) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if h.closed {
		return nil, net.ErrClosed
	}
	network := currentFastCatH2Network()
	if h.network != network {
		if h.client != nil {
			h.client.Close()
		}
		client, err := h2client.NewContext(network, h.config)
		if err != nil {
			return nil, err
		}
		h.network, h.client = network, client
	}
	return h.client, nil
}

func (h *FastCatH2) DialContext(ctx context.Context, m *C.Metadata) (C.Conn, error) {
	if m == nil || !m.Valid() || m.NetWork != C.TCP {
		return nil, fmt.Errorf("fastcat-h2 requires a valid TCP destination")
	}
	client, err := h.currentClient()
	if err != nil {
		return nil, err
	}
	conn, err := client.Dial(ctx, m.RemoteAddress())
	if err != nil {
		return nil, fmt.Errorf("fastcat-h2: %w", err)
	}
	return NewConn(conn, h), nil
}

func (h *FastCatH2) Close() error {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.closed = true
	if h.client != nil {
		return h.client.Close()
	}
	return nil
}

func (h *FastCatH2) Warm(ctx context.Context) error {
	c, err := h.currentClient()
	if err != nil {
		return err
	}
	return c.Warm(ctx)
}
