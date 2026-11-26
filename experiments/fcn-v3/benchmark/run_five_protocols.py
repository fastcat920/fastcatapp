#!/usr/bin/env python3
"""Run a balanced, fixed-network FCN/TUIC/Hysteria 2 comparison on Android."""

import argparse
import json
from pathlib import Path
import os
import re

import run_stall_udp as runner


ARMS = ("fcnv3", "fcnv2", "fcnv1", "tuic", "hysteria2")
PORTS = {"fcnv3": 18532, "fcnv2": 18530, "fcnv1": 18530, "tuic": 18533, "hysteria2": 18535}
WORKLOADS = {
    "cold": (["-phase", "cold", "-bytes", "4096", "-count", "4"], 12, 64, 4),
    "warm": (["-phase", "warm", "-bytes", "4096", "-count", "8", "-interval", "150ms"], 12, 115, 8),
    "download": (["-phase", "download", "-bytes", "4194304", "-count", "1"], 35, 50, 1),
    "parallel": (["-phase", "download", "-bytes", "1048576", "-count", "4", "-workers", "4"], 30, 48, 4),
    "upload": (["-phase", "upload", "-bytes", "1048576", "-count", "1"], 25, 40, 1),
    "udp": (["-udp-diagnostic", "-count", "28"], 55, 70, 28),
}


def make_jobs(prefix, phases, reverse_order=False):
    jobs = []
    for phase_index, phase in enumerate(phases):
        flags, budget, host_timeout, count = WORKLOADS[phase]
        # Each arm appears once in every order position for each workload.
        # Alternate the order of offsets used for different workload families.
        offsets = range(5) if phase_index % 2 == 0 else range(4, -1, -1)
        for number, offset in enumerate(offsets, 1):
            ordered = ARMS[offset:] + ARMS[:offset]
            if reverse_order:
                ordered = ordered[::-1]
            for position, arm in enumerate(ordered, 1):
                diagnostic_id = f"{prefix}-{phase}-{number}-{arm}"
                args = ["./compare", "-config", "bench.json", "-protocol", arm, *flags, "-timeout", f"{budget}s"]
                if phase != "udp":
                    args.extend(["-diagnostic-id", diagnostic_id])
                jobs.append({"phase":phase,"arm":arm,"entry_port":PORTS[arm],"round":number,"rounds":5,
                             "position":position,"args":args,"planned":count,"diagnostic_id":diagnostic_id,
                             "host_timeout_s":host_timeout})
    return jobs


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--serial", required=True)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--phase", choices=["all", *WORKLOADS], default="all")
    parser.add_argument("--reverse-order", action="store_true", help="reverse all five arms within each round")
    parser.add_argument("--resume", action="store_true", help="resume an existing plan on the same validated Wi-Fi")
    opts = parser.parse_args()
    if not re.fullmatch(r"[A-Za-z0-9_-]{1,23}", opts.run_id):
        parser.error("run ID must contain 1 to 23 ASCII letters, digits, underscores or hyphens")
    os.umask(0o077)
    phases = list(WORKLOADS) if opts.phase == "all" else [opts.phase]
    jobs = make_jobs(opts.run_id, phases, opts.reverse_order)
    adb = ["adb", "-s", opts.serial]
    original_snapshot = runner.network_snapshot
    first = original_snapshot(adb)
    if not first["validated"] or first["transports"] != ["WIFI"]:
        parser.error("the phone must have a validated Wi-Fi default network")
    if opts.resume:
        plan = json.loads((opts.out / "plan.json").read_text())
        if (plan.get("run_id") != opts.run_id or plan.get("jobs") != jobs or
                plan.get("network", {}).get("default_net_id") != first["default_net_id"]):
            parser.error("resume requires the original jobs and validated Wi-Fi network")
    else:
        opts.out.mkdir(exist_ok=False, parents=True)
        runner.write_json(opts.out / "plan.json", {"run_id": opts.run_id, "jobs":jobs, "ports": PORTS, "network": first,
                                                 "reverse_order": opts.reverse_order})

    def stable_snapshot(args):
        observed = original_snapshot(args)
        observed["system_validated"] = observed["validated"]
        observed["validated"] = (observed["validated"] and observed["transports"] == ["WIFI"] and
                                 observed["default_net_id"] == first["default_net_id"])
        return observed

    runner.network_snapshot = stable_snapshot
    try:
        for job in jobs:
            if opts.resume:
                directory = opts.out / job["phase"] / f"round-{job['round']:02d}"
                meta = directory / f"{job['arm']}.meta.json"
                if meta.is_file():
                    saved = json.loads(meta.read_text())
                    if all(saved.get(key) == job[key] for key in ("phase", "arm", "round", "diagnostic_id")):
                        continue
                    parser.error(f"existing metadata does not match the plan in {meta}")
            runner.run_job(adb, opts.out, job)
    finally:
        runner.network_snapshot = original_snapshot


if __name__ == "__main__":
    main()
