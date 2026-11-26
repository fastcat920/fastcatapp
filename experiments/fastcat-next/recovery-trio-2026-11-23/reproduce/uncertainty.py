import json,random,math
from pathlib import Path
O=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/recovery-trio-2026-11-23');R=json.loads((O/'all-rows.json').read_text());G=json.loads((O/'download-groups.json').read_text());rng=random.Random(20261123);out=[]
def quant(a,q):return sorted(a)[math.ceil(len(a)*q)-1] if a else None
def bounds(a):return [quant(a,.025),quant(a,.975)] if a else [None,None]
for a,b in [('next-base','next-opt'),('tuic','next-opt'),('tuic','next-base')]:
 for metric in ['single16','parallel4','parallel8','rolling']:
  aa={r['block']:r for r in G if r['metric']==metric and r['version']==a};bb={r['block']:r for r in G if r['metric']==metric and r['version']==b};keys=sorted(set(aa)&set(bb))
  if len(keys)!=6:continue
  def rate(d,idx):return sum(d[i]['verified_bytes'] for i in idx)*8/max(sum(d[i]['elapsed_ms'] for i in idx),1)/1000
  ratios=[]
  for _ in range(10000):
   idx=rng.choices(keys,k=len(keys));ra=rate(aa,idx);rb=rate(bb,idx)
   if ra>0:ratios.append(rb/ra)
  out.append(dict(metric=metric,ratio=b+'/'+a,higher_is_better=True,estimate=rate(bb,keys)/rate(aa,keys),exploratory_ci95=bounds(ratios),blocks=6,wins=sum(bb[i]['mbps']>aa[i]['mbps'] for i in keys)))
 for metric,phase in [('latency','warm'),('mixed','mixed')]:
  aa={};bb={}
  for v,d in [(a,aa),(b,bb)]:
   for r in R:
    if r.get('metric')!=metric or r.get('version')!=v or r.get('phase')!=phase or r.get('error') or not r.get('first_byte_us'):continue
    if phase=='mixed' and not r.get('background_active',0):continue
    d.setdefault(r['block'],[]).append(r['first_byte_us']/1000)
  keys=sorted(set(aa)&set(bb))
  if len(keys)!=6:continue
  def p95(d,idx):return quant([x for i in idx for x in d[i]],.95)
  ratios=[p95(bb,(idx:=rng.choices(keys,k=len(keys))))/p95(aa,idx) for _ in range(10000)]
  out.append(dict(metric=metric+'/p95',ratio=b+'/'+a,higher_is_better=False,estimate=p95(bb,keys)/p95(aa,keys),exploratory_ci95=bounds(ratios),blocks=6))
(O/'paired-uncertainty.json').write_text(json.dumps(dict(method='matched-block bootstrap, 10000 draws; clusters are whole cases; exploratory only, 6 pairs; not a formal significance claim; no multiplicity correction',results=out),indent=2))
print('Wrote',len(out),'paired uncertainty rows')
