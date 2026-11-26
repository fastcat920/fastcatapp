"""Synthetic fixture tests for the offline UDP length analysis."""

import importlib.util
from io import BytesIO, StringIO
import ipaddress
import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest


TOOL = Path(__file__).with_name("analyze-udp-lengths.py")
SPEC = importlib.util.spec_from_file_location("udp_lengths", TOOL)
analyzer = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(analyzer)

SERVER_V4 = "192.0.2.1"
SERVER_V6 = "2001:db8::1"
PORT = 4443
PAYLOAD_MARKER = b"synthetic-private-marker"


def address(value):
    return ipaddress.ip_address(value).packed


def udp(source, destination, size):
    body = (PAYLOAD_MARKER * (size // len(PAYLOAD_MARKER) + 1))[:size]
    return struct.pack("!HHHH", source, destination, size + 8, 0) + body


def ipv4_datagram(length, destination=SERVER_V4, destination_port=PORT):
    datagram = udp(54321, destination_port, length)
    header = struct.pack("!BBHHHBBH4s4s", 0x46, 0, 24 + len(datagram), 0, 0, 64, 17, 0,
                         address("198.51.100.5"), address(destination))
    return header + bytes(4) + datagram


def ipv6_datagram(length, fragment=False):
    datagram = udp(PORT, 54321, length)
    protocol = 44 if fragment else 60
    extension = struct.pack("!BBH4x", 17, 0, int(fragment))
    header = struct.pack("!IHBB16s16s", 6 << 28, len(extension) + len(datagram), protocol, 64,
                         address(SERVER_V6), address("2001:db8::2"))
    return header + extension + datagram


def cooked(ip):
    protocol = 0x0800 if ip[0] >> 4 == 4 else 0x86DD
    return struct.pack("!H18x", protocol) + ip


def pcap(records, order):
    result = bytearray(struct.pack(order + "IHHIIII", 0xA1B23C4D, 2, 4, 0, 0, 65535, 276))
    for frame, captured in records:
        result.extend(struct.pack(order + "IIII", 0, 0, captured, len(frame)))
        result.extend(frame[:captured])
    return bytes(result)


class UDPLengthTests(unittest.TestCase):
    def test_sll2_ipv4_ipv6_truncation_and_no_packet_data_in_output(self):
        request = cooked(ipv4_datagram(300))
        reply = cooked(ipv6_datagram(301))
        fragmented = cooked(ipv6_datagram(8, fragment=True))
        unrelated = cooked(ipv4_datagram(12, destination="192.0.2.2"))
        other_port = cooked(ipv4_datagram(16, destination_port=PORT + 1))
        inconsistent = bytearray(request)
        struct.pack_into("!H", inconsistent, 20 + 24 + 4, 299)
        records = [(request, len(request)), (reply, 20 + 40 + 8 + 8), (reply, 20 + 40 + 8 + 7),
                   (fragmented, len(fragmented)), (unrelated, len(unrelated)),
                   (other_port, len(other_port)), (inconsistent, len(inconsistent))]
        with tempfile.TemporaryDirectory() as tmp:
            capture_path = Path(tmp) / "fixture.pcap"
            for order in ("<", ">"):
                with self.subTest(order=order):
                    capture_path.write_bytes(pcap(records, order))
                    result = subprocess.check_output([
                        sys.executable, str(TOOL), "--pcap", str(capture_path), "--port", str(PORT),
                        "--endpoint", SERVER_V4, "--endpoint", SERVER_V6,
                    ])
                    output = json.loads(result)
                    self.assertEqual(output["capture"]["records"], 7)
                    self.assertEqual(output["capture"]["truncated_records"], 2)
                    self.assertEqual(output["capture"]["truncated_records_with_counted_udp_length"], 1)
                    self.assertEqual(output["capture"]["skipped_records"], {
                        "fragmented_ip": 1, "missing_header": 1, "other_udp_endpoint": 2,
                        "udp_ip_length_mismatch": 1,
                    })
                    self.assertEqual(output["total"]["udp_payload_bytes"], 601)
                    self.assertEqual(output["total"]["udp_datagram_bytes_including_headers"], 617)
                    self.assertEqual(output["total"]["p50_udp_payload_bytes"], 300)
                    self.assertEqual(output["total"]["p95_udp_payload_bytes"], 301)
                    self.assertEqual(output["directions"]["to-server"]["histogram"], {"300": 1})
                    self.assertEqual(output["directions"]["from-server"]["histogram"], {"301": 1})
                    for private_value in (SERVER_V4.encode(), SERVER_V6.encode(), PAYLOAD_MARKER):
                        self.assertNotIn(private_value, result)

    def test_tsv_round_trip_and_bucket_boundaries(self):
        rows = [f"to-server\t{length}\t{count}" for length, count in (
            (0, 1), (1, 1), (300, 14), (301, 1), (600, 1), (601, 1), (900, 1),
            (901, 1), (1200, 1), (1201, 1), (1201, 1),
        )]
        src = StringIO("\t".join(analyzer.TSV_COLUMNS) + "\n" + "\n".join(rows))
        histograms = analyzer.read_tsv(src)
        result = analyzer.summarize(histograms["to-server"])
        self.assertEqual(result["datagrams"], 24)
        self.assertEqual(result["p50_udp_payload_bytes"], 300)
        self.assertEqual(result["p95_udp_payload_bytes"], 1201)
        self.assertEqual([bucket["datagrams"] for bucket in result["buckets"].values()],
                         [1, 15, 2, 2, 2, 2])
        self.assertIsNone(analyzer.summarize(histograms["from-server"])["p50_udp_payload_bytes"])
        dst = StringIO()
        analyzer.write_tsv(dst, histograms)
        dst.seek(0)
        self.assertEqual(analyzer.read_tsv(dst), histograms)

    def test_corrupt_file_is_not_reported_as_complete(self):
        packet = cooked(ipv4_datagram(16))
        damaged = pcap([(packet, len(packet))], "<")[:-1]
        with self.assertRaisesRegex(ValueError, "incomplete pcap record data"):
            analyzer.read_pcap(BytesIO(damaged), PORT, {address(SERVER_V4)})


if __name__ == "__main__":
    unittest.main()
