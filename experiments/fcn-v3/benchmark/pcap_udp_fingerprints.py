#!/usr/bin/env python3
"""Emit one JSONL fingerprint per complete IPv4 UDP packet from a test port.

Use a server-side capture. Linux UDP offloads (GRO/GSO) can coalesce or
segment packets around the capture point, so a capture record is not always
an on-wire datagram. The reader does not reconstruct offloaded records.
"""

import argparse
from collections import Counter
from contextlib import nullcontext
import hashlib
import json
import struct
import sys


SERVER_PORTS = {18532, 18533, 18534}
PCAP_FORMATS = {
    b"\xa1\xb2\xc3\xd4": (">", 1000),
    b"\xd4\xc3\xb2\xa1": ("<", 1000),
    b"\xa1\xb2\x3c\x4d": (">", 1),
    b"\x4d\x3c\xb2\xa1": ("<", 1),
}
LINK_HEADERS = {1: (14, 12), 113: (16, 14), 276: (20, 0)}  # Ethernet, SLL, SLL2
MAX_RECORD_BYTES = 1 << 20
MAX_CAPTURE_BYTES = 64 << 20
MAX_RECORDS = 300_000


class SkippedPacket(Exception):
    """A complete PCAP record without a usable packet."""


def require(data, end):
    if len(data) < end:
        raise SkippedPacket("truncated")


def udp_fingerprint(frame, link, timestamp):
    network, protocol_offset = LINK_HEADERS[link]
    require(frame, network)
    protocol = struct.unpack_from("!H", frame, protocol_offset)[0]
    while protocol in (0x8100, 0x88A8):
        require(frame, network + 4)
        protocol = struct.unpack_from("!H", frame, network + 2)[0]
        network += 4
    if protocol != 0x0800:
        return None

    ip = memoryview(frame)[network:]
    require(ip, 20)
    if ip[0] >> 4 != 4 or ip[9] != 17:
        return None
    udp_offset = (ip[0] & 0x0F) * 4
    total_length, _, fragments = struct.unpack_from("!HHH", ip, 2)
    if fragments & 0x3FFF:
        return None
    if udp_offset < 20 or total_length < udp_offset + 8:
        raise SkippedPacket("malformed")
    require(ip, total_length)
    src_port, _, udp_length = struct.unpack_from("!HHH", ip, udp_offset)
    if src_port not in SERVER_PORTS:
        return None
    if udp_length != total_length - udp_offset:
        raise SkippedPacket("malformed")
    payload = ip[udp_offset + 8:total_length]
    return {
        "timestamp_unix_ns": timestamp,
        "src_port": src_port,
        "payload_bytes": len(payload),
        "sha256_16": hashlib.sha256(payload).hexdigest()[:16],
    }


def fingerprints(stream, counts, max_records):
    header = stream.read(24)
    if len(header) != 24 or header[:4] not in PCAP_FORMATS:
        raise ValueError("expected a classic PCAP header (PCAPNG is unsupported)")
    order, fraction_scale = PCAP_FORMATS[header[:4]]
    major, minor, _, _, snaplen, link_info = struct.unpack_from(order + "HHIIII", header, 4)
    if (major, minor) != (2, 4) or snaplen == 0:
        raise ValueError("expected classic PCAP version 2.4 with a nonzero snapshot length")
    link = link_info & 0xFFFF
    if link not in LINK_HEADERS:
        raise ValueError(f"unsupported PCAP link type {link} (expected Ethernet, SLL, or SLL2)")

    record_header = struct.Struct(order + "IIII")
    remaining = MAX_CAPTURE_BYTES - len(header)
    while record := stream.read(min(record_header.size, remaining + 1)):
        if len(record) > remaining:
            raise ValueError("PCAP exceeds the 64 MiB input limit")
        if counts["records"] >= max_records:
            raise ValueError(f"PCAP exceeds the {max_records}-record limit")
        remaining -= len(record)
        counts["records"] += 1
        if len(record) != record_header.size:
            counts["truncated"] += 1
            raise ValueError("incomplete PCAP record header")
        seconds, fraction, captured, original = record_header.unpack(record)
        if captured > min(snaplen, original, MAX_RECORD_BYTES):
            raise ValueError(f"invalid captured length in PCAP record {counts['records']}")
        if captured > remaining:
            raise ValueError("PCAP exceeds the 64 MiB input limit")
        frame = stream.read(captured)
        remaining -= len(frame)
        if len(frame) != captured:
            counts["truncated"] += 1
            raise ValueError(f"incomplete data in PCAP record {counts['records']}")
        if captured != original:
            counts["truncated"] += 1
            continue
        subseconds_ns = fraction * fraction_scale
        if subseconds_ns >= 1_000_000_000:
            counts["malformed"] += 1
            continue
        try:
            row = udp_fingerprint(frame, link, seconds * 1_000_000_000 + subseconds_ns)
        except SkippedPacket as err:
            counts[err.args[0]] += 1
            continue
        if row is None:
            counts["other"] += 1
            continue
        counts["emitted"] += 1
        yield row


def main():
    parser = argparse.ArgumentParser(
        description=__doc__,
        epilog="Input is limited to 64 MiB. Complete preceding records remain in stdout after an input error.",
    )
    parser.add_argument("capture", help="classic PCAP file, or - to read from standard input")
    parser.add_argument("--max-records", type=int, default=MAX_RECORDS,
                        help="stop with an error after this many records (default: %(default)s)")
    args = parser.parse_args()
    if not 1 <= args.max_records <= MAX_RECORDS:
        parser.error(f"--max-records must be between 1 and {MAX_RECORDS}")

    counts = Counter()
    status = 0
    try:
        with (nullcontext(sys.stdin.buffer) if args.capture == "-" else open(args.capture, "rb")) as stream:
            for row in fingerprints(stream, counts, args.max_records):
                print(json.dumps(row, separators=(",", ":")))
            sys.stdout.flush()
    except (OSError, ValueError) as err:
        message = err.strerror if isinstance(err, OSError) else str(err)
        print(f"PCAP error: {message}", file=sys.stderr)
        status = 1
    print(f"records={counts['records']} emitted={counts['emitted']} "
          f"skipped_truncated={counts['truncated']} skipped_malformed={counts['malformed']} "
          f"skipped_other={counts['other']}", file=sys.stderr)
    return status


if __name__ == "__main__":
    sys.exit(main())
