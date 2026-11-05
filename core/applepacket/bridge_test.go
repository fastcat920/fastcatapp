//go:build with_gvisor

package applepacket

import (
	"context"
	"encoding/binary"
	"github.com/metacubex/gvisor/pkg/tcpip"
	"github.com/metacubex/gvisor/pkg/tcpip/checksum"
	"github.com/metacubex/gvisor/pkg/tcpip/header"
	"github.com/metacubex/mihomo/component/resolver"
	"github.com/metacubex/mihomo/listener/sing_tun"
	"github.com/metacubex/sing/common/buf"
	M "github.com/metacubex/sing/common/metadata"
	N "github.com/metacubex/sing/common/network"
	D "github.com/miekg/dns"
	"io"
	"net"
	"net/netip"
	"testing"
	"time"
)

type echoHandler struct{ *sing_tun.ListenerHandler }

type dnsService struct{}

func (dnsService) ServeMsg(_ context.Context, request *D.Msg) (*D.Msg, error) {
	reply := new(D.Msg).SetReply(request)
	rr, _ := D.NewRR("example.test. 60 IN A 192.0.2.42")
	reply.Answer = []D.RR{rr}
	return reply, nil
}

func TestDNSHijackThroughRealMihomoHandler(t *testing.T) {
	previous := resolver.DefaultService
	resolver.DefaultService = dnsService{}
	defer func() { resolver.DefaultService = previous }()
	b, err := New()
	if err != nil {
		t.Fatal(err)
	}
	defer b.Close()
	query := new(D.Msg).SetQuestion("example.test.", D.TypeA)
	payload, _ := query.Pack()
	p := udpPacket(false, payload)
	h := header.IPv4(p)
	h.SetDestinationAddress(tcpip.AddrFrom4([4]byte{198, 18, 0, 2}))
	h.SetChecksum(0)
	h.SetChecksum(^h.CalculateChecksum())
	u := header.UDP(p[20:])
	u.SetDestinationPort(53)
	u.SetChecksum(0)
	if err = b.Inject(p); err != nil {
		t.Fatal(err)
	}
	done := make(chan []byte, 1)
	go func() { out := make([]byte, 65535); n, _ := b.Receive(out); done <- out[:n] }()
	select {
	case out := <-done:
		if len(out) < 28 {
			t.Fatal("short DNS reply")
		}
		var reply D.Msg
		if err := reply.Unpack(out[28:]); err != nil {
			t.Fatal(err)
		}
		if reply.Id != query.Id || len(reply.Answer) != 1 {
			t.Fatalf("bad DNS reply: %v", reply)
		}
	case <-time.After(3 * time.Second):
		t.Fatal("DNS hijack timed out")
	}
}

func (echoHandler) NewConnection(_ context.Context, conn net.Conn, _ M.Metadata) error {
	defer conn.Close()
	_, err := io.Copy(conn, conn)
	return err
}
func (echoHandler) NewPacket(_ context.Context, _ netip.AddrPort, packet *buf.Buffer, m M.Metadata, init func(N.PacketConn) N.PacketWriter) {
	_ = init(nil).WritePacket(packet, m.Destination)
}

func TestUDPIPv4AndIPv6(t *testing.T) {
	for _, ipv6 := range []bool{false, true} {
		t.Run(map[bool]string{false: "IPv4", true: "IPv6"}[ipv6], func(t *testing.T) {
			b, err := newWithHandler(echoHandler{})
			if err != nil {
				t.Fatal(err)
			}
			defer b.Close()
			packet := udpPacket(ipv6, []byte("fastcat-packet-flow"))
			if err = b.Inject(packet); err != nil {
				t.Fatal(err)
			}
			result := make(chan []byte, 1)
			go func() { out := make([]byte, 65535); n, _ := b.Receive(out); result <- out[:n] }()
			select {
			case out := <-result:
				offset := 20
				if ipv6 {
					offset = 40
				}
				if len(out) < offset+8 || string(out[offset+8:]) != "fastcat-packet-flow" {
					t.Fatalf("bad UDP response: %x", out)
				}
				if binary.BigEndian.Uint16(out[offset:]) != 9000 || binary.BigEndian.Uint16(out[offset+2:]) != 50000 {
					t.Fatal("reply ports reversed incorrectly")
				}
			case <-time.After(time.Second * 3):
				t.Fatal("no UDP reply")
			}
		})
	}
}

func udpPacket(ipv6 bool, payload []byte) []byte {
	headerSize := 20
	if ipv6 {
		headerSize = 40
	}
	p := make([]byte, headerSize+8+len(payload))
	src := tcpip.AddrFrom4([4]byte{198, 18, 0, 1})
	dst := tcpip.AddrFrom4([4]byte{192, 0, 2, 1})
	if ipv6 {
		src = tcpip.AddrFrom16(netip.MustParseAddr("fdfe:dcba:9876::1").As16())
		dst = tcpip.AddrFrom16(netip.MustParseAddr("2001:db8::2").As16())
		header.IPv6(p).Encode(&header.IPv6Fields{PayloadLength: uint16(8 + len(payload)), TransportProtocol: header.UDPProtocolNumber, HopLimit: 64, SrcAddr: src, DstAddr: dst})
	} else {
		h := header.IPv4(p)
		h.Encode(&header.IPv4Fields{TotalLength: uint16(len(p)), TTL: 64, Protocol: uint8(header.UDPProtocolNumber), SrcAddr: src, DstAddr: dst})
		h.SetChecksum(^h.CalculateChecksum())
	}
	u := header.UDP(p[headerSize:])
	u.Encode(&header.UDPFields{SrcPort: 50000, DstPort: 9000, Length: uint16(8 + len(payload))})
	copy(p[headerSize+8:], payload)
	sum := header.PseudoHeaderChecksum(header.UDPProtocolNumber, src, dst, uint16(8+len(payload)))
	u.SetChecksum(^checksum.Checksum(p[headerSize:], sum))
	return p
}

func TestCloseUnblocksReaderAndRejectsOldPackets(t *testing.T) {
	b, err := New()
	if err != nil {
		t.Fatal(err)
	}
	done := make(chan error, 1)
	go func() { _, err := b.Receive(make([]byte, 65535)); done <- err }()
	b.Close()
	b.Close()
	select {
	case err := <-done:
		if err != io.EOF {
			t.Fatal(err)
		}
	case <-time.After(time.Second):
		t.Fatal("reader stuck after stop")
	}
	if b.Inject(udpPacket(false, []byte("old"))) == nil {
		t.Fatal("stopped bridge accepted a packet")
	}
}

func TestInvalidPackets(t *testing.T) {
	b, err := New()
	if err != nil {
		t.Fatal(err)
	}
	defer b.Close()
	for _, p := range [][]byte{nil, {0x45}, {0x60}, make([]byte, 40), make([]byte, 65536)} {
		if b.Inject(p) == nil {
			t.Fatal("invalid packet accepted")
		}
	}
}

func TestTCPIPv4AndIPv6(t *testing.T) {
	for _, v6 := range []bool{false, true} {
		t.Run(map[bool]string{false: "IPv4", true: "IPv6"}[v6], func(t *testing.T) {
			b, err := newWithHandler(echoHandler{})
			if err != nil {
				t.Fatal(err)
			}
			defer b.Close()
			out := make(chan []byte, 32)
			go func() {
				for {
					p := make([]byte, 65535)
					n, err := b.Receive(p)
					if err != nil {
						return
					}
					select {
					case out <- p[:n]:
					case <-b.ctx.Done():
						return
					}
				}
			}()
			receive := func() []byte {
				select {
				case p := <-out:
					return p
				case <-time.After(3 * time.Second):
					t.Fatal("TCP reply timed out")
					return nil
				}
			}
			if err := b.Inject(tcpPacket(v6, 100, 0, header.TCPFlagSyn, nil)); err != nil {
				t.Fatal(err)
			}
			ipSize := 20
			if v6 {
				ipSize = 40
			}
			synAck := receive()
			h := header.TCP(synAck[ipSize:])
			if h.Flags()&(header.TCPFlagSyn|header.TCPFlagAck) != (header.TCPFlagSyn | header.TCPFlagAck) {
				t.Fatalf("not SYN ACK: %x", synAck)
			}
			ack := h.SequenceNumber() + 1
			_ = b.Inject(tcpPacket(v6, 101, ack, header.TCPFlagAck, nil))
			_ = b.Inject(tcpPacket(v6, 101, ack, header.TCPFlagAck|header.TCPFlagPsh, []byte("tcp-echo")))
			for i := 0; i < 8; i++ {
				p := receive()
				tcp := header.TCP(p[ipSize:])
				payload := p[ipSize+int(tcp.DataOffset()):]
				if string(payload) == "tcp-echo" {
					return
				}
			}
			t.Fatal("TCP payload did not round trip")
		})
	}
}

func tcpPacket(v6 bool, seq, ack uint32, flags header.TCPFlags, payload []byte) []byte {
	base := udpPacket(v6, nil)
	size := 20
	if v6 {
		size = 40
	}
	p := make([]byte, size+20+len(payload))
	copy(p, base[:size])
	var src, dst tcpip.Address
	if v6 {
		h := header.IPv6(p)
		src = h.SourceAddress()
		dst = h.DestinationAddress()
		p[6] = 6
		binary.BigEndian.PutUint16(p[4:6], uint16(20+len(payload)))
	} else {
		h := header.IPv4(p)
		src = h.SourceAddress()
		dst = h.DestinationAddress()
		p[9] = 6
		binary.BigEndian.PutUint16(p[2:4], uint16(len(p)))
		h.SetChecksum(0)
		h.SetChecksum(^h.CalculateChecksum())
	}
	h := header.TCP(p[size:])
	h.Encode(&header.TCPFields{SrcPort: 50000, DstPort: 9000, SeqNum: seq, AckNum: ack, DataOffset: 20, Flags: flags, WindowSize: 65535})
	copy(p[size+20:], payload)
	sum := header.PseudoHeaderChecksum(header.TCPProtocolNumber, src, dst, uint16(20+len(payload)))
	h.SetChecksum(^checksum.Checksum(p[size:], sum))
	return p
}
