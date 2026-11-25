package main

import (
	"context"
	"fmt"
	"net"
	"strconv"

	"github.com/fastcat920/fcnv3"
	"github.com/metacubex/mihomo/adapter/outbound"
	"github.com/metacubex/mihomo/component/ca"
	"github.com/metacubex/mihomo/component/dialer"
	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/transport/tuic/common"
	"github.com/metacubex/quic-go"
)

type benchClient struct {
	dial  func(context.Context, string) (net.Conn, error)
	warm  func(context.Context) error
	close func()
}

type clientFactory func() (benchClient, error)

// Constructors, handshakes and connection setup remain inside each cold
// sample's budget. The native FCN adapter loads its own custom CA.
func newFactory(cfg config, protocol string) (clientFactory, error) {
	if protocol == "fcnv3" {
		clientConfig, err := phaseFCNConfig(cfg)
		if err != nil {
			return nil, err
		}
		return func() (benchClient, error) {
			c, err := fcnv3.NewClient(clientConfig)
			if err != nil {
				return benchClient{}, err
			}
			return benchClient{dial: c.Dial, warm: c.Warm, close: func() { c.Close() }}, nil
		}, nil
	}
	if err := prepareBenchmarkAdapter(cfg, protocol); err != nil {
		return nil, err
	}
	return func() (benchClient, error) {
		tracker := new(trackedDialer)
		a, err := newBenchmarkAdapter(cfg, protocol, tracker)
		if err != nil {
			tracker.Close()
			return benchClient{}, err
		}
		return benchClient{dial: func(ctx context.Context, target string) (net.Conn, error) {
			h, p, err := net.SplitHostPort(target)
			if err != nil {
				return nil, err
			}
			port, err := strconv.ParseUint(p, 10, 16)
			if err != nil {
				return nil, err
			}
			return a.DialContext(ctx, &C.Metadata{NetWork: C.TCP, Host: h, DstPort: uint16(port)})
		}, close: func() { a.Close(); tracker.Close() }}, nil
	}, nil
}

// TUIC and Hysteria2 use the native shared root store. Prepare it before the
// timed sample or UDP association so it remains read-only for active clients.
func prepareBenchmarkAdapter(cfg config, protocol string) error {
	if protocol != "tuic" && protocol != "hysteria2" {
		return nil
	}
	_, pem, err := readRoots(cfg.endpointFor(protocol).CAFile)
	if err != nil || len(pem) == 0 {
		return err
	}
	return ca.AddCertificate(string(pem))
}

func newBenchmarkAdapter(cfg config, protocol string, tracker *trackedDialer) (C.ProxyAdapter, error) {
	endpoint := cfg.endpointFor(protocol)
	if endpoint == nil {
		return nil, fmt.Errorf("unsupported benchmark adapter protocol %q", protocol)
	}
	host, portText, err := net.SplitHostPort(endpoint.Endpoint)
	if err != nil {
		return nil, err
	}
	port, err := strconv.Atoi(portText)
	if err != nil {
		return nil, err
	}
	basic := outbound.BasicOption{DialerForAPI: tracker}
	name := "fcn-v3-benchmark-" + protocol
	switch protocol {
	case "fcnv1", "fcnv2":
		version, account := 1, cfg.FCNv1.UUID
		if protocol == "fcnv2" {
			version, account = 2, cfg.FCNv2.UUID
		}
		return outbound.NewFCN(outbound.FCNOption{
			BasicOption: basic, Name: name, Server: host, Port: port, SNI: endpoint.ServerName,
			UUID: account, Version: version, UDP: true, CAFile: endpoint.CAFile,
		})
	case "tuic":
		return outbound.NewTuic(outbound.TuicOption{
			BasicOption: basic, Name: name, Server: host, Port: port, SNI: endpoint.ServerName,
			UUID: cfg.TUIC.UUID, Password: cfg.TUIC.Password, CongestionController: "bbr", ReduceRtt: false, FastOpen: false,
		})
	case "hysteria2":
		return outbound.NewHysteria2(outbound.Hysteria2Option{
			BasicOption: basic, Name: name, Server: host, Port: port, SNI: endpoint.ServerName, Password: cfg.Hysteria2.Password,
		})
	default:
		return nil, fmt.Errorf("unsupported benchmark adapter protocol %q", protocol)
	}
}

func phaseFCNConfig(cfg config) (fcnv3.Config, error) {
	roots, _, err := readRoots(cfg.FCNv3.CAFile)
	if err != nil {
		return fcnv3.Config{}, err
	}
	var entryDNS fcnv3.EntryDNSResolver
	if doh := cfg.FCNv3.EntryDoH; doh != nil {
		entryDNS, err = fcnv3.NewEntryDNSResolver(fcnv3.EntryDNSConfig{
			URL: doh.URL, BootstrapIP: doh.BootstrapIP, RootCAs: roots, DialContext: func(ctx context.Context, network, address string) (net.Conn, error) {
				return dialer.DialContext(ctx, network, address)
			},
		})
		if err != nil {
			return fcnv3.Config{}, err
		}
	}
	return fcnv3.Config{Endpoint: cfg.FCNv3.Endpoint, ServerName: cfg.FCNv3.ServerName, Account: cfg.FCNv3.Account, Secret: cfg.FCNv3.Secret, Roots: roots, EntryDNS: entryDNS, ConfigureQUIC: func(q *quic.Conn) { common.SetCongestionController(q, "bbr", 0, "") }}, nil
}
