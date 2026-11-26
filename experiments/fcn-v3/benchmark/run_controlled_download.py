#!/usr/bin/env python3
"""Run the six balanced FCN download rounds in a prepared Linux network lab."""

import argparse
from itertools import permutations
import json
from pathlib import Path
import re
import subprocess
import time


ARMS = ("current", "adaptive", "tuic")
LOSSES = (0, 2, 8)


def unix_ms():
    return time.time_ns() // 1_000_000


def write_json(path, value):
    with path.open("x", encoding="utf-8") as stream:
        json.dump(value, stream, indent=2)
        stream.write("\n")


def namespace_prefix(namespace):
    return ["ip", "netns", "exec", namespace] if namespace else []


def make_plan(args):
    treatments = {loss: {"run_id": f"{args.run_id}-l{loss}", "jobs": []} for loss in LOSSES}
    blocks = []
    for number, (loss_order, arm_order) in enumerate(zip(permutations(LOSSES), permutations(ARMS)), start=1):
        for loss_position, loss in enumerate(loss_order, start=1):
            treatment = treatments[loss]
            block_jobs = []
            for position, arm in enumerate(arm_order, start=1):
                profile_config = args.adaptive_config if arm == "adaptive" else args.config
                protocol = "tuic" if arm == "tuic" else "fcnv3"
                diagnostic_id = f"{treatment['run_id']}-{arm}-{number}"
                command = [str(args.binary.absolute()), "-config", str(profile_config.absolute()), "-protocol", protocol,
                           "-phase", "download", "-bytes", "1048576", "-count", "4", "-workers", "4", "-timeout", "25s",
                           "-diagnostic-id", diagnostic_id]
                block_jobs.append({"phase": "download", "round": number, "position": position, "arm": arm,
                                   "loss_percent": loss, "loss_position": loss_position, "args": command,
                                   "diagnostic_id": diagnostic_id, "host_timeout_s": 40})
            treatment["jobs"].extend(block_jobs)
            blocks.append({"round": number, "loss_percent": loss, "loss_position": loss_position, "jobs": block_jobs})
    return treatments, blocks


def execute(command, stdout_path, stderr_path, timeout, skip_reason=None):
    exit_code = None
    with stdout_path.open("xb") as stdout, stderr_path.open("xb") as stderr:
        start_unix_ms = unix_ms()
        started = time.monotonic_ns()
        if skip_reason is not None:
            status = "skipped_tc_setup"
            stderr.write((skip_reason + "\n").encode("utf-8"))
        else:
            try:
                result = subprocess.run(command, stdin=subprocess.DEVNULL, stdout=stdout, stderr=stderr, timeout=timeout)
                exit_code, status = result.returncode, "exited"
            except subprocess.TimeoutExpired:
                status = "timed_out"
            except OSError as err:
                status = "start_failed"
                stderr.write((str(err) + "\n").encode("utf-8", errors="replace"))
        elapsed_ms = (time.monotonic_ns() - started) / 1_000_000
        end_unix_ms = unix_ms()
    return {"status": status, "exit_code": exit_code, "start_unix_ms": start_unix_ms, "end_unix_ms": end_unix_ms,
            "elapsed_ms": elapsed_ms, "stdout_bytes": stdout_path.stat().st_size, "skip_reason": skip_reason}


def tc_capture(directory, label, command, inspect=False):
    stdout = directory / f"tc-{label}.txt"
    result = execute(command, stdout, directory / f"tc-{label}.stderr.txt", timeout=10)
    result["command"] = command
    if inspect:
        lines = stdout.read_text(encoding="utf-8", errors="replace").splitlines()
        result["root_netem"] = next((line for line in lines if line.startswith("qdisc netem ") and "root" in line.split()), None)
    return result


def apply_loss(args, directory, label, loss):
    command = namespace_prefix(args.server_namespace) + [
        "tc", "qdisc", "change", "dev", args.interface, "root", "netem",
        "delay", "50ms", "rate", "20mbit", "loss", "random", f"{loss}%",
    ]
    return tc_capture(directory, label, command)


def tc_snapshot(args, directory, label):
    command = ["tc", "-s", "-d", "qdisc", "show", "dev"]
    return {
        "downlink": tc_capture(directory, f"{label}-downlink", namespace_prefix(args.server_namespace) + command + [args.interface], inspect=True),
        "uplink": tc_capture(directory, f"{label}-uplink", namespace_prefix(args.namespace) + command + [args.device], inspect=True),
    }


def tc_snapshot_ok(snapshot):
    return all(result["exit_code"] == 0 and result["root_netem"] is not None for result in snapshot.values())


def run_block(args, block):
    loss, number = block["loss_percent"], block["round"]
    directory = args.out / f"loss-{loss}pct" / "download" / f"round-{number:02d}"
    directory.mkdir(parents=True)
    change = apply_loss(args, directory, "set", loss)
    before = tc_snapshot(args, directory, "before")
    setup_ok = change["exit_code"] == 0 and tc_snapshot_ok(before)
    skip_reason = None if setup_ok else "downlink change or netem snapshot failed; see tc-block.json"
    outcomes = []
    for job in block["jobs"]:
        arm = job["arm"]
        command = namespace_prefix(args.namespace) + job["args"]
        result = execute(command, directory / f"{arm}.jsonl", directory / f"{arm}.stderr.txt",
                         timeout=job["host_timeout_s"], skip_reason=skip_reason)
        outcomes.append({**job, **result})
        print(f"round {number}/6 loss={loss}% {arm} {result['status']} exit={result['exit_code']}", flush=True)

    after = tc_snapshot(args, directory, "after")
    network_stable = setup_ok and tc_snapshot_ok(after) and all(
        before[direction]["root_netem"] == after[direction]["root_netem"] for direction in before
    )
    write_json(directory / "tc-block.json", {**block, "change": change, "before": before, "after": after,
                                              "network_stable": network_stable})
    for outcome in outcomes:
        write_json(directory / f"{outcome['arm']}.meta.json", {**outcome, "network_stable": network_stable,
                                                              "tc_metadata": "tc-block.json"})
    return network_stable and all(row["status"] == "exited" and row["stdout_bytes"] > 0 for row in outcomes)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--binary", required=True, type=Path, help="Linux comparator executable")
    parser.add_argument("--config", required=True, type=Path, help="current FCN and TUIC config")
    parser.add_argument("--adaptive-config", required=True, type=Path, help="adaptive FCN config")
    parser.add_argument("--interface", required=True, help="server-side downlink netem interface")
    parser.add_argument("--device", required=True, help="client-side uplink netem interface")
    parser.add_argument("--namespace", default="fcn3-losslab", help="client network namespace")
    parser.add_argument("--server-namespace", help="server network namespace, when separate from the host")
    parser.add_argument("--run-id", default="controlled-download", help="prefix for origin receipt correlation")
    args = parser.parse_args()
    if not re.fullmatch(r"[A-Za-z0-9_-]{1,34}", args.run_id):
        parser.error("--run-id must contain 1 to 34 ASCII letters, digits, underscores, or hyphens")
    treatments, blocks = make_plan(args)
    args.out.mkdir(parents=True, exist_ok=True)
    plan = {"run_id": args.run_id, "client_namespace": args.namespace, "server_namespace": args.server_namespace,
            "downlink_interface": args.interface, "uplink_interface": args.device, "delay_per_direction_ms": 50,
            "rate_per_direction_mbit": 20, "uplink_loss_percent": 0, "downlink_loss_percent": list(LOSSES),
            "blocks": blocks}
    try:
        write_json(args.out / "plan.json", plan)
    except FileExistsError:
        parser.error("results already exist, choose a new --out directory")
    for loss, treatment in treatments.items():
        treatment_dir = args.out / f"loss-{loss}pct"
        treatment_dir.mkdir()
        write_json(treatment_dir / "plan.json", treatment)

    complete = True
    try:
        for block in blocks:
            if not run_block(args, block):
                complete = False
    finally:
        restore = apply_loss(args, args.out, "restore", 0)
        write_json(args.out / "tc-restore.json", restore)
    return 0 if complete and restore["exit_code"] == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
