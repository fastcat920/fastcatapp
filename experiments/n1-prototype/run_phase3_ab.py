#!/usr/bin/env python3
"""Interleaved native Android comparison of two N1 emitters, same wire format."""
from pathlib import Path
import json
import math
import random
import re
import subprocess

ROOT = Path(__file__).resolve().parent
OUT = ROOT / 'results/phase3-2026-11-24'
OUT.mkdir(parents=True, exist_ok=True)
BASE = ['adb', '-s', 'A3GMVB2110006859', 'shell',
        '/data/local/tmp/fastcat-n1-lab/n1-systemdns', '-mode', 'probe',
        '-target', '127.0.0.1:18462', '-count', '1']
configs = {'legacy': '/data/local/tmp/fastcat-n1-lab/domain.json',
           'coalesced': '/data/local/tmp/fastcat-n1-lab/coalesced.json'}
for service, expected in [('fastcat-n1-experiment', False), ('fastcat-n1-coalesced', True)]:
    check = subprocess.run(['ssh', '-S', '/tmp/n1-prototype-ssh.sock', '-o', 'BatchMode=yes',
        'root@zlhk.fastcat.ink', 'systemctl show --value -p ExecStart '+service],
        capture_output=True, text=True, timeout=15)
    actual = bool(re.search(r'--?emission(?:=|\s+)coalesced', check.stdout))
    if check.returncode or not check.stdout.strip() or actual != expected:
        raise SystemExit('A/B fixture mismatch: restore 18461 legacy and 18463 coalesced before comparing; no requests sent')
rng = random.Random(20261124)
rows = []
for pair in range(10):
    order = list(configs)
    rng.shuffle(order)
    for position, name in enumerate(order):
        result = subprocess.run(BASE + ['-config', configs[name]],
                                capture_output=True, text=True, timeout=150)
        (OUT / f'pair-{pair+1:02d}-{name}.jsonl').write_text(result.stdout)
        parsed = [json.loads(line) for line in result.stdout.splitlines() if line.startswith('{')]
        sample = next((r for r in parsed if 'sample' in r), {'error': 'no sample'})
        rows.append({'pair': pair+1, 'position': position+1, 'profile': name,
                     'exit_code': result.returncode, **sample})
    print('completed pair', pair+1, flush=True)

summary = {}
for name in configs:
    group = [r for r in rows if r['profile'] == name]
    summary[name] = {'success': sum('error' not in r and r['exit_code'] == 0 for r in group),
                     'failed': sum('error' in r or r['exit_code'] != 0 for r in group)}
    for field in ['first_response_headers_ms', 'full_request_ms']:
        values = sorted(r[field] for r in group if field in r)
        if values:
            summary[name][field] = {'p50': values[math.ceil(len(values)*.50)-1],
                'p95': values[math.ceil(len(values)*.95)-1], 'min': min(values), 'max': max(values)}
(OUT / 'ab-samples.json').write_text(json.dumps(rows, indent=2))
(OUT / 'ab-summary.json').write_text(json.dumps(summary, indent=2))
print(json.dumps(summary, indent=2))
if any(r['failed'] for r in summary.values()):
    raise SystemExit(1)
