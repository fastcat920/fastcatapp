//go:build go1.26

package h2client

import (
	"context"
	"crypto/tls"
	"net"
	"net/http"
	"time"
)

func newTransport(config *tls.Config, dial func(context.Context, string, string) (net.Conn, error)) transport {
	protocols := new(http.Protocols)
	protocols.SetHTTP2(true)
	return &http.Transport{
		Protocols: protocols, DialContext: dial, TLSClientConfig: config,
		TLSHandshakeTimeout: 8 * time.Second, IdleConnTimeout: 30 * time.Second,
		MaxConnsPerHost: 1, MaxIdleConnsPerHost: 1, MaxResponseHeaderBytes: 16 << 10,
		DisableCompression: true,
		HTTP2:              &http.HTTP2Config{StrictMaxConcurrentRequests: true},
	}
}
