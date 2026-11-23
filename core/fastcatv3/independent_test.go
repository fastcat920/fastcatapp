package fastcatv3

import (
	"bytes"
	"context"
	"crypto/tls"
	"crypto/x509"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"net/http/httptrace"
	"os"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	qhttp "github.com/metacubex/http"
	"github.com/metacubex/quic-go/http3"
	qtls "github.com/metacubex/tls"
)

func startIndependentCarrier(t *testing.T, c Config, protocol string) (DialConfig, *IndependentServer, func()) {
	t.Helper()
	s, err := NewIndependentServer(c)
	if err != nil {
		t.Fatal(err)
	}
	fixture := httptest.NewUnstartedServer(s)
	fixture.EnableHTTP2 = true
	fixture.TLS = &tls.Config{MinVersion: tls.VersionTLS13}
	fixture.StartTLS()
	roots := x509.NewCertPool()
	roots.AddCert(fixture.Certificate())
	dc := DialConfig{Config: c, Endpoint: fixture.Listener.Addr().String(), Roots: roots, ServerName: "example.com"}
	if protocol == "h2" {
		return dc, s, fixture.Close
	}
	cert := fixture.TLS.Certificates[0]
	socket, err := net.ListenPacket("udp4", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	server := &http3.Server{Handler: qhttp.HandlerFunc(s.ServeHTTP3), TLSConfig: &qtls.Config{MinVersion: qtls.VersionTLS13, Certificates: []qtls.Certificate{{Certificate: cert.Certificate, PrivateKey: cert.PrivateKey}}, NextProtos: []string{"h3"}}}
	go server.Serve(socket)
	dc.Endpoint = socket.LocalAddr().String()
	return dc, s, func() { server.Close(); socket.Close(); fixture.Close() }
}
func TestIndependentCarriers(t *testing.T) {
	target, _ := echoServers(t)
	for _, protocol := range []string{"h2", "h3"} {
		for _, mode := range []IndependentMode{IndependentLight, IndependentSealed, IndependentPipelined} {
			t.Run(protocol+"/"+mode.String(), func(t *testing.T) {
				dc, server, stop := startIndependentCarrier(t, testConfig(), protocol)
				defer stop()
				ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
				defer cancel()
				client, err := DialIndependent(ctx, dc, protocol, mode)
				if err != nil {
					t.Fatal(err)
				}
				defer client.Close()
				var wg sync.WaitGroup
				errs := make(chan error, 8)
				for i := 0; i < 8; i++ {
					wg.Add(1)
					go func(i int) {
						defer wg.Done()
						stream, err := client.Dial(ctx, target)
						if err != nil {
							errs <- err
							return
						}
						defer stream.Close()
						if mode == IndependentSealed {
							if err := stream.(*independentConn).records.update(); err != nil {
								errs <- err
								return
							}
						}
						payload := bytes.Repeat([]byte{byte(i + 1)}, 600000)
						written := make(chan error, 1)
						go func() {
							_, err := stream.Write(payload)
							if err == nil {
								err = stream.(*independentConn).CloseWrite()
							}
							written <- err
						}()
						data, err := io.ReadAll(stream)
						if err == nil {
							err = <-written
						}
						if err == nil && !bytes.Equal(data, payload) {
							err = io.ErrUnexpectedEOF
						}
						errs <- err
					}(i)
				}
				wg.Wait()
				close(errs)
				for err := range errs {
					if err != nil {
						t.Fatal(err)
					}
				}
				// Out-of-order counters were accepted; each stream had its own record state.
				server.mu.Lock()
				a := server.sessions[string(client.sid)]
				seen := len(a.seen)
				server.mu.Unlock()
				if seen != 8 {
					t.Fatalf("accepted %d streams", seen)
				}
				// One slow/unread stream must not stall a new stream at the application layer.
				blocked, err := client.Dial(ctx, target)
				if err != nil {
					t.Fatal(err)
				}
				writeDone := make(chan struct{})
				go func() { blocked.Write(make([]byte, 2<<20)); close(writeDone) }()
				fast, err := client.Dial(ctx, target)
				if err != nil {
					t.Fatal(err)
				}
				if _, err = fast.Write([]byte("fast")); err != nil {
					t.Fatal(err)
				}
				var reply [4]byte
				if _, err = io.ReadFull(fast, reply[:]); err != nil || string(reply[:]) != "fast" {
					t.Fatal("sibling stream stalled", err)
				}
				fast.Close()
				blocked.Close()
				<-writeDone
				// Canceling one request leaves the authenticated connection usable.
				canceled, stopRequest := context.WithCancel(ctx)
				flow, err := client.Dial(canceled, target)
				if err != nil {
					t.Fatal(err)
				}
				stopRequest()
				flow.Close()
				flow, err = client.Dial(ctx, target)
				if err != nil {
					t.Fatal("cancel poisoned session", err)
				}
				flow.Close()
			})
		}
	}
}
func TestIndependentProofBindingReplayAndExpiry(t *testing.T) {
	s, _ := NewIndependentServer(testConfig())
	root, sid, binding := random(32), random(16), random(32)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	a := &independentAuth{root: root, binding: binding, mode: IndependentSealed, expires: time.Now().Add(time.Minute), ctx: ctx, seen: make(map[uint64]struct{})}
	s.sessions[string(sid)] = a
	p, _ := flowPrefix(root, sid, binding, 2, IndependentSealed, "example.com:443")
	if _, _, _, err := s.claim(p, random(32), IndependentSealed); err == nil {
		t.Fatal("cross-connection proof accepted")
	}
	bad := append([]byte(nil), p...)
	bad[len(bad)-1] ^= 1
	if _, _, _, err := s.claim(bad, binding, IndependentSealed); err == nil {
		t.Fatal("forged proof accepted")
	}
	if _, _, _, err := s.claim(p, binding, IndependentLight); err == nil {
		t.Fatal("mode downgrade accepted")
	}
	if _, _, _, err := s.claim(p, binding, IndependentSealed); err != nil {
		t.Fatal(err)
	}
	if _, _, _, err := s.claim(p, binding, IndependentSealed); err == nil {
		t.Fatal("replay accepted")
	}
	older, _ := flowPrefix(root, sid, binding, 1, IndependentSealed, "example.com:443")
	if _, _, _, err := s.claim(older, binding, IndependentSealed); err != nil {
		t.Fatal("independent arrival order rejected", err)
	}
	a.expires = time.Now().Add(-time.Second)
	fresh, _ := flowPrefix(root, sid, binding, 3, IndependentSealed, "example.com:443")
	if _, _, _, err := s.claim(fresh, binding, IndependentSealed); err == nil {
		t.Fatal("expired proof accepted")
	}
	a.expires = time.Now().Add(time.Minute)
	cancel()
	if _, _, _, err := s.claim(fresh, binding, IndependentSealed); err == nil {
		t.Fatal("revoked proof accepted")
	}
	// Root, direction, target, and stream counter separate the traffic keys.
	first := flowRecords(nil, io.Discard, root, p, binding, false)
	server := flowRecords(nil, io.Discard, root, p, binding, true)
	other := flowRecords(nil, io.Discard, root, older, binding, false)
	if !bytes.Equal(first.send.secret, server.receive.secret) || bytes.Equal(first.send.secret, first.receive.secret) || bytes.Equal(first.send.secret, other.send.secret) {
		t.Fatal("traffic key separation failed")
	}
}
func TestIndependentAuthFailureAndPrivatePolicy(t *testing.T) {
	for _, protocol := range []string{"h2", "h3"} {
		for _, mode := range []IndependentMode{IndependentLight, IndependentSealed, IndependentPipelined} {
			t.Run(protocol+"/"+mode.String(), func(t *testing.T) {
				c := testConfig()
				c.AllowPrivate = false
				dc, server, stop := startIndependentCarrier(t, c, protocol)
				defer stop()
				ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
				defer cancel()
				wrong := dc
				wrong.Config.Token = random(32)
				if client, err := DialIndependent(ctx, wrong, protocol, mode); err == nil {
					client.Close()
					t.Fatal("bad token accepted")
				}
				wrong = dc
				wrong.Config.ServerPublic = random(32)
				if client, err := DialIndependent(ctx, wrong, protocol, mode); err == nil {
					client.Close()
					t.Fatal("bad server key accepted")
				}
				client, err := DialIndependent(ctx, dc, protocol, mode)
				if err != nil {
					t.Fatal(err)
				}
				if stream, err := client.Dial(ctx, "127.0.0.1:80"); err == nil {
					stream.Close()
					t.Fatal("private target accepted")
				}
				client.Close()
				deadline := time.Now().Add(time.Second)
				for {
					server.mu.Lock()
					n := len(server.sessions)
					server.mu.Unlock()
					if n == 0 {
						break
					}
					if time.Now().After(deadline) {
						t.Fatal("closed auth session retained")
					}
					time.Sleep(time.Millisecond)
				}
			})
		}
	}
}
func TestIndependentLightRequiresFIN(t *testing.T) {
	p := &independentPayload{reader: bytes.NewReader(nil)}
	if _, err := p.Read(make([]byte, 1)); err != io.ErrUnexpectedEOF {
		t.Fatal("missing FIN accepted", err)
	}
	var wire bytes.Buffer
	writer := &independentPayload{writer: &wire}
	writer.Write([]byte("data"))
	writer.CloseWrite()
	reader := &independentPayload{reader: &wire}
	out, err := io.ReadAll(reader)
	if err != nil || string(out) != "data" {
		t.Fatal(string(out), err)
	}
	// A changed offset must fail even inside the TLS-protected light framing.
	h := []byte{4, 0, 1}
	h = binary.BigEndian.AppendUint64(h, 1)
	h = append(h, 'a')
	reader = &independentPayload{reader: bytes.NewReader(h)}
	if _, err := reader.Read(make([]byte, 1)); err == nil {
		t.Fatal("invalid offset accepted")
	}
}

func TestIndependentReferenceVectors(t *testing.T) {
	data, err := os.ReadFile("../../docs/protocols/fastcat-v3/independent_vectors.json")
	if err != nil {
		t.Fatal(err)
	}
	var v map[string]string
	if err := json.Unmarshal(data, &v); err != nil {
		t.Fatal(err)
	}
	decode := func(k string) []byte {
		t.Helper()
		b, err := hex.DecodeString(v[k])
		if err != nil {
			t.Fatal(err)
		}
		return b
	}
	context := decode("context")
	r := &records{send: newRecord(decode("client_seed"), context, 0), receive: newRecord(decode("server_seed"), context, 1)}
	root := independentRoot(r, false)
	if !bytes.Equal(root, decode("root")) {
		t.Fatal("root does not match Python HKDF reference")
	}
	prefix, err := flowPrefix(root, decode("sid"), decode("binding"), 7, IndependentSealed, "example.com:443")
	if err != nil || !bytes.Equal(prefix, decode("prefix")) {
		t.Fatal("proof does not match reference", err)
	}
	flow := flowRecords(nil, io.Discard, root, prefix, decode("binding"), false)
	if !bytes.Equal(flow.send.ctx, decode("stream_context")) || !bytes.Equal(flow.send.secret, decode("client_traffic_secret")) || !bytes.Equal(flow.receive.secret, decode("server_traffic_secret")) {
		t.Fatal("traffic keys do not match reference")
	}
}

func TestIndependentReplayOverHTTPAndAuthLoss(t *testing.T) {
	target, _ := echoServers(t)
	for _, protocol := range []string{"h2", "h3"} {
		for _, mode := range []IndependentMode{IndependentLight, IndependentSealed, IndependentPipelined} {
			t.Run(protocol+"/"+mode.String(), func(t *testing.T) {
				dc, srv, stop := startIndependentCarrier(t, testConfig(), protocol)
				defer stop()
				ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
				defer cancel()
				client, err := DialIndependent(ctx, dc, protocol, mode)
				if err != nil {
					t.Fatal(err)
				}
				defer client.Close()
				flow, err := client.Dial(ctx, target)
				if err != nil {
					t.Fatal(err)
				}
				flow.Close()
				reused, _ := flowPrefix(client.root, client.sid, client.binding, 1, mode, target)
				response, err := client.roundTrip(ctx, independentFlowPath, bytes.NewReader(reused))
				if err != nil {
					t.Fatal(err)
				}
				var b [1]byte
				n, err := response.body.Read(b[:])
				response.body.Close()
				if n != 0 || err == nil {
					t.Fatal("wire replay received an OPEN acknowledgement", n, err)
				}
				live, err := client.Dial(ctx, target)
				if err != nil {
					t.Fatal(err)
				}
				defer live.Close()
				readDone := make(chan error, 1)
				go func() { var b [1]byte; _, err := live.Read(b[:]); readDone <- err }()
				client.closeAuth()
				select {
				case err := <-readDone:
					if err == nil {
						t.Fatal("auth loss left live flow readable")
					}
				case <-time.After(time.Second):
					srv.mu.Lock()
					count := len(srv.sessions)
					srv.mu.Unlock()
					t.Fatalf("auth loss did not revoke flow; retained sessions=%d client_closed=%v", count, client.ctx.Err())
				}
			})
		}
	}
}

func BenchmarkIndependentLightWrite(b *testing.B) {
	for _, size := range []struct {
		name  string
		bytes int
	}{{"1KiB", 1024}, {"16KiB", 16346}} {
		b.Run(size.name, func(b *testing.B) {
			p := &independentPayload{writer: io.Discard}
			data := make([]byte, size.bytes)
			b.ReportAllocs()
			b.SetBytes(int64(len(data)))
			b.ResetTimer()
			for i := 0; i < b.N; i++ {
				if _, err := p.Write(data); err != nil {
					b.Fatal(err)
				}
			}
		})
	}
}

func TestIndependentLightReusedBuffersVariableFrames(t *testing.T) {
	var wire bytes.Buffer
	writer := &independentPayload{writer: &wire}
	var expected []byte
	for i, n := range []int{1024, 1, 16346, 17, 4096, 3} {
		data := bytes.Repeat([]byte{byte(i + 1)}, n)
		if count, err := writer.Write(data); err != nil || count != len(data) {
			t.Fatal(count, err)
		}
		expected = append(expected, data...)
	}
	if err := writer.CloseWrite(); err != nil {
		t.Fatal(err)
	}
	reader := &independentPayload{reader: &wire}
	var actual []byte
	var small [7]byte
	for {
		n, err := reader.Read(small[:])
		actual = append(actual, small[:n]...)
		if err == io.EOF {
			break
		}
		if err != nil {
			t.Fatal(err)
		}
	}
	if !bytes.Equal(actual, expected) {
		t.Fatal("reusing a shorter/longer frame leaked or overwrote bytes")
	}
}

type independentFlushProbe struct {
	http.ResponseWriter
	initSeen *atomic.Bool
	early    *atomic.Bool
	calls    *atomic.Int32
}

func (w *independentFlushProbe) Unwrap() http.ResponseWriter { return w.ResponseWriter }
func (w *independentFlushProbe) Flush() {
	if !w.initSeen.Load() {
		w.early.Store(true)
	}
	w.calls.Add(1)
	w.ResponseWriter.(http.Flusher).Flush()
}
func TestIndependentH2HeadersWaitForFirstPayload(t *testing.T) {
	var initSeen, early atomic.Bool
	var calls atomic.Int32
	config := testConfig()
	config.Trace = func(event string) {
		if event == "server init_received" {
			initSeen.Store(true)
		}
	}
	server, err := NewIndependentServer(config)
	if err != nil {
		t.Fatal(err)
	}
	fixture := httptest.NewUnstartedServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		server.ServeHTTP(&independentFlushProbe{w, &initSeen, &early, &calls}, r)
	}))
	fixture.EnableHTTP2 = true
	fixture.TLS = &tls.Config{MinVersion: tls.VersionTLS13}
	fixture.StartTLS()
	defer fixture.Close()
	roots := x509.NewCertPool()
	roots.AddCert(fixture.Certificate())
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	client, err := DialIndependent(ctx, DialConfig{Config: config, Endpoint: fixture.Listener.Addr().String(), ServerName: "example.com", Roots: roots}, "h2", IndependentLight)
	if err != nil {
		t.Fatal(err)
	}
	defer client.Close()
	if early.Load() || !initSeen.Load() || calls.Load() != 2 {
		t.Fatalf("early=%v init=%v flushes=%d, want only ACCEPT and READY", early.Load(), initSeen.Load(), calls.Load())
	}
}

func TestIndependentPipelinedOpenWaitsForConfirmation(t *testing.T) {
	for _, valid := range []bool{true, false} {
		name := "invalid"
		if valid {
			name = "valid"
		}
		t.Run(name, func(t *testing.T) {
			var accepted atomic.Int32
			target, err := net.Listen("tcp4", "127.0.0.1:0")
			if err != nil {
				t.Fatal(err)
			}
			defer target.Close()
			go func() {
				for {
					c, e := target.Accept()
					if e != nil {
						return
					}
					accepted.Add(1)
					c.Close()
				}
			}()
			dc, server, stop := startIndependentCarrier(t, testConfig(), "h2")
			defer stop()
			root, cancel := context.WithTimeout(context.Background(), 5*time.Second)
			defer cancel()
			tr := &http.Transport{ForceAttemptHTTP2: true, MaxConnsPerHost: 1, TLSClientConfig: &tls.Config{MinVersion: tls.VersionTLS13, ServerName: dc.ServerName, RootCAs: dc.Roots}}
			defer tr.CloseIdleConnections()
			request := func(path string, body io.Reader) (*http.Response, error) {
				req, e := http.NewRequestWithContext(root, "POST", "https://"+dc.Endpoint+path, body)
				if e != nil {
					return nil, e
				}
				req.Header.Set("Content-Type", "application/octet-stream")
				req.Header.Set("X-Fastcat-Mode", IndependentPipelined.String())
				if path == independentAuthPath {
					req = req.WithContext(httptrace.WithClientTrace(req.Context(), &httptrace.ClientTrace{GotConn: func(info httptrace.GotConnInfo) { go func() { <-root.Done(); info.Conn.Close() }() }}))
				}
				return tr.RoundTrip(req)
			}
			config := independentConfig(dc.Config, IndependentPipelined)
			pending, initial, err := prepareClientHandshake(config, 1)
			if err != nil {
				t.Fatal(err)
			}
			authReader, authWriter := io.Pipe()
			defer authReader.Close()
			defer authWriter.Close()
			response, err := request(independentAuthPath, io.MultiReader(bytes.NewReader(initial), authReader))
			if err != nil {
				t.Fatal(err)
			}
			defer func() { cancel(); response.Body.Close() }()
			binding, err := response.TLS.ExportKeyingMaterial("EXPORTER-FastCat-v3", nil, 32)
			if err != nil {
				t.Fatal(err)
			}
			// A real initiator can derive this material after authenticating ACCEPT,
			// before writing CONFIRM. Inspect it here to deliberately reorder requests.
			server.mu.Lock()
			var sid, secret []byte
			var state *independentAuth
			for id, a := range server.sessions {
				sid = []byte(id)
				secret = append([]byte(nil), a.root...)
				state = a
			}
			server.mu.Unlock()
			if state == nil || state.confirmed == nil {
				t.Fatal("provisional session not published before ACCEPT")
			}
			prefix, err := flowPrefix(secret, sid, binding, 1, IndependentPipelined, target.Addr().String())
			if err != nil {
				t.Fatal(err)
			}
			flowReader, flowWriter := io.Pipe()
			defer flowReader.Close()
			defer flowWriter.Close()
			type result struct {
				r *http.Response
				e error
			}
			finished := make(chan result, 1)
			go func() {
				r, e := request(independentFlowPath, io.MultiReader(bytes.NewReader(prefix), flowReader))
				finished <- result{r, e}
			}()
			// First ensure the proof was actually admitted and reserved, not merely
			// waiting in the client transport. Target dialing must still be blocked.
			deadline := time.Now().Add(time.Second)
			for {
				server.mu.Lock()
				_, reserved := state.seen[1]
				server.mu.Unlock()
				if reserved {
					break
				}
				if time.Now().After(deadline) {
					t.Fatal("OPEN did not reach provisional gate")
				}
				time.Sleep(time.Millisecond)
			}
			select {
			case r := <-finished:
				if r.r != nil {
					r.r.Body.Close()
				}
				t.Fatal("OPEN returned before confirmation", r.e)
			case <-time.After(30 * time.Millisecond):
			}
			if accepted.Load() != 0 {
				t.Fatal("target dialed before confirmation")
			}
			// A duplicate cannot reserve the same counter while the first is pending.
			replay, e := request(independentFlowPath, bytes.NewReader(prefix))
			if e != nil {
				t.Fatal(e)
			}
			var b [2]byte
			n, e := replay.Body.Read(b[:])
			replay.Body.Close()
			if n != 0 || e == nil {
				t.Fatal("pending proof replay accepted")
			}
			if valid {
				records, e := pending.finish(response.Body, authWriter, config, binding)
				if e != nil {
					t.Fatal(e)
				}
				if !bytes.Equal(records.handshakeID, sid) {
					t.Fatal("ACCEPT session ID changed")
				}
			} else {
				// A complete record with an invalid AEAD tag must fail closed.
				bad := make([]byte, 34)
				bad[1] = 32
				if e := writeAll(authWriter, bad); e != nil {
					t.Fatal(e)
				}
			}
			select {
			case r := <-finished:
				if r.r != nil {
					defer func() { cancel(); r.r.Body.Close() }()
				}
				if valid {
					if r.e != nil {
						t.Fatal(r.e)
					}
					ack := make([]byte, 34)
					if _, e := io.ReadFull(r.r.Body, ack); e != nil || !validateFastOpenStatus(secret, prefix, binding, ack) || !bytes.Equal(ack[:2], []byte{0, 0}) {
						t.Fatal("confirmed OPEN acknowledgement failed", e)
					}
					deadline := time.Now().Add(time.Second)
					for accepted.Load() == 0 && time.Now().Before(deadline) {
						time.Sleep(time.Millisecond)
					}
					if accepted.Load() != 1 {
						t.Fatal("target not opened exactly once")
					}
				}
				if !valid {
					if r.r != nil {
						n, e := r.r.Body.Read(b[:])
						if n != 0 || e == nil {
							t.Fatal("invalid confirmation opened target")
						}
					}
					if accepted.Load() != 0 {
						t.Fatal("target dialed after invalid confirmation")
					}
				}
			case <-time.After(time.Second):
				t.Fatal("confirmation did not settle waiting OPEN")
			}
		})
	}
}

func TestIndependentPipelinedMissingOrCanceledGate(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	a := &independentAuth{mode: IndependentPipelined, ctx: ctx, expires: time.Now().Add(time.Minute)}
	if err := awaitIndependentConfirmation(context.Background(), a); err == nil {
		t.Fatal("missing confirmation gate was accepted")
	}
	a.confirmed = make(chan struct{})
	cancel()
	if err := awaitIndependentConfirmation(context.Background(), a); err == nil {
		t.Fatal("canceled authentication gate accepted")
	}
	close(a.confirmed)
	if err := awaitIndependentConfirmation(context.Background(), a); err == nil {
		t.Fatal("confirmation overrode revocation")
	}
}

func TestIndependentPipelinedMetadataAndAckVectors(t *testing.T) {
	data, err := os.ReadFile("../../docs/protocols/fastcat-v3/pipelined_vectors.json")
	if err != nil {
		t.Fatal(err)
	}
	var values map[string]string
	if err := json.Unmarshal(data, &values); err != nil {
		t.Fatal(err)
	}
	decode := func(name string) []byte {
		b, err := hex.DecodeString(values[name])
		if err != nil {
			t.Fatal(err)
		}
		return b
	}
	root, sid, binding := decode("root"), decode("sid"), decode("binding")
	prefix, err := flowPrefix(root, sid, binding, 7, IndependentPipelined, "example.com:443")
	if err != nil || !bytes.Equal(prefix, decode("prefix")) {
		t.Fatal("encrypted OPEN does not match Python", err)
	}
	if bytes.Contains(prefix, []byte("example.com:443")) {
		t.Fatal("target is exposed before channel confirmation")
	}
	target, err := decryptFastTarget(root, prefix, binding)
	if err != nil || target != "example.com:443" {
		t.Fatal(target, err)
	}
	parsed, err := readFlowPrefix(bytes.NewReader(prefix))
	if err != nil || !bytes.Equal(parsed, prefix) {
		t.Fatal("mode-2 parser mismatch", err)
	}
	ack := fastOpenStatus(root, prefix, binding, []byte{0, 0})
	if !bytes.Equal(ack, decode("ack")) || !validateFastOpenStatus(root, prefix, binding, ack) {
		t.Fatal("authenticated ACK does not match Python")
	}
	altered := append([]byte(nil), ack...)
	altered[0] ^= 1
	if validateFastOpenStatus(root, prefix, binding, altered) || validateFastOpenStatus(root, prefix, random(32), ack) {
		t.Fatal("forged or transplanted ACK accepted")
	}
	damaged := append([]byte(nil), prefix...)
	damaged[31] ^= 1
	if _, err := decryptFastTarget(root, damaged, binding); err == nil {
		t.Fatal("altered encrypted target accepted")
	}
	if _, err := decryptFastTarget(root, prefix, random(32)); err == nil {
		t.Fatal("OPEN survived binding change")
	}
	c := independentConfig(Config{ServiceID: decode("service_id_input")}, IndependentPipelined)
	if !bytes.Equal(c.ServiceID, decode("service_id_fast")) {
		t.Fatal("mode domain separation mismatch")
	}
}
func TestIndependentPipelinedRejectsForgedOpenAck(t *testing.T) {
	dc, _, stop := startIndependentCarrier(t, testConfig(), "h2")
	defer stop()
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	client, err := DialIndependent(ctx, dc, "h2", IndependentPipelined)
	if err != nil {
		t.Fatal(err)
	}
	defer client.Close()
	client.roundTrip = func(context.Context, string, io.Reader) (independentResponse, error) {
		return independentResponse{body: io.NopCloser(bytes.NewReader(make([]byte, 34))), binding: client.binding}, nil
	}
	if conn, err := client.Dial(ctx, "example.com:443"); err == nil {
		conn.Close()
		t.Fatal("unauthenticated OPEN success was accepted")
	}
}
