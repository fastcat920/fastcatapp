package fcnv3

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"net"

	"github.com/metacubex/quic-go"
	"github.com/metacubex/tls"
)

var (
	ErrEntryDNS     = errors.New("FCN v3 encrypted entry DNS unavailable")
	ErrECHRejected  = errors.New("FCN v3 entry rejected ECH")
	ErrECHHandshake = errors.New("FCN v3 strict ECH handshake failed")
)

func (c *Client) dialQUIC(ctx context.Context, tc *tls.Config, refreshEntry bool) (*quic.Conn, error) {
	if c.cfg.EntryDNS == nil {
		q, err := c.dialAddr(ctx, c.cfg.Endpoint, tc)
		if err != nil {
			return nil, fmt.Errorf("FCN v3 handshake: %w", err)
		}
		return q, nil
	}
	lookup := c.cfg.EntryDNS.Resolve
	if refreshEntry {
		lookup = c.cfg.EntryDNS.Refresh
	}
	result, err := lookup(ctx, c.cfg.ServerName)
	if err != nil {
		return nil, ErrEntryDNS
	}
	q, err := c.dialECH(ctx, tc, result)
	if !errors.Is(err, ErrECHRejected) || ctx.Err() != nil {
		return q, err
	}

	// Rejection is pre-authorization. Refresh the authenticated DNS source
	// once and retry only a different ECH configuration. An unauthenticated
	// name/address fallback and a clear ClientHello are never attempted.
	next, e := c.cfg.EntryDNS.Refresh(ctx, c.cfg.ServerName)
	if e != nil {
		return nil, errors.Join(ErrECHRejected, ErrEntryDNS)
	}
	if bytes.Equal(next.ECHConfigList, result.ECHConfigList) {
		return nil, ErrECHRejected
	}
	return c.dialECH(ctx, tc, next)
}

func (c *Client) dialECH(ctx context.Context, tc *tls.Config, result EntryDNSResult) (*quic.Conn, error) {
	if !usableEntryECH(result.ECHConfigList, c.cfg.ServerName) || len(result.Addresses) == 0 {
		return nil, ErrEntryDNS
	}
	address := result.Addresses[0]
	if !address.IsValid() || address.IsUnspecified() || address.IsMulticast() || address.Zone() != "" {
		return nil, ErrEntryDNS
	}
	_, port, _ := net.SplitHostPort(c.cfg.Endpoint)
	secure := tc.Clone()
	secure.EncryptedClientHelloConfigList = bytes.Clone(result.ECHConfigList)
	q, err := c.dialAddr(ctx, net.JoinHostPort(address.String(), port), secure)
	if err != nil {
		var rejection *tls.ECHRejectionError
		if errors.As(err, &rejection) {
			return nil, ErrECHRejected
		}
		if ctx.Err() != nil {
			return nil, ctx.Err()
		}
		return nil, ErrECHHandshake
	}
	if !q.ConnectionState().TLS.ECHAccepted {
		q.CloseWithError(0, "")
		return nil, ErrECHRejected
	}
	return q, nil
}
