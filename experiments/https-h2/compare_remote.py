"""Compare two running FastCat gateways from this Mac, using the same HTTPS URL."""
import argparse
from contextlib import ExitStack
from getpass import getpass
import os
from pathlib import Path
import subprocess
import sys
import tempfile
from urllib.parse import urlsplit

from smoke import HERE, HOST, distribution, process, start_h2, unused_port, wait_ready


DEFAULT_URL = "https://www.gstatic.com/generate_204"


def fetch(url, destination, port):
    # A new curl process opens a fresh origin TLS connection for each sample.
    # --connect-to changes the TCP destination while retaining URL hostname verification.
    result = subprocess.run([
        "curl", "--disable", "--silent", "--show-error", "--http1.1", "--noproxy", "*",
        "--max-time", "15", "--connect-to", f"{destination}:{HOST}:{port}",
        "--output", os.devnull, "--write-out", "%{http_code} %{time_starttransfer}", url,
    ], capture_output=True, text=True)
    if result.returncode:
        return None, f"curl {result.returncode}: {result.stderr.strip()}"
    status, elapsed = result.stdout.split()
    if not status.startswith("2") or (url == DEFAULT_URL and status != "204"):
        return None, f"目标网站返回 HTTP {status}"
    return float(elapsed) * 1000, None


def credentials(variable, label):
    if os.environ.get(variable):
        return os.environ[variable]
    if not sys.stdin.isatty():
        raise ValueError(f"请在终端输入{label}令牌，或通过 {variable} 提供")
    return getpass(f"输入{label}令牌（输入时隐藏）：")


def compare(opts):
    url = urlsplit(opts.url)
    if url.scheme != "https" or not url.hostname or url.username is not None:
        raise ValueError("目标须为不含用户名和密码的 HTTPS URL")
    host = f"[{url.hostname}]" if ":" in url.hostname else url.hostname
    destination = f"{host}:{url.port or 443}"
    v1 = HERE.parent / "https-tcp/artifacts/fastcat-https-macos-arm64"
    h2 = HERE / "artifacts/fastcat-h2-macos-arm64"
    for binary in (v1, h2):
        if not os.access(binary, os.X_OK):
            raise ValueError(f"找不到可执行程序 {binary}")
    v1token = credentials("FASTCAT_LAB_TOKEN", "现有 v1")
    h2token = credentials("FASTCAT_H2_TOKEN", "HTTP/2 测试节点")
    with tempfile.TemporaryDirectory(prefix="fastcat-compare-") as work, ExitStack() as stack:
        tmp = Path(work)
        trust = ["-ca", str(opts.gateway_ca)] if opts.gateway_ca else []
        h2port, h2log = start_h2(stack, tmp, "h2", str(h2), [
            "client", "-entry", opts.h2_entry, "-listen", f"{HOST}:0", "-target", destination,
        ] + trust, dict(os.environ, FASTCAT_H2_TOKEN=h2token))
        v1port = unused_port()
        v1log = tmp / "v1.log"
        v1proc = stack.enter_context(process([
            str(v1), "-mode", "client", "-entry", opts.v1_entry, "-listen", f"{HOST}:{v1port}",
            "-target", destination,
        ] + trust, dict(os.environ, FASTCAT_LAB_TOKEN=v1token), v1log))
        ports = {"v1": v1port, "HTTP/2": h2port}
        logs = {"v1": v1log, "HTTP/2": h2log}

        def first_v1():
            sample = fetch(opts.url, destination, v1port)
            # This curl only dials loopback. A refused local socket means startup is incomplete.
            return None if sample[1] and sample[1].startswith("curl 7:") else sample

        def diagnose(label, reason):
            print(f"{label}：{reason}", file=sys.stderr)
            lines = logs[label].read_text(errors="replace").splitlines()
            for line in reversed(lines):
                if any(marker in line for marker in ("error=", "status=", "CONNECT failed:")):
                    print(f"  客户端日志：{line}", file=sys.stderr)
                    break

        print(f"目标 {destination}；入口 v1 {opts.v1_entry}，HTTP/2 {opts.h2_entry}", flush=True)
        cold = {
            "v1": wait_ready(v1proc, first_v1),
            "HTTP/2": fetch(opts.url, destination, h2port),
        }
        for label, (value, err) in cold.items():
            if err:
                diagnose(label, err)
            else:
                print(f"{label} 首次首字节 {value:.1f} ms")
        if any(err for _, err in cold.values()):
            print("首次请求未全部成功，请先核对服务、令牌、证书和入口端口。", file=sys.stderr)
            return 1

        times = {label: [] for label in ports}
        last_errors = {}
        print(f"每个入口再测 {opts.rounds} 次，每轮交换先后顺序。", flush=True)
        for i in range(opts.rounds):
            for label in (("v1", "HTTP/2") if i % 2 == 0 else ("HTTP/2", "v1")):
                value, err = fetch(opts.url, destination, ports[label])
                if err:
                    last_errors[label] = err
                else:
                    times[label].append(value)
        print("入口       成功/总数   失败   首字节 P50   首字节 P95")
        for label, samples in times.items():
            stats = distribution(samples) if samples else {}
            p50 = f"{stats['p50_ms']:.1f} ms" if stats else "—"
            p95 = f"{stats['p95_ms']:.1f} ms" if stats else "—"
            print(f"{label:<8}   {len(samples)}/{opts.rounds}       {opts.rounds-len(samples):<4}   {p50:>8}     {p95:>8}")
        for label, err in last_errors.items():
            diagnose(label, err)
        return int(bool(last_errors))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--v1-entry", default="zlhk.fastcat.ink:8443")
    parser.add_argument("--h2-entry", default="zlhk.fastcat.ink:18444")
    parser.add_argument("--url", default=DEFAULT_URL)
    parser.add_argument("--rounds", type=int, default=20)
    parser.add_argument("--gateway-ca", type=Path, help="自建测试入口的受信任 CA 文件")
    opts = parser.parse_args()
    if opts.rounds < 1:
        parser.error("--rounds 至少为 1")
    try:
        return compare(opts)
    except (OSError, ValueError, RuntimeError, EOFError) as exc:
        print(f"对照未完成：{exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
