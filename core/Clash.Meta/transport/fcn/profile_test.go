package fcn

import (
	"bytes"
	"context"
	"os"
	"sync"
	"testing"
	"time"
)

// Opt-in, local-only diagnostic. No speed assertion: this is not a WAN score.
func TestLocalPrimarySamplerCost(t *testing.T) {
	if os.Getenv("FASTCAT_LOCAL_PROFILE") != "1" {
		t.Skip("opt-in local performance diagnostic")
	}
	old, _, stop := fixture(t, "quic", time.Minute)
	defer stop()
	cfg := old.cfg
	old.Close()
	target, _ := echoTarget(t)
	payload := bytes.Repeat([]byte{0, 1, 2, 3}, 2<<20)
	for round := 0; round < 3; round++ {
		for k := 0; k < 2; k++ {
			primary := (round+k)%2 == 1
			cc := cfg
			cc.QUICLanes = 1
			if primary {
				cc.QUICLanes = 2
				cc.AdaptiveLanes = true
				cc.PrimaryPreferred = true
			}
			ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
			c, e := NewClient(ctx, cc, "quic")
			if e != nil {
				cancel()
				t.Fatal(e)
			}
			if e = c.Warm(ctx); e != nil {
				c.Close()
				cancel()
				t.Fatal(e)
			}
			start := time.Now()
			var wg sync.WaitGroup
			for i := 0; i < 4; i++ {
				wg.Add(1)
				go func() {
					defer wg.Done()
					if e := checkEcho(ctx, c, target, payload); e != nil {
						t.Error(e)
					}
				}()
			}
			wg.Wait()
			elapsed := time.Since(start)
			t.Logf("round=%d primary=%v elapsed_ms=%.3f echo_mbps=%.3f usage=%+v", round+1, primary, float64(elapsed.Microseconds())/1000, float64(4*len(payload)*8)/elapsed.Seconds()/1e6, c.LaneUsage())
			c.Close()
			cancel()
		}
	}
}
