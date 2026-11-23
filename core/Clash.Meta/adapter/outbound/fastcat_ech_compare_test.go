//go:build go1.24

package outbound

import (
	"bufio"
	"context"
	"crypto/tls"
	"encoding/base64"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"strings"
	"testing"
	"time"

	C "github.com/metacubex/mihomo/constant"
	D "github.com/miekg/dns"
)

// TestFastCatEntryComparison measures fresh tunnel requests. It is opt-in and
// expects the temporary CatNode and DoH services with the test certificates.
func TestFastCatEntryComparison(t *testing.T) {
	file := os.Getenv("FASTCAT_ECH_TEST_TOKEN")
	if file == "" {
		t.Skip("no independent test service configured")
	}
	data, err := os.ReadFile(file)
	if err != nil {
		t.Fatal(err)
	}
	const (
		name = "ech-test.fastcat.ink"
		doh  = "https://zlhk.fastcat.ink:18450/dns-query"
		ip   = "191.223.214.8"
	)
	protocols := []string{"h2", "h3"}
	modes := []string{"address", "doh", "doh-ech"}
	run := func(ctx context.Context, protocol, mode string, firstByte *time.Time) error {
		opts := FastCatHTTPSOption{Name: "entry comparison", Server: ip, SNI: name, Port: 18449, Token: strings.TrimSpace(string(data))}
		if mode == "doh" {
			addr, err := lookupComparisonAddress(ctx, doh, name, ip)
			if err != nil {
				return fmt.Errorf("entry DNS: %w", err)
			}
			opts.Server = addr
		}
		if mode == "doh-ech" {
			opts.Server, opts.EntryDoH, opts.EntryDoHIP = name, doh, ip
		}
		var a ProxyAdapter
		var err error
		if protocol == "h2" {
			a, err = NewFastCatH2(opts)
		} else {
			a, err = NewFastCatAuto(FastCatAutoOption{
				FastCatHTTPSOption: opts, V2Transport: "h3", H3Port: opts.Port, H3Token: opts.Token,
			})
		}
		if err != nil {
			return err
		}
		defer a.Close()
		target := &C.Metadata{Host: "example.com", DstPort: 443}
		conn, err := a.DialContext(ctx, target)
		if err != nil {
			return fmt.Errorf("tunnel: %w", err)
		}
		defer conn.Close()
		deadline, _ := ctx.Deadline()
		conn.SetDeadline(deadline)
		server := tls.Client(conn, &tls.Config{ServerName: target.Host, MinVersion: tls.VersionTLS12})
		if err := server.HandshakeContext(ctx); err != nil {
			return fmt.Errorf("target TLS: %w", err)
		}
		if _, err := io.WriteString(server, "HEAD / HTTP/1.1\r\nHost: example.com\r\nConnection: close\r\n\r\n"); err != nil {
			return fmt.Errorf("send request: %w", err)
		}
		reader := bufio.NewReader(server)
		if _, err := reader.Peek(1); err != nil {
			return fmt.Errorf("read first byte: %w", err)
		}
		*firstByte = time.Now()
		response, err := http.ReadResponse(reader, &http.Request{Method: http.MethodHead})
		if err != nil {
			return fmt.Errorf("read response: %w", err)
		}
		response.Body.Close()
		if response.StatusCode != http.StatusOK {
			return fmt.Errorf("unexpected HTTP status %d", response.StatusCode)
		}
		return nil
	}

	for round := 0; round < 24; round++ {
		for index := range protocols {
			protocol := protocols[(index+round)%len(protocols)]
			for index := range modes {
				mode := modes[(index+round)%len(modes)]
				ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
				start := time.Now()
				var firstByte time.Time
				err := run(ctx, protocol, mode, &firstByte)
				elapsed := time.Since(start)
				if err == nil {
					elapsed = firstByte.Sub(start)
				}
				us := elapsed.Microseconds()
				cancel()
				t.Logf("entry-comparison %d %s %s %d %t", round+1, protocol, mode, us, err == nil)
				if err != nil {
					t.Logf("entry-comparison-error %d %s %s %v", round+1, protocol, mode, err)
				}
			}
		}
	}
}

func lookupComparisonAddress(ctx context.Context, endpoint, name, bootstrap string) (string, error) {
	q := new(D.Msg).SetQuestion(D.Fqdn(name), D.TypeA)
	q.Id = 0
	wire, err := q.Pack()
	if err != nil {
		return "", err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint+"?dns="+base64.RawURLEncoding.EncodeToString(wire), nil)
	if err != nil {
		return "", err
	}
	req.Header.Set("Accept", "application/dns-message")
	dialer := new(net.Dialer)
	transport := &http.Transport{ForceAttemptHTTP2: true,
		DialContext: func(ctx context.Context, network, address string) (net.Conn, error) {
			_, port, err := net.SplitHostPort(address)
			if err != nil {
				return nil, err
			}
			return dialer.DialContext(ctx, network, net.JoinHostPort(bootstrap, port))
		}}
	defer transport.CloseIdleConnections()
	client := &http.Client{Transport: transport, Timeout: 5 * time.Second,
		CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }}
	res, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		return "", fmt.Errorf("unexpected DNS HTTP status %d", res.StatusCode)
	}
	body, err := io.ReadAll(io.LimitReader(res.Body, 65536))
	if err != nil {
		return "", err
	}
	msg := new(D.Msg)
	if err := msg.Unpack(body); err != nil {
		return "", err
	}
	if !msg.Response || msg.Rcode != D.RcodeSuccess || msg.Id != q.Id || len(msg.Question) != 1 || msg.Question[0] != q.Question[0] {
		return "", fmt.Errorf("invalid DNS response")
	}
	for _, answer := range msg.Answer {
		if a, ok := answer.(*D.A); ok && a.Hdr.Name == q.Question[0].Name {
			return a.A.String(), nil
		}
	}
	return "", fmt.Errorf("no IPv4 answer")
}
