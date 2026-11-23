package main

import (
	"bytes"
	"context"
	"crypto/tls"
	"crypto/x509"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/netip"
	"net/url"
	"strings"

	"golang.org/x/net/dns/dnsmessage"
)

func resolveDoH(ctx context.Context, endpoint, name, bootstrap string, roots *x509.CertPool) (netip.Addr, error) {
	client, u, closeIdle, err := newDoHClient(endpoint, bootstrap, roots)
	if err != nil {
		return netip.Addr{}, err
	}
	defer closeIdle()
	return lookupDoH(ctx, client, u, name)
}

func newDoHClient(endpoint, bootstrap string, roots *x509.CertPool) (*http.Client, *url.URL, func(), error) {
	u, err := url.Parse(endpoint)
	if err != nil || u.Scheme != "https" || u.Hostname() == "" || u.User != nil {
		return nil, nil, nil, errors.New("expected an HTTPS DNS endpoint")
	}
	tr := &http.Transport{TLSClientConfig: &tls.Config{MinVersion: tls.VersionTLS12, RootCAs: roots}, ForceAttemptHTTP2: true}
	if bootstrap != "" {
		ip, err := netip.ParseAddr(bootstrap)
		if err != nil {
			return nil, nil, nil, fmt.Errorf("invalid DoH bootstrap IP: %w", err)
		}
		dialer := new(net.Dialer)
		tr.DialContext = func(ctx context.Context, network, address string) (net.Conn, error) {
			_, port, err := net.SplitHostPort(address)
			if err != nil {
				return nil, err
			}
			return dialer.DialContext(ctx, network, net.JoinHostPort(ip.String(), port))
		}
	}
	client := &http.Client{Transport: tr, CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }}
	return client, u, tr.CloseIdleConnections, nil
}

func lookupDoH(ctx context.Context, client *http.Client, u *url.URL, name string) (netip.Addr, error) {
	host, err := dnsmessage.NewName(strings.TrimRight(name, ".") + ".")
	if err != nil {
		return netip.Addr{}, err
	}
	q := dnsmessage.Question{Name: host, Type: dnsmessage.TypeA, Class: dnsmessage.ClassINET}
	wire, err := (&dnsmessage.Message{Header: dnsmessage.Header{RecursionDesired: true}, Questions: []dnsmessage.Question{q}}).Pack()
	if err != nil {
		return netip.Addr{}, err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, u.String(), bytes.NewReader(wire))
	if err != nil {
		return netip.Addr{}, err
	}
	req.Header.Set("Content-Type", "application/dns-message")
	req.Header.Set("Accept", "application/dns-message")
	res, err := client.Do(req)
	if err != nil {
		return netip.Addr{}, err
	}
	defer res.Body.Close()
	if res.StatusCode != 200 || !strings.HasPrefix(res.Header.Get("Content-Type"), "application/dns-message") {
		return netip.Addr{}, fmt.Errorf("unexpected DNS HTTP response %d", res.StatusCode)
	}
	body, err := io.ReadAll(io.LimitReader(res.Body, 65536))
	if err != nil {
		return netip.Addr{}, err
	}
	var response dnsmessage.Message
	if err = response.Unpack(body); err != nil {
		return netip.Addr{}, err
	}
	if !response.Response || response.ID != 0 || response.RCode != dnsmessage.RCodeSuccess || len(response.Questions) != 1 || response.Questions[0] != q {
		return netip.Addr{}, errors.New("unexpected DNS message")
	}
	target := host
	for i := 0; i <= len(response.Answers); i++ {
		next := target
		for _, a := range response.Answers {
			if !strings.EqualFold(a.Header.Name.String(), target.String()) || a.Header.Class != dnsmessage.ClassINET {
				continue
			}
			switch value := a.Body.(type) {
			case *dnsmessage.AResource:
				return netip.AddrFrom4(value.A), nil
			case *dnsmessage.CNAMEResource:
				next = value.CNAME
			}
		}
		if next == target {
			break
		}
		target = next
	}
	return netip.Addr{}, errors.New("no IPv4 DNS answer")
}
