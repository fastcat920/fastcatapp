package main

import (
	"fmt"
	"log"
	"runtime"
	"runtime/debug"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/metacubex/mihomo/config"
)

// Go's soft limit excludes Swift, framework and some native allocations. Leave
// substantial headroom below the observed ~50 MiB NetworkExtension footprint.
const appleGoMemoryLimit = 24 << 20

var appleMemoryOnce sync.Once

func configureAppleMemory() {
	appleMemoryOnce.Do(func() {
		debug.SetMemoryLimit(appleGoMemoryLimit)
		debug.SetGCPercent(50)
		runtime.GOMAXPROCS(2)
		go func() {
			ticker := time.NewTicker(time.Second)
			samples := 0
			defer ticker.Stop()
			for range ticker.C {
				samples++
				if samples > 60 && samples%30 != 0 {
					continue
				}
				sampleAppleMemoryStage("periodic")
				if samples <= 60 && samples%20 == 0 && runtime.NumGoroutine() >= 80 {
					sampleAppleGoroutineFunctions()
				}
				var m runtime.MemStats
				runtime.ReadMemStats(&m)
				log.Printf("[AppleMemory] heap=%d heapInuse=%d goResidentEstimate=%d goroutines=%d gc=%d limit=%d", m.HeapAlloc, m.HeapInuse, m.Sys-m.HeapReleased, runtime.NumGoroutine(), m.NumGC, appleGoMemoryLimit)
			}
		}()
	})
}

func patchAppleMemoryConfig(cfg *config.RawConfig) {
	cfg.GeodataLoader = "memconservative"
	// Bound response cache growth without changing fake-IP address mappings.
	if cfg.DNS.CacheMaxSize <= 0 || cfg.DNS.CacheMaxSize > 512 {
		cfg.DNS.CacheMaxSize = 512
	}
	// Avoid speculative parallel dials in the memory-constrained extension.
	cfg.TCPConcurrent = false
}

// Installed by the iOS bridge to send only numeric memory counters to os_log.
var appleMemoryStageSink func(string)

func sampleAppleMemoryStage(stage string) {
	if runtime.GOOS != "ios" {
		return
	}
	var m runtime.MemStats
	runtime.ReadMemStats(&m)
	message := fmt.Sprintf("[AppleMemoryStage] stage=%s heap=%d heapInuse=%d goResidentEstimate=%d goroutines=%d gc=%d limit=%d", stage, m.HeapAlloc, m.HeapInuse, m.Sys-m.HeapReleased, runtime.NumGoroutine(), m.NumGC, appleGoMemoryLimit)
	if appleMemoryStageSink != nil {
		appleMemoryStageSink(message)
	} else {
		log.Print(message)
	}
}

func logAppleDiagnostic(message string) {
	if runtime.GOOS != "ios" {
		return
	}
	if appleMemoryStageSink != nil {
		appleMemoryStageSink(message)
	} else {
		log.Print(message)
	}
}

// Bounded stack-PC sampling: function names only, never arguments or endpoints.
func sampleAppleGoroutineFunctions() {
	if runtime.GOOS != "ios" {
		return
	}
	records := make([]runtime.StackRecord, 512)
	n, ok := runtime.GoroutineProfile(records)
	if !ok {
		logAppleDiagnostic(fmt.Sprintf("[AppleGoroutines] sample_skipped count=%d capacity=512", n))
		return
	}
	counts := map[string]int{}
	for _, record := range records[:n] {
		frames := runtime.CallersFrames(record.Stack())
		seen := map[string]bool{}
		for {
			frame, more := frames.Next()
			name := frame.Function
			if name != "" && !seen[name] {
				counts[name]++
				seen[name] = true
			}
			if !more {
				break
			}
		}
	}
	type entry struct {
		name  string
		count int
	}
	ranked := make([]entry, 0, len(counts))
	for name, count := range counts {
		if strings.HasPrefix(name, "runtime.") || strings.HasPrefix(name, "internal/poll.") || strings.HasPrefix(name, "internal/runtime/") {
			continue
		}
		ranked = append(ranked, entry{name, count})
	}
	sort.Slice(ranked, func(i, j int) bool {
		if ranked[i].count == ranked[j].count {
			return ranked[i].name < ranked[j].name
		}
		return ranked[i].count > ranked[j].count
	})
	for i, value := range ranked {
		if i >= 16 {
			break
		}
		logAppleDiagnostic(fmt.Sprintf("[AppleGoroutines] total=%d function=%s count=%d", n, value.name, value.count))
	}
}
