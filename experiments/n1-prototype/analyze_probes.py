#!/usr/bin/env python3
"""Describe probe timings; a non-significant result is not equivalence."""
from pathlib import Path
import itertools
import json
import math
import random
import statistics
import sys

source = Path(sys.argv[1])
rows = [json.loads(line) for line in source.read_text().splitlines()]
summary = {}
for case in sorted({r['case'] for r in rows}):
    values = [r for r in rows if r['case'] == case]
    times = sorted(r['response_headers_ms'] for r in values if 'response_headers_ms' in r)
    summary[case] = {'samples': len(values), 'errors': sum('error' in r for r in values),
        'statuses': sorted({r.get('status', 0) for r in values}),
        'body_hashes': sorted({r.get('body_sha256', '') for r in values}),
        'connection_close': sorted({r.get('connection_close', False) for r in values}),
        'headers_p50_ms': statistics.median(times) if times else None,
        'headers_p95_ms': times[math.ceil(len(times)*.95)-1] if times else None}

base = {r['round']: r for r in rows if r['case'] == 'ordinary-missing'}
pairs = []
for r in rows:
    b = base.get(r['round'], {})
    if r['case'] == 'wrong-key' and 'response_headers_ms' in r and 'response_headers_ms' in b:
        pairs.append(r['response_headers_ms']-b['response_headers_ms'])
analysis = {'case_summary': summary, 'timing_scope': 'request headers sent to response headers received; excludes TLS setup'}
if pairs and len(pairs) <= 16:
    observed = statistics.mean(pairs)
    null = [abs(statistics.mean(d*s for d, s in zip(pairs, signs)))
            for signs in itertools.product((-1, 1), repeat=len(pairs))]
    rng = random.Random(20261124)
    boot = sorted(statistics.mean(rng.choices(pairs, k=len(pairs))) for _ in range(10000))
    analysis['exploratory_wrong_key_minus_missing'] = {
        'paired_rounds': len(pairs), 'mean_difference_ms': observed,
        'bootstrap_mean_ci95_ms': [boot[249], boot[9749]],
        'paired_sign_flip_p': sum(v >= abs(observed) for v in null)/len(null),
        'limitations': 'Small sample, one device/network; exploratory only; cannot establish timing equivalence or GFW evasion.'}
destination = source.with_name(source.stem+'-analysis.json')
destination.write_text(json.dumps(analysis, indent=2))
print(json.dumps(analysis, indent=2))
