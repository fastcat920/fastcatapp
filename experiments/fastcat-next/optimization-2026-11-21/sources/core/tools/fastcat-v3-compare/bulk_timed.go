package main

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"fmt"
	"net"
	"os"
	"runtime"
	"sync"
	"time"
)

// Fixed-duration echo goodput complements fixed-size completion tests on slow
// links. Count only received, pattern-verified payload; setup is reported apart.
func runTimedBulk(root context.Context, cfg configuration, roots *x509.CertPool, versions []string, target string, rounds, seconds int) error {
	for _, workers := range []int{1, 4} {
		for round := 0; round < rounds; round++ {
			for pi, protocol := range comparisonProtocols(versions) {
				for vi := range versions {
					version := versions[(round+pi+vi)%len(versions)]
					if !comparisonCase(version, protocol) {
						continue
					}
					ctx, cancel := context.WithTimeout(root, time.Duration(seconds)*time.Second+20*time.Second)
					prep := time.Now()
					c, err := newClient(ctx, cfg, roots, version, protocol)
					row := map[string]any{"phase": "timed_bulk", "protocol": protocol, "version": version, "workers": workers, "round": round + 1, "seconds": seconds}
					if err != nil {
						cancel()
						row["errors"] = []string{"setup: " + err.Error()}
						row["download_mbps"] = nil
						json.NewEncoder(os.Stderr).Encode(row)
						continue
					}
					if c.warm != nil {
						_ = c.warm(ctx)
					}
					conns := make([]net.Conn, workers)
					errs := make([]error, workers)
					var wg sync.WaitGroup
					for i := range conns {
						wg.Add(1)
						go func(i int) {
							defer wg.Done()
							conns[i], errs[i] = c.dial(ctx, target)
							if errs[i] == nil && cfg.BulkTLSName != "" {
								outer := conns[i]
								inner := tls.Client(outer, &tls.Config{MinVersion: tls.VersionTLS13, ServerName: cfg.BulkTLSName, RootCAs: roots})
								if e := inner.HandshakeContext(ctx); e != nil {
									outer.Close()
									conns[i] = nil
									errs[i] = e
								} else {
									conns[i] = inner
								}
							}
						}(i)
					}
					wg.Wait()
					row["setup_ms"] = time.Since(prep).Milliseconds()
					var before, after runtime.MemStats
					runtime.ReadMemStats(&before)
					received := make([]int64, workers)
					sent := make([]int64, workers)
					start := time.Now()
					deadline := start.Add(time.Duration(seconds) * time.Second)
					for i, conn := range conns {
						if conn == nil {
							continue
						}
						wg.Add(1)
						go func(i int, conn net.Conn) {
							defer wg.Done()
							defer conn.Close()
							conn.SetDeadline(deadline)
							writing := make(chan struct{})
							go func() {
								defer close(writing)
								block := make([]byte, 32<<10)
								for j := range block {
									block[j] = byte(j % 4)
								}
								for {
									n, e := conn.Write(block)
									sent[i] += int64(n)
									if e != nil {
										return
									}
									if n != len(block) {
										return
									}
								}
							}()
							buffer := make([]byte, 32<<10)
							for {
								n, e := conn.Read(buffer)
								valid := timedPatternValid(buffer[:n], received[i])
								if !valid {
									errs[i] = fmt.Errorf("echo payload mismatch")
									break
								}
								received[i] += int64(n)
								if e != nil {
									if time.Now().Before(deadline.Add(-50 * time.Millisecond)) {
										errs[i] = e
									}
									break
								}
							}
							conn.Close()
							<-writing
							if received[i] == 0 && errs[i] == nil {
								errs[i] = fmt.Errorf("no verified payload")
							}
						}(i, conn)
					}
					wg.Wait()
					elapsed := time.Since(start)
					runtime.ReadMemStats(&after)
					c.close()
					cancel()
					var totalIn, totalOut int64
					failures := []string{}
					for i := range received {
						totalIn += received[i]
						totalOut += sent[i]
						if errs[i] != nil {
							failures = append(failures, errs[i].Error())
						}
					}
					row["elapsed_ms"] = elapsed.Milliseconds()
					row["received_bytes"] = totalIn
					row["sent_bytes"] = totalOut
					row["errors"] = failures
					row["success"] = workers - len(failures)
					row["download_mbps"] = float64(totalIn*8) / elapsed.Seconds() / 1e6
					row["alloc_bytes"] = after.TotalAlloc - before.TotalAlloc
					row["heap_live_bytes"] = after.HeapAlloc
					row["goroutines"] = runtime.NumGoroutine()
					json.NewEncoder(os.Stderr).Encode(row)
				}
			}
		}
	}
	return nil
}

func timedPatternValid(payload []byte, offset int64) bool {
	for j, b := range payload {
		if b != byte((offset+int64(j))%4) {
			return false
		}
	}
	return true
}
