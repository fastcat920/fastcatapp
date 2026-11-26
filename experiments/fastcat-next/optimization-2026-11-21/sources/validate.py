from pathlib import Path
import json,csv,collections,re,hashlib
D=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/optimization-2026-11-21')
expected={'controlled':756,'internet':756,'singlepool':252,'concurrent8':300,'idle70':48,'pilot':48,'downloads1m':36,'downloads10m':12,'downloads100m':3,'downloads100m-reference':2,'post-reference100':2,'throughput':72}
for name,count in expected.items():
 rows=[json.loads(x) for x in (D/(name+'.jsonl')).read_text().splitlines() if x.startswith('{')];assert len(rows)==count,(name,len(rows))
 if name.startswith('downloads'):
  for row in rows:
   if row.get('complete'):assert row.get('checksum_ok') and row['received_bytes']==row['expected_bytes']
rr=list(csv.DictReader((D/'requests.csv').open(encoding='utf-8-sig')));assert len(rr)==2112
keys=[tuple(r[k] for k in ['workload','version','protocol','phase','round','worker','pool']) for r in rr];assert len(set(keys))==len(rr)
formal=[r for r in rr if r['phase'] not in ['prime','idle-prime']];assert len(formal)==2004
counts=collections.Counter((r['version'],r['protocol']) for r in formal);assert len(counts)==12 and set(counts.values())=={167}
meta=json.loads((D/'metadata.json').read_text());assert meta['trace_enabled'] is False and meta['next_mss']==0
assert hashlib.sha256(Path('/tmp/fc-next-opt/compare').read_bytes()).hexdigest()==meta['sha256']['compare']
assert hashlib.sha256(Path('/tmp/fc-next-opt/next-diagnostic').read_bytes()).hexdigest()==meta['sha256']['next-diagnostic']
report=(D/'REPORT.md').read_text();assert 'FINAL_CONCLUSIONS' not in report and '待完成' not in report
for p in re.findall(r'src="([^"]+\.png)"',(D/'DATA.html').read_text()):assert (D/p).exists()
for p in ['final-race.txt','final-vet.txt','fuzz.txt']:
 text=(D/'local'/p).read_text();assert 'FAIL' not in text and 'WARNING: DATA RACE' not in text
print('Validated: 12 profiles × 167 formal requests; all raw row counts; distinct identifiers; verified transfer lengths; binary hashes; local checks; report and image references')
