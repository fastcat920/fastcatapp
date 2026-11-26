#!/usr/bin/env python3
"""Loopback UDP fixture for the FCN comparison tool's sequenced probes."""

import argparse
import json
import re
import socket
import struct
import sys
import time


ADDRESS = ("127.0.0.1", 18477)
HEADER = struct.Struct("!8s16sIQ")
MAGIC = b"FCNUDP01"
MAX_DATAGRAM = 1150
RUN_ID = re.compile(rb"[0-9a-f]{16}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--max-events", type=int, default=200_000,
                        help="maximum JSONL receipts written (default: 200000)")
    parser.add_argument("--run-id", help="only echo datagrams for this 16-character lowercase hex ID")
    args = parser.parse_args()
    if args.max_events < 2:
        parser.error("--max-events must be at least 2")
    expected_id = args.run_id.encode("utf-8") if args.run_id is not None else None
    if expected_id is not None and not RUN_ID.fullmatch(expected_id):
        parser.error("--run-id must be 16 lowercase hex characters")

    events = 0
    warned = False
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.bind(ADDRESS)
        while True:
            # Read an extra byte so truncation cannot make an oversized packet valid.
            packet, peer = sock.recvfrom(MAX_DATAGRAM + 1)
            received = time.time_ns()
            if not HEADER.size <= len(packet) <= MAX_DATAGRAM:
                continue
            magic, run_id, seq, timestamp = HEADER.unpack_from(packet)
            if (magic != MAGIC or not RUN_ID.fullmatch(run_id) or seq == 0 or timestamp == 0
                    or (expected_id is not None and run_id != expected_id)):
                continue

            try:
                responded = sock.sendto(packet, peer) == len(packet)
            except OSError:
                responded = False
            sent = time.time_ns()
            if events + 2 <= args.max_events:
                fields = {"run_id": run_id.decode("ascii"), "seq": seq, "size": len(packet)}
                print(json.dumps(dict(fields, event="receive", timestamp_unix_ns=received)), flush=True)
                events += 1
                if responded:
                    print(json.dumps(dict(fields, event="response", timestamp_unix_ns=sent)), flush=True)
                    events += 1
            elif not warned:
                print("UDP echo reached its receipt limit", file=sys.stderr, flush=True)
                warned = True


if __name__ == "__main__":
    main()
