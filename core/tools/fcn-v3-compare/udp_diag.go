package main

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/netip"
	"strconv"
	"time"

	"github.com/fastcat920/fcn"
	"github.com/fastcat920/fcnv3"
	"github.com/metacubex/mihomo/adapter/outbound"
	"github.com/metacubex/mihomo/common/net/deadline"
	"github.com/metacubex/mihomo/component/ca"
	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/quic-go"
	"github.com/metacubex/sing/common"
)

const (
	udpDiagnosticMagic  = "FCNUDP01"
	udpDiagnosticHeader = 36
	udpPacketTimeout    = 1500 * time.Millisecond
)

var udpDiagnosticSizes = [...]int{64, 256, 512, 900, 1000, 1100, fcnv3.MaxUDPPayload}

type udpDiagnosticConn struct {
	send    func([]byte) error
	receive func(context.Context) ([]byte, error)
	abort   func()
	close   func()
}

type udpPacketRow struct {
	Event              string   `json:"event"`
	Protocol           string   `json:"protocol"`
	RunID              string   `json:"run_id"`
	Sequence           int      `json:"sequence"`
	Bytes              int      `json:"bytes"`
	Attempted          bool     `json:"attempted"`
	Submitted          bool     `json:"submitted"`
	Echoed             bool     `json:"echoed"`
	SendUnixNS         int64    `json:"send_unix_ns,omitempty"`
	EchoDeadlineUnixNS int64    `json:"echo_deadline_unix_ns,omitempty"`
	EchoRTTMS          *float64 `json:"echo_rtt_ms,omitempty"`
	UnmatchedReplies   int      `json:"unmatched_replies"`
	ErrorStage         string   `json:"error_stage,omitempty"`
	ErrorCategory      string   `json:"error_category,omitempty"`
}

type udpCounts struct {
	Planned   int `json:"planned"`
	Attempted int `json:"attempted"`
	Submitted int `json:"submitted"`
	Echoed    int `json:"echoed"`
}

func (c *udpCounts) add(row udpPacketRow) {
	c.Planned++
	if row.Attempted {
		c.Attempted++
	}
	if row.Submitted {
		c.Submitted++
	}
	if row.Echoed {
		c.Echoed++
	}
}

type udpSizeCounts struct {
	Bytes int `json:"bytes"`
	udpCounts
}

type udpDiagnosticSummary struct {
	Event    string `json:"event"`
	Protocol string `json:"protocol"`
	RunID    string `json:"run_id"`
	udpCounts
	BySize             []udpSizeCounts  `json:"by_size"`
	SetupMS            float64          `json:"setup_ms"`
	ElapsedMS          float64          `json:"elapsed_ms"`
	EchoRTTMS          distribution     `json:"echo_rtt_ms"`
	SetupErrorCategory string           `json:"setup_error_category,omitempty"`
	WireRX             *udpWireRXCounts `json:"wire_rx,omitempty"`
}

func runUDPDiagnostic(parent context.Context, out io.Writer, cfg config, protocol string, count int, timeout time.Duration) error {
	return runUDPDiagnosticWithWireRX(parent, out, cfg, protocol, count, timeout, false)
}

func runUDPDiagnosticWithWireRX(parent context.Context, out io.Writer, cfg config, protocol string, count int, timeout time.Duration, capture bool) error {
	target, err := netip.ParseAddrPort(cfg.UDPTarget)
	if err != nil || target.Port() == 0 || target.Addr().Zone() != "" {
		return errors.New("UDP diagnostic target must contain a literal IP and nonzero port")
	}
	switch protocol {
	case "fcnv1", "fcnv2", "fcnv3", "tuic", "hysteria2":
	default:
		return errors.New("UDP diagnostic protocol must be fcnv1, fcnv2, fcnv3, tuic or hysteria2")
	}
	if count < 1 || count > 1000 || timeout <= 0 || timeout > 2*time.Minute {
		return errors.New("UDP diagnostic requires count 1..1000 and timeout up to 2m")
	}
	var randomID [8]byte
	rand.Read(randomID[:])
	runID := hex.EncodeToString(randomID[:])
	started := time.Now()
	ctx, cancel := context.WithTimeout(parent, timeout)
	defer cancel()
	var recorder *udpWireRXRecorder
	var wrapUDP func(*net.UDPConn) net.PacketConn
	if capture {
		recorder = new(udpWireRXRecorder)
		wrapUDP = recorder.wrap
		defer recorder.close()
	}
	conn, setupErr := openUDPDiagnostic(ctx, cfg, protocol, target, wrapUDP)
	closeConn := func() {
		if conn.close != nil {
			conn.close()
			conn.close = nil
		}
	}
	defer closeConn()
	summary := udpDiagnosticSummary{Event: "udp_summary", Protocol: protocol, RunID: runID, SetupMS: milliseconds(time.Since(started))}
	if setupErr != nil {
		if ctx.Err() != nil {
			setupErr = ctx.Err()
		}
		summary.SetupErrorCategory = udpErrorCategory(setupErr)
	}
	for _, size := range udpDiagnosticSizes[:min(count, len(udpDiagnosticSizes))] {
		summary.BySize = append(summary.BySize, udpSizeCounts{Bytes: size})
	}
	enc := json.NewEncoder(out)
	rtts := make([]float64, 0, count)
	var abortErr error
	for i := 0; i < count; i++ {
		sizeIndex := i % len(udpDiagnosticSizes)
		row := udpPacketRow{Event: "udp_packet", Protocol: protocol, RunID: runID, Sequence: i + 1, Bytes: udpDiagnosticSizes[sizeIndex]}
		switch {
		case setupErr != nil:
			row.ErrorStage, row.ErrorCategory = "setup", summary.SetupErrorCategory
		case ctx.Err() != nil:
			row.ErrorStage, row.ErrorCategory = "budget", udpErrorCategory(ctx.Err())
		case abortErr != nil:
			row.ErrorStage, row.ErrorCategory = "transport_aborted", udpErrorCategory(abortErr)
		default:
			abortErr = measureUDPPacket(ctx, conn, &row)
		}
		summary.add(row)
		summary.BySize[sizeIndex].add(row)
		if row.EchoRTTMS != nil {
			rtts = append(rtts, *row.EchoRTTMS)
		}
		if err := enc.Encode(row); err != nil {
			return fmt.Errorf("UDP packet row write failed: %w", err)
		}
	}
	summary.ElapsedMS = milliseconds(time.Since(started))
	summary.EchoRTTMS = stats(rtts)
	if recorder != nil {
		// Keep reading the wire briefly after the final application deadline.
		// This observation window consumes only the remaining run budget.
		if setupErr == nil && abortErr == nil && ctx.Err() == nil {
			timer := time.NewTimer(udpPacketTimeout)
			select {
			case <-timer.C:
			case <-ctx.Done():
			}
			timer.Stop()
		}
		closeConn()
		var err error
		summary.WireRX, err = recorder.emit(enc)
		if err != nil {
			return fmt.Errorf("UDP wire receive row write failed: %w", err)
		}
	}
	if err := enc.Encode(summary); err != nil {
		return fmt.Errorf("UDP summary write failed: %w", err)
	}
	if summary.Echoed < count {
		return fmt.Errorf("UDP echo verified for %d of %d planned datagrams", summary.Echoed, count)
	}
	return nil
}

// measureUDPPacket returns a non-nil error only when it had to abort the
// transport to unblock submission. The remaining rows will show that status.
func measureUDPPacket(ctx context.Context, conn udpDiagnosticConn, row *udpPacketRow) error {
	sentAt := time.Now()
	payload := makeUDPPayload(*row, sentAt.UnixNano())
	sendCtx, cancelSend := context.WithTimeout(ctx, udpPacketTimeout)
	aborted := make(chan struct{})
	// QUIC datagram submission can block on a full queue. Closing just the
	// UDP association does not unblock it, so stop the underlying transport.
	stopAbort := context.AfterFunc(sendCtx, func() {
		conn.abort()
		close(aborted)
	})
	row.Attempted, row.SendUnixNS = true, sentAt.UnixNano()
	sendErr := conn.send(payload)
	if sendErr == nil {
		row.Submitted = true
	}
	stopped := stopAbort()
	sendCtxErr := sendCtx.Err()
	cancelSend()
	if !stopped {
		<-aborted
		row.ErrorStage, row.ErrorCategory = "submit", udpErrorCategory(sendCtxErr)
		return sendCtxErr
	}
	if sendErr != nil {
		row.ErrorStage, row.ErrorCategory = "submit", udpErrorCategory(sendErr)
		return nil
	}

	receiveCtx, cancelReceive := context.WithTimeout(ctx, udpPacketTimeout)
	defer cancelReceive()
	deadline, _ := receiveCtx.Deadline()
	row.EchoDeadlineUnixNS = deadline.UnixNano()
	var receiveErr error
	for receiveCtx.Err() == nil {
		actual, err := conn.receive(receiveCtx)
		if err != nil {
			receiveErr = err
			break
		}
		arrived := time.Now()
		if arrived.After(deadline) || receiveCtx.Err() != nil {
			break
		}
		if bytes.Equal(actual, payload) {
			row.Echoed = true
			row.EchoRTTMS = floatPointer(milliseconds(arrived.Sub(sentAt)))
			return nil
		}
		row.UnmatchedReplies++
	}
	if receiveErr == nil {
		receiveErr = context.DeadlineExceeded
	}
	if receiveCtx.Err() != nil {
		receiveErr = receiveCtx.Err()
	}
	row.ErrorStage, row.ErrorCategory = "echo", udpErrorCategory(receiveErr)
	return nil
}

func makeUDPPayload(row udpPacketRow, timestamp int64) []byte {
	payload := make([]byte, row.Bytes)
	copy(payload[:8], udpDiagnosticMagic)
	copy(payload[8:24], row.RunID)
	binary.BigEndian.PutUint32(payload[24:28], uint32(row.Sequence))
	binary.BigEndian.PutUint64(payload[28:udpDiagnosticHeader], uint64(timestamp))
	for i := udpDiagnosticHeader; i < len(payload); i++ {
		payload[i] = byte((row.Sequence + i) % 251)
	}
	return payload
}

func udpErrorCategory(err error) string {
	switch {
	case errors.Is(err, fcnv3.ErrUDPPayloadTooLarge):
		return "datagram_too_large"
	case errors.Is(err, fcnv3.ErrUDPUnavailable), errors.Is(err, C.ErrNotSupport):
		return "udp_unavailable"
	case errors.Is(err, fcn.ErrAuth), errors.Is(err, fcn.ErrTarget):
		return "connect_rejected"
	case errors.Is(err, io.ErrShortWrite):
		return "short_write"
	}
	// These two status errors from the pinned FCN v1/v2 and Hysteria 2
	// transports do not have exported sentinels.
	if err != nil {
		switch err.Error() {
		case "datagram exceeds negotiated payload limit":
			return "datagram_too_large"
		case "UDP disabled by server":
			return "udp_unavailable"
		}
	}
	var tooLarge *quic.DatagramTooLargeError
	if errors.As(err, &tooLarge) {
		return "datagram_too_large"
	}
	return errorCategory(err)
}

func openUDPDiagnostic(ctx context.Context, cfg config, protocol string, target netip.AddrPort, wrapUDP func(*net.UDPConn) net.PacketConn) (udpDiagnosticConn, error) {
	if protocol == "fcnv3" {
		clientConfig, err := phaseFCNConfig(cfg)
		if err != nil {
			return udpDiagnosticConn{}, err
		}
		clientConfig.EnableUDP = true
		clientConfig.WrapPacketConn = wrapUDP
		client, err := fcnv3.NewClient(clientConfig)
		if err != nil {
			return udpDiagnosticConn{}, err
		}
		assoc, err := client.DialUDP(ctx, target.String())
		if err != nil {
			client.Close()
			return udpDiagnosticConn{}, err
		}
		return udpDiagnosticConn{
			send:    assoc.SendDatagram,
			receive: assoc.ReceiveDatagram,
			abort:   func() { client.Close() },
			close: func() {
				assoc.Close()
				client.Close()
			},
		}, nil
	}
	if protocol != "tuic" {
		return openAdditionalUDPDiagnostic(ctx, cfg, protocol, target, wrapUDP)
	}
	_, pem, err := readRoots(cfg.TUIC.CAFile)
	if err != nil {
		return udpDiagnosticConn{}, err
	}
	if len(pem) > 0 {
		if err := ca.AddCertificate(string(pem)); err != nil {
			return udpDiagnosticConn{}, err
		}
	}
	host, port, err := net.SplitHostPort(cfg.TUIC.Endpoint)
	if err != nil {
		return udpDiagnosticConn{}, err
	}
	p, err := strconv.Atoi(port)
	if err != nil {
		return udpDiagnosticConn{}, err
	}
	tracker := &trackedDialer{wrapUDP: wrapUDP}
	adapter, err := outbound.NewTuic(outbound.TuicOption{
		BasicOption: outbound.BasicOption{DialerForAPI: tracker},
		Name:        "fcn-v3-udp-diagnostic-tuic", Server: host, Port: p,
		UUID: cfg.TUIC.UUID, Password: cfg.TUIC.Password, SNI: cfg.TUIC.ServerName,
		CongestionController: "bbr", ReduceRtt: false, FastOpen: false, UdpRelayMode: "native",
	})
	if err != nil {
		tracker.Close()
		return udpDiagnosticConn{}, err
	}
	return openAdapterUDPDiagnostic(ctx, adapter, tracker, target)
}

func openAdditionalUDPDiagnostic(ctx context.Context, cfg config, protocol string, target netip.AddrPort, wrapUDP func(*net.UDPConn) net.PacketConn) (udpDiagnosticConn, error) {
	if err := prepareBenchmarkAdapter(cfg, protocol); err != nil {
		return udpDiagnosticConn{}, err
	}
	tracker := &trackedDialer{wrapUDP: wrapUDP}
	adapter, err := newBenchmarkAdapter(cfg, protocol, tracker)
	if err != nil {
		tracker.Close()
		return udpDiagnosticConn{}, err
	}
	// Bound association setup even when the adapter waits for its own protocol
	// reply deadline. These sockets belong to this diagnostic only.
	stop := context.AfterFunc(ctx, tracker.Close)
	defer stop()
	return openAdapterUDPDiagnostic(ctx, adapter, tracker, target)
}

func openAdapterUDPDiagnostic(ctx context.Context, adapter C.ProxyAdapter, tracker *trackedDialer, target netip.AddrPort) (udpDiagnosticConn, error) {
	target = netip.AddrPortFrom(target.Addr().Unmap(), target.Port())
	metadata := &C.Metadata{NetWork: C.UDP, DstIP: target.Addr(), DstPort: target.Port()}
	packetConn, err := adapter.ListenPacketContext(ctx, metadata)
	if err != nil {
		tracker.Close()
		adapter.Close()
		return udpDiagnosticConn{}, err
	}
	addr := metadata.UDPAddr()
	// These transports have native read deadlines. The adapter's generic
	// wrapper can leave a read running after a timeout and race with cleanup.
	receiveConn := net.PacketConn(packetConn)
	if wrapped, ok := common.Cast[*deadline.EnhancePacketConn](packetConn); ok {
		receiveConn = wrapped.PacketConn
	}
	var reply [fcnv3.MaxUDPPayload + 1]byte
	return udpDiagnosticConn{
		send: func(p []byte) error {
			n, err := packetConn.WriteTo(p, addr)
			if err == nil && n != len(p) {
				return io.ErrShortWrite
			}
			return err
		},
		receive: func(ctx context.Context) ([]byte, error) {
			expires, _ := ctx.Deadline()
			if err := receiveConn.SetReadDeadline(expires); err != nil {
				return nil, err
			}
			n, from, err := receiveConn.ReadFrom(reply[:])
			if err != nil {
				return nil, err
			}
			if source, ok := from.(*net.UDPAddr); ok && source.Port == addr.Port && source.IP.Equal(addr.IP) {
				return reply[:n], nil
			}
			return nil, nil
		},
		abort: tracker.Close,
		close: func() {
			tracker.Close()
			packetConn.Close()
			adapter.Close()
		},
	}, nil
}
