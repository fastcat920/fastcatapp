package main

import (
	"encoding/json"
	"fmt"
	"os"
	"sync"
	"sync/atomic"
	"time"
)

var diagnoseActive atomic.Int32

func diagnose(cfg settings, target, kind string, s workload, count, workers int, budget time.Duration, runSeconds, intervalMS int) error {
	if runSeconds < 0 || runSeconds > 900 || intervalMS < 0 || intervalMS > 10000 {
		return fmt.Errorf("invalid diagnostic schedule")
	}
	if count < 1 || count > 500 || workers < 1 || workers > 8 || budget < time.Second || budget > 120*time.Second {
		return fmt.Errorf("invalid diagnostic bounds")
	}
	jobs := make(chan int)
	var wg sync.WaitGroup
	var out sync.Mutex
	failures := 0
	completed := 0
	for i := 0; i < workers; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for index := range jobs {
				diagnoseActive.Add(1)
				row, e := executeWorkload(cfg, target, kind, s, budget)
				diagnoseActive.Add(-1)
				if row == nil {
					row = map[string]any{}
				}
				row["sample"] = index
				row["workers"] = workers
				if e != nil {
					row["error"] = errorCategory(e)
				}
				out.Lock()
				completed++
				if e != nil {
					failures++
				}
				json.NewEncoder(os.Stdout).Encode(row)
				out.Unlock()
			}
		}()
	}
	var stop <-chan time.Time
	if runSeconds > 0 {
		timer := time.NewTimer(time.Duration(runSeconds) * time.Second)
		defer timer.Stop()
		stop = timer.C
	}
produce:
	for i := 0; i < count; i++ {
		select {
		case jobs <- i + 1:
		case <-stop:
			break produce
		}
		if intervalMS > 0 {
			timer := time.NewTimer(time.Duration(intervalMS) * time.Millisecond)
			select {
			case <-timer.C:
			case <-stop:
				timer.Stop()
				break produce
			}
		}
	}
	close(jobs)
	wg.Wait()
	if failures > 0 {
		return fmt.Errorf("%d of %d diagnostic requests failed; see phase metadata", failures, completed)
	}
	return nil
}
