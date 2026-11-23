//go:build !go1.21

package h2client

import (
	"context"
	"sync"
)

// Go 1.20 compatibility for context.AfterFunc.
func afterFunc(ctx context.Context, run func()) func() bool {
	var once sync.Once
	stopped := make(chan struct{})
	go func() {
		select {
		case <-ctx.Done():
			once.Do(func() { go run() })
		case <-stopped:
		}
	}()
	return func() bool {
		didStop := false
		once.Do(func() { didStop = true; close(stopped) })
		return didStop
	}
}
