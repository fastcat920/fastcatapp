package main

import (
	"context"
	"crypto/ecdh"
	"crypto/rand"
	"crypto/tls"
	"net"
	"testing"
	"time"

	quic "github.com/metacubex/quic-go"
	qtls "github.com/metacubex/tls"
	"golang.org/x/crypto/cryptobyte"
)

func TestECHOnGatewayTLSStacks(t *testing.T) {
	// Ephemeral lab material. localhost is the certificate name and the
	// public name exists only in this experiment's outer ClientHello.
	key, err := ecdh.X25519().GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	var config cryptobyte.Builder
	config.AddUint16(0xfe0d)
	config.AddUint16LengthPrefixed(func(b *cryptobyte.Builder) {
		b.AddUint8(1)
		b.AddUint16(0x0020)
		b.AddUint16LengthPrefixed(func(b *cryptobyte.Builder) { b.AddBytes(key.PublicKey().Bytes()) })
		b.AddUint16LengthPrefixed(func(b *cryptobyte.Builder) { b.AddUint16(1); b.AddUint16(1) })
		b.AddUint8(32)
		b.AddUint8LengthPrefixed(func(b *cryptobyte.Builder) { b.AddBytes([]byte("public.example")) })
		b.AddUint16(0)
	})
	rawConfig := config.BytesOrPanic()
	var list cryptobyte.Builder
	list.AddUint16LengthPrefixed(func(b *cryptobyte.Builder) { b.AddBytes(rawConfig) })
	configList := list.BytesOrPanic()
	cert, err := localCertificate()
	if err != nil {
		t.Fatal(err)
	}
	t.Run("H2", func(t *testing.T) {
		ctx, cancel := context.WithTimeout(context.Background(), 4*time.Second)
		defer cancel()
		clientConn, serverConn := net.Pipe()
		defer clientConn.Close()
		defer serverConn.Close()
		server := tls.Server(serverConn, &tls.Config{
			MinVersion: tls.VersionTLS13, NextProtos: []string{"h2"},
			Certificates:             []tls.Certificate{{Certificate: cert.chain, PrivateKey: cert.key}},
			EncryptedClientHelloKeys: []tls.EncryptedClientHelloKey{{Config: rawConfig, PrivateKey: key.Bytes()}},
		})
		done := make(chan error, 1)
		go func() { done <- server.HandshakeContext(ctx) }()
		client := tls.Client(clientConn, &tls.Config{
			MinVersion: tls.VersionTLS13, NextProtos: []string{"h2"}, ServerName: "localhost",
			RootCAs: cert.roots, EncryptedClientHelloConfigList: configList,
		})
		if err := client.HandshakeContext(ctx); err != nil {
			t.Fatal(err)
		}
		if err := <-done; err != nil {
			t.Fatal(err)
		}
		if state := client.ConnectionState(); !state.ECHAccepted || state.NegotiatedProtocol != "h2" {
			t.Fatal("H2 did not negotiate ECH")
		}
	})
	t.Run("H3", func(t *testing.T) {
		ctx, cancel := context.WithTimeout(context.Background(), 4*time.Second)
		defer cancel()
		serverSocket, err := net.ListenPacket("udp4", "127.0.0.1:0")
		if err != nil {
			t.Fatal(err)
		}
		defer serverSocket.Close()
		server, err := quic.Listen(serverSocket, &qtls.Config{
			MinVersion: qtls.VersionTLS13, NextProtos: []string{"h3"},
			Certificates:             []qtls.Certificate{{Certificate: cert.chain, PrivateKey: cert.key}},
			EncryptedClientHelloKeys: []qtls.EncryptedClientHelloKey{{Config: rawConfig, PrivateKey: key.Bytes()}},
		}, nil)
		if err != nil {
			t.Fatal(err)
		}
		defer server.Close()
		clientSocket, err := net.ListenPacket("udp4", "127.0.0.1:0")
		if err != nil {
			t.Fatal(err)
		}
		defer clientSocket.Close()
		conn, err := quic.Dial(ctx, clientSocket, server.Addr(), &qtls.Config{
			MinVersion: qtls.VersionTLS13, NextProtos: []string{"h3"}, ServerName: "localhost",
			RootCAs: cert.roots, EncryptedClientHelloConfigList: configList,
		}, nil)
		if err != nil {
			t.Fatal(err)
		}
		defer conn.CloseWithError(0, "")
		if state := conn.ConnectionState().TLS; !state.ECHAccepted || state.NegotiatedProtocol != "h3" {
			t.Fatal("H3 did not negotiate ECH")
		}
	})
}
