import json,sys,math,statistics,collections
from pathlib import Path
ROOT=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/latency-2026-11-22');stage=sys.argv[1] if len(sys.argv)>1 else 'stage12';O=ROOT/stage
R=[]
for f in sorted(O.glob('*.jsonl')):
 for l in f.read_text().splitlines():
  try:r=json.loads(l)
  except:continue
  if not isinstance(r,dict):continue
  r['source']=f.name;r['metric']=f.name.split('-b')[0];R.append(r)
(O/'all-rows.json').write_text(json.dumps(R,indent=2))
V=json.loads((O/'plan.json').read_text())['versions']
def pct(a,q):return sorted(a)[math.ceil(len(a)*q)-1] if a else None
def p(v,phase,metric=None):return [r for r in R if r.get('version')==v and r.get('phase')==phase and (metric is None or r['metric']==metric)]
S={}
for v in V:
 a=p(v,'mixed');loaded=[r for r in a if r.get('background_active',0)>0];good=[r for r in loaded if not r.get('error') and r.get('first_byte_us',0)>0];d=dict(loaded_success=len(good),loaded_total=len(loaded),loaded_p50=pct([r['first_byte_us']/1000 for r in good],.5),loaded_p95=pct([r['first_byte_us']/1000 for r in good],.95),mixed_groups=len(p(v,'mixed_summary')),foreground_success=sum(not r.get('error') for r in a),foreground_total=len(a),background_success=sum(r.get('complete',False) for r in p(v,'mixed_background')),background_total=len(p(v,'mixed_background')))
 for metric,phase in [('parallel','parallel_download'),('rolling','rolling_download')]:
  a=p(v,phase,metric);d[metric]=dict(groups=len(a),success=sum(r.get('success',0) for r in a),jobs=sum(r.get('jobs',r.get('workers',0)) for r in a),aggregate_mbps=sum(r.get('verified_bytes',0) for r in a)*8/max(sum(r.get('elapsed_ms',0) for r in a),1)/1000,median_mbps=statistics.median([r.get('verified_mbps',0) for r in a]) if a else None)
 for phase in ['cold','warm','batch']:
  a=p(v,phase);good=[r for r in a if not r.get('error') and r.get('first_byte_us',0)>0];d[phase]=dict(success=len(good),total=len(a),p50=pct([r['first_byte_us']/1000 for r in good],.5),p95=pct([r['first_byte_us']/1000 for r in good],.95))
 S[v]=d
G={};base=S['next-opt']
for v in V[1:]:
 c=S[v];checks={};checks['enough_samples']=min(c['loaded_total'],base['loaded_total'])>=48 and c['mixed_groups']==base['mixed_groups']==6
 checks['loaded_p95']=bool(c['loaded_p95'] is not None and base['loaded_p95'] and c['loaded_p95']<=base['loaded_p95']*.8)
 checks['foreground_completion']=c['foreground_success']==c['foreground_total'] and base['foreground_success']==base['foreground_total']
 checks['background_completion']=c['background_success']>=base['background_success'] and c['background_total']==base['background_total']==12
 for metric in ['parallel','rolling']:
  a,b=c[metric],base[metric];checks[metric+'_complete']=a['groups']==b['groups']==6 and a['success']>=b['success'];checks[metric+'_throughput']=a['aggregate_mbps']>=b['aggregate_mbps']*.9
 G[v]=dict(passed=all(checks.values()),checks=checks)
result=dict(stage=stage,rows=len(R),summary=S,gate=G)
(O/'summary.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2))
