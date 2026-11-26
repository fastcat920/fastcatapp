#!/usr/bin/env python3
"""Run the six paired download and UDP rounds on an Android benchmark device."""

import argparse
from itertools import permutations
import json
from pathlib import Path
import re
import shlex
import subprocess
import time


DEVICE_DIR = "/data/local/tmp/fastcat-fcn3-diag"
ARMS = {
    "current": ("fcnv3", "bench.json"),
    "adaptive": ("fcnv3", "adaptive.json"),
    "tuic": ("tuic", "bench.json"),
}
WORKLOADS = {
    "download": (["-phase", "download", "-bytes", "1048576", "-count", "4", "-workers", "4"], 25),
    "udp": (["-udp-diagnostic", "-count", "28"], 55),
}


def unix_ms():
    return time.time_ns() // 1_000_000


def write_json(path, value):
    with path.open("x", encoding="utf-8") as stream:
        json.dump(value, stream, indent=2)
        stream.write("\n")


def plan_jobs(phases, run_id):
    jobs = []
    for phase in phases:
        flags, budget = WORKLOADS[phase]
        for number, order in enumerate(permutations(ARMS), start=1):
            for position, arm in enumerate(order, start=1):
                protocol, config = ARMS[arm]
                args = ["./compare", "-config", config, "-protocol", protocol, *flags, "-timeout", f"{budget}s"]
                job = {"phase": phase, "round": number, "position": position, "arm": arm, "args": args,
                       "host_timeout_s": budget + 15}
                if phase == "download":
                    diagnostic_id = f"{run_id}-{arm}-{number}"
                    job["diagnostic_id"] = diagnostic_id
                    args.extend(["-diagnostic-id", diagnostic_id])
                jobs.append(job)
    return jobs


def parse_default_network(dump):
    default = re.search(r"^\s*Active default network:\s*(\d+)\s*$", dump, re.MULTILINE)
    if default is None:
        return None, [], False
    net_id = int(default.group(1))
    agent = next((line for line in dump.splitlines() if f"NetworkAgentInfo{{network{{{net_id}}}" in line), "")
    transports = re.search(r"\bTransports:\s*([A-Z0-9_|]+)", agent)
    capabilities = re.search(r"\bCapabilities:\s*([A-Z0-9_&]+)", agent)
    transport_list = transports.group(1).split("|") if transports else []
    capability_set = set(capabilities.group(1).split("&")) if capabilities else set()
    return net_id, transport_list, bool(capability_set & {"VALIDATED", "IS_VALIDATED"})


def network_snapshot(adb):
    net_id, transports, validated = None, [], False
    exit_code, probe_error = None, None
    try:
        result = subprocess.run(
            adb + ["shell", "-T", "dumpsys connectivity"],
            stdin=subprocess.DEVNULL, capture_output=True, encoding="utf-8", errors="replace", timeout=10,
        )
        exit_code = result.returncode
        if exit_code == 0:
            net_id, transports, validated = parse_default_network(result.stdout)
        else:
            probe_error = "dumpsys_failed"
    except subprocess.TimeoutExpired:
        probe_error = "dumpsys_timeout"
    except OSError:
        probe_error = "adb_start_failed"
    return {"default_net_id": net_id, "validated": validated, "transports": transports,
            "observed_unix_ms": unix_ms(), "exit_code": exit_code, "probe_error": probe_error}


def run_job(adb, output, job):
    directory = output / job["phase"] / f"round-{job['round']:02d}"
    directory.mkdir(parents=True, exist_ok=True)
    arm = job["arm"]
    before = network_snapshot(adb)
    command = f"cd {shlex.quote(DEVICE_DIR)} && exec {shlex.join(job['args'])}"
    exit_code = None
    status = "skipped_unvalidated_network"
    with (directory / f"{arm}.jsonl").open("xb") as stdout, (directory / f"{arm}.stderr.txt").open("xb") as stderr:
        start_unix_ms = unix_ms()
        started_ns = time.monotonic_ns()
        if before["validated"]:
            try:
                result = subprocess.run(adb + ["shell", "-T", command], stdin=subprocess.DEVNULL,
                                        stdout=stdout, stderr=stderr, timeout=job["host_timeout_s"])
                exit_code, status = result.returncode, "exited"
            except subprocess.TimeoutExpired:
                status = "timed_out"
            except OSError as err:
                status = "adb_start_failed"
                stderr.write((str(err) + "\n").encode("utf-8", errors="replace"))
        elapsed_ms = (time.monotonic_ns() - started_ns) / 1_000_000
        end_unix_ms = unix_ms()
    after = network_snapshot(adb)
    network_stable = before["validated"] and after["validated"] and before["default_net_id"] == after["default_net_id"]
    metadata = {**job, "before": before, "after": after, "network_stable": network_stable,
                "status": status, "exit_code": exit_code, "start_unix_ms": start_unix_ms,
                "end_unix_ms": end_unix_ms, "elapsed_ms": elapsed_ms}
    write_json(directory / f"{arm}.meta.json", metadata)
    print(f"{job['phase']} round {job['round']}/{job.get('rounds', 6)} {arm} {status} exit={exit_code} "
          f"network={before['default_net_id']}->{after['default_net_id']} stable={network_stable}", flush=True)
    return network_stable and status == "exited"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--serial", required=True, help="adb device serial")
    parser.add_argument("--out", required=True, type=Path, help="output directory for a new run")
    parser.add_argument("--run-id", required=True, help="HTTP trace prefix, up to 37 ASCII identifier characters")
    parser.add_argument("--phase", choices=["all", *WORKLOADS], default="all")
    args = parser.parse_args()
    if not re.fullmatch(r"[A-Za-z0-9_-]{1,37}", args.run_id):
        parser.error("--run-id must contain 1 to 37 ASCII letters, digits, underscores, or hyphens")
    phases = list(WORKLOADS) if args.phase == "all" else [args.phase]
    jobs = plan_jobs(phases, args.run_id)
    args.out.mkdir(parents=True, exist_ok=True)
    try:
        write_json(args.out / "plan.json", {"run_id": args.run_id, "jobs": jobs})
    except FileExistsError:
        parser.error("results already exist, choose a new --out directory")

    adb = ["adb", "-s", args.serial]
    run_valid = True
    for job in jobs:
        if not run_job(adb, args.out, job):
            run_valid = False
    return 0 if run_valid else 1


if __name__ == "__main__":
    raise SystemExit(main())
