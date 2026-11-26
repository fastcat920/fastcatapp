#!/usr/bin/env python3
"""Summarize FCN Android diagnostics from local runner and server JSON files."""

import argparse
from collections import Counter, defaultdict
import json
import math
from pathlib import Path
import re

from analyze import stats


UDP_SIZES = (64, 256, 512, 900, 1000, 1100, 1150)
UDP_RUN_ID = re.compile(r"[0-9a-f]{16}")


def reject_constant(value):
    raise ValueError(f"non-finite JSON number {value}")


def finite_float(value):
    number = float(value)
    if not math.isfinite(number):
        reject_constant(value)
    return number


def read_object(path):
    value = json.loads(path.read_text(encoding="utf-8"), parse_constant=reject_constant, parse_float=finite_float)
    if not isinstance(value, dict):
        raise ValueError("expected a JSON object")
    return value


def issue(issues, path, error, **detail):
    issues.append({"path": str(path), "error": error, **detail})


def read_rows(path, issues):
    rows = []
    try:
        with path.open(encoding="utf-8", errors="replace") as stream:
            for number, line in enumerate(stream, start=1):
                if not line.strip():
                    continue
                try:
                    row = json.loads(line, parse_constant=reject_constant, parse_float=finite_float)
                    if not isinstance(row, dict) or not isinstance(row.get("event"), str):
                        raise ValueError("expected an event object")
                except ValueError as err:
                    issue(issues, path, str(err), line=number)
                    continue
                rows.append(row)
    except OSError as err:
        issue(issues, path, err.strerror)
    return rows


def index_server(root, issues, phases):
    origins, echoes, logs = defaultdict(list), defaultdict(list), {}
    phase_for_log = {"origin": "download", "echo": "udp"}
    for name in ("origin", "echo", "current", "adaptive"):
        path = root / "server" / f"{name}.jsonl"
        issue_start = len(issues)
        optional = name in phase_for_log and phase_for_log[name] not in phases
        rows = [] if optional and not path.exists() else read_rows(path, issues)
        for row in rows:
            event = row["event"]
            if name == "origin" and event == "origin_body":
                key = row.get("diagnostic_id")
                if isinstance(key, str) and key:
                    origins[key].append(row)
                else:
                    issue(issues, path, "origin receipt lacks a diagnostic ID")
            if name == "echo" and event in {"receive", "response"}:
                run_id, seq, size = row.get("run_id"), row.get("seq"), row.get("size")
                if isinstance(run_id, str) and UDP_RUN_ID.fullmatch(run_id) and type(seq) is int and type(size) is int:
                    echoes[(run_id, seq, size)].append(row)
                else:
                    issue(issues, path, "echo receipt has an invalid join key")
        logs[name] = {"present": path.is_file(), "rows": len(rows), "event_counts": dict(Counter(r["event"] for r in rows)),
                      "issues": len(issues) - issue_start}
    return origins, echoes, logs


def flag(job, name):
    args = job["args"]
    return args[args.index(name) + 1]


def validate_download(row, job, size, protocol, diagnostic_id):
    expected = {"protocol": protocol, "phase": "download", "bytes": size, "workers": int(flag(job, "-workers")),
                "diagnostic_id": diagnostic_id}
    if any(row.get(key) != value for key, value in expected.items()) or type(row.get("success")) is not bool:
        return False
    if row["success"]:
        return row.get("verified_bytes") == size and row.get("body_bytes_received") == size
    return row.get("verified_bytes") == 0


def validate_udp(row, protocol, size, run_id):
    valid_flags = all(type(row.get(key)) is bool for key in ("attempted", "submitted", "echoed"))
    return (run_id is not None and row.get("run_id") == run_id and row.get("protocol") == protocol
            and row.get("bytes") == size and valid_flags and row["attempted"] >= row["submitted"] >= row["echoed"])


def phase_rows(objects, sample_event, ending_event, index_key, count, path, issues):
    by_index, endings = defaultdict(list), []
    for row in objects:
        if row["event"] == ending_event:
            endings.append(row)
        elif row["event"] == sample_event:
            index = row.get(index_key)
            if type(index) is int and 1 <= index <= count:
                by_index[index].append(row)
            else:
                issue(issues, path, "invalid sample index", index=index)
        else:
            issue(issues, path, "unexpected event", event=row["event"])
    if len(endings) != 1:
        issue(issues, path, f"expected one {ending_event} row", recorded=len(endings))
    return by_index, endings[0] if len(endings) == 1 else {}


def normalized_row(rows, valid, path, issues, index):
    if not rows:
        return {"evidence": "missing", "error_stage": "missing_row", "error_category": "missing"}
    if len(rows) != 1 or not valid:
        issue(issues, path, "duplicate or mismatched sample", index=index, recorded=len(rows))
        return {"evidence": "invalid", "error_stage": "invalid_row", "error_category": "malformed",
                "source_rows": rows}
    return {**rows[0], "evidence": "valid"}


def origin_state(receipts, size):
    if not receipts:
        return "missing"
    if len(receipts) > 1:
        return "multiple"
    receipt = receipts[0]
    return "complete" if receipt.get("bytes_written") == size and receipt.get("error") is False else "incomplete"


def collect_download(job, path, objects, count, protocol, origins, issues):
    by_index, ending = phase_rows(objects, "sample", "batch-ended", "sample", count, path, issues)
    expected_bytes = int(flag(job, "-bytes"))
    rows = []
    for index in range(1, count + 1):
        diagnostic_id = f"{job['diagnostic_id']}-{index}"
        candidates = by_index[index]
        valid = len(candidates) == 1 and validate_download(candidates[0], job, expected_bytes, protocol, diagnostic_id)
        row = normalized_row(candidates, valid, path, issues, index)
        receipts = origins.get(diagnostic_id, [])
        row.update(sample=index, diagnostic_id=diagnostic_id, round=job["round"], bytes=expected_bytes,
                   success=row.get("success") is True,
                   origin_state=origin_state(receipts, expected_bytes), origin_receipts=receipts)
        rows.append(row)
    if ending and (ending.get("count") != count or ending.get("verified_bytes") != sum(r.get("verified_bytes", 0) for r in rows)
                   or ending.get("failed") != sum(r.get("success") is not True for r in rows)):
        issue(issues, path, "download batch summary disagrees with normalized rows")
    return rows, ending


def collect_udp(job, path, objects, count, protocol, echoes, issues):
    by_index, ending = phase_rows(objects, "udp_packet", "udp_summary", "sequence", count, path, issues)
    reported_id = ending.get("run_id")
    run_ids = {row["run_id"] for rows in by_index.values() for row in rows
               if isinstance(row.get("run_id"), str) and UDP_RUN_ID.fullmatch(row["run_id"])}
    run_id = reported_id if isinstance(reported_id, str) and UDP_RUN_ID.fullmatch(reported_id) else None
    if run_id is None and len(run_ids) == 1:
        run_id = next(iter(run_ids))
    rows = []
    for index in range(1, count + 1):
        size = UDP_SIZES[(index - 1) % len(UDP_SIZES)]
        candidates = by_index[index]
        valid = len(candidates) == 1 and validate_udp(candidates[0], protocol, size, run_id)
        row = normalized_row(candidates, valid, path, issues, index)
        receipts = echoes.get((run_id, index, size), [])
        row.update(sequence=index, bytes=size, run_id=run_id, round=job["round"], echo_receipts=receipts,
                   attempted=row.get("attempted") is True, submitted=row.get("submitted") is True,
                   echoed=row.get("echoed") is True,
                   server_received=any(r["event"] == "receive" for r in receipts),
                   server_responded=any(r["event"] == "response" for r in receipts))
        rows.append(row)
    if ending and (reported_id != run_id or ending.get("planned") != count or
                   any(ending.get(key) != sum(r.get(key) is True for r in rows) for key in ("attempted", "submitted", "echoed"))):
        issue(issues, path, "UDP batch summary disagrees with normalized rows")
    return rows, ending


def outcome_counts(rows, successful):
    failures = [row for row in rows if row.get(successful) is not True]
    evidence = Counter(row["evidence"] for row in rows)
    return {"planned": len(rows), "valid_rows": evidence["valid"], "missing": evidence["missing"],
            "invalid": evidence["invalid"], "failed": len(failures),
            "failure_stages": dict(Counter(str(row.get("error_stage", "unspecified")) for row in failures))}


def download_metrics(rows):
    good = [r for r in rows if r.get("success") is True]
    failed = [r for r in rows if r.get("success") is not True]
    return {**outcome_counts(rows, "success"), "verified": len(good), "verified_bytes": sum(r["verified_bytes"] for r in good),
            "first_byte_ms": stats([r.get("first_byte_ms") for r in good]),
            "max_body_no_progress_ms": {
                "success": stats([r.get("max_body_no_progress_ms") for r in good]),
                "failure": stats([r.get("max_body_no_progress_ms") for r in failed]),
            },
            "failed_origin_states": dict(Counter(r["origin_state"] for r in failed))}


def udp_metrics(rows):
    echoed = [r for r in rows if r.get("echoed") is True]
    failures_by_stage = defaultdict(list)
    for row in rows:
        if not row["echoed"]:
            failures_by_stage[str(row.get("error_stage", "unspecified"))].append(row)
    return {**outcome_counts(rows, "echoed"), "attempted": sum(r.get("attempted") is True for r in rows),
            "submitted": sum(r.get("submitted") is True for r in rows), "echoed": len(echoed),
            "server_received": sum(r["server_received"] for r in rows), "server_responded": sum(r["server_responded"] for r in rows),
            "echo_rtt_ms": stats([r.get("echo_rtt_ms") for r in echoed]),
            "failure_echo_evidence": {
                stage: {"received": sum(r["server_received"] for r in failures),
                        "responded": sum(r["server_responded"] for r in failures)}
                for stage, failures in failures_by_stage.items()
            }}


def analyze(root, plan):
    issues = []
    origins, echoes, logs = index_server(root, issues, {job["phase"] for job in plan["jobs"]})
    by_arm, rounds = defaultdict(list), defaultdict(list)
    for job in plan["jobs"]:
        phase, arm, number = job["phase"], job["arm"], job["round"]
        if phase not in {"download", "udp"} or arm not in {"current", "adaptive", "tuic"}:
            raise ValueError("unknown runner workload or arm")
        issue_start = len(issues)
        path = root / phase / f"round-{number:02d}" / f"{arm}.jsonl"
        objects = read_rows(path, issues)
        meta_path = path.with_suffix(".meta.json")
        try:
            metadata = read_object(meta_path)
        except (OSError, ValueError) as err:
            issue(issues, meta_path, str(err))
            metadata = {}
        count, protocol = int(flag(job, "-count")), flag(job, "-protocol")
        if phase == "download":
            rows, ending = collect_download(job, path, objects, count, protocol, origins, issues)
            metrics = download_metrics(rows)
            elapsed = ending.get("elapsed_ms")
            metrics["effective_batch_mbps"] = (metrics["verified_bytes"] * 8 / elapsed / 1000
                                                if type(elapsed) in (int, float) and elapsed > 0 else None)
        else:
            if "-udp-wire-rx" in job["args"]:
                objects = [row for row in objects if row["event"] != "udp_wire_rx"]
            rows, ending = collect_udp(job, path, objects, count, protocol, echoes, issues)
            metrics = udp_metrics(rows)
        by_arm[(phase, arm)].extend(rows)
        rounds[(phase, arm)].append({"round": number, "position": job["position"], **metrics,
                                     "input_issues": len(issues) - issue_start,
                                     "comparator_summary": ending, "runner_metadata": metadata})

    result = {"run_id": plan["run_id"], "download": {}, "udp": {}, "server_logs": logs, "issues": issues}
    for (phase, arm), rows in by_arm.items():
        arm_rounds = rounds[(phase, arm)]
        if phase == "download":
            metrics = download_metrics(rows)
            metrics["effective_batch_mbps"] = stats([r["effective_batch_mbps"] for r in arm_rounds])
            success_key = "success"
        else:
            metrics = udp_metrics(rows)
            metrics["by_size"] = {size: udp_metrics([r for r in rows if r["bytes"] == size]) for size in UDP_SIZES}
            success_key = "echoed"
        result[phase][arm] = {**metrics, "rounds": arm_rounds,
                              "input_issues": sum(r["input_issues"] for r in arm_rounds),
                              "network_stable_rounds": sum(r["runner_metadata"].get("network_stable") is True for r in arm_rounds),
                              "failures": [r for r in rows if r.get(success_key) is not True]}
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True, help="existing runner output directory")
    args = parser.parse_args()
    result = analyze(args.out, read_object(args.out / "plan.json"))
    summary = args.out / "summary.json"
    summary.write_text(json.dumps(result, indent=2, allow_nan=False) + "\n", encoding="utf-8")
    print(summary)


if __name__ == "__main__":
    main()
