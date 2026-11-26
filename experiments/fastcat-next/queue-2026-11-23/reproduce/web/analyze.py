from pathlib import Path
import json,math
O=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/queue-2026-11-23/remote-web')
def read(p):
 a=[]
 for l in p.read_text().splitlines():
  try:r=json.loads(l)
  except:continue
  if isinstance(r,dict):a.append(r)
 return a
def pct(a,q):return sorted(a)[math.ceil(len(a)*q)-1] if a else None
T=json.loads((O/'timeline.json').read_text()) if (O/'timeline.json').exists() else [];allrows=[];S={};checks={}
for target in ['example.com:443','www.google.com:443']:
 d={}
 for v in ['baseline','selected']:
  a=[]
  for t in T:
   if t['target']==target and t['variant']==v:a += [dict(r,source=t['name'],variant=v,target=target) for r in read(O/(t['name']+'.jsonl'))]
  allrows+=a;fg=[r for r in a if r.get('phase')=='mixed'];loaded=[r for r in fg if r.get('background_active',0)>0];good=[r for r in loaded if not r.get('error') and r.get('first_byte_us',0)>0];bg=[r for r in a if r.get('phase')=='mixed_background']
  d[v]=dict(foreground_total=len(fg),foreground_success=sum(not r.get('error') for r in fg),loaded_total=len(loaded),loaded_success=len(good),loaded_p50_ms=pct([r['first_byte_us']/1000 for r in good],.5),loaded_p95_ms=pct([r['first_byte_us']/1000 for r in good],.95),background_total=len(bg),background_success=sum(r.get('complete',False) for r in bg),errors=[r['error'] for r in fg if r.get('error')])
 b,c=d['baseline'],d['selected'];checks[target]=dict(enough=min(b['loaded_total'],c['loaded_total'])>=12,foreground=b['foreground_total']==c['foreground_total']==24 and c['foreground_success']>=b['foreground_success'],background=b['background_total']==c['background_total']==b['background_success']==c['background_success']==4,loaded_p95=bool(b['loaded_p95_ms'] and c['loaded_p95_ms'] and c['loaded_p95_ms']<=b['loaded_p95_ms']*1.1));S[target]=d
s=dict(summary=S,checks=checks,passed=all(all(d.values()) for d in checks.values()));(O/'summary.json').write_text(json.dumps(s,indent=2));(O/'rows.json').write_text(json.dumps(allrows,indent=2));print(json.dumps(s,indent=2))
