package fastcatnext

import (
	"context"
	"crypto/x509"
	"errors"
	"github.com/metacubex/mihomo/transport/tuic/common"
	quic "github.com/metacubex/quic-go"
	"net"
	"net/netip"
	"sync/atomic"
	"time"
)

type Config struct {
	Endpoint, ServerName, Account, Congestion string
	Key                                       []byte
	Roots                                     *x509.CertPool
	IdleTimeout                               time.Duration
	ConnectTimeout                            time.Duration
	Trace                                     Trace
}

func (c Config) validate() error {
	if c.ConnectTimeout < 0 || c.IdleTimeout < 0 {
		return ErrProtocol
	}
	if !validTarget(c.Endpoint) || c.ServerName == "" || len(c.Account) < 1 || len(c.Account) > 64 || len(c.Key) != 32 {
		return ErrProtocol
	}
	if c.Congestion != "" && c.Congestion != "reno" && c.Congestion != "bbr" {
		return errors.New("unsupported congestion control")
	}
	return nil
}
func (c Config) idle() time.Duration {
	if c.IdleTimeout > 0 {
		return c.IdleTimeout
	}
	return 60 * time.Second
}
func setCC(q *quic.Conn, cc string) {
	if cc == "bbr" {
		common.SetCongestionController(q, "bbr", 0, "")
	}
}
func quicConfig(idle time.Duration) *quic.Config {
	return &quic.Config{EnableDatagrams: true, HandshakeIdleTimeout: 5 * time.Second, MaxIdleTimeout: idle, MaxIncomingStreams: 128, MaxIncomingUniStreams: -1, InitialStreamReceiveWindow: 2 << 20, MaxStreamReceiveWindow: 6 << 20, InitialConnectionReceiveWindow: 3 << 20, MaxConnectionReceiveWindow: 15 << 20}
}

type Counters struct{ Accepted, Rejected, Upload, Download, Sessions atomic.Uint64 }
type ServerConfig struct {
	Accounts     map[string][]byte
	Congestion   string
	IdleTimeout  time.Duration
	AllowPrivate bool
	DialContext  func(context.Context, string, string) (net.Conn, error)
	Counters     *Counters
	Trace        Trace
}

func publicIP(ip netip.Addr) bool {
	ip = ip.Unmap()
	if !ip.IsGlobalUnicast() || ip.IsPrivate() || ip.IsLoopback() || ip.IsLinkLocalUnicast() {
		return false
	}
	for _, s := range []string{"100.64.0.0/10", "192.0.0.0/24", "192.0.2.0/24", "198.18.0.0/15", "198.51.100.0/24", "203.0.113.0/24", "240.0.0.0/4", "2001:db8::/32"} {
		if netip.MustParsePrefix(s).Contains(ip) {
			return false
		}
	}
	return true
}
func (c ServerConfig) dial(ctx context.Context, network, target string) (net.Conn, error) {
	if !validTarget(target) {
		return nil, ErrTarget
	}
	if c.DialContext != nil {
		return c.DialContext(ctx, network, target)
	}
	host, port, _ := net.SplitHostPort(target)
	ips, e := net.DefaultResolver.LookupNetIP(ctx, "ip", host)
	if e != nil {
		return nil, e
	}
	if len(ips) == 0 {
		return nil, ErrTarget
	}
	for _, ip := range ips {
		if !c.AllowPrivate && !publicIP(ip) {
			return nil, ErrTarget
		}
	}
	// Pin the validated answers. Two staggered candidates avoid a broken family
	// serially consuming the whole target budget; the loser is always closed.
	type result struct {
		conn net.Conn
		err  error
	}
	out := make(chan result)
	race, stop := context.WithCancel(ctx)
	defer stop()
	if len(ips) > 1 {
		for i := 1; i < len(ips); i++ {
			if ips[i].Is4() != ips[0].Is4() {
				ips[1], ips[i] = ips[i], ips[1]
				break
			}
		}
	}
	launch := func(ip netip.Addr) {
		go func() {
			n, e := (&net.Dialer{}).DialContext(race, network, net.JoinHostPort(ip.String(), port))
			select {
			case out <- result{n, e}:
			case <-race.Done():
				if n != nil {
					n.Close()
				}
			}
		}()
	}
	next, active := 1, 1
	launch(ips[0])
	timer := time.NewTimer(250 * time.Millisecond)
	defer timer.Stop()
	var last error
	for active > 0 {
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		case <-timer.C:
			if next < len(ips) && active < 2 {
				launch(ips[next])
				next++
				active++
			}
		case r := <-out:
			active--
			if r.err == nil {
				return r.conn, nil
			}
			last = r.err
			if next < len(ips) {
				launch(ips[next])
				next++
				active++
			}
		}
	}
	return nil, last
}
