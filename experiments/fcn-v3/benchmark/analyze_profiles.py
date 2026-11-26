#!/usr/bin/env python3
"""Aggregate the fixed FCN v3 writing profiles without dropping failed trials."""
from collections import defaultdict
from pathlib import Path
import argparse
import json
import math
import statistics


def quantile(values, fraction):
    values = sorted(values)
    if not values:
        return None
    rank = fraction * (len(values) - 1)
    low = math.floor(rank)
    high = math.ceil(rank)
    return values[low] + (values[high] - values[low]) * (rank - low)


def analyze(root):
    plan = json.loads((root / "plan.json").read_text())
    batches = json.loads((root / "batches.json").read_text())
    by_job = {(b["workload"], b["block"], b["profile"]): b for b in batches}
    collected = defaultdict(list)
    for job in plan:
        key = (job["workload"], job["block"], job["profile"])
        tag = f"{key[0]}-{key[1]:02d}-{key[2]}"
        path = root / "raw" / (tag + ".jsonl")
        data = [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []
        samples = [row for row in data if row.get("event") == "sample"]
        collected[(key[0], key[2])].append((job, by_job.get(key, {}).get("batch", {}), samples))
    summary = {}
    for (workload, profile), trials in collected.items():
        rows = [r for _, _, samples in trials for r in samples]
        good = [r for r in rows if r.get("success")]
        timed = [r for r in good if workload != "interactive" or not r.get("first_in_batch")]
        latency = [r["first_byte_ms"] for r in timed]
        throughput = [b["aggregate_verified_mbps"] for _, b, _ in trials if "aggregate_verified_mbps" in b]
        wire = root / f"{workload}-{profile}-wire.json"
        answer = {
            "expected": sum(job["count"] for job, _, _ in trials),
            "samples": len(rows),
            "verified": len(good),
            "verified_application_bytes": sum(row["verified_bytes"] for row in good),
            "failure_rows": [row for row in rows if not row.get("success")],
            "latency_samples": len(latency),
            "first_byte_p50_ms": quantile(latency, .5),
            "first_byte_p95_ms": quantile(latency, .95),
            "batch_mbps_median": statistics.median(throughput) if throughput else None,
            "batch_mbps": throughput,
        }
        if wire.exists():
            capture = json.loads(wire.read_text())
            answer["wire"] = capture["directions"]
        summary.setdefault(workload, {})[profile] = answer
    return summary


if __name__ == "__main__":
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("results", type=Path)
    path = parser.parse_args().results
    report = analyze(path)
    (path / "summary.json").write_text(json.dumps(report, indent=2) + "\n")
