package fcn

import (
	"context"
	"crypto/x509"
	"errors"
	common "github.com/fastcat920/fcn/internal/cc"
	quic "github.com/metacubex/quic-go"
	"net"
	"net/netip"
	"sync/atomic"
	"time"
)

type Config struct {
	OpenPacket       func(context.Context, string) (net.PacketConn, net.Addr, error)
	PrefixRedundancy bool // explicit QUIC kind-2 extension; defaults off
	// RecoveryAware avoids a recently recovering lane for new streams only.
	RecoveryAware bool
	// LocalUDPPort fixes a diagnostic flow tuple; zero uses an ephemeral port.
	LocalUDPPort int
	// QUICLanes bounds independent stream pools. Zero means one.
	// Each pool retains its existing bound of two physical sessions during rotation.
	QUICLanes int
	// AdaptiveLanes prioritizes ready connections and bounded background preparation.
	AdaptiveLanes bool
	// PrimaryPreferred keeps unproven traffic on the primary. Opt-in only.
	PrimaryPreferred bool
	// LatencyAware scores observed setup/first-read wait and current load. Opt-in.
	LatencyAware bool
	// ReserveInteractive groups the first two concurrent unknown opens briefly,
	// leaving an independent lane available for later work. Never classifies payload.
	ReserveInteractive bool
	// ScheduleHysteresis bounds score-driven switching and consecutive assignments.
	ScheduleHysteresis bool
	// LaneTrace reports sanitized per-stream selection without packet-level tracing.
	LaneTrace func(LaneEvent)
	// QUICProfile selects a bounded transport experiment; empty/baseline preserve 0.2.
	QUICProfile                               string
	CoalesceOpen                              bool
	Endpoint, ServerName, Account, Congestion string
	Key                                       []byte
	Roots                                     *x509.CertPool
	IdleTimeout                               time.Duration
	ConnectTimeout                            time.Duration
	Trace                                     Trace
	PrefixTrace                               bool
}

func (c Config) validate() error {
	if c.LocalUDPPort != 0 && (c.LocalUDPPort < 1024 || c.LocalUDPPort > 65535 || c.QUICLanes == 2 && c.LocalUDPPort == 65535) {
		return ErrProtocol
	}
	if c.RecoveryAware && (!c.AdaptiveLanes || c.PrimaryPreferred || c.LatencyAware) {
		return ErrProtocol
	}
	if (c.PrimaryPreferred || c.LatencyAware) && !c.AdaptiveLanes {
		return ErrProtocol
	}
	if (c.ReserveInteractive || c.ScheduleHysteresis) && !c.LatencyAware {
		return ErrProtocol
	}
	if c.PrimaryPreferred && c.LatencyAware {
		return ErrProtocol
	}
	if c.QUICLanes < 0 || c.QUICLanes > 2 {
		return ErrProtocol
	}
	if c.AdaptiveLanes && c.QUICLanes != 2 {
		return ErrProtocol
	}
	if !validQUICProfile(c.QUICProfile) {
		return ErrProtocol
	}
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
func validQUICProfile(profile string) bool {
	return profile == "" || profile == "baseline" || profile == "wide" || profile == "conservative" || profile == "balanced" || profile == "bbr-legacy"
}
func setCC(q *quic.Conn, cc string) { setProfileCC(q, cc, "") }
func setProfileCC(q *quic.Conn, cc, profile string) {
	if cc == "bbr" {
		if profile == "bbr-legacy" {
			common.SetCongestionController(q, "bbr_meta_v1", 32, "")
			return
		}
		cwnd := 32
		bbrProfile := ""
		if profile == "conservative" || profile == "balanced" {
			cwnd = 16
			bbrProfile = "conservative"
		}
		common.SetCongestionController(q, "bbr", cwnd, bbrProfile)
	}
}
func quicConfig(idle time.Duration) *quic.Config { return profileQUICConfig(idle, "") }
func profileQUICConfig(idle time.Duration, profile string) *quic.Config {
	c := &quic.Config{EnableDatagrams: true, HandshakeIdleTimeout: 5 * time.Second, MaxIdleTimeout: idle, MaxIncomingStreams: 128, MaxIncomingUniStreams: -1, InitialStreamReceiveWindow: 2 << 20, MaxStreamReceiveWindow: 6 << 20, InitialConnectionReceiveWindow: 3 << 20, MaxConnectionReceiveWindow: 15 << 20}
	if profile == "wide" || profile == "balanced" {
		c.MaxStreamReceiveWindow = 16 << 20
		c.InitialConnectionReceiveWindow = 6 << 20
		c.MaxConnectionReceiveWindow = 64 << 20
	}
	return c
}

type Counters struct{ Accepted, Rejected, Upload, Download, Sessions atomic.Uint64 }
type ServerConfig struct {
	PrefixRedundancy bool
	// DownstreamBudget bounds bulk packetization while fresh streams need service. Opt-in.
	DownstreamBudget bool
	TracePeerSalt    []byte // optional, private diagnostic salt; never emitted
	// ReplyCoalesceDelay is opt-in; zero preserves immediate success status.
	ReplyCoalesceDelay time.Duration
	// FixedPacketSize is an isolated, opt-in PMTU diagnostic; zero preserves default.
	FixedPacketSize  uint16
	QUICProfile      string
	Accounts         map[string][]byte
	LookupKey        func(string) []byte
	AuthorizeContext func(context.Context, string, net.Addr) (context.Context, func(), error)
	Congestion       string
	IdleTimeout      time.Duration
	AllowPrivate     bool
	DialContext      func(context.Context, string, string) (net.Conn, error)
	Counters         *Counters
	Trace            Trace
	PrefixTrace      bool
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
