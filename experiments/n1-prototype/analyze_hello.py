#!/usr/bin/env python3
"""Extract IPv4 TCP ClientHello metadata from classic pcap; not a classifier."""
import argparse
import hashlib
import json
from pathlib import Path
import socket
import struct


def u16(b, pos=0):
    return int.from_bytes(b[pos:pos+2], 'big')


def grease(v):
    return v & 0x0f0f == 0x0a0a and v >> 8 == v & 255


def reassemble(parts):
    if not parts:
        return b''
    parts = sorted(parts)
    start = parts[0][0]; data = bytearray()
    for seq, part in parts:
        relative = seq-start
        if relative > len(data):
            break
        overlap = len(data)-relative
        if overlap < len(part):
            data.extend(part[max(overlap, 0):])
    return bytes(data)


def record_lengths(data):
    p = 0; lengths = []
    while p+5 <= len(data):
        kind = data[p]; n = u16(data, p+3); p += 5
        if p+n > len(data):
            break
        lengths.append({'type': kind, 'length': n}); p += n
    return lengths


def contiguous(parts,data):
    if not parts:
        return True
    span=max(seq+len(b) for seq,b in parts)-min(seq for seq,b in parts)
    return span==len(data)


def hello(body):
    p = 34
    p += 1 + body[p]
    size = u16(body, p); p += 2
    ciphers = [u16(body, i) for i in range(p, p+size, 2)]; p += size
    p += 1 + body[p]
    end = p + 2 + u16(body, p); p += 2
    extensions = []
    fields = {}
    while p+4 <= end:
        kind, size = u16(body, p), u16(body, p+2); p += 4
        value = body[p:p+size]; p += size
        extensions.append(kind)
        if kind in (10, 13):
            fields['groups' if kind == 10 else 'signature_algorithms'] = [
                u16(value, i) for i in range(2, len(value), 2)]
        elif kind == 43:
            fields['versions'] = [u16(value, i) for i in range(1, len(value), 2)]
        elif kind == 16:
            q = 2; names = []
            while q < len(value):
                n = value[q]; q += 1
                names.append(value[q:q+n].decode('ascii', errors='replace')); q += n
            fields['alpn'] = names
        elif kind == 0:
            fields['sni'] = value[5:5+u16(value, 3)].decode('ascii', errors='replace')
        elif kind == 51:
            q = 2; shares = []
            while q+4 <= len(value):
                group, n = u16(value, q), u16(value, q+2); q += 4
                shares.append({'group': group, 'bytes': n}); q += n
            fields['key_shares'] = shares
    result = {'hello_bytes': len(body)+4, 'cipher_suites': ciphers,
              'extension_order': extensions, **fields}
    # Retain extension order for observation, but also compare sets because
    # browser implementations may deliberately randomize extension order.
    canonical = {'ciphers': [v for v in ciphers if not grease(v)],
                 'extensions': sorted(v for v in extensions if not grease(v)),
                 'groups': [v for v in fields.get('groups', []) if not grease(v)],
                 'alpn': fields.get('alpn', [])}
    result['normalized_feature_hash'] = hashlib.sha256(
        json.dumps(canonical, sort_keys=True).encode()).hexdigest()
    return result


def analyze(path,port=18461):
    raw = path.read_bytes()
    endian = '<' if raw[:4] in (b'\xd4\xc3\xb2\xa1', b'\x4d\x3c\xb2\xa1') else '>'
    link = struct.unpack_from(endian+'I', raw, 20)[0]
    offset = {1: 14, 113: 16, 276: 20}.get(link)
    if offset is None:
        raise ValueError(f'unsupported link type {link}')
    pos = 24; flows = {}; packet_count = 0; capture_start = None
    scale=1e9 if raw[:4] in (b'\x4d\x3c\xb2\xa1',b'\xa1\xb2\x3c\x4d') else 1e6
    while pos+16 <= len(raw):
        sec, micro, size, original = struct.unpack_from(endian+'IIII', raw, pos)
        timestamp=sec+micro/scale
        if capture_start is None:capture_start=timestamp
        pos += 16; packet = raw[pos:pos+size]; pos += size
        if len(packet) <= offset or packet[offset] >> 4 != 4:
            continue
        ip = packet[offset:]; ihl = (ip[0] & 15)*4
        if len(ip) < ihl+20 or ip[9] != 6:
            continue
        tcp = ip[ihl:]; src, dst, seq = struct.unpack_from('!HHI', tcp)
        if dst != port and src != port:
            continue
        packet_count += 1
        key = (socket.inet_ntoa(ip[12:16]), src, socket.inet_ntoa(ip[16:20]), dst)
        data = tcp[(tcp[12] >> 4)*4:]
        flow = flows.setdefault(key, {'packets': 0, 'wire_bytes': 0, 'parts': [], 'rst_packets': 0,'syn_seen':False,'first_ts':timestamp})
        flow['packets'] += 1; flow['wire_bytes'] += original
        flow['rst_packets'] += bool(tcp[13] & 4)
        flow['syn_seen'] |= bool(tcp[13] & 2)
        if data:
            flow['parts'].append((seq, data))
    hellos = []
    for key, flow in flows.items():
        if key[3] != port:
            continue
        data = reassemble(flow['parts'])
        reverse = flows.get((key[2], key[3], key[0], key[1]), {})
        server_data = reassemble(reverse.get('parts', []))
        p = 0; handshake = bytearray()
        while p+5 <= len(data):
            typ = data[p]; length = u16(data, p+3); p += 5
            if p+length > len(data):
                break
            record = data[p:p+length]; p += length
            if typ == 22:
                handshake.extend(record)
            if len(handshake) >= 4 and handshake[0] == 1:
                n = int.from_bytes(handshake[1:4], 'big')
                if len(handshake) >= n+4:
                    h = hello(handshake[4:n+4])
                    h['client_packets'] = flow['packets']
                    h['client_syn_seen'] = flow['syn_seen']
                    h['first_packet_offset_ms'] = (flow['first_ts']-capture_start)*1000
                    h['client_wire_bytes'] = flow['wire_bytes']
                    h['server_wire_bytes'] = reverse.get('wire_bytes', 0)
                    h['client_rst_packets'] = flow['rst_packets']
                    h['server_rst_packets'] = reverse.get('rst_packets', 0)
                    h['client_unique_tcp_payload_bytes'] = len(data)
                    h['server_unique_tcp_payload_bytes'] = len(server_data)
                    h['client_tls_records'] = record_lengths(data)
                    h['server_tls_records'] = record_lengths(server_data)
                    h['client_tcp_capture_contiguous'] = contiguous(flow['parts'],data)
                    h['server_tcp_capture_contiguous'] = contiguous(reverse.get('parts',[]),server_data)
                    h['client_tls_unparsed_bytes'] = len(data)-sum(5+r['length'] for r in h['client_tls_records'])
                    h['server_tls_unparsed_bytes'] = len(server_data)-sum(5+r['length'] for r in h['server_tls_records'])
                    hellos.append(h); break
    hellos.sort(key=lambda h:h['first_packet_offset_ms'])
    return {'capture': path.name, 'capture_start_unix':capture_start, 'port': port, 'ipv4_entry_packets': packet_count,
            'client_hellos': hellos,
            'limitations': 'IPv4 TCP only; no encrypted content decryption; no detection-probability estimate'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('pcap', type=Path)
    parser.add_argument('--port', type=int, default=18461)
    args = parser.parse_args()
    print(json.dumps(analyze(args.pcap,args.port), indent=2))
