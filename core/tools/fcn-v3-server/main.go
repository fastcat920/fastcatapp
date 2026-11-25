// fcn-v3-server serves FCN v3 over HTTP/3 with an explicit TCP target allowlist.
package main

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/pem"
	"errors"
	"flag"
	"fmt"
	"io"
	"log"
	"net"
	"os"
	"os/signal"
	"syscall"

	"github.com/fastcat920/fcnv3"

	json "github.com/metacubex/jsonv2"
	"github.com/metacubex/mihomo/component/ech"
	"github.com/metacubex/mihomo/transport/tuic/common"
	"github.com/metacubex/quic-go"
	"github.com/metacubex/tls"
)

const maxPrivateFileSize = 64 * 1024

type credentialVersion struct {
	revision uint64
	digest   [sha256.Size]byte
}

func main() {
	if err := run(os.Args[1:]); err != nil {
		log.Print(err)
		os.Exit(1)
	}
}

func run(args []string) error {
	flags := flag.NewFlagSet("fcn-v3-server", flag.ContinueOnError)
	listen := flags.String("listen", "", "UDP listen address (host:port)")
	cert := flags.String("cert", "", "PEM TLS certificate chain")
	key := flags.String("key", "", "PEM TLS private key")
	credentialFile := flags.String("credentials-file", "", "owner-only JSON credentials file (0600)")
	echKeyFile := flags.String("ech-keys-file", "", "owner-only ECH KEYS PEM file (0600), enables mandatory ECH for CONNECT")
	echPublicCert := flags.String("ech-public-cert", "", "PEM TLS certificate chain for the ECH public name, if separate")
	echPublicKey := flags.String("ech-public-key", "", "PEM TLS private key for the ECH public name, if separate")
	adaptiveWrites := flags.Bool("adaptive-writes", false, "adapt TCP downlink write size")
	padding := flags.Bool("limited-padding", false, "opt in to bounded padding on small TCP replies")
	diagnosticTrace := flags.Bool("diagnostic-trace", false, "log summarized QUIC progress and recovery counters")
	udpIdle := flags.Duration("udp-idle-timeout", 0, "UDP association idle timeout (default 30s)")
	var targets, udpTargets []string
	flags.Func("udp-target", "allowed UDP destination as a literal IP:port (repeatable)", func(target string) error {
		udpTargets = append(udpTargets, target)
		return nil
	})
	flags.Func("target", "allowed TCP destination as a literal IP:port (repeatable)", func(target string) error {
		targets = append(targets, target)
		return nil
	})
	flags.Usage = func() {
		fmt.Fprintln(flags.Output(), "Usage: fcn-v3-server -listen :443 -cert chain.pem -key key.pem -credentials-file credentials.json -target 192.0.2.10:443")
		flags.PrintDefaults()
		fmt.Fprintln(flags.Output(), "The JSON document has a positive integer revision and a credentials array of {id, secret} objects.")
		fmt.Fprintln(flags.Output(), "Each secret is 64 hexadecimal characters. Publish a higher revision atomically and send SIGHUP to reload.")
		fmt.Fprintln(flags.Output(), "An empty credentials array revokes all credentials.")
		fmt.Fprintln(flags.Output(), "Replace the ECH keys file atomically and send SIGHUP to reload. The TLS certificates must cover the ECH public name.")
	}
	if err := flags.Parse(args); err != nil {
		if errors.Is(err, flag.ErrHelp) {
			return nil
		}
		return err
	}
	if flags.NArg() != 0 || *listen == "" || *cert == "" || *key == "" || *credentialFile == "" || len(targets)+len(udpTargets) == 0 {
		return errors.New("-listen, -cert, -key, -credentials-file and at least one -target or -udp-target are required. Use -help for details")
	}
	if (*echPublicCert == "") != (*echPublicKey == "") || (*echPublicCert != "" && *echKeyFile == "") {
		return errors.New("-ech-public-cert and -ech-public-key must be used together with -ech-keys-file")
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	hup := make(chan os.Signal, 1)
	signal.Notify(hup, syscall.SIGHUP)
	defer signal.Stop(hup)

	pair, err := tls.LoadX509KeyPair(*cert, *key)
	if err != nil {
		return fmt.Errorf("load TLS certificate and key: %w", err)
	}
	certificates := []tls.Certificate{pair}
	if *echPublicCert != "" {
		publicPair, err := tls.LoadX509KeyPair(*echPublicCert, *echPublicKey)
		if err != nil {
			return fmt.Errorf("load ECH public TLS certificate and key: %w", err)
		}
		certificates = append(certificates, publicPair)
	}
	var echKeys []tls.EncryptedClientHelloKey
	var echVersion [sha256.Size]byte
	if *echKeyFile != "" {
		echKeys, echVersion, err = readECHKeys(*echKeyFile)
		if err != nil {
			return err
		}
	}
	creds, version, err := readCredentials(*credentialFile)
	if err != nil {
		return err
	}
	packet, err := net.ListenPacket("udp", *listen)
	if err != nil {
		return fmt.Errorf("listen for FCN v3: %w", err)
	}
	defer packet.Close()
	config := fcnv3.ServerConfig{
		TLSConfig:      &tls.Config{Certificates: certificates},
		ConfigureQUIC:  func(q *quic.Conn) { common.SetCongestionController(q, "bbr", 0, "") },
		Credentials:    creds,
		Targets:        targets,
		ECHKeys:        echKeys,
		UDPTargets:     udpTargets,
		UDPIdleTimeout: *udpIdle,
		AdaptiveWrites: *adaptiveWrites,
		Padding:        *padding,
	}
	if *diagnosticTrace {
		config.QUICTrace = newDiagnosticTracer()
	}
	server, err := fcnv3.NewServer(config)
	if err != nil {
		return err
	}
	defer server.Close()

	serveErr := make(chan error, 1)
	go func() { serveErr <- server.Serve(packet) }()
	log.Printf("FCN v3 listening on %s with credential revision %d", packet.LocalAddr(), version.revision)
	if *echKeyFile != "" {
		log.Print("ECH required for FCN v3 CONNECT")
	}
	for {
		select {
		case <-ctx.Done():
			return nil
		case err := <-serveErr:
			return err
		case <-hup:
			next, err := reloadCredentials(server, *credentialFile, version)
			if err != nil {
				log.Printf("credential reload rejected at revision %d: %v", version.revision, err)
			} else if next != version {
				version = next
				log.Printf("loaded credential revision %d", version.revision)
			}
			if *echKeyFile != "" {
				nextECH, err := reloadECHKeys(server, *echKeyFile, echVersion)
				if err != nil {
					log.Printf("ECH key reload rejected: %v", err)
				} else if nextECH != echVersion {
					echVersion = nextECH
					log.Print("reloaded ECH keys")
				}
			}
		}
	}
}

func reloadCredentials(server *fcnv3.Server, path string, current credentialVersion) (credentialVersion, error) {
	creds, next, err := readCredentials(path)
	if err != nil {
		return current, err
	}
	if current == next {
		return current, nil
	}
	if next.revision <= current.revision {
		return current, errors.New("changed credentials require a higher revision")
	}
	if err := server.ReplaceCredentials(creds); err != nil {
		return current, err
	}
	return next, nil
}

func readCredentials(path string) ([]fcnv3.Credential, credentialVersion, error) {
	var version credentialVersion
	data, err := readPrivateFile(path, "credentials")
	if err != nil {
		return nil, version, err
	}
	var doc struct {
		Revision    uint64             `json:"revision"`
		Credentials []fcnv3.Credential `json:"credentials"`
	}
	if err := json.Unmarshal(data, &doc, json.RejectUnknownMembers(true)); err != nil {
		return nil, version, errors.New("invalid credentials JSON")
	}
	if doc.Revision == 0 || doc.Credentials == nil {
		return nil, version, errors.New("credentials JSON requires a positive revision and a credentials array")
	}
	return doc.Credentials, credentialVersion{revision: doc.Revision, digest: sha256.Sum256(data)}, nil
}

func reloadECHKeys(server *fcnv3.Server, path string, current [sha256.Size]byte) ([sha256.Size]byte, error) {
	keys, next, err := readECHKeys(path)
	if err != nil || current == next {
		return current, err
	}
	if err := server.ReplaceECHKeys(keys); err != nil {
		return current, err
	}
	return next, nil
}

func readECHKeys(path string) ([]tls.EncryptedClientHelloKey, [sha256.Size]byte, error) {
	var version [sha256.Size]byte
	data, err := readPrivateFile(path, "ECH keys")
	if err != nil {
		return nil, version, err
	}
	encoded := bytes.TrimSpace(data)
	const begin = "-----BEGIN ECH KEYS-----"
	if !bytes.HasPrefix(encoded, []byte(begin)) || bytes.Count(encoded, []byte(begin)) != 1 {
		return nil, version, errors.New("invalid ECH KEYS PEM")
	}
	block, rest := pem.Decode(encoded)
	if block == nil || block.Type != "ECH KEYS" || len(block.Headers) != 0 || len(bytes.TrimSpace(rest)) != 0 {
		return nil, version, errors.New("invalid ECH KEYS PEM")
	}
	keys, err := ech.UnmarshalECHKeys(block.Bytes)
	if err != nil {
		return nil, version, fmt.Errorf("invalid ECH key set: %w", err)
	}
	return keys, sha256.Sum256(data), nil
}

func readPrivateFile(path, label string) ([]byte, error) {
	fd, err := syscall.Open(path, syscall.O_RDONLY|syscall.O_NOFOLLOW|syscall.O_NONBLOCK|syscall.O_CLOEXEC, 0)
	if err != nil {
		return nil, fmt.Errorf("cannot open %s file", label)
	}
	file := os.NewFile(uintptr(fd), path)
	defer file.Close()
	info, err := file.Stat()
	if err != nil || info.Mode() != 0600 {
		return nil, fmt.Errorf("%s file must be a regular file with mode 0600", label)
	}
	if stat, ok := info.Sys().(*syscall.Stat_t); !ok || stat.Uid != uint32(os.Geteuid()) {
		return nil, fmt.Errorf("%s file must be owned by the server user", label)
	}
	data, err := io.ReadAll(io.LimitReader(file, maxPrivateFileSize+1))
	if err != nil || len(data) > maxPrivateFileSize {
		return nil, fmt.Errorf("%s file unreadable or larger than 64 KiB", label)
	}
	return data, nil
}
