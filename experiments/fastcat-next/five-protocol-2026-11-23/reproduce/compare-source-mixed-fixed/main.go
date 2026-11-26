// Compare FastCat v2 and v3 through the same network and HTTPS target.
package main

import (
	"bufio"
	"context"
	"crypto/tls"
	"crypto/x509"
	"encoding/hex"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"github.com/metacubex/mihomo/adapter/outbound"
	"github.com/metacubex/mihomo/component/ca"
	C "github.com/metacubex/mihomo/constant"
	clog "github.com/metacubex/mihomo/log"
	"net"
	"net/http"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"

	next "core/fastcatnext"
	v3 "core/fastcatv3"
	h2 "github.com/metacubex/mihomo/transport/fastcath2"
	h3 "github.com/metacubex/mihomo/transport/fastcath3"
	qtls "github.com/metacubex/tls"
)

var diagnosticMu sync.Mutex
var nextCoalesceOpen bool
var nextQUICProfile string
var nextTraceEnabled bool
var transportSnapshots bool
var laneDiagnostics bool
var prefixTrace bool
var nextLocalPort int
var nextEntryBudget time.Duration

type configuration struct {
	NextPrefixRedundancy                                              bool
	NextRecoveryAware                                                 bool
	NextOptimizedAddress, NextOptimizedProfile                        string
	NextOptimizedCoalesce                                             bool
	NextOptimizedConnections                                          int
	NextOptimizedAdaptive                                             bool
	NextAddress, NextAccount, NextSecret, V2BBRAddress                string
	BulkTLSName                                                       string
	TargetTLSName                                                     string
	HysteriaAddress, TuicAddress, AnyAddress                          string
	HysteriaPassword, TuicUUID, AnyPassword                           string
	V2Address, V3Address, IndependentAddress, ServerName, V2Token, CA string
	V3                                                                v3.Config
	VlessAddress, TrojanAddress, UUID, TrojanPassword                 string
}
type client struct {
	downloadProgress func(int)
	dial             func(context.Context, string) (net.Conn, error)
	close            func()
	warm             func(context.Context) error
	stats            func() any
}
type sample struct {
	TransportBefore *next.TransportObservation `json:"transport_before,omitempty"`
	TransportTLS    *next.TransportObservation `json:"transport_tls,omitempty"`
	TransportEnd    *next.TransportObservation `json:"transport_end,omitempty"`
	Lane            *next.LaneObservation      `json:"lane,omitempty"`
	IdleUS          int64                      `json:"idle_us,omitempty"`
	Start           int64                      `json:"start_unix_us"`
	ClientReady     int64                      `json:"client_ready_us"`
	Pool            int                        `json:"pool"`
	Phase           string                     `json:"phase"`
	Protocol        string                     `json:"protocol"`
	Version         string                     `json:"version"`
	Round           int                        `json:"round"`
	Worker          int                        `json:"worker"`
	Entry           int64                      `json:"entry_us"`
	TargetTLS       int64                      `json:"target_tls_us"`
	Response        int64                      `json:"response_us"`
	First           int64                      `json:"first_byte_us"`
	Elapsed         int64                      `json:"elapsed_us"`
	Error           string                     `json:"error,omitempty"`
	GatewayTLS      string                     `json:"gateway_tls,omitempty"`
	GatewayCipher   string                     `json:"gateway_cipher,omitempty"`
	GatewayALPN     string                     `json:"gateway_alpn,omitempty"`
}

func main() {
	if e := run(); e != nil {
		fmt.Fprintln(os.Stderr, e)
		os.Exit(1)
	}
}
func newClient(ctx context.Context, c configuration, roots *x509.CertPool, version, protocol string) (client, error) {
	if version == "tuic-dual" {
		return newDualTUIC(ctx, c, roots)
	}
	if version == "next" || version == "next-h2" || version == "next-quic" || version == "next-base" || version == "next-opt" || version == "next-fixed" || (version == "next-primary" || (version == "next-latency" || version == "next-reserve")) {
		key, e := hex.DecodeString(c.NextSecret)
		if e != nil {
			return client{}, e
		}
		var laneTrace func(next.LaneEvent)
		if laneDiagnostics {
			laneTrace = func(event next.LaneEvent) {
				diagnosticMu.Lock()
				defer diagnosticMu.Unlock()
				json.NewEncoder(os.Stderr).Encode(map[string]any{"phase": "lane_event", "version": version, "event": event})
			}
		}
		var trace next.Trace
		if nextTraceEnabled {
			trace = func(e next.Event) {
				e.AtUnixUS = time.Now().UnixMicro()
				diagnosticMu.Lock()
				defer diagnosticMu.Unlock()
				json.NewEncoder(os.Stderr).Encode(e)
			}
		}
		endpoint, profile, coalesce := c.NextAddress, nextQUICProfile, nextCoalesceOpen
		if version == "next-base" {
			profile = "baseline"
			coalesce = false
		}
		if version == "next-opt" || version == "next-fixed" || (version == "next-primary" || (version == "next-latency" || version == "next-reserve")) {
			endpoint = c.NextOptimizedAddress
			profile = c.NextOptimizedProfile
			coalesce = c.NextOptimizedCoalesce
		}
		connections := 1
		if version == "next-opt" || version == "next-fixed" || (version == "next-primary" || (version == "next-latency" || version == "next-reserve")) {
			connections = c.NextOptimizedConnections
		}
		adaptive := (version == "next-opt" || (version == "next-primary" || (version == "next-latency" || version == "next-reserve"))) && c.NextOptimizedAdaptive
		if version == "next-primary" || (version == "next-latency" || version == "next-reserve") {
			connections = 2
			adaptive = true
		}
		cl, e := next.NewClient(ctx, next.Config{PrefixRedundancy: c.NextPrefixRedundancy && version == "next-opt", RecoveryAware: c.NextRecoveryAware && version == "next-opt", LocalUDPPort: nextLocalPort, PrimaryPreferred: version == "next-primary", LatencyAware: (version == "next-latency" || version == "next-reserve"), ReserveInteractive: version == "next-reserve", ScheduleHysteresis: version == "next-reserve", PrefixTrace: prefixTrace, LaneTrace: laneTrace, AdaptiveLanes: adaptive, QUICLanes: connections, Endpoint: endpoint, ServerName: c.ServerName, Account: c.NextAccount, Key: key, Roots: roots, Congestion: "bbr", QUICProfile: profile, CoalesceOpen: coalesce, Trace: trace, ConnectTimeout: nextEntryBudget}, protocol)
		if e != nil {
			return client{}, e
		}
		return client{dial: cl.Dial, close: cl.Close, warm: cl.Warm, stats: func() any { return cl.LaneUsage() }}, nil
	}
	if version == "v2-bbr" {
		c.V2Address = c.V2BBRAddress
	}
	if nativeVersion(version) {
		address := c.VlessAddress
		switch version {
		case "trojan":
			address = c.TrojanAddress
		case "hysteria2":
			address = c.HysteriaAddress
		case "tuic":
			address = c.TuicAddress
		case "anytls":
			address = c.AnyAddress
		}
		host, portText, err := net.SplitHostPort(address)
		if err != nil {
			return client{}, err
		}
		port, err := strconv.Atoi(portText)
		if err != nil {
			return client{}, err
		}
		var a C.ProxyAdapter
		tracker := new(trackedDialer)
		basic := outbound.BasicOption{DialerForAPI: tracker}
		switch version {
		case "vless-vision":
			a, err = outbound.NewVless(outbound.VlessOption{BasicOption: basic, Name: "lab-vless", Server: host, Port: port, UUID: c.UUID, Flow: "xtls-rprx-vision", TLS: true, ServerName: c.ServerName, Network: "tcp"})
		case "trojan":
			a, err = outbound.NewTrojan(outbound.TrojanOption{BasicOption: basic, Name: "lab-trojan", Server: host, Port: port, Password: c.TrojanPassword, SNI: c.ServerName, Network: "tcp"})
		case "hysteria2":
			a, err = outbound.NewHysteria2(outbound.Hysteria2Option{BasicOption: basic, Name: "lab-hy2", Server: host, Port: port, Password: c.HysteriaPassword, SNI: c.ServerName})
		case "tuic":
			a, err = outbound.NewTuic(outbound.TuicOption{BasicOption: basic, Name: "lab-tuic", Server: host, Port: port, UUID: c.TuicUUID, Password: c.TuicUUID, SNI: c.ServerName, CongestionController: "bbr", ReduceRtt: false, FastOpen: false})
		case "anytls":
			a, err = outbound.NewAnyTLS(outbound.AnyTLSOption{BasicOption: basic, Name: "lab-anytls", Server: host, Port: port, Password: c.AnyPassword, SNI: c.ServerName})
		}
		if err != nil {
			return client{}, err
		}
		return client{dial: func(ctx context.Context, target string) (net.Conn, error) {
			h, p, e := net.SplitHostPort(target)
			if e != nil {
				return nil, e
			}
			n, e := strconv.ParseUint(p, 10, 16)
			if e != nil {
				return nil, e
			}
			return a.DialContext(ctx, &C.Metadata{NetWork: C.TCP, Host: h, DstPort: uint16(n)})
		}, close: func() { a.Close(); tracker.Close() }}, nil
	}

	if version == "v3-light" || version == "v3-sealed" || version == "v3-light-fast" {
		mode := v3.IndependentLight
		if version == "v3-light-fast" {
			mode = v3.IndependentPipelined
		}
		if version == "v3-sealed" {
			mode = v3.IndependentSealed
		}
		s, e := v3.DialIndependent(ctx, v3.DialConfig{Config: c.V3, Endpoint: c.IndependentAddress, ServerName: c.ServerName, Roots: roots}, protocol, mode)
		if e != nil {
			return client{}, e
		}
		return client{dial: s.Dial, close: func() { s.Close() }}, nil
	}
	if version == "v3" {
		s, e := v3.Dial(ctx, v3.DialConfig{Config: c.V3, Endpoint: c.V3Address, ServerName: c.ServerName, Roots: roots}, protocol)
		if e != nil {
			return client{}, e
		}
		return client{dial: func(ctx context.Context, target string) (net.Conn, error) {
			conn, err := s.Open(ctx, 0, target)
			if err != nil {
				return nil, fmt.Errorf("%w (session: %v)", err, s.Err())
			}
			return conn, nil
		}, close: func() { s.Close() }}, nil
	}
	if protocol == "h2" {
		s, e := h2.NewContext(ctx, h2.Config{Endpoint: c.V2Address, ServerName: c.ServerName, Token: c.V2Token, RootCAs: roots})
		if e != nil {
			return client{}, e
		}
		return client{dial: s.Dial, close: func() { s.Close() }, warm: s.Warm}, nil
	}
	cc := ""
	if version == "v2-bbr" {
		cc = "bbr"
	}
	s, e := h3.NewContext(ctx, h3.Config{Congestion: cc, Endpoint: c.V2Address, ServerName: c.ServerName, Token: c.V2Token, RootCAs: roots})
	if e != nil {
		return client{}, e
	}
	return client{dial: s.Dial, close: func() { s.Close() }, warm: s.Warm}, nil
}
func request(ctx context.Context, c client, target string, roots *x509.CertPool, out *sample, start time.Time) error {
	stream, e := c.dial(ctx, target)
	out.Entry = time.Since(start).Microseconds()
	if e != nil {
		return fmt.Errorf("entry: %w", e)
	}
	if laneDiagnostics {
		if observed, ok := stream.(interface{ LaneObservation() next.LaneObservation }); ok {
			defer func() { o := observed.LaneObservation(); out.Lane = &o }()
		}
	}
	if nextTraceEnabled || transportSnapshots {
		if n, ok := stream.(interface {
			TransportObservation() next.TransportObservation
		}); ok {
			before := n.TransportObservation()
			out.TransportBefore = &before
			defer func() { end := n.TransportObservation(); out.TransportEnd = &end }()
		}
	}
	recordGatewayTLS(stream, out)
	defer stream.Close()
	deadline, _ := ctx.Deadline()
	stream.SetDeadline(deadline)
	host, _, e := net.SplitHostPort(target)
	if e != nil {
		return e
	}
	if targetServerName != "" {
		host = targetServerName
	}
	beginTLS := time.Now()
	tlsStream := tls.Client(stream, &tls.Config{ServerName: host, RootCAs: roots, MinVersion: tls.VersionTLS12})
	if e = tlsStream.HandshakeContext(ctx); e != nil {
		return fmt.Errorf("target TLS: %w", e)
	}
	out.TargetTLS = time.Since(beginTLS).Microseconds()
	if nextTraceEnabled || transportSnapshots {
		if n, ok := stream.(interface {
			TransportObservation() next.TransportObservation
		}); ok {
			o := n.TransportObservation()
			out.TransportTLS = &o
		}
	}
	beginRequest := time.Now()
	if _, e = fmt.Fprintf(tlsStream, "HEAD / HTTP/1.1\r\nHost: %s\r\nConnection: close\r\n\r\n", host); e != nil {
		return e
	}
	reader := bufio.NewReader(tlsStream)
	if _, e = reader.Peek(1); e != nil {
		return fmt.Errorf("response: %w", e)
	}
	out.Response = time.Since(beginRequest).Microseconds()
	out.First = time.Since(start).Microseconds()
	res, e := http.ReadResponse(reader, &http.Request{Method: "HEAD"})
	if e != nil {
		return e
	}
	res.Body.Close()
	if res.StatusCode != 200 {
		return fmt.Errorf("target HTTP %d", res.StatusCode)
	}
	return nil
}
func run() error {
	clog.SetLevel(clog.SILENT)
	flag.BoolVar(&nextCoalesceOpen, "next-coalesce-open", false, "coalesce OPEN with first business write")
	flag.StringVar(&nextQUICProfile, "next-quic-profile", "", "baseline, wide, conservative, balanced, bbr-legacy")
	flag.BoolVar(&laneDiagnostics, "lane-diagnostics", false, "sanitized per-lane selection and stream timing; no packet trace")
	flag.IntVar(&nextLocalPort, "next-local-port", 0, "optional diagnostic Next UDP source port; 0 ephemeral")
	flag.BoolVar(&prefixTrace, "trace-prefix", false, "bounded QUIC prefix offset and packet number metadata; no payload")
	flag.BoolVar(&mixedReady, "mixed-ready", false, "start foreground after both background downloads receive >=256KiB, bounded at 15s")
	flag.StringVar(&mixedForegroundTarget, "mixed-foreground-target", "", "optional independent foreground host:port during local background downloads")
	flag.BoolVar(&transportSnapshots, "transport-snapshots", false, "request boundary counters only; no packet tracing")
	flag.BoolVar(&nextTraceEnabled, "trace-next", false, "sanitized Next stage and QUIC counters to stderr")
	flag.DurationVar(&nextEntryBudget, "next-entry-budget", 0, "Next total entry budget override; 0 uses default")
	versionList := flag.String("versions", "v2,v3", "comma-separated v2,v3,v3-light,v3-sealed,v3-light-fast,vless-vision,trojan")
	trace := flag.Bool("trace-v3", false, "write v3 diagnostic stages to stderr without credentials")
	file := flag.String("config", "", "private comparison configuration")
	pools := flag.Int("pools", 1, "independent warmed clients per protocol and version (1..4)")
	n := flag.Int("samples", 20, "cold and warm samples per protocol and version")
	batches := flag.Int("batches", 5, "concurrent rounds per protocol and version")
	workers := flag.Int("workers", 4, "simultaneous requests per concurrent round")
	bulkSeconds := flag.Int("bulk-seconds", 0, "fixed-duration echo seconds, 0 selects fixed-size (0..60)")
	bulkRounds := flag.Int("bulk-rounds", 3, "bulk rounds per group (1..10)")
	bulkOnly := flag.Bool("bulk-only", false, "run only controlled bulk workload")
	bulkTarget := flag.String("bulk-target", "", "optional controlled TCP echo target")
	prewarmSamples := flag.Int("prewarm-samples", 0, "additional cold prewarmed samples per group")
	mixedBytes := flag.Int("mixed-download-bytes", 0, "two shared-client background downloads with foreground requests")
	downloadBytes := flag.Int("download-bytes", 0, "controlled verified HTTP download bytes")
	downloadRounds := flag.Int("download-rounds", 2, "controlled download rounds")
	downloadJobs := flag.Int("download-jobs", 0, "total rolling jobs sharing a client, 0 equals workers (up to 32)")
	downloadWorkers := flag.Int("download-workers", 1, "shared-client parallel download workers (1..8)")
	flag.DurationVar(&downloadTimeout, "download-timeout", 30*time.Second, "whole verified download budget (up to 10m)")
	idleSeconds := flag.Int("idle-seconds", 0, "idle recovery experiment instead of latency phases")
	workload := flag.String("workload", "all", "all, warm-only or batch-only")
	flag.StringVar(&targetServerName, "target-server-name", "", "optional fixed target TLS and HTTP host")
	target := flag.String("target", "example.com:443", "same HTTPS HEAD target for every request")
	flag.Parse()
	if prefixTrace {
		nextTraceEnabled = true
	}
	if *bulkSeconds < 0 || *bulkSeconds > 60 {
		return errors.New("invalid bulk duration")
	}
	if *bulkRounds < 1 || *bulkRounds > 10 || *prewarmSamples < 0 || *prewarmSamples > 100 {
		return errors.New("invalid extra sample bounds")
	}
	if *pools < 1 || *pools > 4 || *n < 1 || *n > 1000 || *batches < 1 || *batches > 100 || *workers < 1 || *workers > 16 {
		return errors.New("invalid sample bounds")
	}
	data, e := os.ReadFile(*file)
	if e != nil {
		return e
	}
	var cfg configuration
	if json.Unmarshal(data, &cfg) != nil {
		return errors.New("invalid private configuration")
	}
	if *trace {
		cfg.V3.Trace = func(event string) { fmt.Fprintln(os.Stderr, event) }
	}
	pem, e := os.ReadFile(cfg.CA)
	if e != nil {
		return e
	}
	roots := x509.NewCertPool()
	if err := ca.AddCertificate(string(pem)); err != nil {
		return err
	}
	if !roots.AppendCertsFromPEM(pem) {
		return errors.New("invalid CA bundle")
	}
	root, cancel := context.WithTimeout(context.Background(), 45*time.Minute)
	defer cancel()
	enc := json.NewEncoder(os.Stdout)
	var outputMu sync.Mutex
	var outputErr error
	emit := func(s sample) {
		outputMu.Lock()
		defer outputMu.Unlock()
		if outputErr == nil {
			outputErr = enc.Encode(s)
		}
	}
	versions := strings.Split(*versionList, ",")
	seen := make(map[string]bool)
	for _, version := range versions {
		if seen[version] || (version != "next-base" && version != "next-opt" && version != "next-fixed" && version != "next-primary" && version != "next-latency" && version != "next-reserve" && version != "next-h2" && version != "next-quic" && version != "next" && version != "v2-bbr" && version != "v2-reno" && version != "v2" && version != "v3" && version != "v3-light" && version != "v3-sealed" && version != "v3-light-fast" && version != "vless-vision" && version != "trojan" && version != "hysteria2" && version != "tuic" && version != "tuic-dual" && version != "anytls") {
			return errors.New("invalid comparison versions")
		}
		seen[version] = true
	}
	protocols := comparisonProtocols(versions)
	if *downloadBytes > 0 {
		if downloadTimeout <= 0 || downloadTimeout > 10*time.Minute || *downloadBytes > 128<<20 || *downloadRounds < 1 || *downloadRounds > 10 || *downloadWorkers < 1 || *downloadWorkers > 8 {
			return errors.New("invalid download bounds")
		}
		jobs := *downloadJobs
		if jobs == 0 {
			jobs = *downloadWorkers
		}
		if jobs < *downloadWorkers || jobs > 32 {
			return errors.New("invalid download jobs")
		}
		if *downloadWorkers > 1 || jobs > *downloadWorkers {
			return runParallelDownload(root, cfg, roots, versions, *target, *downloadBytes, *downloadRounds, *downloadWorkers, jobs)
		}
		return runDownload(root, cfg, roots, versions, *target, *downloadBytes, *downloadRounds)
	}
	if *mixedBytes > 0 {
		if *mixedBytes > 128<<20 || *downloadRounds < 1 || *downloadRounds > 5 || downloadTimeout <= 0 || downloadTimeout > 10*time.Minute {
			return errors.New("invalid mixed bounds")
		}
		return runMixed(root, cfg, roots, versions, *target, *mixedBytes, *n, *downloadRounds)
	}
	if *idleSeconds > 0 {
		return runIdle(root, cfg, roots, versions, *target, *idleSeconds, emit)
	}
	if *bulkOnly {
		if *bulkTarget == "" {
			return errors.New("bulk-only requires bulk-target")
		}
		if *bulkSeconds > 0 {
			return runTimedBulk(root, cfg, roots, versions, *bulkTarget, *bulkRounds, *bulkSeconds)
		}
		return runBulk(root, cfg, roots, versions, *bulkTarget, *bulkRounds)
	}
	measure := func(c client, phase, version, protocol string, round, worker, pool int) {
		ctx, stop := context.WithTimeout(root, 12*time.Second)
		defer stop()
		out := sample{Phase: phase, Version: version, Protocol: protocol, Round: round, Worker: worker, Pool: pool}
		start := time.Now()
		out.Start = start.UnixMicro()
		e := request(ctx, c, *target, roots, &out, start)
		out.Elapsed = time.Since(start).Microseconds()
		if e != nil {
			out.Error = e.Error()
		}
		emit(out)
	}
	if *workload != "batch-only" && *workload != "warm-only" {
		for round := 0; round < *n; round++ {
			for p := range protocols {
				protocol := protocols[(round+p)%len(protocols)]
				for v := range versions {
					version := versions[(round+v)%len(versions)]
					if !comparisonCase(version, protocol) {
						continue
					}
					ctx, stop := context.WithTimeout(root, 12*time.Second)
					start := time.Now()
					out := sample{Phase: "cold", Version: version, Protocol: protocol, Round: round + 1, Start: start.UnixMicro()}
					c, e := newClient(ctx, cfg, roots, version, protocol)
					out.ClientReady = time.Since(start).Microseconds()
					if e == nil {
						e = request(ctx, c, *target, roots, &out, start)
						c.close()
					}
					out.Elapsed = time.Since(start).Microseconds()
					if e != nil {
						out.Error = e.Error()
					}
					stop()
					emit(out)
				}
			}
		}
		for round := 0; round < *prewarmSamples; round++ {
			for p := range protocols {
				protocol := protocols[(round+p)%len(protocols)]
				for v := range versions {
					version := versions[(round+v)%len(versions)]
					if !comparisonCase(version, protocol) {
						continue
					}
					ctx, stop := context.WithTimeout(root, 12*time.Second)
					prep := time.Now()
					c, e := newClient(ctx, cfg, roots, version, protocol)
					if e == nil && c.warm != nil {
						e = c.warm(ctx)
					}
					out := sample{Phase: "prewarmed", Version: version, Protocol: protocol, Round: round + 1, ClientReady: time.Since(prep).Microseconds()}
					start := time.Now()
					out.Start = start.UnixMicro()
					if e == nil {
						e = request(ctx, c, *target, roots, &out, start)
					}
					if c.close != nil {
						c.close()
					}
					stop()
					out.Elapsed = time.Since(start).Microseconds()
					if e != nil {
						out.Error = e.Error()
					}
					emit(out)
				}
			}
		}
		if *bulkTarget != "" {
			if err := runBulk(root, cfg, roots, versions, *bulkTarget, *bulkRounds); err != nil {
				return err
			}
		}
	}
	clients := make(map[string][]client)
	defer func() {
		for _, group := range clients {
			for _, c := range group {
				c.close()
			}
		}
	}()
	for _, protocol := range protocols {
		for _, version := range versions {
			if !comparisonCase(version, protocol) {
				continue
			}
			for pool := 0; pool < *pools; pool++ {
				c, e := newClient(root, cfg, roots, version, protocol)
				if e != nil {
					failure := fmt.Errorf("client preparation failed: %w", e)
					c = client{dial: func(context.Context, string) (net.Conn, error) { return nil, failure }, close: func() {}}
				}
				clients[version+protocol] = append(clients[version+protocol], c)
				measure(c, "prime", version, protocol, 0, 0, pool+1)
			}
		}
	}
	if *workload != "batch-only" {
		for round := 0; round < *n; round++ {
			for p := range protocols {
				protocol := protocols[(round+p)%len(protocols)]
				for v := range versions {
					version := versions[(round+v)%len(versions)]
					if !comparisonCase(version, protocol) {
						continue
					}
					measure(clients[version+protocol][round%*pools], "warm", version, protocol, round+1, 0, round%*pools+1)
				}
			}
		}
	}
	for round := 0; round < *batches; round++ {
		for p := range protocols {
			protocol := protocols[(round+p)%len(protocols)]
			for v := range versions {
				version := versions[(round+v)%len(versions)]
				if !comparisonCase(version, protocol) {
					continue
				}
				var wg sync.WaitGroup
				for worker := 0; worker < *workers; worker++ {
					wg.Add(1)
					go func(worker int) {
						defer wg.Done()
						measure(clients[version+protocol][round%*pools], "batch", version, protocol, round+1, worker+1, round%*pools+1)
					}(worker)
				}
				wg.Wait()
			}
		}
	}
	return outputErr
}

var targetServerName string

func nativeVersion(v string) bool {
	return v == "vless-vision" || v == "trojan" || v == "hysteria2" || v == "tuic" || v == "anytls"
}
func comparisonProtocols(versions []string) []string {
	p := []string{"h2", "h3"}
	tcp, udp := false, false
	for _, v := range versions {
		if v == "next-base" || v == "next-opt" || v == "next-fixed" || (v == "next-primary" || (v == "next-latency" || v == "next-reserve")) || v == "next-quic" || v == "next" || v == "hysteria2" || v == "tuic" || v == "tuic-dual" {
			udp = true
		} else if nativeVersion(v) {
			tcp = true
		}
	}
	if tcp {
		p = append(p, "tcp-tls")
	}
	if udp {
		p = append(p, "quic")
	}
	return p
}
func comparisonCase(v, p string) bool {
	if v == "next-h2" {
		return p == "h2"
	}
	if v == "next-base" || v == "next-opt" || v == "next-fixed" || (v == "next-primary" || (v == "next-latency" || v == "next-reserve")) || v == "next-quic" {
		return p == "quic"
	}
	if v == "next" {
		return p == "quic" || p == "h2"
	}
	if v == "v2-bbr" || v == "v2-reno" {
		return p == "h3"
	}
	if v == "next-base" || v == "next-opt" || v == "next-fixed" || (v == "next-primary" || (v == "next-latency" || v == "next-reserve")) || v == "next-quic" || v == "next" || v == "hysteria2" || v == "tuic" || v == "tuic-dual" {
		return p == "quic"
	}
	if nativeVersion(v) {
		return p == "tcp-tls"
	}
	return p == "h2" || p == "h3"
}

func recordGatewayTLS(conn net.Conn, out *sample) {
	var current any = conn
	for depth := 0; current != nil && depth < 16; depth++ {
		if c, ok := current.(interface{ ConnectionState() qtls.ConnectionState }); ok {
			s := c.ConnectionState()
			out.GatewayTLS = fmt.Sprintf("0x%04x", s.Version)
			out.GatewayCipher = qtls.CipherSuiteName(s.CipherSuite)
			out.GatewayALPN = s.NegotiatedProtocol
			return
		}
		if c, ok := current.(interface{ ConnectionState() tls.ConnectionState }); ok {
			s := c.ConnectionState()
			out.GatewayTLS = fmt.Sprintf("0x%04x", s.Version)
			out.GatewayCipher = tls.CipherSuiteName(s.CipherSuite)
			out.GatewayALPN = s.NegotiatedProtocol
			return
		}
		if c, ok := current.(interface{ Upstream() any }); ok {
			current = c.Upstream()
		} else {
			return
		}
	}
}
