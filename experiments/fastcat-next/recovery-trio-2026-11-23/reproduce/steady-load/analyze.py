from pathlib import Path
import json,math,statistics,collections
O=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/recovery-trio-2026-11-23/steady-load');V=['next-opt','next-base','tuic']
def pct(a,q):return sorted(a)[math.ceil(len(a)*q)-1] if a else None
def read(p):
 a=[]
 if not p.exists():return a
 for l in p.read_text().splitlines():
  try:r=json.loads(l)
  except:continue
  if isinstance(r,dict):a.append(r)
 return a
T=json.loads((O/'timeline.json').read_text()) if (O/'timeline.json').exists() else [];R=[]
for t in T:
 if t['metric']=='pilot':continue
 for r in read(O/(t['name']+'.jsonl')):R.append(dict(r,source=t['name'],block=t['block'],dest_port=t['ports']['tuic_port' if t['version']=='tuic' else 'next_port']))
S={}
for v in V:
 a=[r for r in R if r.get('version')==v];fg=[r for r in a if r.get('phase')=='mixed'];eligible=[r for r in fg if r.get('background_active',0)>0 and r.get('background_ready')==2];good=[r for r in eligible if not r.get('error') and r.get('first_byte_us',0)>0];bg=[r for r in a if r.get('phase')=='mixed_background'];groups=[r for r in a if r.get('phase')=='mixed_summary'];waits=[r['readiness_wait_ms'] for r in groups];setup=[r['setup_ms']+r['readiness_wait_ms'] for r in groups]
 S[v]=dict(groups=len(groups),foreground_total=len(fg),foreground_success=sum(not r.get('error') for r in fg),strict_loaded_total=len(eligible),strict_loaded_success=len(good),p50_ms=pct([r['first_byte_us']/1000 for r in good],.5),p95_ms=pct([r['first_byte_us']/1000 for r in good],.95),background_total=len(bg),background_success=sum(r.get('complete',False) for r in bg),ready_counts=[r.get('background_ready') for r in groups],median_ready_wait_ms=statistics.median(waits) if waits else None,median_setup_plus_ready_ms=statistics.median(setup) if setup else None,errors=dict(collections.Counter(r.get('error') for r in fg if r.get('error'))))
(O/'all-rows.json').write_text(json.dumps(R,indent=2));(O/'summary.json').write_text(json.dumps(S,indent=2));print(json.dumps(S,indent=2))
