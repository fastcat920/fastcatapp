package main

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"fmt"
	"net"
	"os"
	"time"

	"github.com/metacubex/mihomo/component/fastcattls"
	"github.com/metacubex/mihomo/component/fastcattls/quicprofile"
	quic "github.com/metacubex/quic-go"
	qtls "github.com/metacubex/tls"
)

func remoteHandshake(ctx context.Context, address, name, path, mode string, roots *x509.CertPool, ech []byte) (sample, error) {
	start := time.Now()
	if path == "h2/tcp" {
		raw, err := (&net.Dialer{}).DialContext(ctx, "tcp", address)
		if err != nil {
			return sample{}, err
		}
		defer raw.Close()
		counted := &streamCounter{Conn: raw}
		var negotiated fastcattls.Negotiated
		var protocol string
		var echAccepted bool
		if mode == "default" {
			client := tls.Client(counted, &tls.Config{ServerName: name, RootCAs: roots, MinVersion: tls.VersionTLS13, NextProtos: []string{"h2"}, EncryptedClientHelloConfigList: ech})
			err = client.HandshakeContext(ctx)
			state := client.ConnectionState()
			echAccepted = state.ECHAccepted
			protocol, negotiated = state.NegotiatedProtocol, fastcattls.Security(state)
		} else {
			cfg, e := quicprofile.ClientConfig(name, roots, "h2", mode)
			if e != nil {
				return sample{}, e
			}
			cfg.EncryptedClientHelloConfigList = ech
			client := qtls.Client(counted, cfg)
			err = client.HandshakeContext(ctx)
			state := client.ConnectionState()
			echAccepted = state.ECHAccepted
			protocol, negotiated = state.NegotiatedProtocol, quicprofile.Security(state)
		}
		if err != nil {
			return sample{}, err
		}
		if len(ech) != 0 && !echAccepted {
			return sample{}, fmt.Errorf("H2 ECH was not accepted")
		}
		if protocol != "h2" {
			return sample{}, fmt.Errorf("expected h2, negotiated %q", protocol)
		}
		return sample{time.Since(start), counted.sent, counted.received, negotiated}, nil
	}
	dest, err := net.ResolveUDPAddr("udp", address)
	if err != nil {
		return sample{}, err
	}
	raw, err := net.ListenPacket("udp4", "0.0.0.0:0")
	if err != nil {
		return sample{}, err
	}
	defer raw.Close()
	counted := &packetCounter{PacketConn: raw}
	cfg, err := quicprofile.ClientConfig(name, roots, "h3", mode)
	if err != nil {
		return sample{}, err
	}
	cfg.EncryptedClientHelloConfigList = ech
	client, err := quic.Dial(ctx, counted, dest, cfg, &quic.Config{EnableDatagrams: true})
	if err != nil {
		return sample{}, err
	}
	defer client.CloseWithError(0, "")
	state := client.ConnectionState().TLS
	if len(ech) != 0 && !state.ECHAccepted {
		return sample{}, fmt.Errorf("H3 ECH was not accepted")
	}
	if state.NegotiatedProtocol != "h3" {
		return sample{}, fmt.Errorf("expected h3, negotiated %q", state.NegotiatedProtocol)
	}
	return sample{time.Since(start), counted.sent.Load(), counted.received.Load(), quicprofile.Security(state)}, nil
}

func runRemote(address, name, ca, echFile, doh, dohName, dohIP string, n int, pairECH bool) error {
	if n < 1 || n > 1000 || name == "" {
		return fmt.Errorf("a positive sample count and certificate name are required")
	}
	var roots *x509.CertPool
	if ca != "" {
		pem, err := os.ReadFile(ca)
		if err != nil {
			return err
		}
		roots = x509.NewCertPool()
		if !roots.AppendCertsFromPEM(pem) {
			return fmt.Errorf("could not load CA bundle")
		}
	}
	var ech []byte
	if echFile != "" {
		var err error
		ech, err = os.ReadFile(echFile)
		if err != nil {
			return err
		}
		if len(ech) < 4 {
			return fmt.Errorf("invalid ECHConfigList")
		}
	}
	if doh != "" {
		if dohName == "" {
			dohName = name
		}
		_, port, err := net.SplitHostPort(address)
		if err != nil {
			return err
		}
		ctx, cancel := context.WithTimeout(context.Background(), 8*time.Second)
		start := time.Now()
		ip, err := resolveDoH(ctx, doh, dohName, dohIP, roots)
		cancel()
		if err != nil {
			return fmt.Errorf("entry DoH: %w", err)
		}
		fmt.Fprintf(os.Stderr, "entry DoH OK (%d us)\n", time.Since(start).Microseconds())
		address = net.JoinHostPort(ip.String(), port)
	}
	if pairECH {
		if len(ech) == 0 {
			return fmt.Errorf("paired testing requires an ECH configuration")
		}
		return runECHPairs(address, name, roots, ech, n)
	}
	modes := []string{"default", "x25519", "x25519mlkem768"}
	enc := json.NewEncoder(os.Stdout)
	for _, path := range []string{"h2/tcp", "h3/quic"} {
		buckets := make(map[string][]sample)
		for round := 0; round < n; round++ {
			for i := range modes {
				mode := modes[(round+i)%len(modes)]
				ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
				s, err := remoteHandshake(ctx, address, name, path, mode, roots, ech)
				cancel()
				if err != nil {
					fmt.Fprintf(os.Stderr, "%s %s: %v\n", path, mode, err)
					continue
				}
				buckets[mode] = append(buckets[mode], s)
			}
		}
		for _, mode := range modes {
			s := buckets[mode]
			if len(s) == 0 {
				if err := enc.Encode(map[string]any{"path": path, "mode": mode, "samples": 0, "attempts": n}); err != nil {
					return err
				}
				continue
			}
			row, err := summarize(path, mode, s)
			if err != nil {
				return err
			}
			if err := enc.Encode(struct {
				summary
				Attempts int  `json:"attempts"`
				ECH      bool `json:"ech_accepted"`
			}{row, n, len(ech) != 0}); err != nil {
				return err
			}
		}
	}
	return nil
}
