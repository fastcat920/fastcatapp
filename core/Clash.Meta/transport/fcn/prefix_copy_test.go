package fcn

import (
	"bytes"
	"context"
	"encoding/binary"
	"errors"
	"io"
	"net"
	"os"
	"sync"
	"testing"
	"time"
)

func copyPart(offset int, p []byte) []byte {
	b := binary.BigEndian.AppendUint16(nil, prefixCopyMagic)
	b = binary.BigEndian.AppendUint16(b, uint16(offset))
	return append(b, p...)
}
func TestPrefixCopyAheadReorderAndDedup(t *testing.T) {
	raw, writer := io.Pipe()
	r := newPrefixCopyReader(raw, nil, nil)
	defer func() { r.close(); raw.Close(); writer.Close() }()
	r.offer(copyPart(3, []byte("def")))
	r.offer(copyPart(0, []byte("abc")))
	r.offer(copyPart(0, []byte("abc")))
	got := make([]byte, 6)
	if _, e := io.ReadFull(r, got); e != nil || string(got) != "abcdef" {
		t.Fatal(e, string(got))
	}
	if r.delivered.Load() != 6 {
		t.Fatal("copy not used")
	}
	done := make(chan error, 1)
	go func() { _, e := writer.Write([]byte("abcdefghij")); writer.Close(); done <- e }()
	tail, e := io.ReadAll(r)
	if e != nil || string(tail) != "ghij" {
		t.Fatal("duplicate or missing delivery", e, string(tail))
	}
	if e = <-done; e != nil {
		t.Fatal(e)
	}
}
func TestPrefixCopyConflictsFailClosed(t *testing.T) {
	r := newPrefixCopyReader(bytes.NewBufferString("abc"), nil, nil)
	defer r.close()
	r.offer(copyPart(0, []byte("xyz")))
	b := make([]byte, 3)
	_, e := io.ReadFull(r, b)
	if e != nil && e != ErrProtocol {
		t.Fatal(e)
	}
	if e == nil {
		_, e = r.Read(b)
	}
	if e != ErrProtocol {
		t.Fatal("conflicting canonical bytes accepted", e)
	}
}
func TestPrefixDeadlineCanBeExtended(t *testing.T) {
	raw, wr := io.Pipe()
	r := newPrefixCopyReader(raw, nil, nil)
	defer func() { r.close(); raw.Close(); wr.Close() }()
	r.setDeadline(time.Now().Add(10 * time.Millisecond))
	if _, e := r.Read(make([]byte, 1)); !errors.Is(e, os.ErrDeadlineExceeded) {
		t.Fatal(e)
	}
	r.setDeadline(time.Time{})
	r.offer(copyPart(0, []byte("a")))
	b := make([]byte, 1)
	if n, e := r.Read(b); n != 1 || e != nil || b[0] != 'a' {
		t.Fatal(n, e)
	}
}
func TestPrefixBoundsAndClose(t *testing.T) {
	raw, wr := io.Pipe()
	defer raw.Close()
	defer wr.Close()
	var once sync.Once
	done := make(chan struct{})
	r := newPrefixCopyReader(raw, func() { once.Do(func() { close(done) }) }, nil)
	r.offer(copyPart(prefixCopyLimit, []byte("x")))
	r.offer([]byte{1, 2, 3})
	for i := 0; i < 100; i++ {
		r.offer(copyPart(0, []byte("x")))
	}
	if len(r.parts) > 16 {
		t.Fatal("unbounded queue")
	}
	r.close()
	r.close()
	select {
	case <-done:
	default:
		t.Fatal("not unregistered")
	}
	if _, e := r.Read(make([]byte, 1)); !errors.Is(e, net.ErrClosed) {
		t.Fatal(e)
	}
}
func TestPrefixStreamIntegrityBillingAndLegacy(t *testing.T) {
	c, s, stop := fixtureProfileConfig(t, "quic", 2*time.Second, 1, "", func(s *ServerConfig) { s.PrefixRedundancy = true })
	defer stop()
	target, _ := echoTarget(t)
	for _, enabled := range []bool{false, true} {
		c.cfg.PrefixRedundancy = enabled
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		conn, e := c.Dial(ctx, target)
		if e != nil {
			cancel()
			t.Fatal(e)
		}
		data := bytes.Repeat([]byte("abcdef0123456789"), 128<<10)
		errc := make(chan error, 1)
		go func() {
			_, e := conn.Write(data)
			if cw, ok := conn.(interface{ CloseWrite() error }); ok {
				_ = cw.CloseWrite()
			}
			errc <- e
		}()
		got, e := io.ReadAll(conn)
		conn.Close()
		cancel()
		if e != nil || !bytes.Equal(data, got) {
			t.Fatal("stream changed", enabled, len(got), e)
		}
		if e = <-errc; e != nil {
			t.Fatal(e)
		}
	}
	deadline := time.Now().Add(time.Second)
	for s.Counters().Download.Load() < 4<<20 && time.Now().Before(deadline) {
		time.Sleep(time.Millisecond)
	}
	if n := s.Counters().Download.Load(); n != 4<<20 {
		t.Fatal("copies entered business billing", n)
	}
	if s.Counters().Accepted.Load() != 2 {
		t.Fatal("target replayed")
	}
}
func TestPrefixExplicitRejectAndAuth(t *testing.T) {
	c, s, stop := fixture(t, "quic", time.Second)
	defer stop()
	c.cfg.PrefixRedundancy = true
	target, accepted := echoTarget(t)
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	conn, e := c.Dial(ctx, target)
	if e != nil {
		t.Fatal(e)
	}
	_, e = conn.Read(make([]byte, 1))
	conn.Close()
	if e != ErrProtocol || accepted.Load() != 0 || s.Counters().Accepted.Load() != 0 {
		t.Fatal("extension silently downgraded/replayed", e, accepted.Load())
	}
}
func TestPrefixInvalidCredentialsDoNotReachTarget(t *testing.T) {
	c, _, stop := fixtureProfileConfig(t, "quic", time.Second, 1, "", func(s *ServerConfig) { s.PrefixRedundancy = true })
	defer stop()
	c.cfg.PrefixRedundancy = true
	c.cfg.Key = bytes.Repeat([]byte{9}, 32)
	target, n := echoTarget(t)
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	conn, e := c.Dial(ctx, target)
	if e != nil {
		t.Fatal(e)
	}
	defer conn.Close()
	_, e = conn.Read(make([]byte, 1))
	if e != ErrAuth || n.Load() != 0 {
		t.Fatal("auth bypass", e, n.Load())
	}
}
func TestPrefixBodyReadDeadlineRecoveryAndUnregister(t *testing.T) {
	c, _, stop := fixtureProfileConfig(t, "quic", 2*time.Second, 1, "", func(s *ServerConfig) { s.PrefixRedundancy = true })
	defer stop()
	c.cfg.PrefixRedundancy = true
	target, _ := echoTarget(t)
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	conn, e := c.Dial(ctx, target)
	if e != nil {
		t.Fatal(e)
	}
	defer conn.Close()
	conn.Write([]byte("first"))
	b := make([]byte, 5)
	if _, e = io.ReadFull(conn, b); e != nil || string(b) != "first" {
		t.Fatal(e)
	}
	conn.SetReadDeadline(time.Now().Add(10 * time.Millisecond))
	if _, e = conn.Read(b); e == nil {
		t.Fatal("missing read deadline")
	}
	conn.SetReadDeadline(time.Time{})
	conn.Write([]byte("again"))
	if _, e = io.ReadFull(conn, b); e != nil || string(b) != "again" {
		t.Fatal("deadline could not recover", e, string(b))
	}
	q := conn.(*quicConn)
	conn.Close()
	q.physical.packets.mu.RLock()
	n := len(q.physical.packets.prefixes)
	q.physical.packets.mu.RUnlock()
	if n != 0 {
		t.Fatal("closed prefix registration retained", n)
	}
}
func TestPrefixKindIsExporterAuthenticated(t *testing.T) {
	key := bytes.Repeat([]byte{7}, 32)
	binding := bytes.Repeat([]byte{8}, 32)
	b, e := encodeHeader("test", "example.com:443", 2, key, binding)
	if e != nil {
		t.Fatal(e)
	}
	h, e := readHeader(bytes.NewReader(b))
	if e != nil || !verifyHeader(h, key, binding) {
		t.Fatal(e)
	}
	h.raw[1] = 0
	if verifyHeader(h, key, binding) {
		t.Fatal("extension kind was not bound to auth")
	}
	cfg := Config{PrefixRedundancy: true, Endpoint: "127.0.0.1:443", ServerName: "example.com", Account: "test", Key: key}
	if _, e = NewClient(context.Background(), cfg, "h2"); e == nil {
		t.Fatal("prefix enabled on H2")
	}
}

func TestPrefixCopyCursorAndPacketBudgetSaturate(t *testing.T) {
	w := &prefixCopyWriter{offset: 1, copies: prefixCopyPackets}
	p := make([]byte, 32<<10)
	for i := 0; i < 100000; i++ {
		w.duplicate(p)
	}
	if w.offset != prefixCopyLimit || w.copies != prefixCopyPackets || w.bytes != 0 {
		t.Fatal("prefix budget exceeded", w.offset, w.copies, w.bytes)
	}
}
func TestPrefixConcurrentStreamsAndUDPRemainSeparate(t *testing.T) {
	c, _, stop := fixtureProfileConfig(t, "quic", 3*time.Second, 1, "", func(s *ServerConfig) { s.PrefixRedundancy = true })
	defer stop()
	c.cfg.PrefixRedundancy = true
	target, _ := echoTarget(t)
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	held, e := c.Dial(ctx, target)
	if e != nil {
		t.Fatal(e)
	}
	defer held.Close()
	udp, e := net.ListenPacket("udp4", "127.0.0.1:0")
	if e != nil {
		t.Fatal(e)
	}
	defer udp.Close()
	go func() {
		b := make([]byte, 1200)
		n, a, e := udp.ReadFrom(b)
		if e == nil {
			udp.WriteTo(b[:n], a)
		}
	}()
	p, e := c.DialPacket(ctx, udp.LocalAddr().String())
	if e != nil {
		t.Fatal(e)
	}
	defer p.Close()
	p.SetDeadline(time.Now().Add(time.Second))
	payload := copyPart(0, []byte("UDP payload, not a TCP copy"))
	if _, e = p.WriteTo(payload, nil); e != nil {
		t.Fatal(e)
	}
	b := make([]byte, 1200)
	n, _, e := p.ReadFrom(b)
	if e != nil || !bytes.Equal(payload, b[:n]) {
		t.Fatal("datagram namespaces mixed", e)
	}
	var wg sync.WaitGroup
	errs := make(chan error, 8)
	for i := 0; i < 8; i++ {
		wg.Add(1)
		go func(i int) { defer wg.Done(); errs <- checkEcho(ctx, c, target, bytes.Repeat([]byte{byte(i)}, 64<<10)) }(i)
	}
	wg.Wait()
	close(errs)
	for e := range errs {
		if e != nil {
			t.Fatal(e)
		}
	}
	held.Close()
	if e = checkEcho(ctx, c, target, []byte("survives cancellation")); e != nil {
		t.Fatal(e)
	}
}
