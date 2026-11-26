package main

import (
	"encoding/json"
	"fmt"
	"os"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"
)

// Explicit opt-in local file, never a public admin/pprof endpoint. Bounded to
// 1800 rows/run and16MiB/file, no keys, connections, payloads or stack traces.
func startRuntimeMetrics(path string, n *node, slots chan struct{}) (func(), error) {
	if path == "" {
		return func() {}, nil
	}
	f, e := os.OpenFile(path, os.O_CREATE|os.O_WRONLY|os.O_APPEND|syscall.O_NOFOLLOW, 0600)
	if e != nil {
		return nil, e
	}
	if e = syscall.Flock(int(f.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); e != nil {
		f.Close()
		return nil, e
	}
	info, e := f.Stat()
	if e != nil || !info.Mode().IsRegular() || info.Mode().Perm()&0077 != 0 || info.Size() > 16*1048576 {
		f.Close()
		return nil, fmt.Errorf("metrics path must be private regular bounded file")
	}
	done := make(chan struct{})
	finished := make(chan struct{})
	var once sync.Once
	go func() {
		defer close(finished)
		defer f.Close()
		ticker := time.NewTicker(time.Second)
		defer ticker.Stop()
		start := time.Now()
		bytesWritten := info.Size()
		for i := 0; i < 1800; i++ {
			var m runtime.MemStats
			runtime.ReadMemStats(&m)
			sessions := 0
			if n != nil {
				sessions = len(n.slots)
			}
			row := map[string]any{"elapsed_ms": time.Since(start).Milliseconds(), "pid": os.Getpid(), "goroutines": runtime.NumGoroutine(), "heap_alloc": m.HeapAlloc, "heap_sys": m.HeapSys, "total_alloc": m.TotalAlloc, "num_gc": m.NumGC, "pause_total_ns": m.PauseTotalNs, "active_connections": len(slots), "active_sessions": sessions, "active_jobs": diagnoseActive.Load()}
			for k, v := range procNumbers() {
				row[k] = v
			}
			line, e := json.Marshal(row)
			if e != nil || bytesWritten+int64(len(line)+1) > 16*1048576 {
				return
			}
			if _, e = f.Write(append(line, '\n')); e != nil {
				return
			}
			bytesWritten += int64(len(line) + 1)
			select {
			case <-done:
				return
			case <-ticker.C:
			}
		}
	}()
	return func() { once.Do(func() { close(done); <-finished }) }, nil
}

func procNumbers() map[string]int64 {
	result := map[string]int64{"rss_kib": -1, "os_threads": -1, "fd_count": -1}
	if b, e := os.ReadFile("/proc/self/status"); e == nil {
		for _, line := range strings.Split(string(b), "\n") {
			fields := strings.Fields(line)
			if len(fields) >= 2 {
				value, _ := strconv.ParseInt(fields[1], 10, 64)
				switch fields[0] {
				case "VmRSS:":
					result["rss_kib"] = value
				case "Threads:":
					result["os_threads"] = value
				}
			}
		}
	}
	if entries, e := os.ReadDir("/proc/self/fd"); e == nil {
		result["fd_count"] = int64(len(entries))
	}
	return result
}
