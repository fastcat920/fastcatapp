package main

import (
	"bytes"
	"context"
	"crypto/sha256"
	"crypto/x509"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"runtime"
	"sync"
	"time"
)

// Controlled full duplex echo workload: bounded buffers, exact byte/hash checks.
// Aggregate rate counts upload plus download, not download-only throughput.
func runBulk(root context.Context, cfg configuration, roots *x509.CertPool, versions []string, target string, rounds int) error {
	for _, workers := range []int{1, 4} {
		for pi, protocol := range comparisonProtocols(versions) {
			for round := 0; round < rounds; round++ {
				for vi := range versions {
					version := versions[(pi+vi+round)%len(versions)]
					if !comparisonCase(version, protocol) {
						continue
					}
					ctx, cancel := context.WithTimeout(root, 60*time.Second)
					c, err := newClient(ctx, cfg, roots, version, protocol)
					if err != nil {
						cancel()
						json.NewEncoder(os.Stderr).Encode(map[string]any{"phase": "bulk", "protocol": protocol, "version": version, "workers": workers, "round": round + 1, "success": 0, "errors": []string{"setup: " + err.Error()}, "aggregate_mbps": nil})
						continue
					}
					if c.warm != nil {
						_ = c.warm(ctx)
					}
					const size = 4 << 20
					block := bytes.Repeat([]byte{0x13, 0x37, 0xa5, 0x5a}, 8192)
					expected := sha256.New()
					for n := 0; n < size/len(block); n++ {
						expected.Write(block)
					}
					var before, after runtime.MemStats
					runtime.ReadMemStats(&before)
					started := time.Now()
					failures := make(chan error, workers)
					var wg sync.WaitGroup
					for i := 0; i < workers; i++ {
						wg.Add(1)
						go func() {
							defer wg.Done()
							conn, e := c.dial(ctx, target)
							if e != nil {
								failures <- e
								return
							}
							defer conn.Close()
							conn.SetDeadline(time.Now().Add(50 * time.Second))
							written := make(chan error, 1)
							go func() {
								var e error
								for n := 0; n < size/len(block); n++ {
									if _, e = io.Copy(conn, bytes.NewReader(block)); e != nil {
										break
									}
								}
								written <- e
							}()
							hash := sha256.New()
							_, e = io.CopyN(hash, conn, size)
							if e != nil {
								conn.Close()
							}
							writeErr := <-written
							if e == nil {
								e = writeErr
							}
							if e == nil && !bytes.Equal(hash.Sum(nil), expected.Sum(nil)) {
								e = fmt.Errorf("payload checksum mismatch")
							}
							if e != nil {
								failures <- e
							}
						}()
					}
					wg.Wait()
					elapsed := time.Since(started)
					runtime.ReadMemStats(&after)
					c.close()
					cancel()
					close(failures)
					errors := []string{}
					for e := range failures {
						errors = append(errors, e.Error())
					}
					output := map[string]any{"phase": "bulk", "protocol": protocol, "version": version, "workers": workers, "round": round + 1, "bytes_each_way_per_stream": size, "elapsed_ms": elapsed.Milliseconds(), "success": workers - len(errors), "errors": errors, "aggregate_mbps": float64(2*size*workers*8) / elapsed.Seconds() / 1e6, "alloc_bytes": after.TotalAlloc - before.TotalAlloc, "heap_live_bytes": after.HeapAlloc, "goroutines": runtime.NumGoroutine()}
					if len(errors) > 0 {
						output["aggregate_mbps"] = nil
					}
					json.NewEncoder(os.Stderr).Encode(output)
				}
			}
		}
	}
	return nil
}
