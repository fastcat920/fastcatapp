"""Summarize JSONL from core/tools/fastcat-v3-compare without hiding failures."""
import argparse
import json
import math
from collections import defaultdict
from pathlib import Path
from statistics import median


def distribution(values):
    if not values:
        return None
    ordered = sorted(value / 1000 for value in values)
    return {
        'p50_ms': round(median(ordered), 1),
        'p95_ms': round(ordered[math.ceil(len(ordered) * .95) - 1], 1),
        'max_ms': round(ordered[-1], 1),
    }


def summarize(path):
    groups = defaultdict(list)
    for line in path.read_text().splitlines():
        if line.strip():
            row = json.loads(line)
            groups[row['phase'], row['protocol'], row['version']].append(row)
    results = []
    for (phase, protocol, version), rows in sorted(groups.items()):
        successful = [row for row in rows if not row.get('error')]
        results.append({
            'phase': phase, 'protocol': protocol, 'version': version,
            'success': len(successful), 'attempts': len(rows),
            'first_byte': distribution([row['first_byte_us'] for row in successful]),
            'entry': distribution([row['entry_us'] for row in successful]),
            'target_tls': distribution([row['target_tls_us'] for row in successful]),
            'response': distribution([row['response_us'] for row in successful]),
            'errors': [row['error'] for row in rows if row.get('error')],
        })
    return results


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('input', type=Path)
    parser.add_argument('--json', action='store_true')
    args = parser.parse_args()
    rows = summarize(args.input)
    if args.json:
        print(json.dumps(rows, ensure_ascii=False, indent=2))
    else:
        for row in rows:
            if row['phase'] == 'prime':
                continue
            timing = row['first_byte']
            latency = f"{timing['p50_ms']} / {timing['p95_ms']} ms" if timing else 'no successful requests'
            print(row['phase'], row['protocol'], row['version'],
                  f"{row['success']}/{row['attempts']}", latency)
            for error in row['errors']:
                print('  ', error)
