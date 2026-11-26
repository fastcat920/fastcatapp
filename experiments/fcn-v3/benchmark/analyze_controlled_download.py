#!/usr/bin/env python3
"""Analyze the controlled download matrix and its captured queue counters offline."""

import argparse
from collections import Counter, defaultdict
import json
from pathlib import Path
import re

from analyze import ratio, stats
from analyze_stall_udp import collect_download, download_metrics, flag, index_server, issue, read_object, read_rows


ARMS = ("current", "adaptive", "tuic")
LOSSES = (0, 2, 8)
DIRECTIONS = ("downlink", "uplink")
PAIRS = (("adaptive", "current"), ("current", "tuic"), ("adaptive", "tuic"))
COUNTERS = re.compile(r"^\s*Sent\s+(\d+)\s+bytes\s+(\d+)\s+pkts?\s+\(dropped\s+(\d+)\b")
PROBABILITY = re.compile(r"\bloss\s+(?:random\s+)?([\d.]+)%")


def optional_object(path, issues):
    try:
        return read_object(path)
    except (OSError, ValueError) as err:
        issue(issues, path, str(err))
        return {}


def tc_read(path):
    header = None
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("qdisc "):
            if header is not None:
                break
            if line.startswith("qdisc netem ") and "root" in line.split():
                header = line.strip()
        elif header is not None:
            match = COUNTERS.match(line)
            if match is not None:
                sent_bytes, sent_packets, dropped = map(int, match.groups())
                probability = PROBABILITY.search(header)
                return {"root_netem": header, "displayed_loss_percent": float(probability[1]) if probability else None,
                        "sent_bytes": sent_bytes, "sent_packets": sent_packets, "dropped_packets": dropped}
    raise ValueError("root netem Sent/dropped counters unavailable")


def tc_delta(directory, direction, issues):
    snapshots = {}
    for when in ("before", "after"):
        path = directory / f"tc-{when}-{direction}.txt"
        try:
            snapshots[when] = tc_read(path)
        except (OSError, ValueError) as err:
            issue(issues, path, str(err))
            snapshots[when] = None
    before, after = snapshots.values()
    delta = None
    if before is not None and after is not None:
        candidate = {key: after[key] - before[key] for key in ("sent_bytes", "sent_packets", "dropped_packets")}
        if before["root_netem"] != after["root_netem"] or min(candidate.values()) < 0:
            issue(issues, directory, "netem parameters changed or counters reset", direction=direction)
        else:
            delta = candidate
    return {**snapshots, "delta": delta}


def qdisc_block(directory, issues):
    metadata = optional_object(directory / "tc-block.json", issues)
    directions = {direction: tc_delta(directory, direction, issues) for direction in DIRECTIONS}
    return {"network_stable": metadata.get("network_stable"), "change": metadata.get("change"), **directions}


def qdisc_totals(blocks, downlink_loss, uplink_loss):
    result = {}
    for direction, configured in zip(DIRECTIONS, (downlink_loss, uplink_loss)):
        observations = [block[direction] for block in blocks]
        valid = [obs["delta"] for block, obs in zip(blocks, observations)
                 if block["network_stable"] is True and obs["delta"] is not None]
        totals = {key: sum(delta[key] for delta in valid) for key in ("sent_bytes", "sent_packets", "dropped_packets")}
        denominator = totals["sent_packets"] + totals["dropped_packets"]
        result[direction] = {
            "configured_loss_percent": configured, "blocks": len(observations), "blocks_with_usable_counters": len(valid),
            "displayed_loss_percent_values": sorted({obs["before"]["displayed_loss_percent"] for obs in observations
                                                       if obs["before"] is not None and obs["before"]["displayed_loss_percent"] is not None}),
            **totals, "counter_denominator_packets": denominator,
            "observed_drop_percent": 100 * totals["dropped_packets"] / denominator if denominator else None,
        }
    return result


def elapsed_between(start, end):
    return end - start if type(start) in (int, float) and type(end) in (int, float) and end >= start else None


def sample_timing(row):
    first_byte, headers, entry = (row.get(key) for key in ("first_byte_ms", "headers_ms", "entry_ms"))
    progress = row.get("body_progress")
    last = progress[-1] if isinstance(progress, list) and progress and isinstance(progress[-1], dict) else {}
    last_byte = last.get("offset_ms")
    if row["success"]:
        disposition = "verified"
    elif row["evidence"] != "valid":
        disposition = row["evidence"]
    elif row.get("error_stage") == "body":
        disposition = "body_after_first_byte" if first_byte is not None else "body_before_first_byte"
    else:
        disposition = row.get("error_stage", "unspecified")
    return {
        **{key: row.get(key) for key in ("round", "sample", "diagnostic_id", "evidence", "success", "error_stage",
                                        "error_category", "body_bytes_received", "entry_ms", "headers_ms", "first_byte_ms",
                                        "body_ms", "max_body_no_progress_ms", "total_ms", "origin_state")},
        "disposition": disposition, "entry_to_first_byte_ms": elapsed_between(entry, first_byte),
        "headers_to_first_byte_ms": elapsed_between(headers, first_byte),
        "first_to_last_body_byte_ms": elapsed_between(first_byte, last_byte),
        "first_byte_to_sample_end_ms": elapsed_between(first_byte, row.get("total_ms")),
    }


def timing_metrics(timings):
    result = {}
    for label, success in (("success", True), ("failure", False)):
        subset = [row for row in timings if row["success"] is success]
        result[label] = {key: stats([row[key] for row in subset]) for key in (
            "entry_ms", "first_byte_ms", "entry_to_first_byte_ms", "headers_to_first_byte_ms", "body_ms",
            "first_to_last_body_byte_ms", "first_byte_to_sample_end_ms", "max_body_no_progress_ms",
        )}
        observed_gaps = [row for row in subset if type(row["max_body_no_progress_ms"]) in (int, float)]
        result[label]["worst_body_gap_sample"] = max(observed_gaps, key=lambda row: row["max_body_no_progress_ms"], default=None)
    return result


def measured_rate(metrics, ending):
    elapsed = ending.get("elapsed_ms")
    return metrics["verified_bytes"] * 8 / elapsed / 1000 if type(elapsed) in (int, float) and elapsed > 0 else None


def batch_compare(arms, calibration):
    comparisons = {}
    stable = calibration["network_stable"] is True and all(calibration[d]["delta"] is not None for d in DIRECTIONS)
    for numerator, denominator in PAIRS:
        a, b = (arms.get(arm, {}) for arm in (numerator, denominator))
        observed = ratio(a.get("effective_batch_mbps"), b.get("effective_batch_mbps"))
        complete = all(row.get("valid_rows") == row.get("planned") == 4 and row.get("status") == "exited"
                       for row in (a, b))
        comparisons[f"{numerator}_over_{denominator}"] = {"ratio": observed, "comparable": observed is not None and complete and stable,
                                                         "complete_arm_evidence": complete, "usable_qdisc_evidence": stable}
    return comparisons


def study_treatment(root, loss, uplink_loss, root_origins, issues):
    treatment = root / f"loss-{loss}pct"
    plan = read_object(treatment / "plan.json")
    local_origins = index_server(treatment, issues, {"download"})[0] if (treatment / "server").is_dir() else {}
    origins = {**root_origins, **local_origins}
    jobs = [job for job in plan["jobs"] if job["phase"] == "download"]
    cached_path = treatment / "summary.json"
    cached = optional_object(cached_path, issues) if cached_path.is_file() else {}
    if cached and cached.get("run_id") != plan["run_id"]:
        issue(issues, cached_path, "summary run ID differs from plan")
        cached = {}

    by_round, by_arm = defaultdict(dict), defaultdict(list)
    summary_only = set()
    raw_arms = {path.stem for path in (treatment / "download").glob("round-*/*.jsonl")}
    for job in jobs:
        number, arm = job["round"], job["arm"]
        path = treatment / "download" / f"round-{number:02d}" / f"{arm}.jsonl"
        cached_arm = cached.get("download", {}).get(arm, {})
        cached_batch = next((row for row in cached_arm.get("rounds", []) if row["round"] == number), None)
        if arm not in raw_arms and cached_batch is not None:
            metrics = dict(cached_batch)
            rows = [row for row in cached_arm["failures"] if row["round"] == number]
            summary_only.add(arm)
        else:
            raw = read_rows(path, issues)
            rows, ending = collect_download(job, path, raw, int(flag(job, "-count")), flag(job, "-protocol"), origins, issues)
            metadata = optional_object(path.with_suffix(".meta.json"), issues)
            metrics = download_metrics(rows)
            metrics.update(effective_batch_mbps=measured_rate(metrics, ending), runner_metadata=metadata)
        by_arm[arm].extend(rows)
        by_round[number][arm] = {**{key: metrics.get(key) for key in (
            "planned", "valid_rows", "verified", "failed", "missing", "invalid", "effective_batch_mbps",
        )}, "status": metrics["runner_metadata"].get("status"), "exit_code": metrics["runner_metadata"].get("exit_code"),
            "position": job["position"], "diagnostic_id": job["diagnostic_id"]}

    rounds = []
    for number, arms in sorted(by_round.items()):
        directory = treatment / "download" / f"round-{number:02d}"
        calibration = qdisc_block(directory, issues)
        rounds.append({"round": number, "arms": arms, "qdisc": calibration, "paired_throughput": batch_compare(arms, calibration)})

    arm_metrics = {}
    for arm in ARMS:
        rows = by_arm[arm]
        if arm in summary_only:
            metrics = {k: v for k, v in cached["download"][arm].items() if k not in {"rounds", "failures"}}
        else:
            metrics = download_metrics(rows)
            metrics["effective_batch_mbps"] = stats([r["arms"].get(arm, {}).get("effective_batch_mbps") for r in rounds])
        timings = [sample_timing(r) for r in rows]
        failures = [{**row, "disposition": timing["disposition"]} for row, timing in zip(rows, timings) if not row["success"]]
        arm_metrics[arm] = {**metrics, "successful_raw_timing_rows": sum(row["success"] for row in rows),
                            "sample_timings": timings, "timing": timing_metrics(timings), "failures": failures,
                            "failure_dispositions": dict(Counter(row["disposition"] for row in failures))}
    pair_metrics = {}
    for numerator, denominator in PAIRS:
        key = f"{numerator}_over_{denominator}"
        pair_metrics[key] = stats([r["paired_throughput"][key]["ratio"] for r in rounds if r["paired_throughput"][key]["comparable"]])
    return {"run_id": plan["run_id"], "configured_downlink_loss_percent": loss, "rounds": rounds, "arms": arm_metrics,
            "paired_throughput_comparable": pair_metrics, "qdisc": qdisc_totals([r["qdisc"] for r in rounds], loss, uplink_loss)}


def analyze_controlled(root):
    plan = read_object(root / "plan.json")
    issues = []
    origins, _, logs = index_server(root, issues, {"download"}) if (root / "server").is_dir() else ({}, {}, {})
    restore = optional_object(root / "tc-restore.json", issues)
    return {
        "run_id": plan["run_id"],
        "calibration": {key: plan.get(key) for key in ("client_namespace", "server_namespace", "downlink_interface", "uplink_interface",
                                                        "delay_per_direction_ms", "rate_per_direction_mbit", "uplink_loss_percent",
                                                        "downlink_loss_percent")},
        "root_artifacts": {"files": sorted(path.name for path in root.iterdir() if path.is_file()),
                           "server_logs": logs, "tc_restore": restore},
        "treatments": {loss: study_treatment(root, loss, plan["uplink_loss_percent"], origins, issues) for loss in LOSSES},
        "issues": issues,
        "notes": [
            "The configured netem downlink random loss is a per-packet probability. Each connection encounters the draws corresponding to its packets in the qdisc's shared random sequence, so connections experience different loss sequences.",
            "Observed queue drop percentages use the sum of before-to-after dropped-packet deltas divided by the sum of sent plus dropped packet deltas across usable blocks. These queue-level counts include protocol and control traffic across each block and can also reflect queue overflow.",
            "Throughput uses fully verified bytes over comparator batch elapsed time. Paired summaries require complete sample rows and stable, usable queue evidence for the block. Measured request failures remain in that denominator.",
            "Entry and first byte are offsets from sample start. Body time covers the entire body-read phase. First-to-last body byte measures application delivery between positive reads. Header completion serves as the anchor for waiting on the first body byte.",
        ],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", required=True, type=Path, help="controlled runner output directory")
    parser.add_argument("--out", type=Path, help="write JSON here instead of printing it")
    args = parser.parse_args()
    text = json.dumps(analyze_controlled(args.root), indent=2, allow_nan=False) + "\n"
    if args.out is None:
        print(text, end="")
    else:
        args.out.write_text(text, encoding="utf-8")


if __name__ == "__main__":
    main()
