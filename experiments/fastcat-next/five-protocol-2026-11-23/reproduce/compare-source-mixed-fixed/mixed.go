package main

import (
	"context"
	"crypto/x509"
	"encoding/json"
	"os"
	"sync"
	"sync/atomic"
	"time"
)

var mixedForegroundTarget string
var mixedReady bool

// Two long-lived downloads share the same client as foreground HEAD requests.
// This exercises scheduling after bytes have flowed, rather than only assigning
// a batch of streams before any connection has an observed delivery rate.
func runMixed(root context.Context, cfg configuration, roots *x509.CertPool, versions []string, target string, size, samples, rounds int) error {
	for round := 0; round < rounds; round++ {
		for vi := range versions {
			version := versions[(round+vi)%len(versions)]
			protocol := mixedProtocol(version)
			if protocol == "" {
				continue
			}
			ctx, cancel := context.WithTimeout(root, downloadTimeout)
			start := time.Now()
			c, e := newClient(ctx, cfg, roots, version, "quic")
			if e != nil {
				cancel()
				return e
			}
			if c.warm != nil {
				_ = c.warm(ctx)
			}
			setup := time.Since(start).Milliseconds()
			var active atomic.Int64
			active.Store(2)
			var wg sync.WaitGroup
			readyCh := make(chan struct{}, 2)
			var readyCount atomic.Int64
			results := make([]map[string]any, 2)
			for i := range results {
				wg.Add(1)
				go func(i int) {
					defer wg.Done()
					defer active.Add(-1)
					bg := c
					if mixedReady {
						var bytes int
						var once sync.Once
						bg.downloadProgress = func(n int) {
							bytes += n
							if bytes >= 256<<10 {
								once.Do(func() { readyCount.Add(1); readyCh <- struct{}{} })
							}
						}
					}
					results[i] = downloadUsing(ctx, cfg, roots, version, protocol, target, size, &bg)
				}(i)
			}
			readinessStart := time.Now()
			if mixedReady {
				awaitMixedReady(ctx, readyCh, &readyCount, 15*time.Second)
			} else {
				timer := time.NewTimer(150 * time.Millisecond)
				select {
				case <-timer.C:
				case <-ctx.Done():
					timer.Stop()
				}
			}
			readyWait := time.Since(readinessStart).Milliseconds()

			for n := 0; n < samples; n++ {
				child, stop := context.WithTimeout(ctx, 12*time.Second)
				row := sample{Phase: "mixed", Version: version, Protocol: protocol, Round: round + 1, Worker: n + 1}
				at := time.Now()
				row.Start = at.UnixMicro()
				loading := active.Load()
				readyAtStart := readyCount.Load()
				foreground := target
				if mixedForegroundTarget != "" {
					foreground = mixedForegroundTarget
				}
				err := request(child, c, foreground, roots, &row, at)
				row.Elapsed = time.Since(at).Microseconds()
				if err != nil {
					row.Error = err.Error()
				}
				stop()
				out := struct {
					sample
					BackgroundActive int64 `json:"background_active"`
					BackgroundReady  int64 `json:"background_ready"`
				}{row, loading, readyAtStart}
				// Preserve cleanup even when an output pipe is closed by the caller.
				if err = json.NewEncoder(os.Stderr).Encode(out); err != nil {
					c.close()
					cancel()
					wg.Wait()
					return err
				}
			}
			wg.Wait()
			elapsed := time.Since(start)
			usage := any(nil)
			if c.stats != nil {
				usage = c.stats()
			}
			c.close()
			cancel()
			success := 0
			var verified int64
			for i, r := range results {
				r["phase"] = "mixed_background"
				r["round"] = round + 1
				r["worker"] = i + 1
				if r["complete"] == true {
					success++
					verified += r["received_bytes"].(int64)
				}
				if err := json.NewEncoder(os.Stderr).Encode(r); err != nil {
					return err
				}
			}
			if err := json.NewEncoder(os.Stderr).Encode(map[string]any{"lane_usage": usage, "phase": "mixed_summary", "version": version, "round": round + 1, "success": success, "workers": 2, "setup_ms": setup, "readiness_wait_ms": readyWait, "ready_mode": mixedReady, "background_ready": readyCount.Load(), "elapsed_ms": elapsed.Milliseconds(), "verified_bytes": verified}); err != nil {
				return err
			}
		}
	}
	return nil
}

func awaitMixedReady(ctx context.Context, ch <-chan struct{}, count *atomic.Int64, limit time.Duration) {
	timer := time.NewTimer(limit)
	defer timer.Stop()
	for count.Load() < 2 {
		select {
		case <-ch:
		case <-ctx.Done():
			return
		case <-timer.C:
			return
		}
	}
}

// All five measured variants, including TCP VLESS, must execute this workload.
func mixedProtocol(version string) string {
 for _,p:=range []string{"quic","tcp-tls"} { if comparisonCase(version,p) { return p } }
 return ""
}
