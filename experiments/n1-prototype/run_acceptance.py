#!/usr/bin/env python3
"""Native Android experiment, not an installed App/VPN benchmark."""
import concurrent.futures
import json
import math
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "results" / "2026-11-24"
OUT.mkdir(parents=True, exist_ok=True)
SERIAL = "A3GMVB2110006859"
BASE = ["adb", "-s", SERIAL, "shell", "/data/local/tmp/fastcat-n1-lab/n1-systemdns",
        "-mode", "probe", "-config", "/data/local/tmp/fastcat-n1-lab/domain.json",
        "-target", "127.0.0.1:18462"]


def run(name, count, size):
    started = time.monotonic()
    result = subprocess.run(BASE + ["-count", str(count), "-bytes", str(size)],
                            capture_output=True, text=True, timeout=max(180, count*100))
    (OUT / (name + ".jsonl")).write_text(result.stdout)
    if result.stderr:
        (OUT / (name + ".stderr.txt")).write_text(result.stderr)
    rows = [json.loads(line) for line in result.stdout.splitlines() if line.startswith("{")]
    return {"name": name, "exit_code": result.returncode,
            "elapsed_seconds": time.monotonic()-started, "rows": rows}


def stats(rows, field):
    values = sorted(row[field] for row in rows if field in row)
    if not values:
        return None
    return {"count": len(values), "mean": sum(values)/len(values),
            "p50": values[math.ceil(len(values)*.50)-1],
            "p95": values[math.ceil(len(values)*.95)-1],
            "min": values[0], "max": values[-1]}


results = []
for name, count, size in [("fresh-32k", 20, 32768), ("download-8m", 5, 8388608)]:
    result = run(name, count, size)
    results.append(result)
    print(name, "exit", result["exit_code"], flush=True)
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
    results.extend(pool.map(lambda i: run(f"concurrent-32k-worker-{i}", 5, 32768), range(4)))

summary = {}
for group, items in [("fresh-32k", results[:1]), ("download-8m", results[1:2]),
                     ("concurrent-32k", results[2:])]:
    rows = [row for item in items for row in item["rows"]]
    summary[group] = {"success": sum("full_request_ms" in row for row in rows),
                      "failed": sum("error" in row for row in rows),
                      "exit_codes": [item["exit_code"] for item in items],
                      "first_response_headers_ms": stats(rows, "first_response_headers_ms"),
                      "full_request_ms": stats(rows, "full_request_ms"),
                      "end_to_end_mbps": stats(rows, "end_to_end_mbps")}
(OUT / "summary.json").write_text(json.dumps(summary, indent=2))
print(json.dumps(summary, indent=2))
if any(item["exit_code"] for item in results):
    raise SystemExit(1)
