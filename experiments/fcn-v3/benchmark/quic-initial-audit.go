//go:build ignore

// quic-initial-audit reads a classic tcpdump pcap from the FCN v3 lab.
// It reports counts only, uses the public QUIC v1 client Initial keys, and
// classifies the first ClientHello of each observed Initial key epoch.
// An ECH extension on the wire can also be GREASE. Server acceptance must
// be verified separately by the endpoints.
// Plaintext DNS counts cover UDP messages and TCP messages contained in
// individual segments. Incomplete TCP DNS payloads are counted separately.
package main

import (
	"bytes"
	"crypto/aes"
	"crypto/cipher"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"log"
	"net/netip"
	"os"
	"strings"
)

const maxInitialCrypto = 1 << 20

type counts struct {
	CapturePackets             int `json:"capture_packets"`
	TruncatedCapturePackets    int `json:"truncated_capture_packets"`
	QUICInitialPackets         int `json:"quic_initial_packets"`
	QUICInitialDecrypted       int `json:"quic_initial_decrypted"`
	QUICInitialDecryptFailures int `json:"quic_initial_decryption_failures"`
	QUICInitialFrameErrors     int `json:"quic_initial_frame_errors"`
	QUICAttempts               int `json:"quic_attempts"`
	ClientHellos               int `json:"client_hellos"`
	IncompleteClientHellos     int `json:"incomplete_client_hellos"`
	InvalidClientHellos        int `json:"invalid_client_hellos"`
	WithECH                    int `json:"client_hellos_with_ech"`
	WithOuterSNIAndECH         int `json:"client_hellos_with_outer_sni_and_ech"`
	WithInnerSNI               int `json:"client_hellos_with_inner_sni"`
	WithOuterSNI               int `json:"client_hellos_with_outer_sni"`
	WithOtherSNI               int `json:"client_hellos_with_other_sni"`
	WithoutSNI                 int `json:"client_hellos_without_sni"`
	PlainDNSQueries            int `json:"plaintext_dns_queries"`
	PlainDNSInnerQueries       int `json:"plaintext_dns_inner_queries"`
	PlainDNSOuterQueries       int `json:"plaintext_dns_outer_queries"`
	UnparsedPlainDNSPackets    int `json:"plaintext_dns_unparsed_packets"`
	DoHTCPConnectAttempts      int `json:"doh_tcp_connect_attempts"`
}

type options struct {
	quicPort, dnsPort, dohPort uint
	inner, outer               string
}

type path struct {
	src, dst netip.AddrPort
}

type connectionID struct {
	path
	id string
}

type audit struct {
	options
	counts
	byDCID map[connectionID]*initial
	bySCID map[connectionID][]*initial
	epochs []*initial
}

func main() {
	log.SetFlags(0)
	pcap := flag.String("pcap", "", "classic pcap input from tcpdump -s 0")
	var opts options
	flag.UintVar(&opts.quicPort, "quic-port", 0, "destination UDP port of the QUIC lab endpoint")
	flag.UintVar(&opts.dnsPort, "dns-port", 53, "destination UDP or TCP port for plaintext DNS")
	flag.UintVar(&opts.dohPort, "doh-port", 0, "destination TCP port to count DoH connection attempts (optional)")
	flag.StringVar(&opts.inner, "inner", "", "expected inner SNI or DNS qname")
	flag.StringVar(&opts.outer, "outer", "", "expected outer SNI or DNS qname")
	flag.Parse()
	opts.inner, opts.outer = name(opts.inner), name(opts.outer)
	if *pcap == "" || opts.quicPort == 0 || opts.quicPort > 65535 ||
		opts.dnsPort == 0 || opts.dnsPort > 65535 || opts.dohPort > 65535 ||
		opts.inner == "" || opts.outer == "" || opts.inner == opts.outer || flag.NArg() != 0 {
		flag.Usage()
		os.Exit(2)
	}
	file, err := os.Open(*pcap)
	if err != nil {
		log.Fatal(err)
	}
	defer file.Close()
	result, err := auditCapture(file, opts)
	if err != nil {
		log.Fatal(err)
	}
	if err := json.NewEncoder(os.Stdout).Encode(result); err != nil {
		log.Fatal(err)
	}
}

func name(value string) string {
	return strings.ToLower(strings.TrimSuffix(value, "."))
}

func auditCapture(r io.Reader, opts options) (counts, error) {
	a := audit{
		options: opts,
		byDCID:  make(map[connectionID]*initial),
		bySCID:  make(map[connectionID][]*initial),
	}
	var header [24]byte
	if _, err := io.ReadFull(r, header[:]); err != nil {
		return counts{}, fmt.Errorf("read pcap header: %w", err)
	}
	var order binary.ByteOrder
	switch binary.BigEndian.Uint32(header[:4]) {
	case 0xa1b2c3d4, 0xa1b23c4d:
		order = binary.BigEndian
	case 0xd4c3b2a1, 0x4d3cb2a1:
		order = binary.LittleEndian
	default:
		return counts{}, errors.New("expected classic pcap")
	}
	if order.Uint16(header[4:6]) != 2 || order.Uint16(header[6:8]) != 4 {
		return counts{}, errors.New("expected pcap version 2.4")
	}
	link := uint16(order.Uint32(header[20:24]))
	switch link {
	case 0, 1, 12, 101, 108, 113, 228, 229, 276:
	default:
		return counts{}, fmt.Errorf("unsupported pcap link type %d", link)
	}
	var record [16]byte
	var packet []byte
	for {
		_, err := io.ReadFull(r, record[:])
		if err == io.EOF {
			break
		}
		if err != nil {
			return counts{}, fmt.Errorf("read pcap record: %w", err)
		}
		captured, original := order.Uint32(record[8:12]), order.Uint32(record[12:16])
		if captured > 16<<20 || captured > original {
			return counts{}, errors.New("invalid pcap record size")
		}
		if cap(packet) < int(captured) {
			packet = make([]byte, captured)
		}
		packet = packet[:captured]
		if _, err := io.ReadFull(r, packet); err != nil {
			return counts{}, fmt.Errorf("read pcap packet: %w", err)
		}
		a.CapturePackets++
		if captured < original {
			a.TruncatedCapturePackets++
		}
		a.observeIP(networkPacket(packet, link))
	}
	for _, epoch := range a.epochs {
		a.classify(epoch)
	}
	a.QUICAttempts = len(a.epochs)
	return a.counts, nil
}

func networkPacket(packet []byte, link uint16) []byte {
	var offset, protocolOffset int
	switch link {
	case 12, 101, 228, 229: // Raw IP.
		return packet
	case 0, 108: // Loopback family word precedes IP.
		if len(packet) >= 4 {
			return packet[4:]
		}
		return nil
	case 1: // Ethernet.
		offset, protocolOffset = 14, 12
	case 113: // Linux cooked v1.
		offset, protocolOffset = 16, 14
	case 276: // Linux cooked v2.
		offset, protocolOffset = 20, 0
	}
	if len(packet) < offset {
		return nil
	}
	protocol := binary.BigEndian.Uint16(packet[protocolOffset:])
	for protocol == 0x8100 || protocol == 0x88a8 {
		if len(packet) < offset+4 {
			return nil
		}
		protocol = binary.BigEndian.Uint16(packet[offset+2:])
		offset += 4
	}
	if protocol == 0x0800 || protocol == 0x86dd {
		return packet[offset:]
	}
	return nil
}

func ipPayload(packet []byte) (src, dst netip.Addr, proto byte, payload []byte) {
	if len(packet) == 0 {
		return
	}
	switch packet[0] >> 4 {
	case 4:
		if len(packet) < 20 {
			return
		}
		offset := int(packet[0]&0x0f) * 4
		size := int(binary.BigEndian.Uint16(packet[2:4]))
		if offset < 20 || size < offset || size > len(packet) ||
			binary.BigEndian.Uint16(packet[6:8])&0x3fff != 0 {
			return
		}
		return netip.AddrFrom4([4]byte(packet[12:16])), netip.AddrFrom4([4]byte(packet[16:20])),
			packet[9], packet[offset:size]
	case 6:
		if len(packet) < 40 || len(packet) < 40+int(binary.BigEndian.Uint16(packet[4:6])) {
			return
		}
		next := packet[6]
		data := packet[40 : 40+int(binary.BigEndian.Uint16(packet[4:6]))]
		for next == 0 || next == 43 || next == 44 || next == 51 || next == 60 {
			if len(data) < 8 {
				return
			}
			length := (int(data[1]) + 1) * 8
			switch next {
			case 44:
				if binary.BigEndian.Uint16(data[2:4])&0xfff9 != 0 {
					return
				}
				length = 8
			case 51:
				length = (int(data[1]) + 2) * 4
			}
			if len(data) < length {
				return
			}
			next, data = data[0], data[length:]
		}
		return netip.AddrFrom16([16]byte(packet[8:24])), netip.AddrFrom16([16]byte(packet[24:40])), next, data
	}
	return
}

func (a *audit) observeIP(packet []byte) {
	src, dst, proto, data := ipPayload(packet)
	if len(data) < 8 {
		return
	}
	srcPort, dstPort := binary.BigEndian.Uint16(data), binary.BigEndian.Uint16(data[2:])
	switch proto {
	case 17:
		size := int(binary.BigEndian.Uint16(data[4:]))
		if size < 8 || size > len(data) {
			return
		}
		if uint(dstPort) == a.quicPort {
			a.observeQUIC(path{netip.AddrPortFrom(src, srcPort), netip.AddrPortFrom(dst, dstPort)}, data[8:size])
		}
		if uint(dstPort) == a.dnsPort {
			a.observeDNS(data[8:size])
		}
	case 6:
		if len(data) < 20 {
			return
		}
		headerLength := int(data[12]>>4) * 4
		if headerLength < 20 || headerLength > len(data) {
			return
		}
		if uint(dstPort) == a.dohPort && data[13]&0x12 == 0x02 {
			a.DoHTCPConnectAttempts++
		}
		if uint(dstPort) == a.dnsPort {
			for data = data[headerLength:]; len(data) > 0; {
				if len(data) < 2 || int(binary.BigEndian.Uint16(data)) > len(data)-2 {
					a.UnparsedPlainDNSPackets++
					break
				}
				length := int(binary.BigEndian.Uint16(data))
				if !a.observeDNS(data[2 : 2+length]) {
					break
				}
				data = data[2+length:]
			}
		}
	}
}

type cursor struct {
	data []byte
	bad  bool
}

func (c *cursor) take(n uint64) []byte {
	if n > uint64(len(c.data)) {
		c.bad = true
		return nil
	}
	out := c.data[:n]
	c.data = c.data[n:]
	return out
}

func (c *cursor) u8() uint64 {
	if v := c.take(1); v != nil {
		return uint64(v[0])
	}
	return 0
}

func (c *cursor) u16() uint64 {
	if v := c.take(2); v != nil {
		return uint64(binary.BigEndian.Uint16(v))
	}
	return 0
}

func (c *cursor) varint() uint64 {
	if len(c.data) == 0 {
		c.bad = true
		return 0
	}
	width := uint64(1) << (c.data[0] >> 6)
	v := c.take(width)
	if v == nil {
		return 0
	}
	number := uint64(v[0] & 0x3f)
	for _, octet := range v[1:] {
		number = number<<8 | uint64(octet)
	}
	return number
}

type initial struct {
	hp       cipher.Block
	aead     cipher.AEAD
	iv       [12]byte
	nextPN   uint64
	crypto   []byte
	received []bool
	prefix   int
	invalid  bool
}

var initialSalt, _ = hex.DecodeString("38762cf7f55934b34d179ae6a4c80cadccbb7f0a")

func hmacSHA256(key, data []byte) []byte {
	mac := hmac.New(sha256.New, key)
	mac.Write(data)
	return mac.Sum(nil)
}

// Each Initial key uses at most the first block produced by HKDF-Expand-Label.
func expandLabel(secret []byte, label string, length byte) []byte {
	fullLabel := "tls13 " + label
	info := append([]byte{0, length, byte(len(fullLabel))}, fullLabel...)
	info = append(info, 0, 1) // Empty context, then HKDF block counter.
	return hmacSHA256(secret, info)[:length]
}

func newInitial(dcid string) *initial {
	secret := expandLabel(hmacSHA256(initialSalt, []byte(dcid)), "client in", 32)
	hp, _ := aes.NewCipher(expandLabel(secret, "quic hp", 16))
	key, _ := aes.NewCipher(expandLabel(secret, "quic key", 16))
	aead, _ := cipher.NewGCM(key)
	return &initial{hp: hp, aead: aead, iv: [12]byte(expandLabel(secret, "quic iv", 12))}
}

func (i *initial) open(packet []byte, pnOffset int) ([]byte, bool) {
	if len(packet)-pnOffset < 4+aes.BlockSize {
		return nil, false
	}
	var mask [aes.BlockSize]byte
	i.hp.Encrypt(mask[:], packet[pnOffset+4:pnOffset+4+aes.BlockSize])
	first := packet[0] ^ (mask[0] & 0x0f)
	if first&0x0c != 0 {
		return nil, false
	}
	width := int(first&3) + 1
	header := bytes.Clone(packet[:pnOffset+width])
	header[0] = first
	var truncated uint64
	for n := 0; n < width; n++ {
		header[pnOffset+n] ^= mask[n+1]
		truncated = truncated<<8 | uint64(header[pnOffset+n])
	}
	window := uint64(1) << (8 * width)
	pn := (i.nextPN &^ (window - 1)) | truncated
	switch {
	case pn+window/2 <= i.nextPN && pn < (1<<62)-window:
		pn += window
	case pn > i.nextPN+window/2 && pn >= window:
		pn -= window
	}
	nonce := i.iv
	binary.BigEndian.PutUint64(nonce[4:], binary.BigEndian.Uint64(nonce[4:])^pn)
	plain, err := i.aead.Open(nil, nonce[:], packet[len(header):], header)
	if err != nil {
		return nil, false
	}
	i.nextPN = max(i.nextPN, pn+1)
	return plain, true
}

func (a *audit) observeQUIC(route path, data []byte) {
	for len(data) >= 7 && data[0]&0xc0 == 0xc0 && binary.BigEndian.Uint32(data[1:5]) == 1 {
		kind := (data[0] >> 4) & 3
		if kind == 3 { // Retry has no length field and is never coalesced.
			return
		}
		c := cursor{data: data[5:]}
		dcid := string(c.take(c.u8()))
		scid := string(c.take(c.u8()))
		if kind == 0 {
			a.QUICInitialPackets++
			c.take(c.varint()) // Retry token.
		}
		length := c.varint()
		pnOffset := len(data) - len(c.data)
		c.take(length)
		if c.bad || len(dcid) > 20 || len(scid) > 20 {
			if kind == 0 {
				a.QUICInitialDecryptFailures++
			}
			return
		}
		if kind == 0 {
			a.openInitial(connectionID{route, dcid}, connectionID{route, scid}, data[:pnOffset+int(length)], pnOffset)
		}
		data = c.data
	}
}

func (a *audit) openInitial(dcid, scid connectionID, packet []byte, pnOffset int) {
	epoch := a.byDCID[dcid]
	if epoch != nil {
		a.recordInitial(epoch, packet, pnOffset)
		return
	}
	epoch = newInitial(dcid.id)
	// Following Retry, the destination CID changes and client Initial keys
	// change with it. Packet numbers continue across Retry.
	previous := a.bySCID[scid]
	if len(previous) > 0 {
		epoch.nextPN = previous[len(previous)-1].nextPN
	}
	if data, ok := epoch.open(packet, pnOffset); ok {
		a.byDCID[dcid] = epoch
		a.bySCID[scid] = append(previous, epoch)
		a.epochs = append(a.epochs, epoch)
		a.recordFrames(epoch, data)
		return
	}
	// A server-issued destination CID outside Retry keeps the existing
	// Initial keys. The authenticated packet identifies the matching epoch.
	for _, prior := range previous {
		if data, ok := prior.open(packet, pnOffset); ok {
			a.byDCID[dcid] = prior
			a.recordFrames(prior, data)
			return
		}
	}
	a.QUICInitialDecryptFailures++
}

func (a *audit) recordInitial(epoch *initial, packet []byte, pnOffset int) {
	if data, ok := epoch.open(packet, pnOffset); ok {
		a.recordFrames(epoch, data)
		return
	}
	a.QUICInitialDecryptFailures++
}

func (a *audit) recordFrames(epoch *initial, data []byte) {
	a.QUICInitialDecrypted++
	c := cursor{data: data}
	for len(c.data) > 0 && !c.bad {
		kind := c.varint()
		switch kind {
		case 0, 1: // PADDING, PING.
		case 2, 3: // ACK, ACK with ECN counts.
			c.varint() // Largest acknowledged.
			c.varint() // ACK delay.
			ranges := c.varint()
			c.varint() // First ACK range.
			if ranges > uint64(len(c.data))/2 {
				c.bad = true
				break
			}
			for range ranges {
				c.varint()
				c.varint()
			}
			if kind == 3 {
				c.varint()
				c.varint()
				c.varint()
			}
		case 6: // CRYPTO.
			offset := c.varint()
			part := c.take(c.varint())
			if !c.bad {
				epoch.addCrypto(offset, part)
			}
		case 0x1c: // Transport CONNECTION_CLOSE.
			c.varint()
			c.varint()
			c.take(c.varint())
		default:
			c.bad = true
		}
	}
	if c.bad {
		a.QUICInitialFrameErrors++
	}
}

func (i *initial) addCrypto(offset uint64, part []byte) {
	if len(part) == 0 {
		return
	}
	if offset > maxInitialCrypto || uint64(len(part)) > maxInitialCrypto-offset {
		i.invalid = true
		return
	}
	end := int(offset) + len(part)
	if end > len(i.crypto) {
		i.crypto = append(i.crypto, make([]byte, end-len(i.crypto))...)
		i.received = append(i.received, make([]bool, end-len(i.received))...)
	}
	for n, value := range part {
		pos := int(offset) + n
		if i.received[pos] && i.crypto[pos] != value {
			i.invalid = true
		}
		i.received[pos], i.crypto[pos] = true, value
	}
	for i.prefix < len(i.received) && i.received[i.prefix] {
		i.prefix++
	}
}

func (a *audit) classify(i *initial) {
	if i.invalid {
		a.InvalidClientHellos++
		return
	}
	hello := i.crypto[:i.prefix]
	if len(hello) < 4 {
		a.IncompleteClientHellos++
		return
	}
	length := int(hello[1])<<16 | int(hello[2])<<8 | int(hello[3])
	if hello[0] != 1 || length > maxInitialCrypto-4 {
		a.InvalidClientHellos++
		return
	}
	if len(hello) < length+4 {
		a.IncompleteClientHellos++
		return
	}
	sni, ech, ok := clientHello(hello[4 : length+4])
	if !ok {
		a.InvalidClientHellos++
		return
	}
	a.ClientHellos++
	if ech {
		a.WithECH++
	}
	switch sni {
	case a.inner:
		a.WithInnerSNI++
	case a.outer:
		a.WithOuterSNI++
		if ech {
			a.WithOuterSNIAndECH++
		}
	case "":
		a.WithoutSNI++
	default:
		a.WithOtherSNI++
	}
}

func clientHello(body []byte) (sni string, ech, ok bool) {
	c := cursor{data: body}
	c.take(34) // Legacy version and random.
	c.take(c.u8())
	c.take(c.u16()) // Cipher suites.
	c.take(c.u8())  // Compression methods.
	extensions := cursor{data: c.take(c.u16())}
	if c.bad || len(c.data) != 0 {
		return "", false, false
	}
	for !extensions.bad && len(extensions.data) != 0 {
		kind := extensions.u16()
		value := extensions.take(extensions.u16())
		switch kind {
		case 0: // server_name.
			list := cursor{data: value}
			names := cursor{data: list.take(list.u16())}
			if list.bad || len(list.data) != 0 {
				return "", false, false
			}
			for !names.bad && len(names.data) != 0 {
				nameType := names.u8()
				hostname := names.take(names.u16())
				if nameType == 0 {
					if sni != "" || len(hostname) == 0 {
						return "", false, false
					}
					sni = name(string(hostname))
				}
			}
			if names.bad {
				return "", false, false
			}
		case 0xfe0d: // encrypted_client_hello.
			ech = true
		}
	}
	return sni, ech, !extensions.bad
}

func (a *audit) observeDNS(message []byte) bool {
	inner, outer, query, valid := dnsQuestions(message, a.inner, a.outer)
	if !valid {
		a.UnparsedPlainDNSPackets++
		return false
	}
	if query {
		a.PlainDNSQueries++
		if inner {
			a.PlainDNSInnerQueries++
		}
		if outer {
			a.PlainDNSOuterQueries++
		}
	}
	return true
}

func dnsQuestions(message []byte, expectedInner, expectedOuter string) (inner, outer, query, valid bool) {
	if len(message) < 12 {
		return
	}
	if message[2]&0x80 != 0 { // Response.
		return false, false, false, true
	}
	count := int(binary.BigEndian.Uint16(message[4:6]))
	if count == 0 {
		return
	}
	offset := 12
	for range count {
		qname, next, ok := dnsName(message, offset)
		if !ok || len(message) < next+4 {
			return
		}
		inner = inner || qname == expectedInner
		outer = outer || qname == expectedOuter
		offset = next + 4 // QTYPE and QCLASS.
	}
	return inner, outer, true, true
}

func dnsName(message []byte, offset int) (string, int, bool) {
	var labels []string
	next := -1
	size := 1 // Root label.
	for offset < len(message) {
		length := int(message[offset])
		switch {
		case length == 0:
			if next < 0 {
				next = offset + 1
			}
			return name(strings.Join(labels, ".")), next, true
		case length&0xc0 == 0xc0:
			if len(message) < offset+2 {
				return "", 0, false
			}
			target := int(binary.BigEndian.Uint16(message[offset:]) & 0x3fff)
			if target >= offset {
				return "", 0, false
			}
			if next < 0 {
				next = offset + 2
			}
			offset = target
		case length <= 63 && len(message) >= offset+1+length:
			size += 1 + length
			if size > 255 {
				return "", 0, false
			}
			label := string(message[offset+1 : offset+1+length])
			if strings.Contains(label, ".") {
				return "", 0, false
			}
			labels = append(labels, label)
			offset += 1 + length
		default:
			return "", 0, false
		}
	}
	return "", 0, false
}
