#!/usr/bin/env python3
"""Compare paired Android Wi-Fi and cellular UDP diagnostics offline."""

import argparse
from collections import Counter
import json
from pathlib import Path

from analyze_stall_udp import UDP_SIZES, collect_udp, flag, issue, read_object, read_rows


ARMS = ("current", "adaptive", "tuic")
NETWORKS = {"wifi": "WIFI", "cellular": "CELLULAR"}
QUEUE_STATUSES = {"not_observed", "unsupported", "unavailable", "no_notice", "partial", "reported"}
QUEUE_SOCKETS = ("sockets", "enabled_sockets", "reported_sockets", "unsupported_sockets", "enable_failed_sockets")


def optional_object(path, issues, run_id=None):
    try:
        value = read_object(path)
        if run_id is not None and value.get("run_id") != run_id:
            raise ValueError("summary run ID differs from plan")
        return value
    except (ValueError, OSError) as err:
        issue(issues, path, err.strerror if isinstance(err, OSError) else str(err))
        return {}


def transport_evidence(metadata, expected):
    def snapshot(field):
        source = metadata.get(field)
        if not isinstance(source, dict):
            source = {}
        return {key: source.get(key) for key in ("default_net_id", "transports", "validated")}

    before, after = snapshot("before"), snapshot("after")
    stable = (before["validated"] is True and after["validated"] is True
              and type(before["default_net_id"]) is int and before["default_net_id"] == after["default_net_id"]
              and metadata.get("network_stable") is True)
    expected_validated = stable and before["transports"] == after["transports"] == [expected]
    return {"before": before, "after": after, "stable": stable, "expected_validated": expected_validated}


def queue_observation(ending):
    observer = ending.get("wire_rx")
    if not isinstance(observer, dict):
        observer = {}
    queue = observer.get("rxq_overflow")
    result = {"wire_observer_captured": observer.get("captured"), "wire_observer_dropped": observer.get("dropped")}
    if not isinstance(queue, dict) or queue.get("status") not in QUEUE_STATUSES:
        return {**result, "status": "unknown", "reported_drops": None}
    status = queue["status"]
    count = queue.get("reported_drops")
    count = count if status in {"partial", "reported"} and type(count) is int and count >= 0 else None
    return {**result, "status": status, "reported_drops": count,
            **{key: queue.get(key) for key in QUEUE_SOCKETS}}


def queue_totals(batches):
    observations = [batch["kernel_queue"] for batch in batches]
    counts = [obs["reported_drops"] for obs in observations if obs["reported_drops"] is not None]
    return {"batches": len(observations), "status_counts": dict(Counter(obs["status"] for obs in observations)),
            "batches_with_reported_count": len(counts), "batches_with_positive_count": sum(n > 0 for n in counts),
            "reported_drops_lower_bound": sum(counts) if counts else None}


def reference(row):
    return row.get("round"), row.get("sequence"), row.get("run_id"), row.get("bytes")


def index_failures(rows, path, issues):
    indexed, duplicates = {}, set()
    for row in rows:
        key = reference(row)
        if key in indexed:
            duplicates.add(key)
            issue(issues, path, "duplicate failure reference", round=key[0], sequence=key[1])
        indexed[key] = row
    return {key: row for key, row in indexed.items() if key not in duplicates}


def timeout(row):
    return row["evidence"] == "valid" and row.get("error_stage") == "echo" and row.get("error_category") == "timeout"


def failure(row, source, standard, wire):
    receipt = standard if standard else wire
    received, responded = receipt.get("server_received"), receipt.get("server_responded")
    if type(received) is not bool or type(responded) is not bool:
        ingress = "receipt_evidence_unavailable"
    elif received:
        ingress = "loopback_received_and_responded" if responded else "loopback_receive_receipt_only"
    else:
        ingress = "loopback_response_receipt_only" if responded else "no_loopback_receipt_logged"
    return {**{key: row.get(key) for key in (
        "round", "sequence", "run_id", "bytes", "evidence", "attempted", "submitted", "error_stage", "error_category",
        "send_unix_ns", "echo_deadline_unix_ns",
    )}, "raw_file": source, "timeout": timeout(row), "ingress": ingress,
        "server_received": received, "server_responded": responded,
        "wire_classification": wire.get("classification", "wire_evidence_unavailable"),
        "egress_candidates": wire.get("egress_candidates"), "candidates": wire.get("candidates", [])}


def counts(rows, failures):
    timed_out = [row for row in failures if row["timeout"]]
    planned = len(rows)
    echoed = sum(row["echoed"] for row in rows)
    return {
        "planned": planned, "valid_rows": sum(row["evidence"] == "valid" for row in rows), "echoed": echoed,
        "missing_rows": sum(row["evidence"] == "missing" for row in rows),
        "invalid_rows": sum(row["evidence"] == "invalid" for row in rows),
        "attempted": sum(row["attempted"] for row in rows), "submitted": sum(row["submitted"] for row in rows),
        "failed": len(failures), "timeouts": len(timed_out),
        "echo_rate_percent_of_planned": 100 * echoed / planned if planned else None,
        "timeout_rate_percent_of_planned": 100 * len(timed_out) / planned if planned else None,
        "failure_stages": dict(Counter(row["error_stage"] or "unspecified" for row in failures)),
        "timeout_ingress": dict(Counter(row["ingress"] for row in timed_out)),
        "timeout_return_candidates": dict(Counter(row["wire_classification"] for row in timed_out)),
    }


def workload(job, ports):
    args = job["args"]
    return {
        "count": int(flag(job, "-count")), "protocol": flag(job, "-protocol"),
        "timeout": flag(job, "-timeout") if "-timeout" in args else None,
        "entry_port": job.get("entry_port", ports.get(job["arm"])),
        "wire_capture_requested": "-udp-wire-rx" in args,
    }


def load_batch(root, job, ports, expected, standard, wire, issues):
    inputs = workload(job, ports)
    source = Path("udp") / f"round-{job['round']:02d}" / f"{job['arm']}.jsonl"
    path = root / source
    start_issues = len(issues)
    objects = [row for row in read_rows(path, issues) if row["event"] != "udp_wire_rx"]
    rows, ending = collect_udp(job, path, objects, inputs["count"], inputs["protocol"], {}, issues)
    complete = bool(ending) and len(issues) == start_issues and all(row["evidence"] == "valid" for row in rows)
    metadata = optional_object(path.with_suffix(".meta.json"), issues)
    raw_file = source.as_posix()
    failures = [failure(row, raw_file, standard.get(reference(row), {}), wire.get(reference(row), {}))
                for row in rows if not row["echoed"]]
    return {"round": job["round"], "position": job.get("position"), "raw_file": raw_file, "workload": inputs,
            "transport": transport_evidence(metadata, expected), "runner_status": metadata.get("status"),
            "runner_exit_code": metadata.get("exit_code"), "complete": complete, "kernel_queue": queue_observation(ending),
            "rows": rows, "failures": failures}


def batch_metrics(batches):
    rows = [row for batch in batches for row in batch["rows"]]
    failures = [row for batch in batches for row in batch["failures"]]
    return {**counts(rows, failures), "kernel_queue": queue_totals(batches),
            "by_payload_bytes": {
                str(size): counts([row for row in rows if row["bytes"] == size],
                                  [row for row in failures if row["bytes"] == size])
                for size in UDP_SIZES
            }}


def load_network(root, expected):
    plan = read_object(root / "plan.json")
    jobs = [job for job in plan["jobs"] if job["phase"] == "udp"]
    ids = {(job["arm"], job["round"]) for job in jobs}
    if (not jobs or len(ids) != len(jobs)
            or any(arm not in ARMS or type(number) is not int or number < 1 for arm, number in ids)):
        raise ValueError(f"{root} has an invalid UDP job plan")
    issues, arms, batches = [], {}, {}
    summary_path, wire_path = root / "summary.json", root / "wire-summary.json"
    summary = optional_object(summary_path, issues, plan["run_id"])
    wire = optional_object(wire_path, issues, plan["run_id"])
    for path, document in ((summary_path, summary), (wire_path, wire)):
        if document.get("issues"):
            issue(issues, path, "source analysis reported input issues", count=len(document["issues"]))

    for arm in ARMS:
        arm_summary = summary.get("udp", {}).get(arm, {})
        arm_wire = wire.get("arms", {}).get(arm, {})
        standard_refs = index_failures(arm_summary.get("failures", []), summary_path, issues)
        wire_refs = index_failures(arm_wire.get("failures", []), wire_path, issues)
        group = [
            load_batch(root, job, plan.get("ports", {}), expected, standard_refs, wire_refs, issues)
            for job in jobs if job["arm"] == arm
        ]
        all_metrics = batch_metrics(group)
        for path, aggregate in ((summary_path, arm_summary), (wire_path, arm_wire)):
            if aggregate and any(aggregate.get(key) != all_metrics[key] for key in ("planned", "echoed")):
                issue(issues, path, "source analysis disagrees with comparator rows", arm=arm)
        arms[arm] = {
            "all": all_metrics,
            "validated_transport": batch_metrics([row for row in group if row["transport"]["expected_validated"]]),
            "loopback_totals_from_summary": {key: arm_summary.get(key) for key in ("server_received", "server_responded")},
            "wire": arm_wire.get("wire"),
            "batches": [{key: value for key, value in row.items() if key not in {"rows", "failures"}} for row in group],
            "failures": [failure for row in group for failure in row["failures"]],
        }
        batches[arm] = {batch["round"]: batch for batch in group}
    return {
        "path": str(root), "run_id": plan["run_id"], "expected_transport": expected,
        "transport_batches": {"planned": len(jobs),
                              "expected_validated": sum(batch["transport"]["expected_validated"]
                                                        for group in batches.values() for batch in group.values())},
        "arms": arms, "issues": issues,
    }, batches


def pair_arms(wifi, cellular):
    eligible, excluded = [], []
    for number in sorted(wifi.keys() | cellular.keys()):
        pair = {"wifi": wifi.get(number), "cellular": cellular.get(number)}
        reasons = [f"{name}_batch_missing" for name, batch in pair.items() if batch is None]
        for name, batch in pair.items():
            if batch is None:
                continue
            if not batch["transport"]["expected_validated"]:
                reasons.append(f"{name}_transport_unverified")
            if not batch["complete"] or batch["runner_status"] != "exited":
                reasons.append(f"{name}_batch_incomplete")
        if all(pair.values()) and pair["wifi"]["workload"] != pair["cellular"]["workload"]:
            reasons.append("different_workload")
        if reasons:
            excluded.append({"round": number, "reasons": reasons})
        else:
            eligible.append(number)
    metrics = {"wifi": batch_metrics([wifi[n] for n in eligible]),
               "cellular": batch_metrics([cellular[n] for n in eligible])}
    rate_keys = ("echo_rate_percent_of_planned", "timeout_rate_percent_of_planned")
    deltas = {key.replace("_percent_of_planned", "_percentage_points"):
              metrics["cellular"][key] - metrics["wifi"][key] if eligible else None for key in rate_keys}
    return {"eligible_rounds": eligible, "excluded_rounds": excluded, **metrics, "cellular_minus_wifi": deltas}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in NETWORKS:
        parser.add_argument(f"--{name}", type=Path, required=True, help=f"{name} run directory")
    parser.add_argument("--out", type=Path, required=True, help="comparison JSON file")
    args = parser.parse_args()
    try:
        by_network, batches = {}, {}
        for network, transport in NETWORKS.items():
            by_network[network], batches[network] = load_network(getattr(args, network).resolve(), transport)
        result = {
            "networks": by_network,
            "paired": {arm: pair_arms(batches["wifi"][arm], batches["cellular"][arm]) for arm in ARMS},
            "limitations": [
                "Validated Android default-transport snapshots bracket each batch. Network changes between snapshots can go unseen.",
                "This is a comparison of the tested device, paths, and measurement windows. Carrier, access point, routing, and time may differ.",
                "Loopback receipts document observed application ingress and send. Missing receipts leave that stage unresolved.",
                "Wire candidates use empirical timing and size. Missing socket matches can reflect capture coverage, offloads, socket reading, or path loss.",
                "Android socket timestamps describe userspace reads. Server timestamps are used only for server-side comparisons.",
                "SO_RXQ_OVFL notices are cumulative per socket. Reported drops are lower bounds. Missing notices leave the drop count unknown.",
            ],
        }
        args.out.write_text(json.dumps(result, indent=2, allow_nan=False) + "\n", encoding="utf-8")
    except (KeyError, OSError, TypeError, ValueError) as err:
        parser.exit(1, f"UDP network comparison failed: {err}\n")
    print(args.out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
