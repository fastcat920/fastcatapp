#!/usr/bin/env python3
"""Compare Android socket reads with a server egress capture of the UDP test phase."""

import argparse
from bisect import bisect_left, bisect_right
from collections import Counter, defaultdict
from dataclasses import dataclass
import json
from pathlib import Path
import re

from analyze_stall_udp import UDP_RUN_ID, collect_udp, flag, issue, read_object, read_rows


PORTS = {"current": 18532, "adaptive": 18534, "tuic": 18533}
FINGERPRINT = re.compile(r"[a-f0-9]{16}")
CALIBRATION_SEARCH_NS = 250_000_000
MODEL_MARGIN_NS = 5_000_000
APP_TIME_TOLERANCE_NS = 1000
REPORTED_CANDIDATES = 8
WIRE_COUNTS = (
    "server", "android", "matched", "server_unmatched", "android_unmatched", "unique_matches",
    "matched_with_duplicate_fingerprint",
)


@dataclass(frozen=True)
class WireRecord:
    timestamp: int
    size: int
    fingerprint: str
    round: int = 0

    @property
    def key(self):
        return self.size, self.fingerprint


def wire_record(row, size_key, fingerprint_key, round_number=0):
    size = row.get(size_key)
    fingerprint = row.get(fingerprint_key)
    timestamp = row.get("timestamp_unix_ns")
    if (type(size) is not int or not 0 <= size <= 65527 or type(timestamp) is not int or timestamp < 1
            or not isinstance(fingerprint, str) or not FINGERPRINT.fullmatch(fingerprint)):
        raise ValueError("invalid wire fingerprint row")
    return WireRecord(timestamp, size, fingerprint, round_number)


def load_egress(path, ports, issues):
    by_port = {port: arm for arm, port in ports.items()}
    egress = defaultdict(list)
    try:
        with path.open(encoding="utf-8", errors="replace") as stream:
            for line_no, line in enumerate(stream, 1):
                if not line.strip():
                    continue
                try:
                    row = json.loads(line)
                    if not isinstance(row, dict) or type(row.get("src_port")) is not int:
                        raise ValueError("invalid server egress source port")
                    arm = by_port.get(row["src_port"])
                    if arm is None:
                        raise ValueError("server egress source port is outside the plan")
                    egress[arm].append(wire_record(row, "payload_bytes", "sha256_16"))
                except ValueError as err:
                    issue(issues, path, str(err), line=line_no)
    except OSError as err:
        issue(issues, path, err.strerror)
    return egress


def load_echoes(path, issues):
    echoes = defaultdict(list)
    for row in read_rows(path, issues):
        run_id, seq, size = row.get("run_id"), row.get("seq"), row.get("size")
        timestamp = row.get("timestamp_unix_ns")
        if (row["event"] not in {"receive", "response"} or not isinstance(run_id, str)
                or not UDP_RUN_ID.fullmatch(run_id) or type(seq) is not int or seq < 1
                or type(size) is not int or not 36 <= size <= 1150
                or type(timestamp) is not int or timestamp < 1):
            issue(issues, path, "invalid echo receipt")
            continue
        echoes[(run_id, seq, size)].append(row)
    return echoes


def load_job(root, job, echoes, issues):
    number, arm = job["round"], job["arm"]
    path = root / "udp" / f"round-{number:02d}" / f"{arm}.jsonl"
    objects = read_rows(path, issues)
    probes, ending = collect_udp(job, path, [r for r in objects if r["event"] != "udp_wire_rx"],
                                 int(flag(job, "-count")), flag(job, "-protocol"), echoes, issues)
    android = []
    for row in objects:
        if row["event"] == "udp_wire_rx":
            try:
                android.append(wire_record(row, "bytes", "sha256_64", number))
            except ValueError as err:
                issue(issues, path, str(err))
    observer = ending.get("wire_rx")
    if (not isinstance(observer, dict) or type(observer.get("captured")) is not int
            or type(observer.get("dropped")) is not int or observer["dropped"] < 0):
        issue(issues, path, "missing or invalid Android wire observer summary")
        observer = {}
    elif observer["captured"] != len(android):
        issue(issues, path, "Android wire observer count differs from parsed rows")
    return probes, android, {"round": number, "captured_rows": len(android),
                             "observer_reported": observer.get("captured"),
                             "observer_dropped": observer.get("dropped")}


def index_wire(records):
    by_key = defaultdict(list)
    for record in records:
        by_key[record.key].append(record)
    return by_key


def join_wire(egress, android):
    server_keys, android_keys = index_wire(egress), index_wire(android)
    unique_matches, nonunique = {}, set()
    by_size = defaultdict(Counter)
    totals = Counter()
    for key in server_keys.keys() | android_keys.keys():
        server = server_keys.get(key, [])
        phone = android_keys.get(key, [])
        count = min(len(server), len(phone))
        unique = len(server) == len(phone) == 1
        if unique:
            unique_matches[key] = phone[0]
        elif len(server) > 1 or len(phone) > 1:
            nonunique.add(key)
        contribution = {
            "server": len(server), "android": len(phone), "matched": count,
            "server_unmatched": len(server) - count, "android_unmatched": len(phone) - count,
            "unique_matches": int(unique), "matched_with_duplicate_fingerprint": count - int(unique),
        }
        by_size[key[0]].update(contribution)
        totals.update(contribution)
    wire = {key: totals[key] for key in WIRE_COUNTS}
    wire["by_payload_bytes"] = {str(size): dict(by_size[size]) for size in sorted(by_size)}
    return wire, unique_matches, nonunique


def receipt_times(probe):
    received, responded = ([r["timestamp_unix_ns"] for r in probe["echo_receipts"] if r["event"] == event]
                           for event in ("receive", "response"))
    if len(received) == len(responded) == 1 and received[0] <= responded[0]:
        return received[0], responded[0]
    return None


def windows(probes, egress):
    # These bounds use only server timestamps. A subsequent loopback receive
    # ends the window so its egress cannot be reused for the preceding probe.
    egress = sorted(egress, key=lambda row: row.timestamp)
    timestamps = [row.timestamp for row in egress]
    receives = sorted({receipt["timestamp_unix_ns"] for probe in probes for receipt in probe["echo_receipts"]
                       if receipt["event"] == "receive"})
    for probe in probes:
        receipt = receipt_times(probe)
        if receipt is None:
            yield probe, None, []
            continue
        receive, response = receipt
        next_receive = bisect_right(receives, receive)
        end = response + CALIBRATION_SEARCH_NS + 1
        if next_receive < len(receives):
            end = min(end, receives[next_receive])
        candidates = egress[bisect_left(timestamps, receive):bisect_left(timestamps, end)]
        yield probe, response, candidates


def client_echo_time(probe):
    sent = probe.get("send_unix_ns")
    rtt = probe.get("echo_rtt_ms")
    if type(sent) is not int or sent < 1 or type(rtt) not in (int, float) or not 0 <= rtt <= 120_000:
        return None
    return sent, sent + round(rtt * 1_000_000)


def learn_calibration(windowed, unique_matches):
    seeds = []
    for probe, response, packets in windowed:
        if not probe["echoed"] or response is None or (times := client_echo_time(probe)) is None:
            continue
        sent, completed = times
        matches = []
        for packet in packets:
            android = unique_matches.get(packet.key)
            if (android is not None and android.round == probe["round"] and packet.size >= probe["bytes"]
                    and sent <= android.timestamp <= completed + APP_TIME_TOLERANCE_NS):
                matches.append(packet)
        if len(matches) == 1:
            seeds.append((probe["bytes"], matches[0], response))
    uses = Counter(packet.key for _, packet, _ in seeds)
    delays = defaultdict(lambda: defaultdict(list))
    for app_size, packet, response in seeds:
        if uses[packet.key] == 1:
            delays[app_size][packet.size].append(packet.timestamp - response)
    return {app: {wire: {"successful_seeds": len(values), "overhead_bytes": wire - app,
                         "min_delay_ns": min(values), "max_delay_ns": max(values)}
                  for wire, values in sorted(sizes.items())}
            for app, sizes in sorted(delays.items())}


def describe_candidate(packet, response, probe, unique_matches, nonunique):
    details = {
        "server_timestamp_unix_ns": packet.timestamp, "server_delay_from_response_ns": packet.timestamp - response,
        "payload_bytes": packet.size, "sha256_16": packet.fingerprint,
    }
    android = unique_matches.get(packet.key)
    deadline = probe.get("echo_deadline_unix_ns")
    sent = probe.get("send_unix_ns")
    if packet.key in nonunique:
        outcome = "candidate_duplicate_fingerprint"
    elif android is None:
        outcome = "candidate_no_android_match"
    elif android.round != probe["round"]:
        outcome = "candidate_matched_another_round"
    elif type(sent) is int and android.timestamp < sent:
        outcome = "candidate_android_read_before_probe"
    elif type(deadline) is not int or deadline < 1:
        outcome = "candidate_android_read_deadline_unavailable"
    else:
        delta = android.timestamp - deadline
        outcome = "candidate_android_read_after_deadline" if delta > 0 else "candidate_android_read_by_deadline"
        details["android_delta_from_deadline_ns"] = delta
    if android is not None:
        details.update(android_timestamp_unix_ns=android.timestamp, android_round=android.round)
    return {**details, "classification": outcome}


def explain_failure(probe, response, packets, calibration, unique_matches, nonunique):
    candidates = []
    if probe.get("error_stage") != "echo" or probe.get("error_category") != "timeout":
        classification = "other_failure"
    elif response is None:
        classification = "ambiguous_loopback_receipts" if probe["server_responded"] else "no_loopback_response_receipt"
    elif not (sizes := calibration.get(probe["bytes"])):
        classification = "no_calibration_for_payload_size"
    else:
        for packet in packets:
            model = sizes.get(packet.size)
            if model is None:
                continue
            delay = packet.timestamp - response
            if model["min_delay_ns"] - MODEL_MARGIN_NS <= delay <= model["max_delay_ns"] + MODEL_MARGIN_NS:
                candidates.append(packet)
        if len(candidates) > 1:
            classification = "ambiguous_egress_candidates"
        elif candidates:
            classification = describe_candidate(candidates[0], response, probe, unique_matches, nonunique)["classification"]
        else:
            classification = "no_egress_candidate_in_calibrated_window"
    return {
        **probe, "classification": classification, "egress_candidates": len(candidates),
        "candidates": [describe_candidate(packet, response, probe, unique_matches, nonunique)
                       for packet in candidates[:REPORTED_CANDIDATES]],
    }


def analyze(root, plan):
    ports = plan.get("ports", PORTS)
    if (not isinstance(ports, dict) or set(ports) != set(PORTS)
            or any(type(port) is not int or port not in PORTS.values() for port in ports.values())
            or len(set(ports.values())) != len(ports)):
        raise ValueError("plan ports must map the three arms to distinct UDP test ports")
    jobs = [job for job in plan["jobs"] if job["phase"] == "udp"]
    if not jobs:
        raise ValueError("plan has no UDP jobs")
    identities = {(job["arm"], job["round"]) for job in jobs}
    if len(identities) != len(jobs) or any(arm not in ports or type(number) is not int or number < 1
                                         for arm, number in identities):
        raise ValueError("plan has invalid or repeated UDP jobs")

    issues, arms = [], {}
    egress = load_egress(root / "server" / "egress.jsonl", ports, issues)
    echoes = load_echoes(root / "server" / "echo.jsonl", issues)
    for arm, port in ports.items():
        probes, android, batches = [], [], []
        for job in jobs:
            if job["arm"] != arm:
                continue
            job_probes, job_android, job_observer = load_job(root, job, echoes, issues)
            probes.extend(job_probes)
            android.extend(job_android)
            batches.append(job_observer)
        wire, unique_matches, nonunique = join_wire(egress[arm], android)
        windowed = list(windows(probes, egress[arm]))
        calibration = learn_calibration(windowed, unique_matches)
        failures = [explain_failure(probe, response, packets, calibration, unique_matches, nonunique)
                    for probe, response, packets in windowed if not probe["echoed"]]
        arms[arm] = {
            "port": port, "planned": len(probes), "echoed": len(probes) - len(failures),
            "wire": wire, "android_observer": batches, "calibration": calibration,
            "failure_counts": dict(Counter(row["classification"] for row in failures)), "failures": failures,
        }
    return {
        "run_id": plan["run_id"],
        "method": {
            "fingerprint_scope": "source port and UDP-phase capture, equal wire sizes and SHA-256 prefixes",
            "duplicate_fingerprints": "matched by minimum multiplicity, excluded from unique associations",
            "calibration_max_server_delay_ns": CALIBRATION_SEARCH_NS,
            "calibration_margin_ns": MODEL_MARGIN_NS,
            "calibration": "successful probes with one eligible exact pair teach wire size and server-side delay",
            "candidate_window": "starts at loopback receive, ends at next receive or calibration search limit",
            "candidate_caveat": "time and size indicate a possible association to a probe",
            "android_timestamp": "userspace socket read, compared only with the same Android probe's deadline",
            "missing_fingerprint_caveat": "capture gaps, offloads, socket reading and packet loss can all affect visibility",
        },
        "wire": {key: sum(arm["wire"][key] for arm in arms.values()) for key in WIRE_COUNTS},
        "arms": arms, "issues": issues,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True, help="existing UDP run directory")
    args = parser.parse_args()
    try:
        result = analyze(args.out, read_object(args.out / "plan.json"))
        summary = args.out / "wire-summary.json"
        summary.write_text(json.dumps(result, indent=2, allow_nan=False) + "\n", encoding="utf-8")
    except (KeyError, OSError, TypeError, ValueError) as err:
        parser.exit(1, f"UDP wire analysis failed: {err}\n")
    print(summary)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
