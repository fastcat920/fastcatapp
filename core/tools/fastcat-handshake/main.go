// Compare fresh FastCat gateway handshakes on this device's loopback interface.
package main

import (
	"context"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"math/big"
	"net"
	"os"
	"runtime"
	"sort"
	"sync/atomic"
	"time"

	"github.com/metacubex/mihomo/component/fastcattls"
	"github.com/metacubex/mihomo/component/fastcattls/quicprofile"
	quic "github.com/metacubex/quic-go"
	qtls "github.com/metacubex/tls"
)

type certificate struct {
	chain [][]byte
	key   *ecdsa.PrivateKey
	roots *x509.CertPool
}

func localCertificate() (certificate, error) {
	key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		return certificate{}, err
	}
	now := time.Now()
	template := &x509.Certificate{SerialNumber: big.NewInt(1), NotBefore: now.Add(-time.Hour), NotAfter: now.Add(time.Hour), DNSNames: []string{"localhost"}, KeyUsage: x509.KeyUsageDigitalSignature, ExtKeyUsage: []x509.ExtKeyUsage{x509.ExtKeyUsageServerAuth}}
	der, err := x509.CreateCertificate(rand.Reader, template, template, &key.PublicKey, key)
	if err != nil {
		return certificate{}, err
	}
	cert, err := x509.ParseCertificate(der)
	if err != nil {
		return certificate{}, err
	}
	roots := x509.NewCertPool()
	roots.AddCert(cert)
	return certificate{[][]byte{der}, key, roots}, nil
}

type streamCounter struct {
	net.Conn
	sent, received int64
}

func (c *streamCounter) Write(p []byte) (int, error) {
	n, e := c.Conn.Write(p)
	c.sent += int64(n)
	return n, e
}
func (c *streamCounter) Read(p []byte) (int, error) {
	n, e := c.Conn.Read(p)
	c.received += int64(n)
	return n, e
}

type packetCounter struct {
	net.PacketConn
	sent, received atomic.Int64
}

func (c *packetCounter) WriteTo(p []byte, a net.Addr) (int, error) {
	n, e := c.PacketConn.WriteTo(p, a)
	c.sent.Add(int64(n))
	return n, e
}
func (c *packetCounter) ReadFrom(p []byte) (int, net.Addr, error) {
	n, a, e := c.PacketConn.ReadFrom(p)
	c.received.Add(int64(n))
	return n, a, e
}

type sample struct {
	took           time.Duration
	sent, received int64
	security       fastcattls.Negotiated
}

func handshakeTCP(ctx context.Context, cert certificate, mode string) (sample, error) {
	listener, err := net.Listen("tcp4", "127.0.0.1:0")
	if err != nil {
		return sample{}, err
	}
	defer listener.Close()
	server := &tls.Config{NextProtos: []string{"h2"}, Certificates: []tls.Certificate{{Certificate: cert.chain, PrivateKey: cert.key}}, SessionTicketsDisabled: true}
	config, err := quicprofile.ClientConfig("localhost", cert.roots, "h2", mode)
	if err != nil {
		return sample{}, err
	}
	if err = fastcattls.Apply(server, "default"); err != nil {
		return sample{}, err
	}
	done := make(chan error, 1)
	go func() {
		conn, err := listener.Accept()
		if err == nil {
			defer conn.Close()
			err = tls.Server(conn, server).HandshakeContext(ctx)
		}
		done <- err
	}()
	raw, err := new(net.Dialer).DialContext(ctx, "tcp4", listener.Addr().String())
	if err != nil {
		return sample{}, err
	}
	defer raw.Close()
	stream := &streamCounter{Conn: raw}
	client := qtls.Client(stream, config)
	start := time.Now()
	if err = client.HandshakeContext(ctx); err != nil {
		return sample{}, err
	}
	select {
	case err = <-done:
	case <-ctx.Done():
		err = ctx.Err()
	}
	if err != nil {
		return sample{}, err
	}
	state := client.ConnectionState()
	if state.NegotiatedProtocol != "h2" || state.DidResume {
		return sample{}, errors.New("expected fresh h2 handshake")
	}
	return sample{time.Since(start), stream.sent, stream.received, quicprofile.Security(state)}, nil
}

func handshakeQUIC(ctx context.Context, cert certificate, mode string) (sample, error) {
	server := &qtls.Config{NextProtos: []string{"h3"}, Certificates: []qtls.Certificate{{Certificate: cert.chain, PrivateKey: cert.key}}, SessionTicketsDisabled: true}
	config := &qtls.Config{NextProtos: []string{"h3"}, RootCAs: cert.roots, ServerName: "localhost"}
	if err := quicprofile.ApplyQUIC(server, "default"); err != nil {
		return sample{}, err
	}
	if err := quicprofile.ApplyQUIC(config, mode); err != nil {
		return sample{}, err
	}
	udp, err := net.ListenPacket("udp4", "127.0.0.1:0")
	if err != nil {
		return sample{}, err
	}
	defer udp.Close()
	listener, err := quic.Listen(udp, server, &quic.Config{EnableDatagrams: true})
	if err != nil {
		return sample{}, err
	}
	defer listener.Close()
	socket, err := net.ListenPacket("udp4", "127.0.0.1:0")
	if err != nil {
		return sample{}, err
	}
	defer socket.Close()
	packets := &packetCounter{PacketConn: socket}
	start := time.Now()
	client, err := quic.Dial(ctx, packets, listener.Addr(), config, &quic.Config{EnableDatagrams: true})
	if err != nil {
		return sample{}, err
	}
	defer client.CloseWithError(0, "")
	peer, err := listener.Accept(ctx)
	if err != nil {
		return sample{}, err
	}
	defer peer.CloseWithError(0, "")
	state := client.ConnectionState().TLS
	if state.NegotiatedProtocol != "h3" || state.DidResume {
		return sample{}, errors.New("expected fresh h3 handshake")
	}
	return sample{time.Since(start), packets.sent.Load(), packets.received.Load(), quicprofile.Security(state)}, nil
}

type summary struct {
	Path           string  `json:"path"`
	Mode           string  `json:"mode"`
	Version        string  `json:"tls"`
	Group          string  `json:"group"`
	Cipher         string  `json:"cipher"`
	Samples        int     `json:"samples"`
	MedianUS       float64 `json:"p50_us"`
	P95US          int64   `json:"p95_us"`
	MedianSent     float64 `json:"p50_client_bytes_sent"`
	MedianReceived float64 `json:"p50_client_bytes_received"`
}

func median(v []int64) float64 {
	sort.Slice(v, func(i, j int) bool { return v[i] < v[j] })
	return float64(v[(len(v)-1)/2]+v[len(v)/2]) / 2
}
func summarize(path, mode string, samples []sample) (summary, error) {
	first := samples[0].security
	if first.Version != "TLS 1.3" || first.Cipher == "" || first.Group == "" {
		return summary{}, fmt.Errorf("negotiated group unavailable on %s", runtime.Version())
	}
	expected := map[string]string{"x25519": "X25519", "x25519mlkem768": "X25519MLKEM768"}[mode]
	if expected != "" && expected != first.Group {
		return summary{}, fmt.Errorf("negotiated %s, expected %s", first.Group, expected)
	}
	var durations, up, down []int64
	for _, s := range samples {
		if s.security != first {
			return summary{}, errors.New("inconsistent negotiated parameters")
		}
		durations = append(durations, s.took.Microseconds())
		up = append(up, s.sent)
		down = append(down, s.received)
	}
	p50 := median(durations)
	return summary{path, mode, first.Version, first.Group, first.Cipher, len(samples), p50, durations[(len(samples)*95+99)/100-1], median(up), median(down)}, nil
}
func run(n int) error {
	if n < 1 || n > 1000 {
		return errors.New("samples must be between 1 and 1000")
	}
	cert, err := localCertificate()
	if err != nil {
		return err
	}
	var results []summary
	for _, path := range []string{"h2/tcp", "h3/quic"} {
		measure := handshakeTCP
		if path == "h3/quic" {
			measure = handshakeQUIC
		}
		var samples [2][]sample
		modes := []string{"x25519", "x25519mlkem768"}
		for round := 0; round < n; round++ {
			for step := 0; step < 2; step++ {
				i := (round + step) % 2
				ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
				s, err := measure(ctx, cert, modes[i])
				cancel()
				if err != nil {
					return fmt.Errorf("%s %s: %w", path, modes[i], err)
				}
				samples[i] = append(samples[i], s)
			}
		}
		for i, mode := range modes {
			row, err := summarize(path, mode, samples[i])
			if err != nil {
				return err
			}
			results = append(results, row)
		}
	}
	enc := json.NewEncoder(os.Stdout)
	enc.SetIndent("", "  ")
	return enc.Encode(struct {
		GOOS    string    `json:"os"`
		GOARCH  string    `json:"arch"`
		Go      string    `json:"go"`
		Results []summary `json:"results"`
	}{runtime.GOOS, runtime.GOARCH, runtime.Version(), results})
}
func main() {
	n := flag.Int("samples", 31, "fresh handshakes per mode and transport")
	remote := flag.String("remote", "", "public address:port to measure")
	name := flag.String("server-name", "", "certificate name for remote measurements")
	ca := flag.String("ca", "", "optional remote CA bundle PEM")
	ech := flag.String("ech-list", "", "binary ECHConfigList for strict remote testing")
	doh := flag.String("doh", "", "HTTPS DNS endpoint for remote IPv4 bootstrap")
	dohName := flag.String("doh-name", "", "optional entry lookup name distinct from certificate name")
	dohIP := flag.String("doh-ip", "", "optional HTTPS resolver bootstrap IP")
	dohTrials := flag.Bool("doh-trials", false, "measure fresh and reused DoH connections without a tunnel handshake")
	pairECH := flag.Bool("pair-ech", false, "alternate baseline and ECH with the default key exchange")
	quicTail := flag.Bool("quic-tail", false, "compare QUIC Initial packet sizes and emit per-handshake trace IDs")
	flag.Parse()
	var err error
	if *quicTail {
		err = runQUICTail(*remote, *name, *ech, *ca, *n)
	} else if *dohTrials {
		err = runDoHTrials(*doh, *dohName, *dohIP, *ca, *n)
	} else if *remote != "" {
		err = runRemote(*remote, *name, *ca, *ech, *doh, *dohName, *dohIP, *n, *pairECH)
	} else {
		err = run(*n)
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
