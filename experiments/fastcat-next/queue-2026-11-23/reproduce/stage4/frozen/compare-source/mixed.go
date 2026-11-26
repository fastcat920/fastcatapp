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

// Two long-lived downloads share the same client as foreground HEAD requests.
// This exercises scheduling after bytes have flowed, rather than only assigning
// a batch of streams before any connection has an observed delivery rate.
func runMixed(root context.Context, cfg configuration, roots *x509.CertPool, versions []string, target string, size, samples, rounds int) error {
	for round := 0; round < rounds; round++ {
		for vi := range versions {
			version := versions[(round+vi)%len(versions)]
			if !comparisonCase(version, "quic") {
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
			results := make([]map[string]any, 2)
			for i := range results {
				wg.Add(1)
				go func(i int) {
					defer wg.Done()
					defer active.Add(-1)
					results[i] = downloadUsing(ctx, cfg, roots, version, "quic", target, size, &c)
				}(i)
			}
			timer := time.NewTimer(150 * time.Millisecond)
			select {
			case <-timer.C:
			case <-ctx.Done():
				timer.Stop()
			}
			for n := 0; n < samples; n++ {
				child, stop := context.WithTimeout(ctx, 12*time.Second)
				row := sample{Phase: "mixed", Version: version, Protocol: "quic", Round: round + 1, Worker: n + 1}
				at := time.Now()
				row.Start = at.UnixMicro()
				loading := active.Load()
				err := request(child, c, target, roots, &row, at)
				row.Elapsed = time.Since(at).Microseconds()
				if err != nil {
					row.Error = err.Error()
				}
				stop()
				out := struct {
					sample
					BackgroundActive int64 `json:"background_active"`
				}{row, loading}
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
			if err := json.NewEncoder(os.Stderr).Encode(map[string]any{"lane_usage": usage, "phase": "mixed_summary", "version": version, "round": round + 1, "success": success, "workers": 2, "setup_ms": setup, "elapsed_ms": elapsed.Milliseconds(), "verified_bytes": verified}); err != nil {
				return err
			}
		}
	}
	return nil
}
