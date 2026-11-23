//go:build !go1.26

package h2client

import (
	"context"
	"crypto/tls"
	"net"
	"time"

	"github.com/metacubex/mihomo/component/fastcatprobe"
	"golang.org/x/net/http2"
)

// The core also ships with older Go toolchains, before net/http exposed strict
// H2-only protocol selection. x/net/http2 only speaks H2.
func newTransport(config *tls.Config, dial func(context.Context, string, string) (net.Conn, error)) transport {
	return &http2.Transport{
		TLSClientConfig: config, StrictMaxConcurrentStreams: true,
		IdleConnTimeout: 30 * time.Second, MaxHeaderListSize: 16 << 10, DisableCompression: true,
		DialTLSContext: func(ctx context.Context, network, addr string, cfg *tls.Config) (net.Conn, error) {
			ctx, cancel := context.WithTimeout(ctx, 8*time.Second)
			defer cancel()
			raw, err := dial(ctx, network, addr)
			if err != nil {
				return nil, err
			}
			conn := tls.Client(raw, cfg)
			timing := fastcatprobe.From(ctx)
			timing.Mark(fastcatprobe.GatewayTLSStart)
			if err = conn.HandshakeContext(ctx); err != nil {
				raw.Close()
				return nil, err
			}
			timing.Mark(fastcatprobe.GatewayTLSDone)
			return conn, nil
		},
	}
}
