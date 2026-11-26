# -*- coding: utf-8 -*-
from pathlib import Path
import sys,json,random,itertools,math
MODE=sys.argv[1];O=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/five-protocol-2026-11-23')/MODE;V=['next-opt','next-base','tuic','hysteria2','vless-vision'];G=json.loads((O/'download-groups.json').read_text());R=json.loads((O/'all-rows.json').read_text());rng=random.Random(20261123);out=[]
if MODE=='latency' and (O.parent/'latency-loaded/all-rows.json').exists():
 R += json.loads((O.parent/'latency-loaded/all-rows.json').read_text())
def pct(a,q):return sorted(a)[math.ceil(len(a)*q)-1] if a else None
for a,b in itertools.combinations(V,2):
 if MODE=='speed':
  for metric in ['single32','parallel4','parallel8','rolling']:
   aa={r['block']:r for r in G if r['metric']==metric and r['version']==a};bb={r['block']:r for r in G if r['metric']==metric and r['version']==b};keys=sorted(set(aa)&set(bb))
   if len(keys)!=10:continue
   def rate(d,idx):return sum(d[k]['prefix_verified_bytes'] for k in idx)*8/max(sum(d[k]['elapsed_ms'] for k in idx),1)/1000
   if rate(aa,keys)<=0:continue
   samples=[]
   for _ in range(10000):
    idx=rng.choices(keys,k=10);ra=rate(aa,idx)
    if ra>0:samples.append(rate(bb,idx)/ra)
   out.append(dict(metric=metric,ratio=b+'/'+a,estimate=rate(bb,keys)/rate(aa,keys),exploratory_ci95=[pct(samples,.025),pct(samples,.975)],higher_is_better=True,blocks=10,wins=sum(bb[k]['prefix_mbps']>aa[k]['prefix_mbps'] for k in keys)))
 else:
  for metric,phase in [('latency','cold'),('latency','warm'),('latency','batch'),('batch8','batch'),('mixed','mixed')]:
   aa={};bb={}
   for v,d in [(a,aa),(b,bb)]:
    for r in R:
     if r['metric']!=metric or r.get('phase')!=phase or r.get('version')!=v or r.get('error') or not r.get('first_byte_us'):continue
     if phase=='mixed' and (r.get('background_ready')!=2 or r.get('background_active',0)<=0):continue
     d.setdefault(r['block'],[]).append(r['first_byte_us']/1000)
   keys=sorted(set(aa)&set(bb))
   if len(keys)!=10:continue
   def p95(d,idx):return pct([x for k in idx for x in d[k]],.95)
   samples=[]
   for _ in range(10000):
    idx=rng.choices(keys,k=10);samples.append(p95(bb,idx)/p95(aa,idx))
   out.append(dict(metric=metric+'/'+phase+'/p95',ratio=b+'/'+a,estimate=p95(bb,keys)/p95(aa,keys),exploratory_ci95=[pct(samples,.025),pct(samples,.975)],higher_is_better=False,blocks=10))
(O/'paired-uncertainty.json').write_text(json.dumps(dict(method='paired whole-block bootstrap10000draws,10blocks; exploratory, no multiple-comparison correction, not formal significance',results=out),indent=2));print(len(out),'ratios')
