from pathlib import Path
import json,math
O=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/queue-2026-11-23/cold-confirm');S={};R=[]
def pct(a,q):return sorted(a)[math.ceil(len(a)*q)-1] if a else None
for v in ['baseline','recovery']:
 a=[]
 for f in O.glob('cold-'+v+'-b*-p*.jsonl'):
  for l in f.read_text().splitlines():
   try:r=json.loads(l)
   except:continue
   if r.get('phase') in ['cold','warm']:a.append(dict(r,source=f.stem,variant=v))
 R+=a;d={}
 for phase in ['cold','warm']:
  rows=[r for r in a if r['phase']==phase];good=[r for r in rows if not r.get('error') and r.get('first_byte_us',0)>0];d[phase]=dict(total=len(rows),success=len(good),p50_ms=pct([r['first_byte_us']/1000 for r in good],.5),p95_ms=pct([r['first_byte_us']/1000 for r in good],.95),errors=[r['error'] for r in rows if r.get('error')])
 S[v]=d
b,c=S['baseline']['cold'],S['recovery']['cold'];checks=dict(enough=b['total']==c['total']==48,success=c['success']>=b['success'],p95=bool(b['p95_ms'] and c['p95_ms'] and c['p95_ms']<=b['p95_ms']*1.1));out=dict(summary=S,checks=checks,passed=all(checks.values()));(O/'summary.json').write_text(json.dumps(out,indent=2));(O/'rows.json').write_text(json.dumps(R,indent=2));print(json.dumps(out,indent=2))
