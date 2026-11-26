from pathlib import Path
import json,csv,math,statistics,collections
O=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/quic-tuic-2026-11-22')
def rows(p):
 out=[]
 for line in p.read_text().splitlines():
  try:r=json.loads(line)
  except:continue
  if isinstance(r,dict):out.append(r)
 return out
def q(a,p):
 a=sorted(a);return round(a[max(0,math.ceil(len(a)*p)-1)],1) if a else None
summary=[];raw=[]
for f in sorted(O.glob('final-*.jsonl')):
 rr=rows(f)
 for r in rr:
  r=dict(r);r['test']=f.stem;raw.append(r)
 groups=collections.defaultdict(list)
 for r in rr:
  if r.get('phase') in ('cold','warm','prime','batch','idle-prime','idle-resume','idle-recovery'):groups[(r.get('version'),r.get('phase'))].append(r)
 for (v,phase),g in groups.items():
  good=[r for r in g if not r.get('error')];a=[r['first_byte_us']/1000 for r in good if r.get('first_byte_us',0)>0]
  summary.append(dict(test=f.stem,version=v,phase=phase,success=len(good),total=len(g),p50_ms=q(a,.5),p95_ms=q(a,.95),mean_ms=round(statistics.mean(a),1) if a else None))
(O/'summary.json').write_text(json.dumps(summary,indent=2));(O/'all-final-rows.json').write_text(json.dumps(raw,indent=2))
if summary:
 with (O/'latency.csv').open('w') as f:
  w=csv.DictWriter(f,fieldnames=list(summary[0]));w.writeheader();w.writerows(summary)
for r in summary:print(r)
for r in raw:
 if r.get('phase') in ('download','timed_bulk'):print({k:v for k,v in r.items() if k not in ('start_unix_us',)})
