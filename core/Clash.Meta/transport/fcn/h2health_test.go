package fcn

import (
	"context"
	"io"
	"net"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

func TestH2SlowTargetKeepsHealthyConnection(t *testing.T) {
	l, e := net.Listen("tcp4", "127.0.0.1:0")
	if e != nil {
		t.Fatal(e)
	}
	defer l.Close()
	go func() {
		c, e := l.Accept()
		if e != nil {
			return
		}
		defer c.Close()
		var b [1]byte
		io.ReadFull(c, b[:])
		time.Sleep(3 * time.Second)
		c.Write(b[:])
	}()
	c, _, stop := fixture(t, "h2", 30*time.Second)
	defer stop()
	var probes atomic.Int64
	c.cfg.Trace = func(e Event) {
		if e.Stage == "entry_health" {
			probes.Add(1)
		}
	}
	ctx, cancel := context.WithTimeout(context.Background(), 7*time.Second)
	defer cancel()
	conn, e := c.Dial(ctx, l.Addr().String())
	if e != nil {
		t.Fatal(e)
	}
	defer conn.Close()
	c.mu.Lock()
	p := c.pool
	c.mu.Unlock()
	conn.Write([]byte{17})
	var b [1]byte
	if _, e = io.ReadFull(conn, b[:]); e != nil || b[0] != 17 {
		t.Fatalf("read: %v", e)
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	if probes.Load() == 0 {
		t.Fatal("health check was not exercised")
	}
	if c.pool != p || p.retired {
		t.Fatal("slow target retired a healthy entry")
	}
}

func TestH2BlackholeRetiresOnlyForNewBusiness(t *testing.T) {
	c, _, stop := fixture(t, "h2", 30*time.Second)
	defer stop()
	origin := c.cfg.Endpoint
	listener, e := net.Listen("tcp4", "127.0.0.1:0")
	if e != nil {
		t.Fatal(e)
	}
	defer listener.Close()
	var drop atomic.Bool
	var accepts atomic.Int64
	var socketsMu sync.Mutex
	var sockets []net.Conn
	defer func() {
		socketsMu.Lock()
		defer socketsMu.Unlock()
		for _, s := range sockets {
			s.Close()
		}
	}()
	go func() {
		for {
			down, e := listener.Accept()
			if e != nil {
				return
			}
			up, e := net.Dial("tcp", origin)
			if e != nil {
				down.Close()
				return
			}
			first := accepts.Add(1) == 1
			socketsMu.Lock()
			sockets = append(sockets, down, up)
			socketsMu.Unlock()
			pipe := func(dst, src net.Conn) {
				b := make([]byte, 32<<10)
				for {
					n, e := src.Read(b)
					if e != nil {
						return
					}
					if first && drop.Load() {
						continue
					}
					if _, e = dst.Write(b[:n]); e != nil {
						return
					}
				}
			}
			go pipe(up, down)
			go pipe(down, up)
		}
	}()
	c.cfg.Endpoint = listener.Addr().String()
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	target, _ := echoTarget(t)
	if e = checkEcho(ctx, c, target, []byte("prime")); e != nil {
		t.Fatal(e)
	}
	held, e := c.Dial(ctx, target)
	if e != nil {
		t.Fatal(e)
	}
	defer held.Close()
	c.mu.Lock()
	old := c.pool
	c.mu.Unlock()
	drop.Store(true)
	short, finish := context.WithTimeout(ctx, 100*time.Millisecond)
	defer finish()
	if n, e := c.Dial(short, target); e == nil {
		n.Close()
		t.Fatal("blackholed OPEN accepted")
	}
	deadline := time.Now().Add(3 * time.Second)
	for {
		c.mu.Lock()
		retired := old.retired
		stillTracked := c.all[old]
		c.mu.Unlock()
		if retired {
			if !stillTracked {
				t.Fatal("active old connection removed")
			}
			break
		}
		if time.Now().After(deadline) {
			t.Fatal("unresponsive entry not retired")
		}
		time.Sleep(5 * time.Millisecond)
	}
	if e = checkEcho(ctx, c, target, []byte("fresh business")); e != nil {
		t.Fatal(e)
	}
	c.mu.Lock()
	if c.pool == old {
		t.Fatal("old connection reused")
	}
	c.mu.Unlock()
	held.Close()
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.all[old] {
		t.Fatal("drained retired connection retained")
	}
}
