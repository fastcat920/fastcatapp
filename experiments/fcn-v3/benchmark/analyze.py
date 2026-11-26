#!/usr/bin/env python3
"""Offline, failure-preserving analysis of the bounded FCNv3 / TUIC matrix.

Accepts a results directory and --plan (default: results/plan.json). The plan
contains jobs/batches, each identifying a JSONL file by path/file/raw/id/label.
Run metadata and measured rows remain separate. No device or network actions.
"""
import argparse
import collections
import json
import math
from pathlib import Path
import statistics


def quantile(values, p):
    if not values:
        return None
    values = sorted(values)
    i = (len(values) - 1) * p
    lo, hi = math.floor(i), math.ceil(i)
    return values[lo] + (values[hi] - values[lo]) * (i - lo)


def stats(values):
    values = [x for x in values if isinstance(x, (int, float)) and math.isfinite(x)]
    return {"n": len(values), "p50": quantile(values, .5),
            "p95": quantile(values, .95),
            "mean": statistics.mean(values) if values else None,
            "min": min(values) if values else None, "max": max(values) if values else None}


def category(job):
    if job.get("category"):
        return {"download_single": "single_download", "download_concurrent": "parallel_download"}.get(job["category"], job["category"])
    phase = job["phase"]
    if phase == "download":
        return "single_download" if job["workers"] == 1 else "parallel_download"
    if phase == "upload":
        return "upload" if job["workers"] == 1 else "parallel_upload"
    return phase


def ratio(a, b):
    return a / b if a is not None and b is not None and b > 0 else None


def locate(root, job, index):
    value = next((job[k] for k in ("path", "file", "raw", "jsonl", "id", "label")
                  if isinstance(job.get(k), str)), None)
    if value:
        p = Path(value)
        if p.suffix != ".jsonl":
            p = p.with_suffix(".jsonl")
        for candidate in (root / p, root / "raw" / p):
            if candidate.exists():
                return candidate
        return root / p
    label = "%02d-%s-%s-w%d-b%d" % (
        index, job["protocol"], job["phase"], job["workers"], job.get("block", 1))
    for candidate in (root / "raw" / (label + ".jsonl"), root / (label + ".jsonl")):
        if candidate.exists():
            return candidate
    return root / "raw" / (label + ".jsonl")


def analyze(root, plan):
    jobs = plan if isinstance(plan, list) else plan.get("jobs", plan.get("batches", []))
    if not jobs:
        raise ValueError("plan requires a nonempty jobs or batches list")
    all_rows, batches, issues = [], [], []
    for index, job in enumerate(jobs, 1):
        path = locate(root, job, index)
        objects = []
        if path.exists():
            for line_no, line in enumerate(path.read_text().splitlines(), 1):
                if not line.strip():
                    continue
                try:
                    value = json.loads(line)
                    if not isinstance(value, dict):
                        raise ValueError("JSON object required")
                    objects.append(value)
                except (ValueError, TypeError):
                    issues.append({"batch": index, "file": str(path), "line": line_no,
                                   "error": "invalid JSONL row"})
        else:
            issues.append({"batch": index, "file": str(path), "error": "missing raw file"})
        by_sample = {}
        for row in (v for v in objects if "sample" in v):
            sample = row.get("sample")
            if type(sample) is not int or not 1 <= sample <= job["count"] or sample in by_sample:
                issues.append({"batch": index, "error": "duplicate or invalid sample index"})
                continue
            by_sample[sample] = row
        rows = []
        for sample in range(1, job["count"] + 1):
            row = dict(by_sample.get(sample, {"sample": sample, "success": False,
                                             "error_stage": "missing-row", "error_category": "missing"}))
            mismatch = any(k in row and row[k] != job[k]
                           for k in ("protocol", "phase", "bytes", "workers") if k in job)
            if mismatch:
                issues.append({"batch": index, "sample": sample, "error": "row disagrees with plan"})
                row.update(success=False, error_stage="metadata", error_category="mismatched-row")
            if row.get("success") is True and row.get("verified_bytes") != job["bytes"]:
                row.update(success=False, error_stage="verification", error_category="unverified-bytes")
            row.update(protocol=job["protocol"], phase=job["phase"], bytes=job["bytes"],
                       workers=job["workers"], block=job.get("block", 1), batch=index,
                       category=category(job), first_in_batch=sample == 1)
            rows.append(row)
        endings = [v for v in objects if v.get("event") == "batch-ended"]
        ending = endings[-1] if endings else {}
        if len(endings) != 1:
            issues.append({"batch": index, "error": "expected one batch-ended summary"})
        failures = sum(r.get("success") is not True for r in rows)
        if ending and (ending.get("count") != job["count"] or ending.get("failed") != failures):
            issues.append({"batch": index, "error": "summary counts disagree with samples"})
        verified = sum(job["bytes"] for r in rows if r.get("success") is True)
        elapsed_ms = ending.get("elapsed_ms")
        aggregate = verified * 8 / elapsed_ms / 1000 if isinstance(elapsed_ms, (int, float)) and elapsed_ms > 0 else None
        timed_rows = [r for r in rows if isinstance(r.get("start_unix_ms"), (int, float)) and
                      isinstance(r.get("total_ms"), (int, float))]
        span = (max(r["start_unix_ms"] + r["total_ms"] for r in timed_rows) -
                min(r["start_unix_ms"] for r in timed_rows)) if timed_rows else None
        payload_aggregate = verified * 8 / span / 1000 if span is not None and span > 0 else None
        metadata = {}
        meta_path = path.with_suffix(".meta.json")
        if meta_path.exists():
            try:
                metadata = json.loads(meta_path.read_text())
                if not isinstance(metadata, dict):
                    raise ValueError("metadata must be an object")
                if metadata.get("exit_code", 0) != 0:
                    issues.append({"batch": index, "error": "nonzero process exit", "exit_code": metadata["exit_code"]})
            except (ValueError, TypeError):
                issues.append({"batch": index, "error": "invalid batch metadata"})
                metadata = {}
        good = [r for r in rows if r.get("success") is True and
                not (job["phase"] == "warm" and r["first_in_batch"])]
        batches.append({**job, "batch": index, "category": category(job), "file": str(path),
                        "failed": failures, "verified_bytes": verified, "elapsed_ms": elapsed_ms,
                        "aggregate_verified_mbps": aggregate,
                        "payload_makespan_ms": span, "payload_aggregate_mbps": payload_aggregate,
                        "metadata": metadata,
                        "first_byte_ms": stats([r.get("first_byte_ms") for r in good]),
                        "total_ms": stats([r.get("total_ms") for r in good])})
        all_rows.extend(rows)
    grouped = collections.defaultdict(dict)
    for protocol in sorted({r["protocol"] for r in all_rows}):
        for label in sorted({r["category"] for r in all_rows}):
            rows = [r for r in all_rows if r["protocol"] == protocol and r["category"] == label]
            if not rows:
                continue
            good = [r for r in rows if r.get("success") is True]
            timed = [r for r in good if not (r["phase"] == "warm" and r["first_in_batch"])]
            relevant_batches = [b for b in batches if b["protocol"] == protocol and b["category"] == label]
            grouped[protocol][label] = {
                "attempted": len(rows), "success": len(good), "failed": len(rows) - len(good),
                "first_byte_ms": stats([r.get("first_byte_ms") for r in timed]),
                "total_ms": stats([r.get("total_ms") for r in timed]),
                "entry_ms": stats([r.get("entry_ms") for r in timed]),
                "e2e_mbps": stats([r.get("e2e_mbps") for r in good]),
                "batch_aggregate_mbps": stats([b["aggregate_verified_mbps"] for b in relevant_batches]),
                "payload_aggregate_mbps": stats([b["payload_aggregate_mbps"] for b in relevant_batches]),
                "block_median_first_byte_ms": stats([b["first_byte_ms"]["p50"] for b in relevant_batches]),
                "block_p95_first_byte_ms": stats([b["first_byte_ms"]["p95"] for b in relevant_batches]),
                "first_sample_first_byte_ms": [r.get("first_byte_ms") for r in good if r["first_in_batch"]],
            }
    comparisons, gates = {}, {}
    for label in sorted(set(grouped["fcnv3"]) & set(grouped["tuic"])):
        f, t = grouped["fcnv3"][label], grouped["tuic"][label]
        comparisons[label] = {
            "first_byte_p50_ratio": ratio(f["first_byte_ms"]["p50"], t["first_byte_ms"]["p50"]),
            "first_byte_p95_ratio": ratio(f["first_byte_ms"]["p95"], t["first_byte_ms"]["p95"]),
            "total_p50_ratio": ratio(f["total_ms"]["p50"], t["total_ms"]["p50"]),
            "total_p95_ratio": ratio(f["total_ms"]["p95"], t["total_ms"]["p95"]),
            "throughput_ratio": ratio(f["batch_aggregate_mbps"]["p50"], t["batch_aggregate_mbps"]["p50"]),
            "payload_throughput_ratio": ratio(f["payload_aggregate_mbps"]["p50"], t["payload_aggregate_mbps"]["p50"]),
            "block_median_first_byte_ratio": ratio(f["block_median_first_byte_ms"]["p50"], t["block_median_first_byte_ms"]["p50"]),
        }
        paired = []
        fb = {b.get("block", 1): b for b in batches if b["protocol"] == "fcnv3" and b["category"] == label}
        tb = {b.get("block", 1): b for b in batches if b["protocol"] == "tuic" and b["category"] == label}
        for block in sorted(set(fb) & set(tb)):
            a, b = fb[block], tb[block]
            paired.append({
                "block": block,
                "fcnv3_first_byte_p50_ms": a["first_byte_ms"]["p50"],
                "tuic_first_byte_p50_ms": b["first_byte_ms"]["p50"],
                "first_byte_p50_ratio": ratio(a["first_byte_ms"]["p50"], b["first_byte_ms"]["p50"]),
                "first_byte_p95_ratio": ratio(a["first_byte_ms"]["p95"], b["first_byte_ms"]["p95"]),
                "total_p50_ratio": ratio(a["total_ms"]["p50"], b["total_ms"]["p50"]),
                "total_p95_ratio": ratio(a["total_ms"]["p95"], b["total_ms"]["p95"]),
                "fcnv3_aggregate_mbps": a["aggregate_verified_mbps"],
                "tuic_aggregate_mbps": b["aggregate_verified_mbps"],
                "throughput_ratio": ratio(a["aggregate_verified_mbps"], b["aggregate_verified_mbps"]),
                "payload_throughput_ratio": ratio(a["payload_aggregate_mbps"], b["payload_aggregate_mbps"]),
                "failed": a["failed"] + b["failed"],
            })
        comparisons[label]["paired_blocks"] = paired
        comparisons[label]["paired_p50_ratios"] = stats([b["first_byte_p50_ratio"] for b in paired])
        comparisons[label]["paired_p95_ratios"] = stats([b["first_byte_p95_ratio"] for b in paired])
        comparisons[label]["paired_throughput_ratios"] = stats([b["throughput_ratio"] for b in paired])
    for label in ("cold", "warm", "concurrent"):
        c = comparisons.get(label, {})
        gates[label + "_p50"] = c.get("first_byte_p50_ratio") is not None and c["first_byte_p50_ratio"] <= 1.10
        gates[label + "_p95"] = c.get("first_byte_p95_ratio") is not None and c["first_byte_p95_ratio"] <= 1.15
    for label in ("single_download", "parallel_download"):
        c = comparisons.get(label, {})
        gates[label + "_throughput"] = c.get("throughput_ratio") is not None and c["throughput_ratio"] >= .90
    gates["zero_failures"] = all(r.get("success") is True for r in all_rows)
    gates["complete_evidence"] = not issues
    gates["minimum_latency_counts"] = all(
        grouped[protocol].get(label, {}).get("attempted", 0) >= minimum
        for protocol in ("fcnv3", "tuic") for label, minimum in (("cold", 30), ("warm", 60), ("concurrent", 40)))
    gates["six_paired_throughput_blocks"] = all(
        len(comparisons.get(label, {}).get("paired_blocks", [])) >= 6
        for label in ("single_download", "parallel_download"))
    failures = [r for r in all_rows if r.get("success") is not True]
    return {"protocols": dict(grouped), "comparisons_fcnv3_over_tuic": comparisons,
            "gates": gates, "metrics_pass": all(gates.values()), "issues": issues,
            "failures": failures, "batches": batches,
            "notes": ["Warm percentiles omit sample 1 of each retained-client batch; all attempts and failures remain counted.",
                      "Percentiles use linear interpolation on successful samples; failures independently fail acceptance.",
                      "Throughput uses verified bytes divided by full batch elapsed time, including failed attempts.",
                      "Environmental validity (same phone, server, target and unchanged network) requires the runner's separate evidence.",
                      "Timestamp payload makespan has 1ms start-time resolution; batch throughput uses the monotonic elapsed duration."]}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("results", type=Path)
    p.add_argument("--plan", type=Path)
    p.add_argument("--out", type=Path)
    args = p.parse_args()
    plan_path = args.plan or args.results / "plan.json"
    result = analyze(args.results, json.loads(plan_path.read_text()))
    output = args.out or args.results / "summary.json"
    output.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"summary": str(output), "metrics_pass": result["metrics_pass"],
                      "gates": result["gates"], "comparisons": result["comparisons_fcnv3_over_tuic"]}, indent=2))


if __name__ == "__main__":
    main()
