package dns

import (
	"context"
	"crypto/x509"
	"errors"
	"fmt"
	"io"
	"net"
	"net/netip"
	"net/url"
	"strings"
	"syscall"

	"github.com/metacubex/http"
	"github.com/metacubex/mihomo/component/dialer"
	"github.com/metacubex/mihomo/component/ech/echparser"
	"github.com/metacubex/tls"
	D "github.com/miekg/dns"
)

// NewFastCatEntryResolver pins the DoH resolver's socket address while
// authenticating its HTTPS hostname. It never calls a system DNS resolver.
func NewFastCatEntryResolver(endpoint, bootstrap, innerName string, roots *x509.CertPool) (func(context.Context, string, string) (string, []byte, error), error) {
	u, err := url.Parse(endpoint)
	if err != nil || u.Scheme != "https" || u.Hostname() == "" || u.User != nil || u.RawQuery != "" || u.Fragment != "" {
		return nil, errors.New("FastCat entry DoH requires an HTTPS URL")
	}
	if strings.EqualFold(strings.TrimSuffix(u.Hostname(), "."), strings.TrimSuffix(innerName, ".")) {
		return nil, errors.New("entry DoH hostname must differ from the inner TLS name")
	}
	ip, err := netip.ParseAddr(bootstrap)
	if err != nil || ip.Zone() != "" {
		return nil, errors.New("FastCat entry DoH requires a literal bootstrap IP")
	}
	port := u.Port()
	if port == "" {
		port = "443"
	}
	transport := &http.Transport{
		ForceAttemptHTTP2: true,
		TLSClientConfig:   &tls.Config{MinVersion: tls.VersionTLS12, ServerName: u.Hostname(), RootCAs: roots},
		IdleConnTimeout:   transportDefaultIdleConnTimeout,
		DialContext: func(ctx context.Context, network, _ string) (net.Conn, error) {
			return dialer.DialContext(ctx, network, net.JoinHostPort(ip.String(), port))
		},
	}
	client := &http.Client{
		Transport: transport, Timeout: DefaultTimeout,
		CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse },
	}
	doh := &dnsOverHTTPS{url: u}
	query := func(ctx context.Context, name string, typ uint16) (*D.Msg, error) {
		req := new(D.Msg).SetQuestion(D.Fqdn(name), typ)
		req.Id = 0
		msg, err := doh.exchangeHTTPS(ctx, client, req)
		if ctx.Err() == nil && (errors.Is(err, io.ErrUnexpectedEOF) || errors.Is(err, io.EOF) || errors.Is(err, syscall.ECONNRESET)) {
			// A new socket can recover after the mobile network or peer closes
			// a connection mid-response. Retry only the same encrypted query.
			client.CloseIdleConnections()
			msg, err = doh.exchangeHTTPS(ctx, client, req)
		}
		if err != nil {
			var requestError *url.Error
			if errors.As(err, &requestError) {
				return nil, requestError.Err
			}
			return nil, err
		}
		if !msg.Response || msg.Truncated || msg.Rcode != D.RcodeSuccess || len(msg.Question) != 1 ||
			msg.Question[0].Qtype != typ || msg.Question[0].Qclass != D.ClassINET ||
			!strings.EqualFold(msg.Question[0].Name, req.Question[0].Name) {
			return nil, errors.New("invalid entry DoH response")
		}
		return msg, nil
	}
	lookupECH := func(ctx context.Context, name string) ([]byte, error) {
		msg, err := query(ctx, name, D.TypeHTTPS)
		if err != nil {
			return nil, fmt.Errorf("entry ECH lookup: %w", err)
		}
		var ech []byte
		for _, answer := range msg.Answer {
			if record, ok := answer.(*D.HTTPS); ok && record.Priority > 0 &&
				strings.EqualFold(record.Hdr.Name, D.Fqdn(name)) {
				for _, item := range record.Value {
					if config, ok := item.(*D.SVCBECHConfig); ok {
						if configs, err := echparser.ParseECHConfigList(config.ECH); err == nil && len(configs) != 0 {
							ech = config.ECH
							break
						}
					}
				}
			}
			if len(ech) != 0 {
				break
			}
		}
		if len(ech) == 0 {
			return nil, errors.New("entry HTTPS record has no usable ECH configuration")
		}
		return ech, nil
	}
	lookupAddress := func(ctx context.Context, host, port string) (string, error) {
		for _, typ := range []uint16{D.TypeA, D.TypeAAAA} {
			msg, err := query(ctx, host, typ)
			if err != nil {
				return "", fmt.Errorf("entry address lookup: %w", err)
			}
			for _, answer := range msg.Answer {
				if !strings.EqualFold(answer.Header().Name, D.Fqdn(host)) {
					continue
				}
				switch entry := answer.(type) {
				case *D.A:
					if typ == D.TypeA {
						return net.JoinHostPort(entry.A.String(), port), nil
					}
				case *D.AAAA:
					if typ == D.TypeAAAA {
						return net.JoinHostPort(entry.AAAA.String(), port), nil
					}
				}
			}
		}
		return "", errors.New("entry DoH returned no address")
	}
	return func(ctx context.Context, address, name string) (string, []byte, error) {
		host, port, err := net.SplitHostPort(address)
		if err != nil {
			return "", nil, err
		}
		if _, err := netip.ParseAddr(host); err == nil {
			ech, err := lookupECH(ctx, name)
			return address, ech, err
		}

		// HTTPS and address answers are independent. The same DoH transport
		// can multiplex them, and the caller still needs both before dialing.
		ctx, cancel := context.WithCancel(ctx)
		defer cancel()
		type addressResult struct {
			address string
			err     error
		}
		resolved := make(chan addressResult, 1)
		go func() {
			address, err := lookupAddress(ctx, host, port)
			resolved <- addressResult{address, err}
		}()
		ech, err := lookupECH(ctx, name)
		if err != nil {
			return "", nil, err
		}
		select {
		case result := <-resolved:
			return result.address, ech, result.err
		case <-ctx.Done():
			return "", nil, ctx.Err()
		}
	}, nil
}
