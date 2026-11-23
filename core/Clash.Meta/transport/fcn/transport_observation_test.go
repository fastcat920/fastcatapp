package fcn

import (
	"context"
	"io"
	"net"
	"sync"
	"testing"
	"time"
)

func waitObservation(t *testing.T, n *quicConn, predicate func(TransportObservation) bool) TransportObservation {
	t.Helper()
	deadline := time.Now().Add(3 * time.Second)
	for time.Now().Before(deadline) {
		o := n.TransportObservation()
		if predicate(o) {
			return o
		}
		time.Sleep(time.Millisecond)
	}
	t.Fatal("observation transition missing")
	return TransportObservation{}
}
func TestAsyncOpenStatusIncludesTargetDialWait(t *testing.T) {
	release := make(chan struct{})
	var once sync.Once
	unblock := func() { once.Do(func() { close(release) }) }
	defer unblock()
	var mu sync.Mutex
	var events []Event
	c, _, stop := fixtureProfileConfig(t, "quic", time.Second, 1, "", func(cfg *ServerConfig) {
		cfg.Trace = func(e Event) { mu.Lock(); events = append(events, e); mu.Unlock() }
		cfg.DialContext = func(ctx context.Context, network, target string) (net.Conn, error) {
			select {
			case <-release:
			case <-ctx.Done():
				return nil, ctx.Err()
			}
			return (&net.Dialer{}).DialContext(ctx, network, target)
		}
	})
	defer stop()
	c.cfg.Trace = func(Event) {}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	target, _ := echoTarget(t)
	n, e := c.Dial(ctx, target)
	if e != nil {
		t.Fatal(e)
	}
	defer n.Close()
	q := n.(*quicConn)
	if _, e = n.Write([]byte("x")); e != nil {
		t.Fatal(e)
	}
	done := make(chan error, 1)
	go func() { _, e := io.ReadFull(n, make([]byte, 1)); done <- e }()
	o := waitObservation(t, q, func(o TransportObservation) bool { return o.StatusStartUS > 0 && o.StatusEndUS == 0 })
	if o.FirstDataUS != 0 {
		t.Fatal("payload arrived before held target dial")
	}
	unblock()
	if e = <-done; e != nil {
		t.Fatal(e)
	}
	o = q.TransportObservation()
	if o.StatusWaitUS <= 0 || o.Session == 0 || o.RequestTag == "" || o.FirstDataUS < o.StatusEndUS {
		t.Fatal("status timing/tag invalid", o)
	}
	mu.Lock()
	defer mu.Unlock()
	matched := false
	for _, event := range events {
		if event.RequestTag == o.RequestTag && event.Stage == "server_target_dial" && event.Session > 0 {
			matched = true
		}
	}
	if !matched {
		t.Fatal("no cross-end target dial correlation")
	}
}
func TestPayloadWaitRemainsSeparateFromOpenStatus(t *testing.T) {
	listener, e := net.Listen("tcp4", "127.0.0.1:0")
	if e != nil {
		t.Fatal(e)
	}
	defer listener.Close()
	release := make(chan struct{})
	var once sync.Once
	unblock := func() { once.Do(func() { close(release) }) }
	defer unblock()
	go func() {
		n, e := listener.Accept()
		if e != nil {
			return
		}
		defer n.Close()
		b := make([]byte, 1)
		if _, e = io.ReadFull(n, b); e != nil {
			return
		}
		<-release
		n.Write(b)
	}()
	c, _, stop := fixture(t, "quic", time.Second)
	defer stop()
	c.cfg.Trace = func(Event) {}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	n, e := c.Dial(ctx, listener.Addr().String())
	if e != nil {
		t.Fatal(e)
	}
	defer n.Close()
	q := n.(*quicConn)
	n.Write([]byte("x"))
	done := make(chan error, 1)
	go func() { _, e := io.ReadFull(n, make([]byte, 1)); done <- e }()
	o := waitObservation(t, q, func(o TransportObservation) bool { return o.StatusEndUS > 0 })
	if o.FirstDataUS != 0 {
		t.Fatal("held payload already arrived")
	}
	unblock()
	if e = <-done; e != nil {
		t.Fatal(e)
	}
	if q.TransportObservation().FirstDataUS < o.StatusEndUS {
		t.Fatal("status and payload boundaries reversed")
	}
}
