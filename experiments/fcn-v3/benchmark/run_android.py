#!/usr/bin/env python3
"""Run a fixed paired FCN v3 / TUIC matrix on the attached benchmark phone."""
from pathlib import Path
import argparse
import json
import random
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT.parent / "n1-prototype"))
from phone_network import state

ADB = ["adb", "-s", "A3GMVB2110006859", "shell"]
DEVICE = "/data/local/tmp/fastcat-fcn3-phase1"
OUTPUT = ROOT / "results/public"
RAW = OUTPUT / "raw"


def run(protocol, phase, byte_count, count, workers, config="bench.json", budget=30):
    args = ADB + [
        DEVICE + "/compare", "-config", DEVICE + "/" + config,
        "-protocol", protocol, "-phase", phase, "-bytes", str(byte_count),
        "-count", str(count), "-workers", str(workers), "-timeout", f"{budget}s",
    ]
    deadline = budget * ((count + workers - 1) // workers) + 20
    try:
        result = subprocess.run(args, capture_output=True, text=True, timeout=deadline)
        return result.returncode, result.stdout, result.stderr
    except subprocess.TimeoutExpired as exc:
        return 124, (exc.stdout or b"").decode(errors="replace"), (exc.stderr or b"").decode(errors="replace")


def verified_network():
    value = state()
    if value["transport"] != "wifi" or not value["validated"]:
        raise RuntimeError("test requires validated Wi-Fi: " + json.dumps(value))
    return value


def run_preflight():
    for protocol in ("fcnv3", "tuic"):
        code, out, err = run(protocol, "cold", 8192, 2, 1)
        (OUTPUT / f"preflight-{protocol}.jsonl").write_text(out)
        (OUTPUT / f"preflight-{protocol}.stderr.txt").write_text(err)
        if code != 0:
            raise RuntimeError(f"{protocol} failed preflight")
        print(protocol, "preflight passed", flush=True)
    code, out, err = run("fcnv3", "cold", 8192, 1, 1, "wrong.json")
    (OUTPUT / "wrong-credential.jsonl").write_text(out)
    (OUTPUT / "wrong-credential.stderr.txt").write_text(err)
    rows = [json.loads(line) for line in out.splitlines() if line.startswith("{")]
    if code == 0 or not any("reject" in str(row).lower() for row in rows):
        raise RuntimeError("wrong credential was not explicitly rejected")
    print("wrong credential explicitly rejected", flush=True)


def make_plan():
    cases = [
        ("cold", "cold", 32768, 10, 1, 3),
        ("warm", "warm", 32768, 20, 1, 3),
        ("concurrent", "concurrent", 131072, 16, 4, 3),
        ("single_download", "download", 4194304, 1, 1, 6),
        ("parallel_download", "download", 1048576, 4, 4, 6),
        ("upload", "upload", 1048576, 1, 1, 6),
    ]
    rng = random.Random(20261125)
    jobs = []
    for category, phase, size, count, workers, blocks in cases:
        first = ["fcnv3", "tuic"]
        rng.shuffle(first)
        for block in range(1, blocks + 1):
            order = first if block % 2 else first[::-1]
            for protocol in order:
                jobs.append(dict(id=f"{category}-{block:02d}-{protocol}", protocol=protocol,
                                 phase=phase, category=category, block=block,
                                 bytes=size, count=count, workers=workers))
    return {"jobs": jobs, "name": "FCN v3 Phase 1", "network": "validated wifi",
            "endpoint_name": "zlhk.fastcat.lol", "seed": 20261125,
            "gates": {"p50_max": 1.10, "p95_max": 1.15, "download_min": .90}}


def main():
    global OUTPUT, RAW
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    OUTPUT = parser.parse_args().output
    RAW = OUTPUT / "raw"
    if (OUTPUT / "plan.json").exists():
        parser.error("results already exist, choose a new --output directory")
    RAW.mkdir(parents=True, exist_ok=True)
    plan = make_plan()
    (OUTPUT / "plan.json").write_text(json.dumps(plan, indent=2))
    verified_network()
    run_preflight()
    for index, job in enumerate(plan["jobs"], 1):
        name = job["id"]
        before = verified_network()
        started = time.time()
        code, out, err = run(job["protocol"], job["phase"], job["bytes"], job["count"], job["workers"])
        after = state()
        (RAW / f"{name}.jsonl").write_text(out)
        (RAW / f"{name}.stderr.txt").write_text(err)
        metadata = dict(before=before, after=after, exit_code=code, start=started, end=time.time())
        (RAW / f"{name}.meta.json").write_text(json.dumps(metadata, indent=2))
        rows = [json.loads(line) for line in out.splitlines() if line.startswith("{")]
        print(index, "/", len(plan["jobs"]), name, "exit", code,
              "successful", sum(row["success"] for row in rows if row.get("event") == "sample"), flush=True)
        if after["transport"] != "wifi" or not after["validated"]:
            raise RuntimeError("network changed during " + name)


if __name__ == "__main__":
    main()
