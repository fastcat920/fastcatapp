package h3client

import (
	"context"
	"errors"
	"io"
	"net"
	"os"
	"sync"
	"time"

	"github.com/metacubex/mihomo/common/net/deadline"
	quic "github.com/metacubex/quic-go"
	"github.com/metacubex/quic-go/http3"
	"github.com/metacubex/quic-go/quicvarint"
)

// Prefix is the fixed URI template /.well-known/masque/udp/{target_host}/{target_port}/.
const Prefix = "/.well-known/masque/udp/"
const maxUDP = 65527

type DatagramStream interface {
	io.Reader
	io.Closer
	CancelRead(quic.StreamErrorCode)
	CancelWrite(quic.StreamErrorCode)
	SendDatagram([]byte) error
	ReceiveDatagram(context.Context) ([]byte, error)
}

type datagramConn struct {
	str           DatagramStream
	local, remote net.Addr
	ctx           context.Context
	cancel        context.CancelFunc
	input         chan []byte
	read, write   deadline.PipeDeadline
	once          sync.Once
}

// NewDatagramConn wraps a negotiated CONNECT-UDP stream on either peer.
// The HTTP/3 library associates QUIC DATAGRAMs with their request stream.
// RFC 9298 context ID zero carries the target UDP payload.
func NewDatagramConn(str DatagramStream, local, remote net.Addr) net.Conn {
	ctx, cancel := context.WithCancel(context.Background())
	c := &datagramConn{str: str, local: local, remote: remote, ctx: ctx, cancel: cancel, input: make(chan []byte, 16), read: deadline.MakePipeDeadline(), write: deadline.MakePipeDeadline()}
	go c.readDatagrams()
	go c.readCapsules()
	return c
}

func (c *datagramConn) deliver(id uint64, p []byte) bool {
	if id != 0 {
		return true
	}
	if len(p) > maxUDP {
		return false
	}
	select {
	case c.input <- p:
	default:
	} // UDP permits drops under backpressure.
	return true
}
func (c *datagramConn) readDatagrams() {
	defer c.Close()
	for {
		msg, err := c.str.ReceiveDatagram(c.ctx)
		if err != nil {
			return
		}
		id, n, err := quicvarint.Parse(msg)
		if err != nil || !c.deliver(id, msg[n:]) {
			return
		}
	}
}
func (c *datagramConn) readCapsules() {
	defer c.Close()
	reader := http3.NewCapsuleParser(c.str)
	for {
		typ, body, err := reader.Next()
		if err != nil {
			return
		}
		if typ != 0 {
			if body.Discard() != nil {
				return
			}
			continue
		}
		id, err := quicvarint.Read(body)
		if err != nil {
			return
		}
		if id != 0 {
			if body.Discard() != nil {
				return
			}
			continue
		}
		if body.Remaining() > maxUDP {
			return
		}
		p, err := io.ReadAll(body)
		if err != nil || !c.deliver(id, p) {
			return
		}
	}
}
func (c *datagramConn) Read(p []byte) (int, error) {
	select {
	case <-c.ctx.Done():
		return 0, net.ErrClosed
	case <-c.read.Wait():
		return 0, os.ErrDeadlineExceeded
	case b := <-c.input:
		return copy(p, b), nil
	}
}
func (c *datagramConn) Write(p []byte) (int, error) {
	if len(p) > maxUDP {
		return 0, errors.New("UDP payload too large")
	}
	select {
	case <-c.ctx.Done():
		return 0, net.ErrClosed
	case <-c.write.Wait():
		return 0, os.ErrDeadlineExceeded
	default:
	}
	msg := make([]byte, 1+len(p))
	copy(msg[1:], p)
	if err := c.str.SendDatagram(msg); err != nil {
		return 0, err
	}
	return len(p), nil
}
func (c *datagramConn) Close() error {
	c.once.Do(func() {
		c.cancel()
		c.str.CancelRead(quic.StreamErrorCode(http3.ErrCodeRequestCanceled))
		c.str.Close()
		c.read.Set(time.Time{})
		c.write.Set(time.Time{})
	})
	return nil
}
func (c *datagramConn) LocalAddr() net.Addr                { return c.local }
func (c *datagramConn) RemoteAddr() net.Addr               { return c.remote }
func (c *datagramConn) SetDeadline(t time.Time) error      { c.read.Set(t); c.write.Set(t); return nil }
func (c *datagramConn) SetReadDeadline(t time.Time) error  { c.read.Set(t); return nil }
func (c *datagramConn) SetWriteDeadline(t time.Time) error { c.write.Set(t); return nil }
