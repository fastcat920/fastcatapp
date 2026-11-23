package fcn

import (
	"bytes"
	"context"
	"crypto/tls"
	"crypto/x509"
	qtls "github.com/metacubex/tls"
	"io"
	"net"
	"net/http/httptest"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

func fixture(t *testing.T, carrier string, idle time.Duration) (*Client, *Server, func()) {
	return fixtureChain(t, carrier, idle, 1)
}
func fixtureChain(t *testing.T, carrier string, idle time.Duration, copies int) (*Client, *Server, func()) {
	return fixtureProfile(t, carrier, idle, copies, "")
}
func fixtureProfile(t *testing.T, carrier string, idle time.Duration, copies int, profile string) (*Client, *Server, func()) {
	return fixtureProfileConfig(t, carrier, idle, copies, profile, nil)
}
func fixtureProfileConfig(t *testing.T, carrier string, idle time.Duration, copies int, profile string, configure func(*ServerConfig)) (*Client, *Server, func()) {
	t.Helper()
	key := bytes.Repeat([]byte{7}, 32)
	cfg := ServerConfig{Accounts: map[string][]byte{"test": key}, QUICProfile: profile, AllowPrivate: true, IdleTimeout: idle, Congestion: "bbr"}
	if configure != nil {
		configure(&cfg)
	}
	s, e := NewServer(cfg)
	if e != nil {
		t.Fatal(e)
	}
	h := httptest.NewUnstartedServer(s)
	h.EnableHTTP2 = true
	h.Config.ConnContext = s.ConnContext
	h.Config.IdleTimeout = idle
	h.TLS = &tls.Config{MinVersion: tls.VersionTLS13}
	h.StartTLS()
	roots := x509.NewCertPool()
	roots.AddCert(h.Certificate())
	endpoint := h.Listener.Addr().String()
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	var pc net.PacketConn
	if carrier == "quic" {
		pc, e = net.ListenPacket("udp4", "127.0.0.1:0")
		if e != nil {
			t.Fatal(e)
		}
		endpoint = pc.LocalAddr().String()
		cert := h.TLS.Certificates[0]
		chain := make([][]byte, copies)
		for i := range chain {
			chain[i] = cert.Certificate[0]
		}
		cert.Certificate = chain
		go func() {
			defer close(done)
			s.ServeQUIC(ctx, pc, &qtls.Config{Certificates: []qtls.Certificate{{Certificate: cert.Certificate, PrivateKey: cert.PrivateKey}}})
		}()
	} else {
		close(done)
	}
	c, e := NewClient(ctx, Config{Endpoint: endpoint, ServerName: "example.com", Account: "test", Key: key, Roots: roots, IdleTimeout: idle, QUICProfile: profile, Congestion: "bbr"}, carrier)
	if e != nil {
		t.Fatal(e)
	}
	return c, s, func() {
		c.Close()
		cancel()
		if pc != nil {
			pc.Close()
		}
		h.Close()
		select {
		case <-done:
		case <-time.After(3 * time.Second):
			t.Error("server did not stop")
		}
	}
}
func echoTarget(t *testing.T) (string, *atomic.Int64) {
	t.Helper()
	l, e := net.Listen("tcp4", "127.0.0.1:0")
	if e != nil {
		t.Fatal(e)
	}
	count := new(atomic.Int64)
	t.Cleanup(func() { l.Close() })
	go func() {
		for {
			c, e := l.Accept()
			if e != nil {
				return
			}
			count.Add(1)
			go func() { defer c.Close(); io.Copy(c, c) }()
		}
	}()
	return l.Addr().String(), count
}
func checkEcho(ctx context.Context, c *Client, target string, payload []byte) error {
	conn, e := c.Dial(ctx, target)
	if e != nil {
		return e
	}
	defer conn.Close()
	conn.SetDeadline(time.Now().Add(5 * time.Second))
	done := make(chan error, 1)
	go func() {
		_, e := conn.Write(payload)
		if e == nil {
			e = conn.(interface{ CloseWrite() error }).CloseWrite()
		}
		done <- e
	}()
	b, e := io.ReadAll(conn)
	if e != nil {
		return e
	}
	if e = <-done; e != nil {
		return e
	}
	if !bytes.Equal(b, payload) {
		return io.ErrUnexpectedEOF
	}
	return nil
}
func TestConcurrentIntegrityHalfCloseAndIdle(t *testing.T) {
	target, _ := echoTarget(t)
	for _, carrier := range []string{"quic", "h2"} {
		t.Run(carrier, func(t *testing.T) {
			c, s, stop := fixture(t, carrier, 200*time.Millisecond)
			defer stop()
			ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
			defer cancel()
			var wg sync.WaitGroup
			for i := 0; i < 8; i++ {
				wg.Add(1)
				go func(i int) {
					defer wg.Done()
					if e := checkEcho(ctx, c, target, bytes.Repeat([]byte{byte(i)}, 256<<10)); e != nil {
						t.Error(e)
					}
				}(i)
			}
			wg.Wait()
			time.Sleep(600 * time.Millisecond)
			if e := checkEcho(ctx, c, target, []byte("after-idle")); e != nil {
				t.Fatal(e)
			}
			if s.Counters().Sessions.Load() < 2 {
				t.Fatal("idle did not create fresh connection")
			}
			c.Reset()
			if e := checkEcho(ctx, c, target, []byte("after-network-reset")); e != nil {
				t.Fatal(e)
			}
			if s.Counters().Upload.Load() != s.Counters().Download.Load() {
				t.Fatal("meter mismatch")
			}
		})
	}
}
func TestAuthorizationNoTargetDial(t *testing.T) {
	target, count := echoTarget(t)
	for _, carrier := range []string{"quic", "h2"} {
		t.Run(carrier, func(t *testing.T) {
			c, _, stop := fixture(t, carrier, time.Second)
			defer stop()
			c.cfg.Key = bytes.Repeat([]byte{8}, 32)
			before := count.Load()
			ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
			defer cancel()
			conn, e := c.Dial(ctx, target)
			if e == nil {
				defer conn.Close()
				conn.SetReadDeadline(time.Now().Add(time.Second))
				var b [1]byte
				_, e = conn.Read(b[:])
			}
			if e == nil {
				t.Fatal("bad credential accepted")
			}
			if count.Load() != before {
				t.Fatal("unauthorized target dialed")
			}
		})
	}
}
func TestBindingTamperReplayAndBounds(t *testing.T) {
	key := bytes.Repeat([]byte{1}, 32)
	binding := bytes.Repeat([]byte{2}, 32)
	b, e := encodeHeader("a", "example.com:443", 0, key, binding)
	if e != nil {
		t.Fatal(e)
	}
	h, e := readHeader(bytes.NewReader(b))
	if e != nil {
		t.Fatal(e)
	}
	s, _ := NewServer(ServerConfig{Accounts: map[string][]byte{"a": key}})
	state := &connState{seen: make(map[[16]byte]bool)}
	if !s.authorize(h, binding, state) || s.authorize(h, binding, state) {
		t.Fatal("replay protection")
	}
	if verifyHeader(h, key, bytes.Repeat([]byte{3}, 32)) {
		t.Fatal("cross TLS replay")
	}
	h.raw[5] ^= 1
	if verifyHeader(h, key, binding) {
		t.Fatal("tamper accepted")
	}
	for _, bad := range [][]byte{{255, 255}, {0, 1, 1}, {0, 55, 1}} {
		if _, e := readHeader(bytes.NewReader(bad)); e == nil {
			t.Fatal("malformed accepted")
		}
	}
}
func TestUDPDatagrams(t *testing.T) {
	udp, e := net.ListenPacket("udp4", "127.0.0.1:0")
	if e != nil {
		t.Fatal(e)
	}
	defer udp.Close()
	go func() {
		b := make([]byte, 2048)
		for {
			n, a, e := udp.ReadFrom(b)
			if e != nil {
				return
			}
			udp.WriteTo(b[:n], a)
		}
	}()
	c, _, stop := fixture(t, "quic", time.Second)
	defer stop()
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	p, e := c.DialPacket(ctx, udp.LocalAddr().String())
	if e != nil {
		t.Fatal(e)
	}
	defer p.Close()
	p.SetDeadline(time.Now().Add(2 * time.Second))
	for _, payload := range [][]byte{[]byte("udp"), bytes.Repeat([]byte{3}, 1100), {}} {
		if _, e := p.WriteTo(payload, nil); e != nil {
			t.Fatal(e)
		}
		b := make([]byte, 1200)
		n, _, e := p.ReadFrom(b)
		if e != nil || !bytes.Equal(payload, b[:n]) {
			t.Fatalf("datagram: %d %v", n, e)
		}
	}
	if _, e = p.WriteTo(make([]byte, 1101), nil); e == nil {
		t.Fatal("oversize accepted")
	}
}
func FuzzHeader(f *testing.F) {
	f.Add([]byte{0, 1, 1})
	f.Fuzz(func(t *testing.T, b []byte) { readHeader(bytes.NewReader(b)) })
}

func TestStreamCancellationIsolated(t *testing.T) {
	target, _ := echoTarget(t)
	for _, carrier := range []string{"h2", "quic"} {
		t.Run(carrier, func(t *testing.T) {
			c, _, stop := fixture(t, carrier, 3*time.Second)
			defer stop()
			ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
			defer cancel()
			bad, e := c.Dial(ctx, target)
			if e != nil {
				t.Fatal(e)
			}
			defer bad.Close()
			bad.SetDeadline(time.Now().Add(30 * time.Millisecond))
			var b [1]byte
			if _, e = bad.Read(b[:]); e == nil {
				t.Fatal("deadline ignored")
			}
			if e = checkEcho(ctx, c, target, []byte("unrelated stream survives")); e != nil {
				t.Fatal(e)
			}
		})
	}
}
func TestTargetDenialAndGenerationLimit(t *testing.T) {
	s, e := NewServer(ServerConfig{Accounts: map[string][]byte{"a": bytes.Repeat([]byte{1}, 32)}})
	if e != nil {
		t.Fatal(e)
	}
	for _, target := range []string{"127.0.0.1:80", "[::1]:80", "192.168.1.1:80", "169.254.169.254:80", "198.18.0.1:80", "example.com:0"} {
		if n, e := s.cfg.dial(context.Background(), "tcp", target); e == nil {
			n.Close()
			t.Fatal("private/reserved target allowed: " + target)
		}
	}
	st := &connState{seen: make(map[[16]byte]bool)}
	for i := 0; i < maxRequests; i++ {
		var nonce [16]byte
		nonce[0] = byte(i)
		nonce[1] = byte(i >> 8)
		st.seen[nonce] = true
	}
	b, _ := encodeHeader("a", "example.com:443", 0, s.cfg.Accounts["a"], bytes.Repeat([]byte{2}, 32))
	h, _ := readHeader(bytes.NewReader(b))
	if s.authorize(h, bytes.Repeat([]byte{2}, 32), st) {
		t.Fatal("nonce bound ignored")
	}
}

func TestCertificateValidationAndClosedClient(t *testing.T) {
	for _, carrier := range []string{"quic", "h2"} {
		t.Run(carrier, func(t *testing.T) {
			c, _, stop := fixture(t, carrier, time.Second)
			defer stop()
			c.cfg.Roots = x509.NewCertPool()
			ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
			defer cancel()
			if e := c.Warm(ctx); e == nil {
				t.Fatal("untrusted certificate accepted")
			}
			c.Close()
			if _, e := c.Dial(ctx, "example.com:443"); e == nil {
				t.Fatal("closed client accepted business")
			}
		})
	}
}

func TestConnectingWaiterCancellationAndClose(t *testing.T) {
	pc, e := net.ListenPacket("udp4", "127.0.0.1:0")
	if e != nil {
		t.Fatal(e)
	}
	defer pc.Close()
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	c, e := NewClient(ctx, Config{Endpoint: pc.LocalAddr().String(), ServerName: "example.com", Account: "test", Key: bytes.Repeat([]byte{1}, 32), ConnectTimeout: time.Second}, "quic")
	if e != nil {
		t.Fatal(e)
	}
	defer c.Close()
	first := make(chan error, 1)
	go func() { first <- c.Warm(ctx) }()
	deadline := time.Now().Add(time.Second)
	for {
		c.mu.Lock()
		pending := c.pending != nil
		c.mu.Unlock()
		if pending {
			break
		}
		if time.Now().After(deadline) {
			t.Fatal("dial did not start")
		}
		time.Sleep(time.Millisecond)
	}
	short, stop := context.WithTimeout(ctx, 25*time.Millisecond)
	defer stop()
	start := time.Now()
	if e := c.Warm(short); e == nil {
		t.Fatal("waiter ignored cancellation")
	}
	if time.Since(start) > 150*time.Millisecond {
		t.Fatal("waiter blocked behind physical dial")
	}
	start = time.Now()
	c.Close()
	if time.Since(start) > 150*time.Millisecond {
		t.Fatal("Close blocked behind physical dial")
	}
	select {
	case e := <-first:
		if e == nil {
			t.Fatal("blackhole unexpectedly connected")
		}
	case <-time.After(time.Second):
		t.Fatal("dial not cancelled")
	}
}

func TestHandshakeProgressBeyondLegacyCutoff(t *testing.T) {
	for _, budget := range []time.Duration{5 * time.Second, 0} {
		t.Run(budget.String(), func(t *testing.T) {
			c, _, stop := fixtureChain(t, "quic", 15*time.Second, 8)
			defer stop()
			server, e := net.ResolveUDPAddr("udp", c.cfg.Endpoint)
			if e != nil {
				t.Fatal(e)
			}
			pc, e := net.ListenPacket("udp4", "127.0.0.1:0")
			if e != nil {
				t.Fatal(e)
			}
			var timersMu sync.Mutex
			var timers []*time.Timer
			done := make(chan struct{})
			start := time.Now()
			go func() {
				defer close(done)
				var client net.Addr
				seq := 0
				buf := make([]byte, 65536)
				for {
					n, from, e := pc.ReadFrom(buf)
					if e != nil {
						return
					}
					data := append([]byte(nil), buf[:n]...)
					if from.String() == server.String() {
						if client == nil {
							continue
						}
						to := client
						delay := 4*time.Second + time.Duration(seq)*200*time.Millisecond - time.Since(start)
						seq++
						timersMu.Lock()
						timers = append(timers, time.AfterFunc(delay, func() { pc.WriteTo(data, to) }))
						timersMu.Unlock()
					} else {
						client = from
						pc.WriteTo(data, server)
					}
				}
			}()
			defer func() {
				pc.Close()
				<-done
				timersMu.Lock()
				for _, timer := range timers {
					timer.Stop()
				}
				timersMu.Unlock()
			}()
			c.cfg.Endpoint = pc.LocalAddr().String()
			c.cfg.ConnectTimeout = budget
			ctx, cancel := context.WithTimeout(context.Background(), 12*time.Second)
			defer cancel()
			e = c.Warm(ctx)
			if budget != 0 {
				if e == nil {
					t.Fatal("legacy 5s cutoff did not reproduce")
				}
			} else if e != nil {
				t.Fatal(e)
			}
		})
	}
}

func TestQUICProfilesPreserveStreams(t *testing.T) {
	target, _ := echoTarget(t)
	for _, profile := range []string{"baseline", "wide", "conservative", "balanced", "bbr-legacy"} {
		t.Run(profile, func(t *testing.T) {
			c, _, stop := fixtureProfile(t, "quic", time.Second, 1, profile)
			defer stop()
			ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
			defer cancel()
			var wg sync.WaitGroup
			for i := 0; i < 4; i++ {
				wg.Add(1)
				go func(i int) {
					defer wg.Done()
					if e := checkEcho(ctx, c, target, bytes.Repeat([]byte{byte(i)}, 512<<10)); e != nil {
						t.Error(e)
					}
				}(i)
			}
			wg.Wait()
		})
	}
}

func TestCoalescedOpenLargeDuplexAndServerFirst(t *testing.T) {
	c, _, stop := fixture(t, "quic", time.Second)
	defer stop()
	c.cfg.CoalesceOpen = true
	target, _ := echoTarget(t)
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	if e := checkEcho(ctx, c, target, bytes.Repeat([]byte{1, 2, 3, 4}, 3<<20)); e != nil {
		t.Fatal(e)
	}
	l, e := net.Listen("tcp4", "127.0.0.1:0")
	if e != nil {
		t.Fatal(e)
	}
	defer l.Close()
	go func() {
		n, e := l.Accept()
		if e != nil {
			return
		}
		defer n.Close()
		n.Write([]byte("greeting"))
	}()
	n, e := c.Dial(ctx, l.Addr().String())
	if e != nil {
		t.Fatal(e)
	}
	defer n.Close()
	n.SetDeadline(time.Now().Add(3 * time.Second))
	b := make([]byte, 8)
	if _, e = io.ReadFull(n, b); e != nil || string(b) != "greeting" {
		t.Fatalf("server-first: %q %v", b, e)
	}
	n2, e := c.Dial(ctx, target)
	if e != nil {
		t.Fatal(e)
	}
	defer n2.Close()
	n2.SetDeadline(time.Now().Add(3 * time.Second))
	if e = n2.(interface{ CloseWrite() error }).CloseWrite(); e != nil {
		t.Fatal(e)
	}
	data, e := io.ReadAll(n2)
	if e != nil || len(data) != 0 {
		t.Fatalf("empty half-close: %d %v", len(data), e)
	}
}
