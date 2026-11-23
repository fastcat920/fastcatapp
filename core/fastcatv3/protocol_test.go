package fastcatv3

import (
	"bytes"
	"context"
	"crypto/tls"
	"crypto/x509"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"net/netip"
	"os"
	"sync"
	"testing"
	"time"

	qhttp "github.com/metacubex/http"
	"github.com/metacubex/quic-go/http3"
	qtls "github.com/metacubex/tls"
)

func unhex(t *testing.T, s string) []byte {
	t.Helper()
	b, e := hex.DecodeString(s)
	if e != nil {
		t.Fatal(e)
	}
	return b
}
func TestSpecVectors(t *testing.T) {
	path := os.Getenv("FASTCAT_V3_VECTOR_FILE")
	if path == "" {
		path = "../../docs/protocols/fastcat-v3/vectors.json"
	}
	data, e := os.ReadFile(path)
	if e != nil {
		t.Fatal(e)
	}
	var v map[string]json.RawMessage
	if e = json.Unmarshal(data, &v); e != nil {
		t.Fatal(e)
	}
	get := func(k string) []byte {
		var s string
		if e := json.Unmarshal(v[k], &s); e != nil {
			t.Fatal(k, e)
		}
		return unhex(t, s)
	}
	si, sr, ei, er := get("client_static_private"), get("server_static_private"), get("client_ephemeral_private"), get("server_ephemeral_private")
	pub, _ := public(sr)
	a, b := newNoise(get("prologue"), pub), newNoise(get("prologue"), pub)
	m, e := a.clientInit(si, ei, pub, get("client_payload"))
	if e != nil || !bytes.Equal(m, get("client_init")) {
		t.Fatal("Noise message 1 mismatch", e)
	}
	ep, sp, plain, e := b.readInit(sr, m)
	if e != nil || !bytes.Equal(plain, get("client_payload")) {
		t.Fatal("Noise message 1 decode", e)
	}
	m, e = b.accept(er, ep, sp, get("server_payload"))
	if e != nil || !bytes.Equal(m, get("server_accept")) {
		t.Fatal("Noise message 2 mismatch", e)
	}
	plain, e = a.readAccept(ei, si, m)
	if e != nil || !bytes.Equal(plain, get("server_payload")) {
		t.Fatal("Noise message 2 decode", e)
	}
	a1, a2 := a.split()
	b1, b2 := b.split()
	if !bytes.Equal(a.h, get("handshake_hash")) || !bytes.Equal(a1, b1) || !bytes.Equal(a2, b2) || !bytes.Equal(a1, get("split_c2s")) {
		t.Fatal("Noise final mismatch")
	}
	ctx := contextHash(get("prologue"), a.h, get("carrier_binding"))
	if !bytes.Equal(ctx, get("context")) {
		t.Fatal("binding context mismatch")
	}
	r := newRecord(a1, ctx, 0)
	wire, e := r.seal(get("record_plaintext"))
	if e != nil || !bytes.Equal(wire, get("record_wire")) {
		t.Fatal("record mismatch", e)
	}
	for _, mutate := range []string{"tag", "direction", "binding"} {
		t.Run(mutate, func(t *testing.T) {
			wire := append([]byte(nil), wire...)
			c := newRecord(a1, ctx, 0)
			switch mutate {
			case "tag":
				wire[len(wire)-1] ^= 1
			case "direction":
				c.direction = 1
			case "binding":
				c.ctx = append([]byte(nil), ctx...)
				c.ctx[0] ^= 1
			}
			if _, e := c.read(bytes.NewReader(wire)); e == nil {
				t.Fatal("accepted invalid record")
			}
		})
	}
}
func testConfig() Config {
	key := random(32)
	pub, _ := public(key)
	return Config{ServiceID: random(16), ServerPrivate: key, ServerPublic: pub, Token: random(32), AllowPrivate: true}
}
func startCarrier(t *testing.T, c Config, protocol string) (DialConfig, func()) {
	t.Helper()
	s, e := NewServer(c)
	if e != nil {
		t.Fatal(e)
	}
	s.OnError = func(e error) { fmt.Println("server session ended:", e) }
	fixture := httptest.NewUnstartedServer(s)
	fixture.EnableHTTP2 = true
	fixture.TLS = &tls.Config{MinVersion: tls.VersionTLS13}
	fixture.StartTLS()
	roots := x509.NewCertPool()
	roots.AddCert(fixture.Certificate())
	dc := DialConfig{Config: c, Endpoint: fixture.Listener.Addr().String(), Roots: roots, ServerName: "example.com"}
	if protocol == "h2" {
		return dc, fixture.Close
	}
	cert := fixture.TLS.Certificates[0]
	socket, e := net.ListenPacket("udp4", "127.0.0.1:0")
	if e != nil {
		t.Fatal(e)
	}
	server := &http3.Server{Handler: qhttp.HandlerFunc(s.ServeHTTP3), TLSConfig: &qtls.Config{MinVersion: qtls.VersionTLS13, Certificates: []qtls.Certificate{{Certificate: cert.Certificate, PrivateKey: cert.PrivateKey}}, NextProtos: []string{"h3"}}}
	go server.Serve(socket)
	dc.Endpoint = socket.LocalAddr().String()
	return dc, func() { server.Close(); socket.Close(); fixture.Close() }
}
func echoServers(t *testing.T) (string, string) {
	t.Helper()
	ln, e := net.Listen("tcp4", "127.0.0.1:0")
	if e != nil {
		t.Fatal(e)
	}
	t.Cleanup(func() { ln.Close() })
	go func() {
		for {
			c, e := ln.Accept()
			if e != nil {
				return
			}
			go func() { defer c.Close(); io.Copy(c, c) }()
		}
	}()
	udp, e := net.ListenPacket("udp4", "127.0.0.1:0")
	if e != nil {
		t.Fatal(e)
	}
	t.Cleanup(func() { udp.Close() })
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
	return ln.Addr().String(), udp.LocalAddr().String()
}
func TestCarriersMultiplexFlowAndKeyUpdate(t *testing.T) {
	tcpTarget, udpTarget := echoServers(t)
	for _, protocol := range []string{"h2", "h3"} {
		t.Run(protocol, func(t *testing.T) {
			dc, closeServer := startCarrier(t, testConfig(), protocol)
			defer closeServer()
			ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
			defer cancel()
			session, e := Dial(ctx, dc, protocol)
			if e != nil {
				t.Fatal(e)
			}
			defer session.Close()
			const workers = 8
			errs := make(chan error, workers)
			var wg sync.WaitGroup
			for i := 0; i < workers; i++ {
				wg.Add(1)
				go func(index int) {
					defer wg.Done()
					stream, e := session.Open(ctx, 0, tcpTarget)
					if e != nil {
						errs <- e
						return
					}
					defer stream.Close()
					stream.SetDeadline(time.Now().Add(15 * time.Second))
					payload := bytes.Repeat([]byte{byte(index + 1)}, 600000)
					sent := make(chan error, 1)
					go func() {
						_, e := stream.Write(payload)
						if e == nil {
							e = stream.CloseWrite()
						}
						sent <- e
					}()
					out, e := io.ReadAll(stream)
					if e == nil {
						e = <-sent
					}
					if e == nil && !bytes.Equal(out, payload) {
						e = io.ErrUnexpectedEOF
					}
					errs <- e
				}(i)
			}
			if e = session.UpdateKeys(); e != nil {
				t.Fatal(e)
			}
			wg.Wait()
			close(errs)
			for e := range errs {
				if e != nil {
					t.Fatal("multiplex", e)
				}
			}
			udp, e := session.Open(ctx, 1, udpTarget)
			if e != nil {
				t.Fatal(e)
			}
			defer udp.Close()
			for _, n := range []int{0, 8, 1024} {
				payload := bytes.Repeat([]byte{42}, n)
				if e = udp.SendDatagram(payload); e != nil {
					t.Fatal(e)
				}
				out, e := udp.ReceiveDatagram(ctx)
				if e != nil || !bytes.Equal(out, payload) {
					t.Fatal("UDP", n, e)
				}
			}
			if e := udp.SendDatagram(make([]byte, 1025)); e == nil {
				t.Fatal("oversize UDP accepted")
			}
		})
	}
}
func TestAuthenticationAndTargetPolicy(t *testing.T) {
	for _, protocol := range []string{"h2", "h3"} {
		t.Run(protocol, func(t *testing.T) {
			dc, closeServer := startCarrier(t, testConfig(), protocol)
			defer closeServer()
			ctx, cancel := context.WithTimeout(context.Background(), 8*time.Second)
			defer cancel()
			bad := dc
			bad.Config.Token = random(32)
			if s, e := Dial(ctx, bad, protocol); e == nil {
				s.Close()
				t.Fatal("accepted wrong credential")
			}
			bad = dc
			bad.Config.ServerPublic, _ = public(random(32))
			if s, e := Dial(ctx, bad, protocol); e == nil {
				s.Close()
				t.Fatal("accepted wrong identity")
			}
			bad = dc
			bad.Roots = x509.NewCertPool()
			if s, e := Dial(ctx, bad, protocol); e == nil {
				s.Close()
				t.Fatal("accepted untrusted certificate")
			}
		})
	}
	for _, ip := range []string{"127.0.0.1", "10.0.0.1", "169.254.169.254", "::1", "fc00::1"} {
		if allowedIP(netip.MustParseAddr(ip)) {
			t.Fatal("policy allowed", ip)
		}
	}
}

func TestReplayAndCarrierBinding(t *testing.T) {
	config := testConfig()
	prologue := append([]byte{'F', 'C', 'V', '3', 1, 1}, config.ServiceID...)
	attempt := random(16)
	prologue = append(prologue, attempt...)
	payload := append([]byte{0}, attempt...)
	payload = append(payload, vector16(config.Token)...)
	payload = append(payload, params()...)
	payload = append(payload, 0, 0)
	si, ei := random(32), random(32)
	state := newNoise(prologue, config.ServerPublic)
	message, err := state.clientInit(si, ei, config.ServerPublic, payload)
	if err != nil {
		t.Fatal(err)
	}
	cache := new(replayCache)
	binding := random(32)
	first := func(replay bool) {
		client, server := net.Pipe()
		defer client.Close()
		defer server.Close()
		client.SetDeadline(time.Now().Add(2 * time.Second))
		server.SetDeadline(time.Now().Add(2 * time.Second))
		done := make(chan error, 1)
		go func() {
			defer server.Close()
			_, err := serverHandshake(server, server, config, 1, binding, cache)
			done <- err
		}()
		if err := writeAll(client, prologue); err != nil {
			t.Fatal(err)
		}
		if err := writeMessage(client, message); err != nil {
			t.Fatal(err)
		}
		response, err := readMessage(client)
		if replay {
			if err == nil {
				t.Fatal("replayed init obtained a second acceptance")
			}
			if err := <-done; err == nil {
				t.Fatal("server accepted replay")
			}
			return
		}
		if err != nil {
			t.Fatal(err)
		}
		if _, err := state.readAccept(ei, si, response); err != nil {
			t.Fatal(err)
		}
		seed, _ := state.split()
		cipher := newRecord(seed, contextHash(prologue, state.h, binding), 0)
		record, err := cipher.seal((frame{1, 0, state.h}).encode())
		if err != nil {
			t.Fatal(err)
		}
		if err := writeAll(client, record); err != nil {
			t.Fatal(err)
		}
		if err := <-done; err != nil {
			t.Fatal(err)
		}
	}
	first(false)
	first(true)
	client, server := net.Pipe()
	defer client.Close()
	defer server.Close()
	client.SetDeadline(time.Now().Add(2 * time.Second))
	server.SetDeadline(time.Now().Add(2 * time.Second))
	done := make(chan error, 1)
	go func() {
		defer server.Close()
		_, err := serverHandshake(server, server, config, 1, binding, new(replayCache))
		done <- err
	}()
	_, err = clientHandshake(client, client, config, 1, random(32))
	if err != nil {
		t.Fatal("unexpected failure before encrypted confirmation", err)
	}
	if err := <-done; err == nil {
		t.Fatal("different TLS exporter was accepted")
	}
}

func TestPolicyEnforcedOnNormalOpen(t *testing.T) {
	target, _ := echoServers(t)
	config := testConfig()
	config.AllowPrivate = false
	for _, carrier := range []string{"h2", "h3"} {
		t.Run(carrier, func(t *testing.T) {
			dc, closeServer := startCarrier(t, config, carrier)
			defer closeServer()
			ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
			defer cancel()
			session, err := Dial(ctx, dc, carrier)
			if err != nil {
				t.Fatal(err)
			}
			defer session.Close()
			if stream, err := session.Open(ctx, 0, target); err == nil {
				stream.Close()
				t.Fatal("normal OPEN bypassed private address policy")
			}
		})
	}
}

func TestFrameValidation(t *testing.T) {
	valid := (frame{8, 0, make([]byte, 8)}).encode()
	if _, err := parseFrames(valid); err != nil {
		t.Fatal(err)
	}
	for _, input := range [][]byte{valid[:13], valid[:len(valid)-1], append([]byte{0, 0}, valid[2:]...)} {
		if _, err := parseFrames(input); err == nil {
			t.Fatal("accepted invalid frame")
		}
	}
}

func TestCancelledStreamsReleaseConnectionCredit(t *testing.T) {
	target, _ := echoServers(t)
	for _, carrier := range []string{"h2", "h3"} {
		t.Run(carrier, func(t *testing.T) {
			dc, closeServer := startCarrier(t, testConfig(), carrier)
			defer closeServer()
			ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
			defer cancel()
			s, err := Dial(ctx, dc, carrier)
			if err != nil {
				t.Fatal(err)
			}
			defer s.Close()
			payload := bytes.Repeat([]byte{7}, streamCredit)
			for i := 0; i < 24; i++ {
				stream, err := s.Open(ctx, 0, target)
				if err != nil {
					t.Fatal("open", i, err)
				}
				stream.SetDeadline(time.Now().Add(8 * time.Second))
				if _, err := stream.Write(payload); err != nil {
					t.Fatal("write", i, err)
				}
				stream.Close()
			}
			stream, err := s.Open(ctx, 0, target)
			if err != nil {
				t.Fatal(err)
			}
			defer stream.Close()
			stream.SetDeadline(time.Now().Add(5 * time.Second))
			if _, err := stream.Write([]byte{9}); err != nil {
				t.Fatal(err)
			}
			b := make([]byte, 1)
			if _, err := io.ReadFull(stream, b); err != nil || b[0] != 9 {
				t.Fatal("session stalled after cancellations", err)
			}
		})
	}
}

// A server may wait for the request body before sending response headers.
// This also guards against reintroducing an extra HTTP-header round trip.
func TestClientInitBeforeResponseHeaders(t *testing.T) {
	c := testConfig()
	server, err := NewServer(c)
	if err != nil {
		t.Fatal(err)
	}
	fixture := httptest.NewUnstartedServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		controller := http.NewResponseController(w)
		controller.SetReadDeadline(time.Now().Add(2 * time.Second))
		prefix := make([]byte, 38)
		if _, err := io.ReadFull(r.Body, prefix); err != nil {
			http.Error(w, "missing initial body", 400)
			return
		}
		msg, err := readMessage(r.Body)
		if err != nil {
			http.Error(w, "missing Noise init", 400)
			return
		}
		controller.SetReadDeadline(time.Time{})
		r.Body = struct {
			io.Reader
			io.Closer
		}{io.MultiReader(bytes.NewReader(append(prefix, vector16(msg)...)), r.Body), r.Body}
		server.ServeHTTP(w, r)
	}))
	fixture.EnableHTTP2 = true
	fixture.TLS = &tls.Config{MinVersion: tls.VersionTLS13}
	fixture.StartTLS()
	defer fixture.Close()
	roots := x509.NewCertPool()
	roots.AddCert(fixture.Certificate())
	ctx, cancel := context.WithTimeout(context.Background(), 4*time.Second)
	defer cancel()
	session, err := Dial(ctx, DialConfig{Config: c, Endpoint: fixture.Listener.Addr().String(), ServerName: "example.com", Roots: roots}, "h2")
	if err != nil {
		t.Fatal(err)
	}
	session.Close()
}

type countedRecordWriter struct {
	bytes.Buffer
	writes int
}

func (w *countedRecordWriter) Write(b []byte) (int, error) { w.writes++; return w.Buffer.Write(b) }

func TestCreditPairSharesOneRecord(t *testing.T) {
	for _, rotate := range []bool{false, true} {
		t.Run(fmt.Sprint(rotate), func(t *testing.T) {
			var wire countedRecordWriter
			key, binding := random(32), random(32)
			send, recv := newRecord(key, binding, 0), newRecord(key, binding, 0)
			if rotate {
				send.number = (1 << 24) - 1
				recv.number = send.number
			}
			out := &records{w: &wire, send: send}
			in := &records{r: &wire, receive: recv}
			expected := []frame{{6, 1, make([]byte, 8)}, {6, 0, make([]byte, 8)}}
			if err := out.writeFrames(expected...); err != nil {
				t.Fatal(err)
			}
			wantWrites := 1
			if rotate {
				wantWrites++
			}
			if wire.writes != wantWrites {
				t.Fatalf("writes %d, want %d", wire.writes, wantWrites)
			}
			if rotate {
				if frames, err := in.read(); err != nil || len(frames) != 0 {
					t.Fatalf("rotation: %v %v", frames, err)
				}
			}
			frames, err := in.read()
			if err != nil || len(frames) != 2 {
				t.Fatalf("frames: %v %v", frames, err)
			}
			for i, f := range frames {
				if f.kind != expected[i].kind || f.id != expected[i].id || !bytes.Equal(f.body, expected[i].body) {
					t.Fatal("changed control frame")
				}
			}
			before := send.number
			if err := out.writeFrames(frame{4, 1, make([]byte, 16354)}, frame{6, 0, make([]byte, 8)}); err == nil {
				t.Fatal("oversized group accepted")
			}
			if send.number != before {
				t.Fatal("invalid group consumed record nonce")
			}
			if err := out.write(frame{8, 0, make([]byte, 8)}); err != nil {
				t.Fatal(err)
			}
			if _, err := in.read(); err != nil {
				t.Fatal("record state corrupted", err)
			}
		})
	}
}

func BenchmarkCreditPair(b *testing.B) {
	pair := []frame{{6, 1, make([]byte, 8)}, {6, 0, make([]byte, 8)}}
	for _, combined := range []bool{false, true} {
		name := "separate"
		if combined {
			name = "combined"
		}
		b.Run(name, func(b *testing.B) {
			out := &records{w: io.Discard, send: newRecord(make([]byte, 32), make([]byte, 32), 0)}
			b.ReportAllocs()
			b.ResetTimer()
			for i := 0; i < b.N; i++ {
				if combined {
					if err := out.writeFrames(pair...); err != nil {
						b.Fatal(err)
					}
				} else {
					for _, f := range pair {
						if err := out.write(f); err != nil {
							b.Fatal(err)
						}
					}
				}
			}
		})
	}
}

type blockedCreditWriter struct {
	started chan struct{}
	release chan struct{}
	wrote   chan struct{}
	once    sync.Once
}

func (w *blockedCreditWriter) Write(p []byte) (int, error) {
	w.once.Do(func() { close(w.started) })
	<-w.release
	select {
	case w.wrote <- struct{}{}:
	default:
	}
	return len(p), nil
}

func TestReadDoesNotWaitForReverseCreditWrite(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	w := &blockedCreditWriter{started: make(chan struct{}), release: make(chan struct{}), wrote: make(chan struct{}, 4)}
	s := &Session{ctx: ctx, creditPending: make(map[uint64]uint64), creditWake: make(chan struct{}, 1), records: &records{w: w, send: newRecord(make([]byte, 32), make([]byte, 32), 0)}}
	done := make(chan struct{})
	go func() { s.flushCredits(); close(done) }()
	defer func() { cancel(); <-done }()
	defer close(w.release)
	stream := &Stream{session: s, id: 1, buffer: make([]byte, 1024)}
	read := func() {
		t.Helper()
		completed := make(chan error, 1)
		go func() {
			var b [512]byte
			n, err := stream.Read(b[:])
			if err == nil && n != len(b) {
				err = io.ErrUnexpectedEOF
			}
			completed <- err
		}()
		select {
		case err := <-completed:
			if err != nil {
				t.Fatal(err)
			}
		case <-time.After(time.Second):
			t.Fatal("application read blocked on reverse credit write")
		}
	}
	read()
	select {
	case <-w.started:
	case <-time.After(time.Second):
		t.Fatal("credit sender did not wake immediately")
	}
	read() // The carrier is deliberately still blocked here.
	s.mu.Lock()
	if s.creditPending[1] != streamCredit+1024 || s.creditPending[0] != connectionCredit+1024 {
		t.Error("latest absolute limits were lost")
	}
	s.mu.Unlock()
}

func TestRecordWriteTimingSeparatesCarrierWait(t *testing.T) {
	w := &blockedCreditWriter{started: make(chan struct{}), release: make(chan struct{}), wrote: make(chan struct{}, 1)}
	out := &records{w: w, send: newRecord(make([]byte, 32), make([]byte, 32), 0)}
	measured := make(chan recordWriteTiming, 1)
	out.trace = func(timing recordWriteTiming) {
		if !out.mu.TryLock() {
			t.Error("trace callback holds record mutex")
		} else {
			out.mu.Unlock()
		}
		measured <- timing
	}
	completed := make(chan error, 1)
	go func() { completed <- out.write(frame{8, 0, make([]byte, 8)}) }()
	select {
	case <-w.started:
	case <-time.After(time.Second):
		t.Fatal("writer did not start")
	}
	time.Sleep(25 * time.Millisecond)
	close(w.release)
	if err := <-completed; err != nil {
		t.Fatal(err)
	}
	timing := <-measured
	if timing.Write < 20*time.Millisecond || timing.Total < timing.Write || timing.Bytes != 40 || !timing.OK {
		t.Fatalf("incorrect timing: %+v", timing)
	}
	if timing.Lock < 0 || timing.Seal < 0 || timing.Encode < 0 {
		t.Fatal("negative phase duration")
	}
}
