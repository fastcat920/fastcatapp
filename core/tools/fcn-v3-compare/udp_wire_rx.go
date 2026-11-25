package main

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"net"
	"sync"
	"syscall"
	"time"

	"github.com/metacubex/quic-go"
	"golang.org/x/net/ipv4"
)

const udpWireRXLimit = 16_384

type udpWireRXRow struct {
	Event           string `json:"event"`
	TimestampUnixNS int64  `json:"timestamp_unix_ns"`
	Bytes           int    `json:"bytes"`
	SHA256_64       string `json:"sha256_64"`
}

type udpWireRXCounts struct {
	Captured    int                  `json:"captured"`
	Dropped     int                  `json:"dropped"`
	RXQOverflow udpRXQOverflowCounts `json:"rxq_overflow"`
}

type udpRXQMode uint8

const (
	udpRXQUnsupported udpRXQMode = iota
	udpRXQUnavailable
	udpRXQEnabled
)

type udpRXQOverflowCounts struct {
	Status              string  `json:"status"`
	ReportedDrops       *uint64 `json:"reported_drops"`
	Sockets             int     `json:"sockets"`
	EnabledSockets      int     `json:"enabled_sockets"`
	ReportedSockets     int     `json:"reported_sockets"`
	UnsupportedSockets  int     `json:"unsupported_sockets"`
	EnableFailedSockets int     `json:"enable_failed_sockets"`
}

// A count is a lower bound through the latest notice. The kernel only reports
// these drops on a later datagram, and some sockets may have no notice at all.
func summarizeUDPRXQOverflow(sockets []*udpWireRXConn) udpRXQOverflowCounts {
	counts := udpRXQOverflowCounts{Sockets: len(sockets)}
	var drops uint64
	for _, socket := range sockets {
		switch socket.rxqMode {
		case udpRXQEnabled:
			counts.EnabledSockets++
			if socket.rxqReported {
				counts.ReportedSockets++
				drops += uint64(socket.rxqDrops)
			}
		case udpRXQUnsupported:
			counts.UnsupportedSockets++
		case udpRXQUnavailable:
			counts.EnableFailedSockets++
		}
	}
	if counts.ReportedSockets > 0 {
		counts.ReportedDrops = &drops
	}
	switch {
	case counts.Sockets == 0:
		counts.Status = "not_observed"
	case counts.UnsupportedSockets == counts.Sockets:
		counts.Status = "unsupported"
	case counts.EnabledSockets == 0:
		counts.Status = "unavailable"
	case counts.ReportedSockets == counts.Sockets:
		counts.Status = "reported"
	case counts.EnabledSockets == counts.Sockets && counts.ReportedSockets == 0:
		counts.Status = "no_notice"
	default:
		counts.Status = "partial"
	}
	return counts
}

type udpWireRXRecorder struct {
	mu      sync.Mutex
	rows    []udpWireRXRow
	dropped int
	sockets []*udpWireRXConn
	closed  bool
}

func (r *udpWireRXRecorder) wrap(socket *net.UDPConn) net.PacketConn {
	conn := &udpWireRXConn{
		UDPConn: socket, batch: ipv4.NewPacketConn(socket), recorder: r,
		rxqMode: enableUDPRXQOverflow(socket),
	}
	r.mu.Lock()
	closed := r.closed
	if !closed {
		r.sockets = append(r.sockets, conn)
	}
	r.mu.Unlock()
	if closed {
		conn.Close()
	}
	return conn
}

func (r *udpWireRXRecorder) record(timestamp time.Time, size int, payload []byte, truncated bool) {
	r.mu.Lock()
	defer r.mu.Unlock()
	if truncated || size < 0 || size > len(payload) || len(r.rows) == udpWireRXLimit {
		r.dropped++
		return
	}
	digest := sha256.Sum256(payload[:size])
	r.rows = append(r.rows, udpWireRXRow{
		Event: "udp_wire_rx", TimestampUnixNS: timestamp.UnixNano(), Bytes: size,
		SHA256_64: hex.EncodeToString(digest[:8]),
	})
}

func (r *udpWireRXRecorder) close() []*udpWireRXConn {
	r.mu.Lock()
	r.closed = true
	sockets := r.sockets
	r.sockets = nil
	r.mu.Unlock()
	for _, conn := range sockets {
		conn.Close()
	}
	return sockets
}

func (r *udpWireRXRecorder) emit(enc *json.Encoder) (*udpWireRXCounts, error) {
	rxqOverflow := summarizeUDPRXQOverflow(r.close())
	r.mu.Lock()
	rows := r.rows
	counts := &udpWireRXCounts{Captured: len(rows), Dropped: r.dropped, RXQOverflow: rxqOverflow}
	r.mu.Unlock()
	for _, row := range rows {
		if err := enc.Encode(row); err != nil {
			return nil, err
		}
	}
	return counts, nil
}

type udpWireRXConn struct {
	*net.UDPConn
	batch       *ipv4.PacketConn
	recorder    *udpWireRXRecorder
	readMu      sync.Mutex
	rxqMode     udpRXQMode
	rxqDrops    uint32
	rxqReported bool
}

var _ quic.OOBCapablePacketConn = (*udpWireRXConn)(nil)

func (c *udpWireRXConn) observeRXQOverflow(oob []byte) {
	if c.rxqMode != udpRXQEnabled || len(oob) == 0 {
		return
	}
	if count, ok := readUDPRXQOverflow(oob); ok {
		c.rxqDrops = max(c.rxqDrops, count)
		c.rxqReported = true
	}
}

// QUIC's batched receive path uses the original socket, preserving ancillary
// data and socket options while observing the bytes before QUIC processes them.
func (c *udpWireRXConn) ReadBatch(messages []ipv4.Message, flags int) (int, error) {
	c.readMu.Lock()
	defer c.readMu.Unlock()
	n, err := c.batch.ReadBatch(messages, flags)
	timestamp := time.Now()
	for i := 0; i < n; i++ {
		message := messages[i]
		// The pinned QUIC transport supplies one buffer per message.
		var payload []byte
		if len(message.Buffers) == 1 {
			payload = message.Buffers[0]
		}
		c.observeRXQOverflow(message.OOB[:message.NN])
		c.recorder.record(timestamp, message.N, payload, message.Flags&syscall.MSG_TRUNC != 0)
	}
	return n, err
}

func (c *udpWireRXConn) ReadMsgUDP(payload, oob []byte) (n, oobn, flags int, source *net.UDPAddr, err error) {
	c.readMu.Lock()
	defer c.readMu.Unlock()
	n, oobn, flags, source, err = c.UDPConn.ReadMsgUDP(payload, oob)
	if err == nil {
		c.observeRXQOverflow(oob[:oobn])
		c.recorder.record(time.Now(), n, payload, flags&syscall.MSG_TRUNC != 0)
	}
	return
}

func (c *udpWireRXConn) ReadFrom(payload []byte) (int, net.Addr, error) {
	var overflowOOB [32]byte
	var oob []byte
	if c.rxqMode == udpRXQEnabled {
		oob = overflowOOB[:]
	}
	n, _, _, source, err := c.ReadMsgUDP(payload, oob)
	if source == nil {
		return n, nil, err
	}
	return n, source, err
}

func (c *udpWireRXConn) Close() error {
	err := c.UDPConn.Close()
	// Wait for any successful read to finish recording before export.
	c.readMu.Lock()
	c.readMu.Unlock()
	return err
}
