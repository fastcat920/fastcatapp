// Package fastcatentry bounds entry establishment for automatic FastCat nodes.
package fastcatentry

import (
	"context"
	"sync"
	"time"
)

// Prepare resolves the entry and obtains ECH configuration before a new physical dial.
type Prepare func(ctx context.Context, address, serverName string) (resolved string, ech []byte, err error)

type key struct{}

type Attempt struct {
	mu      sync.Mutex
	timer   *time.Timer
	ready   bool
	expired bool
}

// Start budgets only the connection to the entry. Once acquired, the target's
// CONNECT exchange can use the caller's full remaining deadline.
func Start(parent context.Context, limit time.Duration) (context.Context, *Attempt, context.CancelFunc) {
	ctx, cancel := context.WithCancel(parent)
	a := &Attempt{}
	a.timer = time.AfterFunc(limit, func() {
		a.mu.Lock()
		defer a.mu.Unlock()
		if !a.ready {
			a.expired = true
			cancel()
		}
	})
	return context.WithValue(ctx, key{}, a), a, func() { a.timer.Stop(); cancel() }
}

func Ready(ctx context.Context) {
	a, _ := ctx.Value(key{}).(*Attempt)
	if a != nil {
		a.mu.Lock()
		a.ready = true
		a.timer.Stop()
		a.mu.Unlock()
	}
}

func (a *Attempt) State() (ready, expired bool) {
	a.mu.Lock()
	defer a.mu.Unlock()
	return a.ready, a.expired
}
