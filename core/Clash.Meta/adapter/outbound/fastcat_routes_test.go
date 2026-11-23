package outbound

import (
	"context"
	"crypto/x509"
	"errors"
	"io"
	"net"
	"net/netip"
	"sync/atomic"
	"syscall"
	"testing"
	"time"

	"github.com/metacubex/mihomo/component/fastcatentry"
	"github.com/metacubex/mihomo/component/fastcatprobe"
	C "github.com/metacubex/mihomo/constant"
)

func TestV2RouteWindow(t *testing.T) {
	a := new(FastCatAuto)
	n, p, err := a.choose(time.Now())
	if err != nil || p != pathH3 {
		t.Fatal(p, err)
	}
	i := a.observed(n, pathH3, time.Now().Add(-20*time.Millisecond), true)
	a.firstPayload(n, pathH3, i, time.Second)
	_, p, _ = a.choose(time.Now())
	if p != pathH2 {
		t.Fatal("did not sample other transport")
	}
	for j := 0; j < 2; j++ {
		a.observed(n, pathH3, time.Now().Add(-time.Second), true)
		a.observed(n, pathH2, time.Now().Add(-100*time.Millisecond), true)
	}
	i = a.observed(n, pathH2, time.Now().Add(-50*time.Millisecond), true)
	a.firstPayload(n, pathH2, i, 100*time.Millisecond)
	_, p, _ = a.choose(time.Now())
	if p != pathH2 {
		t.Fatal("ignored observed first response")
	}
	a.observed(n, pathH2, time.Now(), false)
	_, p, _ = a.choose(time.Now())
	if p != pathH3 {
		t.Fatal("preferred unreachable path")
	}
	ResetFastCatH2Connections()
	n2, p, _ := a.choose(time.Now())
	if n2 == n || p != pathH3 || a.routes.paths[pathH2].count != 0 {
		t.Fatal("carried stale route across networks")
	}
	a.firstPayload(n, pathH2, i, time.Hour)
	if a.routes.paths[pathH2].count != 0 {
		t.Fatal("late read contaminated new path")
	}
}

func TestV2RouteFailureBoundaries(t *testing.T) {
	m := &C.Metadata{Host: "test.invalid", DstPort: 443}
	for _, tc := range []struct {
		name      string
		ready     bool
		failure   error
		alternate bool
	}{
		{"UDP-unreachable", false, syscall.ECONNREFUSED, true},
		{"invalid-certificate", false, x509.UnknownAuthorityError{}, false},
		{"target-rejected", true, errors.New("CONNECT denied"), false},
		{"entry-reset-after-CONNECT", true, io.ErrUnexpectedEOF, false},
	} {
		t.Run(tc.name, func(t *testing.T) {
			var alts, writes atomic.Int32
			x := &autoTestChild{Base: NewBase(BaseOption{Name: "region"}), dial: func(ctx context.Context) (C.Conn, error) {
				if tc.ready {
					fastcatentry.Ready(ctx)
				}
				return nil, tc.failure
			}}
			y := &autoTestChild{Base: x.Base}
			y.dial = func(ctx context.Context) (C.Conn, error) {
				alts.Add(1)
				l, r := net.Pipe()
				go func() {
					defer r.Close()
					b := make([]byte, 1)
					if _, err := io.ReadFull(r, b); err == nil {
						writes.Add(1)
						r.Write(b)
					}
				}()
				return NewConn(l, y), nil
			}
			a := &FastCatAuto{Base: x.Base, h3: x, h2: y}
			defer a.Close()
			trace := new(fastcatprobe.Timing)
			c, err := a.DialContext(trace.WithContext(context.Background()), m)
			if !tc.alternate {
				if err == nil || alts.Load() != 0 {
					t.Fatal("retried terminal error")
				}
				return
			}
			if err != nil {
				t.Fatal(err)
			}
			defer c.Close()
			if _, err = c.Write([]byte{42}); err != nil {
				t.Fatal(err)
			}
			var b [1]byte
			if _, err = io.ReadFull(c, b[:]); err != nil || b[0] != 42 || writes.Load() != 1 || alts.Load() != 1 || trace.Snapshot()["used-protocol"] != "h2" {
				t.Fatal("wrong payload/route", err)
			}
			if a.routes.paths[pathH2].recent[0].firstPayload <= 0 {
				t.Fatal("no first byte observation")
			}
		})
	}
}

func TestV2UDPPathsAndDeadlines(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	var opens atomic.Int32
	pc := newFastCatPackets(ctx, func(ctx context.Context, target string) (net.Conn, error) {
		opens.Add(1)
		l, r := net.Pipe()
		go func() {
			defer r.Close()
			buf := make([]byte, 64)
			for {
				n, e := r.Read(buf)
				if e != nil {
					return
				}
				if _, e = r.Write(append([]byte(target+" "), buf[:n]...)); e != nil {
					return
				}
			}
		}()
		return l, nil
	})
	defer pc.Close()
	for _, port := range []uint16{4010, 4011, 4010} {
		addr := net.UDPAddrFromAddrPort(netip.AddrPortFrom(netip.MustParseAddr("127.0.0.1"), port))
		if _, err := pc.WriteTo([]byte("probe"), addr); err != nil {
			t.Fatal(err)
		}
		pc.SetReadDeadline(time.Now().Add(time.Second))
		var b [96]byte
		n, from, err := pc.ReadFrom(b[:])
		if err != nil || from.String() != addr.String() || string(b[:n]) != addr.String()+" probe" {
			t.Fatal(n, from, err)
		}
	}
	if opens.Load() != 2 {
		t.Fatal("wrong stream count")
	}
	pc.SetReadDeadline(time.Now())
	if _, _, err := pc.ReadFrom(nil); err == nil {
		t.Fatal("read deadline ignored")
	}
	pc.SetDeadline(time.Time{})
	pc.Close()
	if _, _, err := pc.ReadFrom(nil); !errors.Is(err, net.ErrClosed) {
		t.Fatal(err)
	}
}

type udpOnlyTest struct {
	*autoTestChild
	calls atomic.Int32
}

func (u *udpOnlyTest) ListenPacketContext(context.Context, *C.Metadata) (C.PacketConn, error) {
	u.calls.Add(1)
	return nil, syscall.ECONNREFUSED
}
func TestV2UDPFailureNeverUsesTCP(t *testing.T) {
	base := NewBase(BaseOption{UDP: true})
	h3 := &udpOnlyTest{autoTestChild: &autoTestChild{Base: base}}
	h2 := &udpOnlyTest{autoTestChild: &autoTestChild{Base: base}}
	a := &FastCatAuto{Base: base, h3: h3, h2: h2}
	for i := 0; i < 2; i++ {
		if _, err := a.ListenPacketContext(context.Background(), &C.Metadata{NetWork: C.UDP, DstPort: 53, Host: "example.test"}); !errors.Is(err, C.ErrFastCatAutoDialFinished) {
			t.Fatal(err)
		}
	}
	if h2.calls.Load() != 0 || h3.calls.Load() != 1 {
		t.Fatal("UDP path retry/fallback", h2.calls.Load(), h3.calls.Load())
	}
}

func TestV2RouteHysteresis(t *testing.T) {
	a := new(FastCatAuto)
	now := time.Now()
	n, _, _ := a.choose(now)
	for i := 0; i < 3; i++ {
		a.observed(n, pathH3, now.Add(-time.Second), true)
		a.observed(n, pathH2, now.Add(-100*time.Millisecond), true)
	}
	a.choose(now)
	if a.routes.preferred != pathH2 {
		t.Fatal("failed to prefer materially faster path")
	}
	for i := 0; i < 8; i++ {
		a.observed(n, pathH2, now.Add(-2*time.Second), true)
		a.observed(n, pathH3, now.Add(-time.Millisecond), true)
	}
	a.choose(now.Add(time.Second))
	if a.routes.preferred != pathH2 {
		t.Fatal("flapped inside hold time")
	}
	a.choose(now.Add(12 * time.Second))
	if a.routes.preferred != pathH3 {
		t.Fatal("stayed on degraded path")
	}
}
