import json,math,statistics,sys
from pathlib import Path
O=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/reply-2026-11-23/ecn-performance');S={}
def pct(a,q):return sorted(a)[math.ceil(len(a)*q)-1] if a else None
for phase in ['mechanism','performance']:
 P=O/phase
 if not P.exists():continue
 T=json.loads((P/'timeline.json').read_text()) if (P/'timeline.json').exists() else [];variants={r['name']:r['variant'] for r in T};R=[]
 for f in sorted(P.glob('*.jsonl')):
  v=variants.get(f.stem)
  if v is None:v='noecn' if 'noecn' in f.stem else 'baseline'
  for l in f.read_text().splitlines():
   try:r=json.loads(l)
   except:continue
   r.update(source=f.name,variant=v);R.append(r)
 a={}
 for v in ['baseline','noecn']:
  rows=[r for r in R if r['variant']==v];m=[r for r in rows if r.get('phase')=='mixed'];loaded=[r for r in m if r.get('background_active',0)>0];good=[r for r in loaded if not r.get('error') and r.get('first_byte_us',0)>0]
  d=dict(loaded_success=len(good),loaded_total=len(loaded),loaded_p50=pct([r['first_byte_us']/1000 for r in good],.5),loaded_p95=pct([r['first_byte_us']/1000 for r in good],.95),foreground_success=sum(not r.get('error') for r in m),foreground_total=len(m),background_success=sum(r.get('complete',False) for r in rows if r.get('phase')=='mixed_background'),background_total=sum(r.get('phase')=='mixed_background' for r in rows))
  for metric,stage in [('parallel','parallel_download'),('rolling','rolling_download')]:
   g=[r for r in rows if r.get('phase')==stage];d[metric]=dict(groups=len(g),success=sum(r['success'] for r in g),jobs=sum(r.get('jobs',r['workers']) for r in g),aggregate_mbps=sum(r.get('verified_bytes',0) for r in g)*8/max(sum(r['elapsed_ms'] for r in g),1)/1000,median_mbps=statistics.median([r['verified_mbps'] for r in g]) if g else None)
  for stage in ['cold','warm','batch']:
   g=[r for r in rows if r.get('phase')==stage];good=[r for r in g if not r.get('error') and r.get('first_byte_us',0)>0];d[stage]=dict(success=len(good),total=len(g),p50=pct([r['first_byte_us']/1000 for r in good],.5),p95=pct([r['first_byte_us']/1000 for r in good],.95))
  if phase=='mechanism':
   events=[]
   for f in P.glob('*'+v+'*-server.log'):
    for l in f.read_text().splitlines():
     try:events.append(json.loads(l))
     except:pass
   d['combined']=sum(e.get('stage')=='reply_combined' for e in events);d['flushed']=sum(e.get('stage')=='reply_status_flushed' for e in events);d['first_byte_only_frames']=sum(e.get('stage')=='server_stream_prefix_sent' and e.get('frame_offset',0)==0 and e.get('frame_length')==1 for e in events)
  a[v]=d
 result=dict(phase=phase,summary=a,rows=len(R));
 if phase=='performance':
  b,c=a['baseline'],a['noecn'];checks={};checks['enough_loaded']=min(b['loaded_total'],c['loaded_total'])>=48;checks['loaded_p95']=bool(b['loaded_p95'] and c['loaded_p95'] and c['loaded_p95']<=b['loaded_p95']*.8);checks['foreground_complete']=b['foreground_total']==c['foreground_total']==72 and c['foreground_success']>=b['foreground_success'];checks['background_complete']=b['background_total']==c['background_total']==12 and c['background_success']>=b['background_success']
  for k in ['parallel','rolling']:
   checks[k+'_complete']=b[k]['groups']==c[k]['groups']==6 and c[k]['success']>=b[k]['success'];checks[k+'_throughput']=c[k]['aggregate_mbps']>=b[k]['aggregate_mbps']*.9
  checks['warm_not_regressed']=bool(b['warm']['p95'] and c['warm']['p95'] and c['warm']['p95']<=b['warm']['p95']*1.1 and b['warm']['total']==c['warm']['total']==36)
  result['gate']=dict(passed=all(checks.values()),checks=checks)
 (P/'rows.json').write_text(json.dumps(R,indent=2));(P/'summary.json').write_text(json.dumps(result,indent=2));S[phase]=result
print(json.dumps(S,indent=2))
