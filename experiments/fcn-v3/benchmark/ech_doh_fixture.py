#!/usr/bin/env python3
"""Controlled DoH records for the FCN v3 lab. No recursive resolution."""
import argparse
import base64
import ipaddress
import json
import ssl
import struct
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

LOCK = threading.Lock()
HTTPS_COUNTS = {}


def parse_question(data):
    if len(data) < 17 or data[2] & 0x80 or data[4:6] != b"\x00\x01":
        raise ValueError("invalid DNS request")
    labels = []
    pos = 12
    while data[pos]:
        length = data[pos]
        pos += 1
        if length > 63 or length > len(data) - pos:
            raise ValueError("invalid label length")
        labels.append(data[pos:pos + length].decode("ascii"))
        pos += length
    pos += 1
    kind, cls = struct.unpack_from(">HH", data, pos)
    if cls != 1:
        raise ValueError("invalid DNS class")
    return ".".join(labels).lower(), kind, data[12:pos + 4]


class DoHHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *args):
        pass

    def setup(self):
        self.request.settimeout(5)
        super().setup()

    def do_POST(self):
        if self.path != "/dns-query" or self.headers.get_content_type() != "application/dns-message":
            self.send_error(404)
            return
        try:
            n = int(self.headers.get("Content-Length", "0"))
            if not 17 <= n <= 4096:
                raise ValueError("invalid query size")
            wire = self.rfile.read(n)
            name, kind, question = parse_question(wire)
            cfg = json.loads(self.server.state_path.read_text())
            if cfg.get("mode") == "outage":
                self.send_error(503)
                return
            code = 3 if name != self.server.inner else 0
            payload = b""
            if code == 0 and kind == 1:
                payload = self.server.address.packed
            if code == 0 and kind == 65 and cfg.get("mode") != "missing":
                with LOCK:
                    epoch = cfg["epoch"]
                    if epoch not in HTTPS_COUNTS:
                        HTTPS_COUNTS.clear()
                        HTTPS_COUNTS[epoch] = 0
                    counter = HTTPS_COUNTS[epoch] = HTTPS_COUNTS[epoch] + 1
                ech = cfg.get("first_ech", cfg["ech"]) if counter == 1 else cfg["ech"]
                config = base64.b64decode(ech, validate=True)
                payload = b"\x00\x01\x00" + struct.pack(">HH", 5, len(config)) + config
                print(f"epoch={epoch} https_answer={counter}", flush=True)
            answer = (b"\xc0\x0c" + struct.pack(">HHIH", kind, 1, 30, len(payload)) + payload) if payload else b""
            reply = wire[:2] + struct.pack(">HHHHH", 0x8180 | code, 1, bool(answer), 0, 0) + question + answer
        except (ValueError, IndexError, KeyError, OSError, struct.error):
            self.send_error(400)
            return
        self.send_response(200)
        self.send_header("Content-Type", "application/dns-message")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(reply)))
        self.end_headers()
        self.wfile.write(reply)


class DoHServer(ThreadingHTTPServer):
    daemon_threads = True
    slots = threading.BoundedSemaphore(12)

    def process_request(self, request, address):
        if not self.slots.acquire(blocking=False):
            self.shutdown_request(request)
            return
        try:
            super().process_request(request, address)
        except BaseException:
            self.slots.release()
            raise

    def process_request_thread(self, request, address):
        try:
            # A stalled TLS handshake must not hold up the accept loop or
            # other A/AAAA/HTTPS requests made by the client.
            request.settimeout(5)
            try:
                secure = self.context.wrap_socket(request, server_side=True)
            except OSError:
                self.shutdown_request(request)
                return
            super().process_request_thread(secure, address)
        finally:
            self.slots.release()


if __name__ == "__main__":
    args = argparse.ArgumentParser(__doc__)
    for option in ("cert", "key", "state", "inner", "answer-ip"):
        args.add_argument("--" + option, required=True)
    args.add_argument("--port", type=int, default=18535)
    options = args.parse_args()
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.minimum_version = ssl.TLSVersion.TLSv1_3
    context.load_cert_chain(options.cert, options.key)
    server = DoHServer(("0.0.0.0", options.port), DoHHandler)
    server.state_path = Path(options.state)
    server.inner = options.inner
    server.address = ipaddress.IPv4Address(options.answer_ip)
    server.context = context
    server.serve_forever()
