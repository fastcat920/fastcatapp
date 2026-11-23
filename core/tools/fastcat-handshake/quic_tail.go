package main

import (
	"context"
	"crypto/x509"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"os"
	"time"

	"github.com/metacubex/mihomo/component/fastcattls/quicprofile"
	quic "github.com/metacubex/quic-go"
	"github.com/metacubex/quic-go/qlog"
	"github.com/metacubex/quic-go/qlogwriter"
)

func runQUICTail(address, name, listFile, caFile string, samples int) error {
	if address == "" || name == "" || listFile == "" || samples < 1 || samples > 1000 {
		return errors.New("QUIC tail testing requires a remote address, hostname, ECH config, and 1–1000 samples")
	}
	list, err := os.ReadFile(listFile)
	if err != nil {
		return err
	}
	if len(list) < 4 {
		return errors.New("invalid ECHConfigList")
	}
	var roots *x509.CertPool
	if caFile != "" {
		pem, err := os.ReadFile(caFile)
		if err != nil {
			return err
		}
		roots = x509.NewCertPool()
		if !roots.AppendCertsFromPEM(pem) {
			return errors.New("could not load CA bundle")
		}
	}
	peer, err := net.ResolveUDPAddr("udp4", address)
	if err != nil {
		return err
	}
	modes := []struct {
		name string
		ech  []byte
		size uint16
	}{
		{"baseline", nil, 0},
		{"ech", list, 0},
		{"ech-1200", list, 1200},
	}
	enc := json.NewEncoder(os.Stdout)
	for round := 0; round < samples; round++ {
		for i := range modes {
			mode := modes[(round+i)%len(modes)]
			cfg, err := quicprofile.ClientConfig(name, roots, "h3", "default")
			if err != nil {
				return err
			}
			cfg.EncryptedClientHelloConfigList = mode.ech
			packet, err := net.ListenPacket("udp4", "0.0.0.0:0")
			if err != nil {
				return err
			}
			counted := &packetCounter{PacketConn: packet}
			result := struct {
				Round   int    `json:"round"`
				Mode    string `json:"mode"`
				Trace   string `json:"trace"`
				Elapsed int64  `json:"elapsed_us"`
				Sent    int64  `json:"sent"`
				Read    int64  `json:"received"`
				Error   string `json:"error,omitempty"`
			}{Round: round + 1, Mode: mode.name}
			config := &quic.Config{
				EnableDatagrams: true, InitialPacketSize: mode.size,
				Tracer: func(ctx context.Context, client bool, id quic.ConnectionID) qlogwriter.Trace {
					result.Trace = id.String()
					return qlog.DefaultConnectionTracer(ctx, client, id)
				},
			}
			ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
			start := time.Now()
			conn, err := quic.Dial(ctx, counted, peer, cfg, config)
			result.Elapsed = time.Since(start).Microseconds()
			result.Sent, result.Read = counted.sent.Load(), counted.received.Load()
			cancel()
			if conn != nil {
				state := conn.ConnectionState().TLS
				if len(mode.ech) != 0 && !state.ECHAccepted {
					err = fmt.Errorf("gateway did not accept ECH")
				}
				if err == nil && state.NegotiatedProtocol != "h3" {
					err = fmt.Errorf("unexpected gateway ALPN %q", state.NegotiatedProtocol)
				}
				conn.CloseWithError(0, "")
			}
			packet.Close()
			if err != nil {
				result.Error = err.Error()
			}
			if err := enc.Encode(result); err != nil {
				return err
			}
		}
	}
	return nil
}
