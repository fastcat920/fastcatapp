#!/usr/bin/env python3
"""Summarize the five-protocol Wi-Fi benchmark from captured files."""

import argparse
from collections import Counter, defaultdict
import json
from pathlib import Path

from analyze import stats
from analyze_stall_udp import (
    UDP_SIZES, collect_udp, download_metrics, index_server, issue, normalized_row,
    origin_state, phase_rows, read_object, read_rows, udp_metrics,
)
from run_five_protocols import ARMS, WORKLOADS


def option(args, name, default=None):
    return args[args.index(name) + 1] if name in args else default


def positive_metric(value):
    return type(value) in (int, float) and value >= 0


def validate_plan(plan):
    seen, phases = set(), set()
    for job in plan["jobs"]:
        phase, arm, number = job["phase"], job["arm"], job["round"]
        key = phase, arm, number
        if phase not in WORKLOADS or arm not in ARMS or type(number) is not int or not 1 <= number <= 5 or key in seen:
            raise ValueError(f"invalid or duplicate plan job {key}")
        flags, budget, _, count = WORKLOADS[phase]
        args = job["args"]
        if job["planned"] != count or option(args, "-protocol") != arm or option(args, "-timeout") != f"{budget}s":
            raise ValueError(f"workload or protocol differs from the expected plan for {key}")
        if phase == "udp":
            if "-udp-diagnostic" not in args or option(args, "-count") != str(count):
                raise ValueError(f"UDP flags differ from the expected plan for {key}")
        elif (any(option(args, name) != value for name, value in zip(flags[::2], flags[1::2])) or
              option(args, "-diagnostic-id") != job["diagnostic_id"] or
              option(args, "-workers", "1") != option(flags, "-workers", "1")):
            raise ValueError(f"TCP flags differ from the expected plan for {key}")
        seen.add(key)
        phases.add(phase)
    expected = {(phase, arm, round_number) for phase in phases for arm in ARMS for round_number in range(1, 6)}
    if not phases or seen != expected:
        raise ValueError("the plan must describe five rounds for each protocol in every included workload")


def network_valid(metadata, expected):
    network_id = expected.get("default_net_id")
    if type(network_id) is not int or expected.get("validated") is not True or expected.get("transports") != ["WIFI"]:
        return False
    for when in ("before", "after"):
        snapshot = metadata.get(when, {})
        if (snapshot.get("validated") is not True or snapshot.get("transports") != ["WIFI"] or
                snapshot.get("default_net_id") != network_id):
            return False
    return metadata.get("network_stable") is True


def validate_tcp_row(row, phase, arm, index, workers, size, diagnostic_id):
    expected = {"protocol": arm, "phase": phase, "bytes": size, "workers": workers,
                "diagnostic_id": diagnostic_id, "client_lifecycle": "new" if phase == "cold" else "retained"}
    if (any(row.get(key) != value for key, value in expected.items()) or type(row.get("success")) is not bool or
            row.get("first_in_batch") is not (index == 1)):
        return False
    if not row["success"]:
        return row.get("verified_bytes") == 0 and isinstance(row.get("error_stage"), str)
    body_bytes = len(str(size)) if phase == "upload" else size
    timings = [row.get(key) for key in ("entry_ms", "headers_ms", "first_byte_ms", "total_ms")]
    body = row.get("body_ms")
    gap = row.get("max_body_no_progress_ms")
    return (row.get("verified_bytes") == size and row.get("body_bytes_received") == body_bytes
            and all(positive_metric(value) for value in timings) and timings == sorted(timings)
            and positive_metric(gap) and positive_metric(body) and gap <= body <= timings[-1])


def collect_tcp(job, path, objects, origins, issues):
    args, count, arm = job["args"], job["planned"], job["arm"]
    phase = option(args, "-phase")
    workers, size = int(option(args, "-workers", "1")), int(option(args, "-bytes"))
    candidates, ending = phase_rows(objects, "sample", "batch-ended", "sample", count, path, issues)
    rows = []
    for index in range(1, count + 1):
        diagnostic_id = f"{job['diagnostic_id']}-{index}"
        recorded = candidates[index]
        valid = len(recorded) == 1 and validate_tcp_row(recorded[0], phase, arm, index, workers, size, diagnostic_id)
        row = normalized_row(recorded, valid, path, issues, index)
        receipts = origins.get(diagnostic_id, [])
        row.update(sample=index, diagnostic_id=diagnostic_id, bytes=size, success=row.get("success") is True,
                   origin_state="untraced" if phase == "upload" else origin_state(receipts, size), origin_receipts=receipts)
        rows.append(row)
    verified = sum(row["success"] for row in rows)
    expected = {"protocol": arm, "phase": phase, "bytes": size, "count": count, "workers": workers,
                "success": verified, "failed": count - verified, "verified_bytes": verified * size}
    valid_ending = bool(ending) and all(ending.get(key) == value for key, value in expected.items())
    if ending and not valid_ending:
        issue(issues, path, "TCP batch summary disagrees with planned workload or validated rows")
    elapsed = ending.get("elapsed_ms")
    throughput = (verified * size * 8 / elapsed / 1000
                  if valid_ending and positive_metric(elapsed) and elapsed > 0 and all(r["evidence"] == "valid" for r in rows) else None)
    return rows, ending, throughput


def collect_udp_rows(job, path, objects, echoes, issues):
    if "-udp-wire-rx" in job["args"]:
        objects = [row for row in objects if row["event"] != "udp_wire_rx"]
    rows, ending = collect_udp(job, path, objects, job["planned"], job["arm"], echoes, issues)
    for row in rows:
        if row["echoed"] and (not positive_metric(row.get("echo_rtt_ms")) or row.get("error_stage")):
            issue(issues, path, "UDP echoed row has an invalid RTT or failure stage", index=row["sequence"])
            original = dict(row)
            row.update(evidence="invalid", error_stage="invalid_row", error_category="malformed",
                       source_rows=[original], attempted=False, submitted=False, echoed=False)
    return rows, ending


def sample_counts(rows, success_key):
    return {"verified_valid_network": sum(r.get(success_key) is True and r["network_valid"] for r in rows),
            "network_invalid": sum(not row["network_valid"] for row in rows),
            "network_invalid_verified": sum(r.get(success_key) is True and not r["network_valid"] for r in rows)}


def summarize_udp(rows):
    metrics = udp_metrics(rows)
    good = [row for row in rows if row["echoed"] and row["network_valid"]]
    comparable = [row for row in rows if row["network_valid"]]
    bad = [row for row in rows if not row["echoed"]]
    stages = Counter((str(row.get("error_stage", "unspecified")), str(row.get("error_category", "unspecified"))) for row in bad)
    return {**metrics, **sample_counts(rows, "echoed"), "echo_rtt_ms": stats([row.get("echo_rtt_ms") for row in good]),
            "planned_valid_network": len(comparable), "echo_valid_network_fraction": len(good) / len(comparable) if comparable else None,
            "failure_stage_categories": [{"stage": stage, "category": category, "count": count}
                                         for (stage, category), count in sorted(stages.items())]}


def summarize_group(phase, rows, batches):
    if phase == "udp":
        metrics = summarize_udp(rows)
        metrics["common_64_to_1100"] = summarize_udp([row for row in rows if row["bytes"] <= 1100])
        metrics["bytes_1150"] = summarize_udp([row for row in rows if row["bytes"] == 1150])
        metrics["by_size"] = {size: summarize_udp([row for row in rows if row["bytes"] == size]) for size in UDP_SIZES}
        key = "echoed"
    else:
        metrics = {**download_metrics(rows), **sample_counts(rows, "success")}
        good = [row for row in rows if row["success"] and row["network_valid"] and (phase != "warm" or row["sample"] > 1)]
        metrics["first_byte_ms"] = stats([row["first_byte_ms"] for row in good])
        metrics["effective_batch_mbps"] = stats([batch["effective_batch_mbps"] for batch in batches if batch["network_valid"]])
        if phase == "warm":
            first = [row for row in rows if row["sample"] == 1]
            metrics["excluded_first_samples"] = {"planned": len(first), "verified": sum(row["success"] for row in first),
                                                 "failed": sum(not row["success"] for row in first)}
        if phase == "parallel":
            bad = [row for row in rows if not row["success"] and row["network_valid"]]
            metrics["max_body_no_progress_ms"] = {"success": stats([row.get("max_body_no_progress_ms") for row in good]),
                                                  "failure": stats([row.get("max_body_no_progress_ms") for row in bad])}
        key = "success"
    return {**metrics, "batches": batches, "failures": [row for row in rows if not row[key]],
            "network_invalid_samples": [row for row in rows if not row["network_valid"]]}


def make_tables(arms):
    tables = {phase: [] for phase in WORKLOADS}
    for arm, phases in arms.items():
        for phase, metrics in phases.items():
            table = {"protocol": arm, **{key: metrics[key] for key in ("planned", "failed", "missing", "invalid",
                                                                       "network_invalid", "verified_valid_network")}}
            if phase in {"cold", "warm"}:
                table["first_byte_ms"] = metrics["first_byte_ms"]
            elif phase == "udp":
                table.update(common_64_to_1100=metrics["common_64_to_1100"], bytes_1150=metrics["bytes_1150"])
            else:
                table["effective_batch_mbps"] = metrics["effective_batch_mbps"]
                if phase == "parallel":
                    table["max_body_no_progress_ms"] = metrics["max_body_no_progress_ms"]
            tables[phase].append(table)
    return tables


def analyze_five(root):
    plan = read_object(root / "plan.json")
    validate_plan(plan)
    issues = []
    phases = {job["phase"] for job in plan["jobs"]}
    origins, echoes, logs = index_server(root, issues, phases | ({"download"} if phases - {"udp"} else set()))
    issues = [item for item in issues if Path(item["path"]).name not in {"adaptive.jsonl", "current.jsonl"}
              or Path(item["path"]).is_file()]
    logs = {name: entry for name, entry in logs.items() if name in {"origin", "echo"} or entry["present"]}
    by_group, batches = defaultdict(list), defaultdict(list)
    for job in plan["jobs"]:
        phase, arm, number = job["phase"], job["arm"], job["round"]
        path = root / phase / f"round-{number:02d}" / f"{arm}.jsonl"
        objects = read_rows(path, issues)
        meta_path = path.with_suffix(".meta.json")
        try:
            metadata = read_object(meta_path)
        except (OSError, ValueError) as err:
            issue(issues, meta_path, str(err))
            metadata = {}
        metadata_matches = all(metadata.get(key) == job[key] for key in ("phase", "arm", "round", "position", "diagnostic_id"))
        if metadata and not metadata_matches:
            issue(issues, meta_path, "batch metadata differs from the planned job", round=number, protocol=arm)
        stable = metadata_matches and network_valid(metadata, plan.get("network", {}))
        if not stable:
            issue(issues, meta_path, "batch lacks the planned validated Wi-Fi network", round=number, protocol=arm)
        throughput = None
        if phase == "udp":
            rows, ending = collect_udp_rows(job, path, objects, echoes, issues)
        else:
            rows, ending, throughput = collect_tcp(job, path, objects, origins, issues)
        for row in rows:
            row.update(round=number, workload=phase, protocol=arm, network_valid=stable)
        key = "echoed" if phase == "udp" else "success"
        group = (arm, phase)
        by_group[group].extend(rows)
        batches[group].append({"round": number, "position": job["position"], "entry_port": job["entry_port"],
                               "planned": job["planned"], "verified": sum(row[key] for row in rows),
                               "effective_batch_mbps": throughput, "network_valid": stable,
                               "valid_rows": sum(row["evidence"] == "valid" for row in rows),
                               "comparator_summary": ending, "runner_metadata": metadata})

    arms = {arm: {phase: summarize_group(phase, by_group[arm, phase], batches[arm, phase])
                  for phase in WORKLOADS if phase in phases} for arm in ARMS}
    return {
        "run_id": plan["run_id"], "network": plan.get("network", {}), "ports": plan.get("ports", {}),
        "arms": arms, "tables": make_tables(arms), "server_logs": logs, "issues": issues,
        "notes": [
            "Latency and throughput distributions use batches with the planned validated Wi-Fi network; row counts preserve missing, invalid and network-invalid attempts.",
            "Warm first-byte percentiles exclude the first request of every batch and include only successful requests.",
            "Effective transfer throughput divides fully verified bytes by comparator batch elapsed time, including time spent on failed requests. A full set of validated rows and a matching batch summary are required.",
            "The 1,150-byte UDP probes have their own denominator and failure stages. Common-size UDP RTT uses exactly echoed, valid-network probes from 64 through 1,100 bytes.",
        ],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True, help="existing runner output directory")
    args = parser.parse_args()
    result = analyze_five(args.out)
    path = args.out / "summary.json"
    path.write_text(json.dumps(result, indent=2, allow_nan=False) + "\n", encoding="utf-8")
    print(path)


if __name__ == "__main__":
    main()
