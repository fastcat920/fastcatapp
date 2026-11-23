package h2client

import (
	"context"
	"crypto/tls"
	"errors"
	"net"
	"time"

	"github.com/metacubex/mihomo/component/fastcatprobe"
	"github.com/metacubex/mihomo/component/fastcattls"
	"github.com/metacubex/mihomo/component/fastcattls/quicprofile"
	qtls "github.com/metacubex/tls"
	"golang.org/x/net/http2"
)

type explicitConn struct {
	net.Conn
	security fastcattls.Negotiated
}

func explicitTransport(config Config, dial func(context.Context, string, string) (net.Conn, error)) (transport, error) {
	cfg, err := quicprofile.ClientConfig(config.ServerName, config.RootCAs, "h2", config.CurveMode)
	if err != nil {
		return nil, err
	}
	return &http2.Transport{
		StrictMaxConcurrentStreams: true, IdleConnTimeout: 30 * time.Second,
		MaxHeaderListSize: 16 << 10, DisableCompression: true,
		DialTLSContext: func(ctx context.Context, network, addr string, _ *tls.Config) (net.Conn, error) {
			ctx, cancel := context.WithTimeout(ctx, 8*time.Second)
			defer cancel()
			tlsConfig := cfg
			if config.Prepare != nil {
				resolved, ech, err := config.Prepare(ctx, addr, config.ServerName)
				if err != nil {
					return nil, err
				}
				if len(ech) == 0 {
					return nil, errors.New("entry ECH configuration is empty")
				}
				addr, tlsConfig = resolved, cfg.Clone()
				tlsConfig.EncryptedClientHelloConfigList = ech
			}
			raw, err := dial(ctx, network, addr)
			if err != nil {
				return nil, err
			}
			client := qtls.Client(raw, tlsConfig)
			timing := fastcatprobe.From(ctx)
			timing.Mark(fastcatprobe.GatewayTLSStart)
			if err = client.HandshakeContext(ctx); err != nil {
				raw.Close()
				return nil, err
			}
			if config.Prepare != nil && !client.ConnectionState().ECHAccepted {
				raw.Close()
				return nil, errors.New("HTTP/2 gateway did not accept ECH")
			}
			timing.Mark(fastcatprobe.GatewayTLSDone)
			return &explicitConn{client, quicprofile.Security(client.ConnectionState())}, nil
		},
	}, nil
}
