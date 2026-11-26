"""Exercise the FastCat HTTP/2 command-line client and server entirely on loopback."""
import argparse
import json
import math
import os
import re
import secrets
import socket
import socketserver
import statistics
import subprocess
import tempfile
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from contextlib import ExitStack, contextmanager
from pathlib import Path

HERE = Path(__file__).resolve().parent
HOST = "127.0.0.1"
TIMEOUT = 10


class Echo(socketserver.BaseRequestHandler):
    def handle(self):
        with self.request as conn:
            conn.settimeout(TIMEOUT)
            while True:
                data = conn.recv(65536)
                if not data:
                    return
                conn.sendall(data)


class EchoServer(socketserver.ThreadingTCPServer):
    daemon_threads = True
    request_queue_size = 128


@contextmanager
def echo_target():
    with EchoServer((HOST, 0), Echo) as server:
        thread = threading.Thread(target=server.serve_forever, args=(0.05,), daemon=True)
        thread.start()
        try:
            yield "%s:%d" % server.server_address
        finally:
            server.shutdown()
            thread.join()


@contextmanager
def process(command, env, log):
    with log.open("wb") as out:
        child = subprocess.Popen(command, stdout=out, stderr=subprocess.STDOUT, env=env)
        try:
            yield child
        finally:
            if child.poll() is None:
                child.terminate()
                try:
                    child.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    child.kill()
                    child.wait(timeout=3)


def wait_ready(child, check):
    until = time.monotonic() + TIMEOUT
    while time.monotonic() < until:
        rc = child.poll()
        if rc is not None:
            raise RuntimeError("test process exited during startup (code %d)" % rc)
        result = check()
        if result:
            return result
        time.sleep(0.01)
    raise TimeoutError("test listener did not become ready")


def start_h2(stack, tmp, name, binary, args, env):
    log = tmp / (name + ".log")
    child = stack.enter_context(process([binary] + args, env, log))

    def address():
        match = re.search(r"\b(?:server|client) listen=127\.0\.0\.1:(\d+)", log.read_text())
        return int(match.group(1)) if match else None

    return wait_ready(child, address), log


def exchange(port, payload, proxy_target=None):
    start = time.perf_counter()
    with socket.create_connection((HOST, port), timeout=TIMEOUT) as conn, conn.makefile("rb") as reader:
        if proxy_target:
            # One write deliberately lets the HTTP parser pre-read target bytes.
            request = "CONNECT {0} HTTP/1.1\r\nHost: {0}\r\n\r\n".format(proxy_target)
            conn.sendall(request.encode("ascii") + payload)
            if not reader.readline(1024).startswith(b"HTTP/1.1 200 "):
                raise RuntimeError("local HTTP CONNECT did not succeed")
            while True:
                line = reader.readline(8192)
                if line == b"\r\n":
                    break
                if not line or len(line) == 8192:
                    raise RuntimeError("invalid local CONNECT response")
        else:
            conn.sendall(payload)
        conn.shutdown(socket.SHUT_WR)
        first_byte = reader.read(1)
        first_ms = (time.perf_counter() - start) * 1000
        if first_byte + reader.read(len(payload) - 1) != payload or reader.read(1):
            raise RuntimeError("echo mismatch or truncated stream")
    return first_ms, (time.perf_counter() - start) * 1000


def distribution(times):
    ordered = sorted(times)
    return {
        "samples": len(times),
        "p50_ms": round(statistics.median(times), 3),
        "p95_ms": round(ordered[math.ceil(0.95 * len(times)) - 1], 3),
    }


def measure(port, sample, opts, starting_client=None):
    def one_round(index):
        # Tag each stream so cross-stream delivery can be detected. Reuse the
        # same source bytes for v1 and v2 without preallocating every payload.
        tag = index.to_bytes(8, "little")[:len(sample)]
        return exchange(port, tag + sample[len(tag):])

    def try_first_round():
        try:
            return one_round(0)
        except ConnectionRefusedError:
            return None

    # V1 has no bound-address log; use its first actual exchange as the
    # readiness check instead of starting an extra TLS handshake in parallel.
    first = wait_ready(starting_client, try_first_round) if starting_client else one_round(0)
    warm = [one_round(i) for i in range(1, 1 + opts.warm)]
    count = 1 + opts.warm + opts.batch
    start = time.perf_counter()
    with ThreadPoolExecutor(max_workers=opts.concurrency) as pool:
        batch = list(pool.map(one_round, range(1 + opts.warm, count)))
    elapsed_ms = (time.perf_counter() - start) * 1000
    return {
        "first_ms": round(first[1], 3),
        "warm": distribution([full for _, full in warm]),
        "batch": {**distribution([full for _, full in batch]), "workers": opts.concurrency,
                  "elapsed_ms": round(elapsed_ms, 3)},
        "first_echo_byte": {
            "cold_ms": round(first[0], 3),
            "warm": distribution([first_byte for first_byte, _ in warm]),
            "batch": distribution([first_byte for first_byte, _ in batch]),
        },
        "verified_streams": count,
    }


def unused_port():
    with socket.socket() as sock:
        sock.bind((HOST, 0))
        return sock.getsockname()[1]


def listener_ready(port):
    try:
        with socket.create_connection((HOST, port), timeout=0.2):
            return True
    except OSError:
        return False


def measure_v1(binary, tmp, env, target, sample, opts):
    # v1 does not print its bound address. Use temporary ports for its two
    # listeners and check each socket before timing real echo exchanges.
    with ExitStack() as stack:
        entry = unused_port()
        server = stack.enter_context(process([
            binary, "-mode", "server", "-listen", "%s:%d" % (HOST, entry),
            "-target", target, "-cert", str(tmp / "cert.pem"), "-key", str(tmp / "key.pem")
        ], env, tmp / "v1-server.log"))
        wait_ready(server, lambda: listener_ready(entry))
        local = unused_port()
        client = stack.enter_context(process([
            binary, "-mode", "client", "-listen", "%s:%d" % (HOST, local),
            "-entry", "%s:%d" % (HOST, entry), "-target", target, "-ca", str(tmp / "cert.pem")
        ], env, tmp / "v1-client.log"))
        return measure(local, sample, opts, starting_client=client)


def run(opts):
    with tempfile.TemporaryDirectory(prefix="fastcat-h2-") as work, ExitStack() as stack:
        tmp = Path(work)
        binary = opts.binary
        if not binary:
            binary = str(tmp / "fastcat-h2")
            subprocess.run(["go", "build", "-o", binary, "."], cwd=HERE, check=True, timeout=180)
        subprocess.run([
            "openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1",
            "-subj", "/CN=localhost", "-addext", "subjectAltName=IP:127.0.0.1,DNS:localhost",
            "-keyout", str(tmp / "key.pem"), "-out", str(tmp / "cert.pem")
        ], check=True, timeout=30, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        token = secrets.token_urlsafe(32)
        env = dict(os.environ, FASTCAT_H2_TOKEN=token, FASTCAT_LAB_TOKEN=token)
        target = stack.enter_context(echo_target())
        entry, server_log = start_h2(stack, tmp, "h2-server", binary, [
            "server", "-listen", HOST + ":0", "-allow-private-targets",
            "-cert", str(tmp / "cert.pem"), "-key", str(tmp / "key.pem")
        ], env)
        client_args = ["client", "-listen", HOST + ":0", "-entry", "%s:%d" % (HOST, entry),
                       "-ca", str(tmp / "cert.pem")]
        with ExitStack() as proxy_stack:
            proxy, _ = start_h2(proxy_stack, tmp, "h2-proxy", binary, client_args, env)
            exchange(proxy, os.urandom(8192), proxy_target=target)

        before = server_log.read_text().count("entry negotiated=h2")
        sample = os.urandom(opts.bytes)
        with ExitStack() as fixed_stack:
            fixed, _ = start_h2(fixed_stack, tmp, "h2-fixed", binary, client_args + ["-target", target], env)
            h2 = measure(fixed, sample, opts)
        connections = server_log.read_text().count("entry negotiated=h2") - before
        if before != 1 or connections != 1:
            raise RuntimeError("expected one HTTP/2 entry connection per local client; observed %d/%d" %
                               (before, connections))
        h2["negotiated_h2_connections"] = connections
        result = {
            "scope": "loopback; first_ms/warm/batch measure local connect through full echo and EOF; "
                     "first_echo_byte measures local connect through first received payload byte",
            "bytes_per_stream_each_way": opts.bytes, "local_http_connect_buffered_payload_verified": True,
            "h2_fixed": h2,
        }
        if opts.v1:
            result["v1_fixed"] = measure_v1(opts.v1, tmp, env, target, sample, opts)
        return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", help="native fastcat-h2 executable (default: build in a temporary directory)")
    parser.add_argument("--v1", help="optional native fastcat-https v1 executable for the same fixed-target workload")
    parser.add_argument("--output", type=Path, help="write verified aggregate metrics to JSON")
    parser.add_argument("--warm", type=int, default=32)
    parser.add_argument("--batch", type=int, default=64)
    parser.add_argument("--concurrency", type=int, default=8)
    parser.add_argument("--bytes", type=int, default=32768, help="echo payload size in bytes (1..65536)")
    opts = parser.parse_args()
    if min(opts.warm, opts.batch, opts.concurrency, opts.bytes) <= 0:
        parser.error("sample counts, concurrency and payload bytes must be positive")
    if opts.bytes > 65536:
        parser.error("--bytes must be at most 65536 for this short-connection benchmark")
    result = json.dumps(run(opts), indent=2)
    if opts.output:
        opts.output.write_text(result + "\n")
    print(result)


if __name__ == "__main__":
    main()
