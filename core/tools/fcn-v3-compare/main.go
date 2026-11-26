// fcn-v3-compare runs a bounded deterministic FCN, TUIC and Hysteria2 benchmark.
package main

import (
	"context"
	"flag"
	"fmt"
	"io"
	"os"
	"os/signal"
	"time"

	clog "github.com/metacubex/mihomo/log"
)

type options struct {
	DiagnosticID string
	Preconnect   bool
	Protocol     string
	Phase        string
	Bytes        int
	Count        int
	Workers      int
	Timeout      time.Duration
	Interval     time.Duration
}

const protocolNames = "fcnv1, fcnv2, fcnv3, tuic or hysteria2"

func (o options) validate() error {
	if len(o.DiagnosticID) > 48 {
		return fmt.Errorf("diagnostic ID must be at most 48 characters")
	}
	for _, c := range o.DiagnosticID {
		if !(c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c >= '0' && c <= '9' || c == '_' || c == '-') {
			return fmt.Errorf("diagnostic ID must contain only ASCII letters, digits, underscores, and hyphens")
		}
	}
	if o.Preconnect && (o.Protocol != "fcnv3" || o.Phase == "cold") {
		return fmt.Errorf("preconnect requires a retained FCN v3 client")
	}
	switch o.Protocol {
	case "fcnv1", "fcnv2", "fcnv3", "tuic", "hysteria2":
	default:
		return fmt.Errorf("protocol must be %s", protocolNames)
	}
	switch o.Phase {
	case "cold", "warm", "concurrent", "download", "upload":
	default:
		return fmt.Errorf("phase must be cold, warm, concurrent, download or upload")
	}
	if o.Bytes < 1 || o.Bytes > 8*1048576 || o.Count < 1 || o.Count > 1000 || o.Workers < 1 || o.Workers > 16 || o.Workers > o.Count {
		return fmt.Errorf("bounds: bytes 1..8388608, count 1..1000, workers 1..16 and <= count")
	}
	if (o.Phase == "cold" || o.Phase == "warm") && o.Workers != 1 {
		return fmt.Errorf("cold and warm latency phases require one worker")
	}
	if o.Timeout < time.Second || o.Timeout > 2*time.Minute {
		return fmt.Errorf("timeout must be 1s..2m")
	}
	if o.Interval < 0 || o.Interval > 5*time.Second || (o.Interval > 0 && o.Workers != 1) {
		return fmt.Errorf("interval must be 0..5s and requires one worker")
	}
	return nil
}

func execute(ctx context.Context, args []string, out, stderr io.Writer) error {
	f := flag.NewFlagSet("fcn-v3-compare", flag.ContinueOnError)
	f.SetOutput(stderr)
	var configPath string
	var networkProbe bool
	var udpDiagnostic bool
	var udpWireRX bool
	var o options
	f.BoolVar(&networkProbe, "network-probe", false, "run FCN v3 TCP/UDP recovery probes from JSON lines on stdin")
	f.BoolVar(&udpDiagnostic, "udp-diagnostic", false, "measure individual UDP echo submissions and responses as JSON lines")
	f.BoolVar(&udpWireRX, "udp-wire-rx", false, "record bounded fingerprints of encrypted UDP datagrams received by the diagnostic socket")
	f.StringVar(&o.DiagnosticID, "diagnostic-id", "", "prefix for correlating body progress with the test origin")
	f.BoolVar(&o.Preconnect, "preconnect", false, "prepare FCN v3 QUIC before the measured request batch")
	f.StringVar(&configPath, "config", "", "owner-only JSON config path")
	f.StringVar(&o.Protocol, "protocol", "", protocolNames)
	f.StringVar(&o.Phase, "phase", "warm", "cold, warm, concurrent, download or upload")
	f.IntVar(&o.Bytes, "bytes", 32768, "deterministic payload size")
	f.IntVar(&o.Count, "count", 8, "total measured requests, including the retained client's first request")
	f.IntVar(&o.Workers, "workers", 1, "simultaneous requests sharing one client except in cold phase")
	f.DurationVar(&o.Timeout, "timeout", 45*time.Second, "overall budget for each request")
	f.DurationVar(&o.Interval, "interval", 0, "delay between a completed request and the next start; requires one worker")
	if err := f.Parse(args); err != nil {
		return err
	}
	if f.NArg() != 0 || configPath == "" {
		return fmt.Errorf("a config path is required and positional arguments are unsupported")
	}
	if err := o.validate(); err != nil {
		return err
	}
	if networkProbe && o.Protocol != "fcnv3" {
		return fmt.Errorf("network probe requires FCN v3")
	}
	if udpDiagnostic && (networkProbe || o.Preconnect || o.Workers != 1 || o.Interval != 0) {
		return fmt.Errorf("UDP diagnostics require one worker and do not accept preconnect, interval, or network probe")
	}
	if udpWireRX && !udpDiagnostic {
		return fmt.Errorf("UDP wire receive capture requires UDP diagnostics")
	}
	cfg, err := loadConfig(configPath, o.Protocol)
	if err != nil {
		return err
	}
	clog.SetLevel(clog.ERROR)
	if udpDiagnostic {
		return runUDPDiagnosticWithWireRX(ctx, out, cfg, o.Protocol, o.Count, o.Timeout, udpWireRX)
	}
	if networkProbe {
		return runNetworkProbe(ctx, os.Stdin, out, cfg, o.Timeout)
	}
	factory, err := newFactory(cfg, o.Protocol)
	if err != nil {
		return err
	}
	return runBench(ctx, out, o, cfg.Target, factory)
}

func main() {
	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt)
	defer cancel()
	if err := execute(ctx, os.Args[1:], os.Stdout, os.Stderr); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
