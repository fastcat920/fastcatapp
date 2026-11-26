#!/usr/bin/env python3
"""Summarize UDP payload lengths in a bounded QUIC endpoint capture.

Classic pcap input is filtered by server UDP port and optionally by server IP.
TSV input/output uses three columns: direction, udp_payload_bytes, datagrams.
The analysis reads the UDP header length field. Packet contents, addresses,
port numbers, timestamps, and connection identifiers are omitted from output.
UDP offload and the capture interface can change observed record boundaries.
UDP sizes include all encrypted transport content, including any padding.
"""

import argparse
from collections import Counter
import csv
import ipaddress
import json
from pathlib import Path
import struct
import sys


DIRECTIONS = ("to-server", "from-server")
TSV_COLUMNS = ("direction", "udp_payload_bytes", "datagrams")
BUCKETS = ((0, 0), (1, 300), (301, 600), (601, 900), (901, 1200), (1201, 65527))
PCAP_ORDERS = {
    b"\xa1\xb2\xc3\xd4": ">",
    b"\xa1\xb2\x3c\x4d": ">",
    b"\xd4\xc3\xb2\xa1": "<",
    b"\x4d\x3c\xb2\xa1": "<",
}
LINK_HEADERS = {1: (14, 12), 113: (16, 14), 276: (20, 0)}
UNENCAPSULATED = {0: 4, 12: 0, 101: 0, 108: 4, 228: 0, 229: 0}


class SkippedFrame(Exception):
    """A frame without a usable UDP length observation."""


def require_header(frame, end):
    if len(frame) < end:
        raise SkippedFrame("missing_header")


def network_offset(frame, link):
    if link in UNENCAPSULATED:
        return UNENCAPSULATED[link]
    offset, protocol_offset = LINK_HEADERS[link]
    require_header(frame, offset)
    protocol = struct.unpack_from("!H", frame, protocol_offset)[0]
    while protocol in (0x8100, 0x88A8):
        require_header(frame, offset + 4)
        protocol = struct.unpack_from("!H", frame, offset + 2)[0]
        offset += 4
    if protocol not in (0x0800, 0x86DD):
        raise SkippedFrame("other_link_protocol")
    return offset


def ipv4_headers(packet):
    require_header(packet, 20)
    offset = (packet[0] & 0x0F) * 4
    end, _, fragment = struct.unpack_from("!HHH", packet, 2)
    if end < offset or offset < 20:
        raise SkippedFrame("invalid_ip_length")
    if fragment & 0x3FFF:
        raise SkippedFrame("fragmented_ip")
    return packet[12:16], packet[16:20], offset, end, packet[9]


def ipv6_headers(packet):
    require_header(packet, 40)
    payload_length, protocol = struct.unpack_from("!HB", packet, 4)
    if payload_length == 0:
        raise SkippedFrame("unsupported_ipv6_zero_length")
    offset, end = 40, 40 + payload_length
    while protocol in (0, 43, 44, 51, 60):
        if offset + 2 > end:
            raise SkippedFrame("invalid_ip_length")
        require_header(packet, offset + 2)
        next_protocol, length = struct.unpack_from("!BB", packet, offset)
        if protocol == 44:
            extension_size = 8
            if offset + extension_size > end:
                raise SkippedFrame("invalid_ip_length")
            require_header(packet, offset + extension_size)
            fragment = struct.unpack_from("!H", packet, offset + 2)[0]
            if fragment & 0xFFF9:
                raise SkippedFrame("fragmented_ip")
        elif protocol == 51:
            extension_size = (length + 2) * 4
        else:
            extension_size = (length + 1) * 8
        offset += extension_size
        if offset > end:
            raise SkippedFrame("invalid_ip_length")
        require_header(packet, offset)
        protocol = next_protocol
    return packet[8:24], packet[24:40], offset, end, protocol


def udp_observation(frame, original, link, port, endpoints):
    ip_offset = network_offset(frame, link)
    packet = memoryview(frame)[ip_offset:]
    require_header(packet, 1)
    version = packet[0] >> 4
    if version == 4:
        source, destination, offset, end, protocol = ipv4_headers(packet)
    elif version == 6:
        source, destination, offset, end, protocol = ipv6_headers(packet)
    else:
        raise SkippedFrame("other_ip_version")

    if protocol != 17:
        raise SkippedFrame("other_ip_protocol")
    if offset + 8 > end or ip_offset + end > original:
        raise SkippedFrame("invalid_ip_length")
    require_header(packet, offset + 8)
    source_port, destination_port, udp_length = struct.unpack_from("!HHH", packet, offset)
    outgoing = source_port == port and (not endpoints or bytes(source) in endpoints)
    incoming = destination_port == port and (not endpoints or bytes(destination) in endpoints)
    if not (outgoing or incoming):
        raise SkippedFrame("other_udp_endpoint")
    if outgoing and incoming:
        raise SkippedFrame("ambiguous_direction")
    if udp_length < 8 or udp_length != end - offset:
        raise SkippedFrame("udp_ip_length_mismatch")
    return "from-server" if outgoing else "to-server", udp_length - 8


def read_pcap(stream, port, endpoints):
    header = stream.read(24)
    order = PCAP_ORDERS.get(header[:4])
    if len(header) != 24 or order is None:
        raise ValueError("expected a classic pcap header")
    major, minor, _, _, snaplen, link_info = struct.unpack_from(order + "HHIIII", header, 4)
    if (major, minor) != (2, 4) or snaplen == 0:
        raise ValueError("expected a classic pcap 2.4 header with a nonzero snapshot length")
    link = link_info & 0xFFFF
    if link not in LINK_HEADERS and link not in UNENCAPSULATED:
        raise ValueError(f"unsupported pcap link type {link}")

    histograms = {direction: Counter() for direction in DIRECTIONS}
    records = truncated = truncated_counted = 0
    skipped = Counter()
    record_format = struct.Struct(order + "IIII")
    while record := stream.read(record_format.size):
        if len(record) != record_format.size:
            raise ValueError("incomplete pcap record header")
        _, _, captured, original = record_format.unpack(record)
        if captured > min(snaplen, original, 16 << 20):
            raise ValueError("invalid pcap record size")
        frame = stream.read(captured)
        if len(frame) != captured:
            raise ValueError("incomplete pcap record data")
        records += 1
        truncated += captured < original
        try:
            direction, length = udp_observation(frame, original, link, port, endpoints)
        except SkippedFrame as exc:
            skipped[str(exc)] += 1
            continue
        histograms[direction][length] += 1
        truncated_counted += captured < original

    return histograms, {
        "link_type": link,
        "records": records,
        "truncated_records": truncated,
        "truncated_records_with_counted_udp_length": truncated_counted,
        "skipped_records": dict(skipped),
    }


def read_tsv(stream):
    histograms = {direction: Counter() for direction in DIRECTIONS}
    rows = csv.reader(stream, delimiter="\t", quoting=csv.QUOTE_NONE)
    if tuple(next(rows, ())) != TSV_COLUMNS:
        raise ValueError("expected TSV columns: " + ", ".join(TSV_COLUMNS))
    for line_number, row in enumerate(rows, start=2):
        try:
            direction, raw_length, raw_count = row
            length, count = int(raw_length), int(raw_count)
            if direction not in histograms or not 0 <= length <= 65527 or count < 1:
                raise ValueError
        except ValueError as exc:
            raise ValueError(f"invalid histogram TSV row {line_number}") from exc
        histograms[direction][length] += count
    return histograms


def summarize(histogram):
    datagrams = sum(histogram.values())
    ordered = sorted(histogram.items())
    payload_bytes = sum(length * count for length, count in ordered)
    p50 = p95 = None
    accumulated = 0
    bucket_counts = [0] * len(BUCKETS)
    bucket_bytes = [0] * len(BUCKETS)
    for length, count in ordered:
        accumulated += count
        if p50 is None and 100 * accumulated >= 50 * datagrams:
            p50 = length
        if p95 is None and 100 * accumulated >= 95 * datagrams:
            p95 = length
        bucket = next(i for i, (low, high) in enumerate(BUCKETS) if low <= length <= high)
        bucket_counts[bucket] += count
        bucket_bytes[bucket] += length * count
    return {
        "datagrams": datagrams,
        "udp_payload_bytes": payload_bytes,
        "udp_datagram_bytes_including_headers": payload_bytes + 8 * datagrams,
        "p50_udp_payload_bytes": p50,
        "p95_udp_payload_bytes": p95,
        "buckets": {
            f"{low}-{high}": {
                "datagrams": count,
                "fraction_datagrams": count / datagrams if datagrams else None,
                "udp_payload_bytes": size,
            }
            for (low, high), count, size in zip(BUCKETS, bucket_counts, bucket_bytes)
        },
        "histogram": dict(ordered),
    }


def write_tsv(stream, histograms):
    rows = csv.writer(stream, delimiter="\t", lineterminator="\n")
    rows.writerow(TSV_COLUMNS)
    for direction, histogram in histograms.items():
        rows.writerows((direction, length, count) for length, count in sorted(histogram.items()))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--pcap", type=Path, help="classic pcap file")
    source.add_argument("--tsv", type=Path, help="sanitized directional histogram file")
    parser.add_argument("--port", type=int, help="server UDP port required for pcap")
    parser.add_argument("--endpoint", type=ipaddress.ip_address, action="append", default=[],
                        help="server IP as observed in pcap; repeat for multiple addresses")
    parser.add_argument("--direction", choices=("both", *DIRECTIONS), default="both")
    parser.add_argument("--format", choices=("json", "tsv"), default="json")
    args = parser.parse_args()

    if args.pcap is not None and (args.port is None or not 1 <= args.port <= 65535):
        parser.error("--pcap requires --port in 1..65535")
    if args.tsv is not None and (args.port is not None or args.endpoint):
        parser.error("--port and --endpoint apply to --pcap")
    capture = None
    try:
        if args.pcap is not None:
            endpoints = {address.packed for address in args.endpoint}
            with args.pcap.open("rb") as stream:
                histograms, capture = read_pcap(stream, args.port, endpoints)
        else:
            with args.tsv.open(encoding="utf-8", newline="") as stream:
                histograms = read_tsv(stream)
    except (OSError, ValueError) as exc:
        parser.exit(1, f"{exc}\n")

    if args.direction != "both":
        histograms = {args.direction: histograms[args.direction]}
    if args.format == "tsv":
        write_tsv(sys.stdout, histograms)
        return

    total = sum(histograms.values(), Counter())
    output = {
        "source": "pcap" if capture is not None else "histogram_tsv",
        "quantile_method": "nearest rank",
        "measurement": "UDP header lengths at the capture point. Offload can affect record boundaries. Lengths include encrypted content and any padding.",
        "capture": capture,
        "total": summarize(total),
        "directions": {direction: summarize(histogram) for direction, histogram in histograms.items()},
    }
    print(json.dumps(output, indent=2))


if __name__ == "__main__":
    main()
