#!/usr/bin/env python3
"""Compare the two offline FCN download runs with crossed listener ports."""

import argparse
from collections import defaultdict
from itertools import permutations
import json
from pathlib import Path

from analyze import ratio, stats
from analyze_stall_udp import analyze, flag, read_object


ARMS = ("current", "adaptive", "tuic")
DEFAULT_PORTS = {
    "A": {"current": 18532, "adaptive": 18534, "tuic": 18533},
    "B": {"current": 18534, "adaptive": 18532, "tuic": 18533},
}
WORKLOAD = ("download", "1048576", "4", "4", "25s")
EXPECTED_ROUNDS = list(permutations(ARMS))


def load_ports(stage, path):
    if path is None:
        return DEFAULT_PORTS[stage], "declared default mapping"
    manifest = read_object(path)
    ports = manifest.get("ports", manifest)
    if not isinstance(ports, dict) or any(type(ports.get(arm)) is not int or not 1 <= ports[arm] <= 65535 for arm in ARMS):
        raise ValueError(f"{path} must specify a valid port for each arm")
    return {arm: ports[arm] for arm in ARMS}, str(path)


def time_window(records):
    starts = [r["start_unix_ms"] for r in records if type(r.get("start_unix_ms")) is int]
    ends = [r["end_unix_ms"] for r in records if type(r.get("end_unix_ms")) is int]
    return {"start_unix_ms": min(starts, default=None), "end_unix_ms": max(ends, default=None)}


def default_network(metadata):
    before, after = (metadata.get(key, {}) for key in ("before", "after"))
    net_id = before.get("default_net_id")
    if (metadata.get("network_stable") is True and before.get("validated") is True and after.get("validated") is True
            and type(net_id) is int and after.get("default_net_id") == net_id):
        return net_id
    return None


def round_entry(row):
    metadata = row.get("runner_metadata", {})
    return {
        **{key: row.get(key) for key in (
            "position", "planned", "valid_rows", "verified", "failed", "missing", "invalid", "first_byte_ms",
            "max_body_no_progress_ms", "effective_batch_mbps",
        )},
        **time_window([metadata]), "default_net_id": default_network(metadata),
        "exit_code": metadata.get("exit_code"), "process_status": metadata.get("status"),
    }


def paired_round(number, entries, order, plan_matches):
    current, adaptive = (entries.get(arm, {}) for arm in ARMS[:2])
    current_net, adaptive_net = (row.get("default_net_id") for row in (current, adaptive))
    observed_ratio = ratio(adaptive.get("effective_batch_mbps"), current.get("effective_batch_mbps"))
    issues = []
    if not plan_matches:
        issues.append("workload or order differs from the planned crossover")
    if any(row.get("valid_rows") != 4 or row.get("process_status") != "exited" for row in (current, adaptive)):
        issues.append("missing or invalid batch evidence")
    if current_net is None or adaptive_net != current_net:
        issues.append("default networks differ or lack validation")
    if observed_ratio is None:
        issues.append("throughput ratio unavailable")
    return {"round": number, "order": order, "arms": entries, "adaptive_over_current": observed_ratio,
            "comparable": not issues, "comparability_issues": issues}


def summarize_stage(label, root, manifest):
    plan = read_object(root / "plan.json")
    jobs = [job for job in plan["jobs"] if job["phase"] == "download"]
    if not jobs:
        raise ValueError(f"{root} does not contain a download plan")
    summary_path = root / "summary.json"
    if summary_path.is_file():
        summary = read_object(summary_path)
        if summary["run_id"] != plan["run_id"]:
            raise ValueError(f"{summary_path} does not match the plan's run ID")
    else:
        summary = analyze(root, {**plan, "jobs": jobs})

    ports, port_source = load_ports(label, manifest)
    planned_rounds = defaultdict(list)
    for job in jobs:
        planned_rounds[job["round"]].append(job)
    rounds, arms, metadata = defaultdict(dict), {}, []
    for arm in ARMS:
        data = summary["download"][arm]
        for row in data["rounds"]:
            rounds[row["round"]][arm] = round_entry(row)
        arm_metadata = [row.get("runner_metadata", {}) for row in data["rounds"]]
        metadata.extend(arm_metadata)
        failures = [{**row, "disposition": f"{row.get('error_stage', 'unknown')}/{row.get('error_category', 'unknown')}",
                     "arm": arm, "port": ports[arm]}
                    for row in data["failures"]]
        arms[arm] = {**{key: data[key] for key in (
            "planned", "valid_rows", "verified", "verified_bytes", "missing", "invalid", "failed",
            "first_byte_ms", "max_body_no_progress_ms", "effective_batch_mbps", "failure_stages",
            "failed_origin_states", "network_stable_rounds",
        )}, "port": ports[arm], **time_window(arm_metadata), "failures": failures}

    pairs = []
    for number in sorted(set(range(1, 7)) | planned_rounds.keys()):
        ordered_jobs = sorted(planned_rounds[number], key=lambda job: job["position"])
        order = tuple(job["arm"] for job in ordered_jobs)
        expected = EXPECTED_ROUNDS[number - 1] if 1 <= number <= 6 else None
        workload_matches = all(tuple(flag(job, key) for key in ("-phase", "-bytes", "-count", "-workers", "-timeout"))
                               == WORKLOAD for job in ordered_jobs)
        pairs.append(paired_round(number, rounds[number], order, order == expected and workload_matches))
    comparable_ratios = [p["adaptive_over_current"] for p in pairs if p["comparable"]]
    return {"run_id": plan["run_id"], "directory": str(root), "ports": ports, "port_source": port_source,
            **time_window(metadata), "arms": arms, "paired_rounds": pairs,
            "comparable_rounds": len(comparable_ratios), "adaptive_over_current_comparable_rounds": stats(comparable_ratios),
            "input_issues": [item for item in summary["issues"] if "/download/" in item["path"]]}


def comparison_cell(stage, arm):
    data = stage["arms"][arm]
    return {"run_id": stage["run_id"], "arm": arm, **{key: data[key] for key in (
        "port", "start_unix_ms", "end_unix_ms", "planned", "valid_rows", "verified", "missing", "invalid", "failed",
        "first_byte_ms", "max_body_no_progress_ms", "effective_batch_mbps",
    )}}


def analyze_crossover(first, second, first_ports=None, second_ports=None):
    stages = {"A": summarize_stage("A", first, first_ports), "B": summarize_stage("B", second, second_ports)}
    a, b = stages.values()
    a_ports, b_ports = a["ports"], b["ports"]
    crossed = (a_ports["current"] == b_ports["adaptive"] and a_ports["adaptive"] == b_ports["current"]
               and a_ports["current"] != a_ports["adaptive"])
    same_port = defaultdict(dict)
    for label, stage in stages.items():
        for arm in ARMS[:2]:
            same_port[stage["ports"][arm]].setdefault(label, []).append(comparison_cell(stage, arm))
    return {
        "stages": stages,
        "design": {
            "declared_fcn_ports_crossed": crossed, "declared_tuic_port_unchanged": a_ports["tuic"] == b_ports["tuic"],
            "distinct_run_ids": a["run_id"] != b["run_id"],
            "b_starts_after_a_ends": (a["end_unix_ms"] is not None and b["start_unix_ms"] is not None
                                     and b["start_unix_ms"] >= a["end_unix_ms"]),
        },
        "comparison_panel": {
            "same_port_across_stages": dict(same_port),
            "same_profile_across_stages": {arm: {label: comparison_cell(stage, arm) for label, stage in stages.items()}
                                           for arm in ARMS[:2]},
            "tuic_reference_across_stages": {label: comparison_cell(stage, "tuic") for label, stage in stages.items()},
        },
        "notes": [
            "Stage and arm times are host Unix milliseconds. First-byte distributions use successful samples.",
            "Effective batch throughput divides fully verified bytes by comparator batch elapsed time, including failed requests.",
            "Comparable throughput pairs require complete request rows, the planned workload and order, and the same validated default network ID.",
            "Same-port cells change profile and measurement time together. Same-profile cells change port and measurement time together. TUIC shows the reference at both times.",
        ],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--first", type=Path, required=True, help="stage A runner output directory")
    parser.add_argument("--second", type=Path, required=True, help="stage B runner output directory")
    parser.add_argument("--first-ports", type=Path, help="JSON manifest with stage A ports by arm")
    parser.add_argument("--second-ports", type=Path, help="JSON manifest with stage B ports by arm")
    parser.add_argument("--out", type=Path, help="write this JSON file instead of stdout")
    args = parser.parse_args()
    result = analyze_crossover(args.first, args.second, args.first_ports, args.second_ports)
    text = json.dumps(result, indent=2, allow_nan=False) + "\n"
    if args.out is None:
        print(text, end="")
    else:
        args.out.write_text(text, encoding="utf-8")


if __name__ == "__main__":
    main()
