#!/usr/bin/env python3
"""Synthetic evidence tests; never starts a server or contacts a device."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location("fcn3_analyze", Path(__file__).with_name("analyze.py"))
analyzer = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(analyzer)


class AnalysisTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="fcn3-analysis-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "raw").mkdir()
        self.plan = {"jobs": []}
        cases = [("cold", "cold", 10, 1, 3), ("warm", "warm", 20, 1, 3),
                 ("concurrent", "concurrent", 16, 4, 3),
                 ("single_download", "download", 1, 1, 6),
                 ("parallel_download", "download", 4, 4, 6), ("upload", "upload", 1, 1, 6)]
        for label, phase, count, workers, blocks in cases:
            for block in range(1, blocks + 1):
                for protocol in ("fcnv3", "tuic"):
                    job = dict(id=f"{label}-{block:02d}-{protocol}", category=label, phase=phase,
                               count=count, workers=workers, block=block, protocol=protocol, bytes=32768)
                    self.plan["jobs"].append(job)
                    multiplier = 1.05 if protocol == "fcnv3" else 1
                    rows = []
                    for sample in range(1, count + 1):
                        # Deliberately slow first warm request must remain
                        # recorded while leaving retained percentiles unchanged.
                        first = 1000 if phase == "warm" and sample == 1 else 10 * multiplier
                        rows.append(dict(event="sample", sample=sample, success=True, verified_bytes=job["bytes"],
                                         protocol=protocol, phase=phase, workers=workers, bytes=job["bytes"],
                                         first_byte_ms=first, total_ms=first + 5, entry_ms=5,
                                         start_unix_ms=sample * 1000, e2e_mbps=20))
                    rows.append(dict(event="batch-ended", count=count, failed=0, elapsed_ms=100 * multiplier))
                    path = self.root / "raw" / (job["id"] + ".jsonl")
                    path.write_text("\n".join(json.dumps(row) for row in rows) + "\n")

    def test_full_matrix_passes_and_retains_first_warm_samples(self):
        result = analyzer.analyze(self.root, self.plan)
        self.assertTrue(result["metrics_pass"], result["gates"])
        f = result["protocols"]["fcnv3"]
        self.assertEqual(f["warm"]["attempted"], 60)
        self.assertEqual(f["warm"]["first_byte_ms"]["n"], 57)
        self.assertEqual(f["warm"]["first_sample_first_byte_ms"], [1000] * 3)
        c = result["comparisons_fcnv3_over_tuic"]["single_download"]
        self.assertEqual(len(c["paired_blocks"]), 6)
        self.assertAlmostEqual(c["throughput_ratio"], 1 / 1.05)

    def test_missing_sample_is_retained_as_failure(self):
        job = self.plan["jobs"][0]
        path = self.root / "raw" / (job["id"] + ".jsonl")
        lines = path.read_text().splitlines()
        path.write_text("\n".join(lines[1:]) + "\n")
        result = analyzer.analyze(self.root, self.plan)
        self.assertFalse(result["metrics_pass"])
        self.assertEqual(len(result["failures"]), 1)
        self.assertEqual(result["failures"][0]["error_stage"], "missing-row")

    def test_unverified_success_never_counts_as_payload(self):
        job = self.plan["jobs"][0]
        path = self.root / "raw" / (job["id"] + ".jsonl")
        rows = [json.loads(line) for line in path.read_text().splitlines()]
        rows[0]["verified_bytes"] = 0
        path.write_text("\n".join(json.dumps(row) for row in rows) + "\n")
        result = analyzer.analyze(self.root, self.plan)
        self.assertFalse(result["gates"]["zero_failures"])
        self.assertEqual(result["batches"][0]["verified_bytes"], 9 * job["bytes"])

    def test_nonzero_exit_fails_even_with_complete_success_rows(self):
        job = self.plan["jobs"][0]
        (self.root / "raw" / (job["id"] + ".meta.json")).write_text(json.dumps({"exit_code": 124}))
        result = analyzer.analyze(self.root, self.plan)
        self.assertFalse(result["gates"]["complete_evidence"])


if __name__ == "__main__":
    unittest.main()
