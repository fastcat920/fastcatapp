package fcn

import (
	"context"
	"crypto/tls"
	"errors"
	quic "github.com/metacubex/quic-go"
	qtls "github.com/metacubex/tls"
	"golang.org/x/net/http2"
	"io"
	"net"
	"net/http"
	"strconv"
	"sync"
	"sync/atomic"
	"time"
)

type physical struct {
	q                 *quic.Conn
	stats             *quicTrace
	pc                net.PacketConn
	tcp               *tls.Conn
	h2                *http2.ClientConn
	binding           []byte
	count             int
	packets           *clientAssociations
	active            int
	retired, checking bool
}

func (p *physical) close() {
	if p.q != nil {
		p.q.CloseWithError(0, "")
		p.pc.Close()
	}
	if p.tcp != nil {
		p.tcp.Close()
	}
}
func (p *physical) alive() bool {
	if p.q != nil {
		return p.q.Context().Err() == nil
	}
	return p.h2.CanTakeNewRequest()
}

type Client struct {
	recovery         [2]recoverySignal
	recoverySwitchAt time.Time
	recoveryLastLane int
	lanes            []*Client
	laneActive       []int
	laneMetrics      []*laneMetrics
	laneWarming      []chan struct{}
	laneWarmCancel   []context.CancelFunc
	laneWarmLast     []time.Time
	laneAssigned     [2]uint64
	laneSequence     uint64
	lastLane         int
	laneStreak       int
	laneSwitchAt     time.Time
	laneTrials       uint64
	laneSpills       uint64
	probeWindow      time.Time
	probeBytes       int64
	probeCount       int
	spareIdle        *time.Timer
	spareIdleSeq     uint64
	cfg              Config
	carrier          string
	ctx              context.Context
	cancel           context.CancelFunc
	mu               sync.Mutex
	pool             *physical
	all              map[*physical]bool
	closed           bool
	pending          chan struct{}
	pendingCancel    context.CancelFunc
	epoch            uint64
	lastReplacement  time.Time
}

func NewClient(parent context.Context, c Config, carrier string) (*Client, error) {
	if e := c.validate(); e != nil {
		return nil, e
	}
	if carrier != "quic" && carrier != "h2" {
		return nil, ErrProtocol
	}
	if carrier != "quic" && (c.LocalUDPPort != 0 || c.PrefixRedundancy) {
		return nil, ErrProtocol
	}
	if carrier != "quic" && c.QUICLanes > 1 {
		return nil, ErrProtocol
	}
	c.Key = append([]byte(nil), c.Key...)
	ctx, cancel := context.WithCancel(parent)
	cl := &Client{cfg: c, carrier: carrier, ctx: ctx, cancel: cancel, all: make(map[*physical]bool)}
	if c.QUICLanes == 2 {
		childConfig := c
		childConfig.QUICLanes = 1
		childConfig.AdaptiveLanes = false
		childConfig.PrimaryPreferred = false
		childConfig.LatencyAware = false
		childConfig.RecoveryAware = false
		childConfig.ReserveInteractive = false
		childConfig.ScheduleHysteresis = false
		childConfig.LaneTrace = nil
		for i := 0; i < 2; i++ {
			laneConfig := childConfig
			if laneConfig.LocalUDPPort > 0 {
				laneConfig.LocalUDPPort += i
			}
			child, err := NewClient(ctx, laneConfig, carrier)
			if err != nil {
				cl.Close()
				return nil, err
			}
			cl.lanes = append(cl.lanes, child)
			cl.laneActive = append(cl.laneActive, 0)
			cl.laneMetrics = append(cl.laneMetrics, new(laneMetrics))
			cl.laneWarming = append(cl.laneWarming, nil)
			cl.laneWarmCancel = append(cl.laneWarmCancel, nil)
			cl.laneWarmLast = append(cl.laneWarmLast, time.Time{})
		}
	}
	go func() { <-ctx.Done(); cl.Close() }()
	return cl, nil
}
func (c *Client) Close() {
	c.cancel()
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.closed {
		return
	}
	c.closed = true
	c.cancelSpareIdleLocked()
	c.cancel()
	for _, cancel := range c.laneWarmCancel {
		if cancel != nil {
			cancel()
		}
	}
	for _, child := range c.lanes {
		child.Close()
	}
	for p := range c.all {
		p.close()
	}
	c.all = nil
	c.pool = nil
}

// Reset retires the network generation. Existing streams terminate explicitly;
// no application bytes are replayed. Only later Dial calls obtain a new session.
func (c *Client) Reset() {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.epoch++
	c.recovery = [2]recoverySignal{}
	c.recoverySwitchAt = time.Time{}
	c.recoveryLastLane = 0
	c.cancelSpareIdleLocked()
	c.laneStreak = 0
	c.laneSwitchAt = time.Time{}
	c.probeWindow = time.Time{}
	c.probeCount = 0
	c.probeBytes = 0
	for i, cancel := range c.laneWarmCancel {
		if cancel != nil {
			cancel()
		}
		c.laneWarmCancel[i] = nil
		c.laneWarming[i] = nil
		c.laneWarmLast[i] = time.Time{}
		c.laneMetrics[i] = new(laneMetrics)
		c.laneActive[i] = 0
	}
	for _, child := range c.lanes {
		child.Reset()
	}
	c.lastReplacement = time.Time{}
	if c.pendingCancel != nil {
		c.pendingCancel()
	}
	for p := range c.all {
		p.close()
		delete(c.all, p)
	}
	c.pool = nil
}
func (c *Client) acquire(ctx context.Context) (*physical, error) {
	for {
		c.mu.Lock()
		if c.closed {
			c.mu.Unlock()
			return nil, net.ErrClosed
		}
		if p := c.pool; p != nil && p.count < maxRequests && !p.retired && p.alive() {
			p.count++
			c.mu.Unlock()
			return p, nil
		}
		if pending := c.pending; pending != nil {
			c.mu.Unlock()
			select {
			case <-pending:
				continue
			case <-ctx.Done():
				return nil, ctx.Err()
			case <-c.ctx.Done():
				return nil, net.ErrClosed
			}
		}
		for p := range c.all {
			if !p.alive() || (p != c.pool && p.active == 0) {
				p.close()
				delete(c.all, p)
			}
		}
		if len(c.all) >= 2 {
			c.mu.Unlock()
			return nil, errors.New("retired session limit reached")
		}
		pending := make(chan struct{})
		dialctx, dialcancel := context.WithCancel(ctx)
		c.pendingCancel = dialcancel
		c.pending = pending
		epoch := c.epoch
		c.mu.Unlock()
		p, e := c.connect(dialctx)
		dialcancel()
		c.mu.Lock()
		if e == nil && (c.closed || c.epoch != epoch) {
			p.close()
			e = net.ErrClosed
		}
		if e == nil {
			c.pool = p
			c.all[p] = true
		}
		c.pending = nil
		c.pendingCancel = nil
		close(pending)
		c.mu.Unlock()
		return p, e
	}
}
func resolveEntry(ctx context.Context, endpoint string) (*net.UDPAddr, error) {
	host, port, e := net.SplitHostPort(endpoint)
	if e != nil {
		return nil, e
	}
	n, e := strconv.Atoi(port)
	if e != nil {
		return nil, e
	}
	if ip := net.ParseIP(host); ip != nil {
		return &net.UDPAddr{IP: ip, Port: n}, nil
	}
	ips, e := net.DefaultResolver.LookupIPAddr(ctx, host)
	if e != nil {
		return nil, e
	}
	if len(ips) == 0 {
		return nil, ErrTarget
	}
	return &net.UDPAddr{IP: ips[0].IP, Zone: ips[0].Zone, Port: n}, nil
}
func (c *Client) connect(parent context.Context) (*physical, error) {
	timeout := c.cfg.ConnectTimeout
	if timeout == 0 {
		timeout = 10 * time.Second
	}
	ctx, cancel := context.WithTimeout(parent, timeout)
	defer cancel()
	stop := context.AfterFunc(c.ctx, cancel)
	defer stop()
	p := &physical{count: 1}
	var e error
	if c.carrier == "quic" {
		stageStart := time.Now()
		var addr net.Addr
		if c.cfg.OpenPacket != nil {
			p.pc, addr, e = c.cfg.OpenPacket(ctx, c.cfg.Endpoint)
		} else {
			var resolved *net.UDPAddr
			resolved, e = resolveEntry(ctx, c.cfg.Endpoint)
			if e == nil {
				addr = resolved
				family := "udp4"
				if resolved.IP.To4() == nil {
					family = "udp6"
				}
				p.pc, e = (&net.ListenConfig{}).ListenPacket(ctx, family, net.JoinHostPort("", strconv.Itoa(c.cfg.LocalUDPPort)))
			}
		}
		emitStage(c.cfg.Trace, c.carrier, "udp_socket", stageStart, e)
		if e != nil {
			return nil, e
		}
		qc := profileQUICConfig(c.cfg.idle(), c.cfg.QUICProfile)
		stats := new(quicTrace)
		if c.cfg.Trace != nil {
			stats.prefix = c.cfg.PrefixTrace
			p.stats = stats
			stats.trace = c.cfg.Trace
			stats.started = time.Now()
			stats.side = "client"
			stats.session = traceSession.Add(1)
			attachQUICTrace(qc, stats)
		}
		stageStart = time.Now()
		p.q, e = quic.Dial(ctx, p.pc, addr, &qtls.Config{ServerName: c.cfg.ServerName, RootCAs: c.cfg.Roots, MinVersion: qtls.VersionTLS13, NextProtos: []string{ALPN}}, qc)
		if c.cfg.Trace != nil {
			c.cfg.Trace(stats.snapshot("quic_handshake", stageStart, e))
		}
		if e != nil {
			p.pc.Close()
			return nil, e
		}
		setProfileCC(p.q, c.cfg.Congestion, c.cfg.QUICProfile)
		if c.cfg.Trace != nil {
			go stats.progress(p.q.Context())
		}
		state := p.q.ConnectionState().TLS
		p.binding, e = state.ExportKeyingMaterial(exporterLabel, nil, 32)
		p.packets = newClientAssociations(p.q)
		go p.packets.receive()
	} else {
		stageStart := time.Now()
		raw, e2 := (&net.Dialer{}).DialContext(ctx, "tcp", c.cfg.Endpoint)
		emitStage(c.cfg.Trace, c.carrier, "tcp_connect", stageStart, e2)
		if e2 != nil {
			return nil, e2
		}
		p.tcp = tls.Client(raw, &tls.Config{MinVersion: tls.VersionTLS13, ServerName: c.cfg.ServerName, RootCAs: c.cfg.Roots, NextProtos: []string{"h2"}})
		stageStart = time.Now()
		e = p.tcp.HandshakeContext(ctx)
		emitStage(c.cfg.Trace, c.carrier, "tls_handshake", stageStart, e)
		if e != nil {
			p.tcp.Close()
			return nil, e
		}
		state := p.tcp.ConnectionState()
		if state.NegotiatedProtocol != "h2" {
			p.tcp.Close()
			return nil, ErrProtocol
		}
		p.binding, e = state.ExportKeyingMaterial(exporterLabel, nil, 32)
		if e == nil {
			p.h2, e = (&http2.Transport{DisableCompression: true}).NewClientConn(p.tcp)
		}
	}
	if e != nil {
		p.close()
		return nil, e
	}
	return p, nil
}

func (c *Client) Warm(ctx context.Context) error {
	if len(c.lanes) != 0 {
		if err := c.lanes[0].Warm(ctx); err != nil {
			return err
		}
		if c.cfg.AdaptiveLanes && !c.cfg.PrimaryPreferred {
			c.mu.Lock()
			done := c.prepareLaneLocked(1)
			c.mu.Unlock()
			if done != nil {
				select {
				case <-done:
				case <-ctx.Done():
					return ctx.Err()
				}
			}
		}
		return nil
	}
	_, e := c.acquire(ctx)
	return e
}
func (c *Client) Dial(ctx context.Context, target string) (net.Conn, error) {
	if len(c.lanes) != 0 {
		return c.dialLane(ctx, target)
	}
	c.mu.Lock()
	c.laneAssigned[0]++
	c.mu.Unlock()
	return c.dial(ctx, target, 0)
}
func (c *Client) dial(ctx context.Context, target string, kind byte) (net.Conn, error) {
	if kind == 0 && c.cfg.PrefixRedundancy {
		kind = 2
	}
	if !validTarget(target) || kind > 2 || kind == 2 && !c.cfg.PrefixRedundancy {
		return nil, ErrProtocol
	}
	if kind == 1 && c.carrier != "quic" {
		return nil, errors.New("UDP requires QUIC path")
	}
	p, e := c.acquire(ctx)
	if e != nil {
		return nil, e
	}
	if e = c.retain(p); e != nil {
		return nil, e
	}
	transferred := false
	defer func() {
		if !transferred {
			c.release(p)
		}
	}()
	head, e := encodeHeader(c.cfg.Account, target, kind, c.cfg.Key, p.binding)
	if e != nil {
		return nil, e
	}
	tag := ""
	if c.cfg.Trace != nil {
		var nonce [16]byte
		copy(nonce[:], head[len(head)-48:len(head)-32])
		tag = diagnosticTag(nonce)
	}
	if p.q != nil {
		if kind == 2 && !p.q.ConnectionState().SupportsDatagrams.Remote {
			return nil, ErrProtocol
		}
		stream, e := p.q.OpenStreamSync(ctx)
		if e != nil {
			return nil, e
		}
		conn := &quicConn{physical: p, traced: c.cfg.Trace != nil, tag: tag, openedAt: time.Now().UnixMicro(), Stream: stream, local: p.q.LocalAddr(), remote: p.q.RemoteAddr(), onClose: func() { c.release(p) }}
		if kind == 2 {
			var trace Trace
			if c.cfg.Trace != nil {
				trace = func(e Event) {
					e.AtUnixUS = time.Now().UnixMicro()
					e.RequestTag = tag
					e.Stream = uint64(stream.StreamID())
					if p.stats != nil {
						e.Session = p.stats.session
					}
					c.cfg.Trace(e)
				}
			}
			conn.prefix = p.packets.addPrefix(uint64(stream.StreamID()), stream, trace)
		}
		if c.cfg.CoalesceOpen {
			conn.pendingHeader = head
			transferred = true
			return conn, nil
		}
		deadline, _ := ctx.Deadline()
		stream.SetWriteDeadline(deadline)
		if _, e = stream.Write(head); e != nil {
			if conn.prefix != nil {
				conn.prefix.close()
			}
			stream.CancelRead(0)
			stream.CancelWrite(0)
			return nil, e
		}
		stream.SetWriteDeadline(time.Time{})
		transferred = true
		return conn, nil
	}
	// A fixed ClientConn cannot silently reconnect or replay a POST. Its exporter
	// always matches this exact TLS connection. Concurrent requests remain streams.
	reader, writer := io.Pipe()
	streamctx, cancel := context.WithCancel(ctx)
	req, e := http.NewRequestWithContext(streamctx, "POST", "https://"+c.cfg.Endpoint+"/session", reader)
	if e != nil {
		cancel()
		return nil, e
	}
	req.Header.Set("Content-Type", "application/octet-stream")
	req.Header.Set("User-Agent", "")
	headerDone := make(chan error, 1)
	go func() { _, e := writer.Write(head); headerDone <- e }()
	res, e := p.h2.RoundTrip(req)
	if e != nil {
		if ctx.Err() != nil {
			go c.checkH2(p)
		}
		cancel()
		reader.Close()
		writer.Close()
		<-headerDone
		return nil, e
	}
	if res.StatusCode != 200 {
		res.Body.Close()
		cancel()
		reader.Close()
		writer.Close()
		<-headerDone
		if res.StatusCode == 502 {
			return nil, ErrTarget
		}
		return nil, ErrAuth
	}
	if e = <-headerDone; e != nil {
		res.Body.Close()
		cancel()
		return nil, e
	}
	transferred = true
	return &httpConn{body: res.Body, w: writer, cancel: cancel, local: p.tcp.LocalAddr(), remote: p.tcp.RemoteAddr(), onClose: func() { c.release(p) }, onStall: func() { c.checkH2(p) }}, nil
}

type quicConn struct {
	prefix                                                 *prefixCopyReader
	physical                                               *physical
	traced                                                 bool
	tag                                                    string
	openedAt                                               int64
	statusStart, statusEnd, firstData, readWait, writeWait atomic.Int64
	writeMu                                                sync.Mutex
	pendingHeader                                          []byte
	prefixDone                                             atomic.Bool
	prefixErr                                              error
	*quic.Stream
	once          sync.Once
	status        error
	closeOnce     sync.Once
	onClose       func()
	local, remote net.Addr
}

// The first write combines OPEN with at most 16 KiB of business data. Reads
// and half-close flush OPEN alone, preserving server-first protocols.
func (c *quicConn) Write(b []byte) (int, error) {
	if c.traced {
		start := time.Now()
		defer func() { c.writeWait.Add(time.Since(start).Microseconds()) }()
	}
	c.writeMu.Lock()
	defer c.writeMu.Unlock()
	if c.prefixErr != nil {
		return 0, c.prefixErr
	}
	if len(c.pendingHeader) == 0 {
		c.prefixDone.Store(true)
		return c.Stream.Write(b)
	}
	h := c.pendingHeader
	c.pendingHeader = nil
	first := len(b)
	if first > 16<<10 {
		first = 16 << 10
	}
	packet := make([]byte, len(h)+first)
	copy(packet, h)
	copy(packet[len(h):], b[:first])
	n, e := c.Stream.Write(packet)
	user := n - len(h)
	if user < 0 {
		user = 0
	}
	if e != nil {
		c.prefixErr = e
		c.prefixDone.Store(true)
		return user, e
	}
	if n != len(packet) {
		c.prefixErr = io.ErrShortWrite
		c.prefixDone.Store(true)
		return user, c.prefixErr
	}
	c.prefixDone.Store(true)
	if first < len(b) {
		more, e := c.Stream.Write(b[first:])
		return first + more, e
	}
	return first, nil
}
func (c *quicConn) flushOpen() error {
	if c.prefixDone.Load() {
		return c.prefixErr
	}
	c.writeMu.Lock()
	defer c.writeMu.Unlock()
	if c.prefixErr != nil {
		return c.prefixErr
	}
	if len(c.pendingHeader) == 0 {
		c.prefixDone.Store(true)
		return nil
	}
	h := c.pendingHeader
	c.pendingHeader = nil
	n, e := c.Stream.Write(h)
	if e == nil && n != len(h) {
		e = io.ErrShortWrite
	}
	c.prefixErr = e
	c.prefixDone.Store(true)
	return e
}
func (c *quicConn) Read(b []byte) (int, error) {
	if c.traced {
		start := time.Now()
		defer func() { c.readWait.Add(time.Since(start).Microseconds()) }()
	}
	if err := c.flushOpen(); err != nil {
		return 0, err
	}
	c.once.Do(func() {
		if c.traced {
			c.statusStart.Store(time.Now().UnixMicro())
			defer func() { c.statusEnd.Store(time.Now().UnixMicro()) }()
		}
		var status [1]byte
		_, c.status = io.ReadFull(c.readSource(), status[:])
		if c.status == nil {
			switch status[0] {
			case 0:
			case 1:
				c.status = ErrAuth
			case 2:
				c.status = ErrTarget
			default:
				c.status = ErrProtocol
			}
		}
	})
	if c.status != nil {
		return 0, c.status
	}
	n, e := c.readSource().Read(b)
	if c.traced && n > 0 {
		c.firstData.CompareAndSwap(0, time.Now().UnixMicro())
	}
	return n, e
}
func (c *quicConn) Close() error {
	c.closeOnce.Do(func() {
		if c.prefix != nil {
			c.prefix.close()
		}
		c.CancelRead(0)
		c.CancelWrite(0)
		if c.onClose != nil {
			c.onClose()
		}
	})
	return nil
}
func (c *quicConn) CloseWrite() error {
	if e := c.flushOpen(); e != nil {
		return e
	}
	return c.Stream.Close()
}
func (c *quicConn) LocalAddr() net.Addr  { return c.local }
func (c *quicConn) RemoteAddr() net.Addr { return c.remote }

type httpConn struct {
	closeOnce        sync.Once
	onClose, onStall func()
	body             io.ReadCloser
	w                *io.PipeWriter
	cancel           context.CancelFunc
	local, remote    net.Addr
	mu               sync.Mutex
	timer            *time.Timer
}

func (c *httpConn) Read(b []byte) (int, error) {
	var timer *time.Timer
	if c.onStall != nil {
		timer = time.AfterFunc(2*time.Second, c.onStall)
		defer timer.Stop()
	}
	return c.body.Read(b)
}
func (c *httpConn) Write(b []byte) (int, error) { return c.w.Write(b) }
func (c *httpConn) CloseWrite() error           { return c.w.Close() }
func (c *httpConn) Close() error {
	var err error
	c.closeOnce.Do(func() {
		c.mu.Lock()
		if c.timer != nil {
			c.timer.Stop()
		}
		c.mu.Unlock()
		c.cancel()
		c.w.Close()
		err = c.body.Close()
		if c.onClose != nil {
			c.onClose()
		}
	})
	return err
}

func (c *httpConn) LocalAddr() net.Addr  { return c.local }
func (c *httpConn) RemoteAddr() net.Addr { return c.remote }

// HTTP/2 cannot set per-stream socket deadlines. A stream deadline cancels only
// this request, preserving other streams and the physical connection.
func (c *httpConn) SetDeadline(t time.Time) error {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.timer != nil {
		c.timer.Stop()
	}
	if !t.IsZero() {
		c.timer = time.AfterFunc(time.Until(t), func() { c.cancel(); c.w.CloseWithError(context.DeadlineExceeded); c.body.Close() })
	}
	return nil
}
func (c *httpConn) SetReadDeadline(t time.Time) error  { return c.SetDeadline(t) }
func (c *httpConn) SetWriteDeadline(t time.Time) error { return c.SetDeadline(t) }

func (c *quicConn) readSource() io.Reader {
	if c.prefix != nil {
		return c.prefix
	}
	return c.Stream
}
func (c *quicConn) SetReadDeadline(t time.Time) error {
	e := c.Stream.SetReadDeadline(t)
	if c.prefix != nil {
		c.prefix.setDeadline(t)
	}
	return e
}
func (c *quicConn) SetDeadline(t time.Time) error {
	e := c.Stream.SetDeadline(t)
	if c.prefix != nil {
		c.prefix.setDeadline(t)
	}
	return e
}
