import json,math,statistics,collections,csv
from pathlib import Path
O=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/recovery-trio-2026-11-23');V=['next-opt','next-base','tuic']
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
 for r in read(O/(t['name']+'.jsonl')):R.append(dict(r,source=t['name'],metric=t['metric'],block=t['block'],position=t['position'],dest_port=t['ports']['tuic_port' if t['version']=='tuic' else 'next_port']))
S={};G=[]
for v in V:
 a=[r for r in R if r.get('version')==v];d={}
 for metric,phase in [('latency','cold'),('latency','warm'),('latency','batch'),('batch8','batch'),('mixed','mixed'),('web-example','mixed'),('web-google','mixed'),('idle','idle-resume')]:
  rows=[r for r in a if r.get('metric')==metric and r.get('phase')==phase]
  if phase=='idle-resume':rows=[r for r in rows if r.get('round')==1]
  if phase=='mixed':
   fg=rows;rows=[r for r in rows if r.get('background_active',0)>0];bg=[r for r in a if r.get('metric')==metric and r.get('phase')=='mixed_background']
  good=[r for r in rows if not r.get('error') and r.get('first_byte_us',0)>0];vals=[r['first_byte_us']/1000 for r in good]
  x=dict(total=len(rows),success=len(good),p50_ms=pct(vals,.5),p95_ms=pct(vals,.95),max_ms=max(vals) if vals else None,errors=dict(collections.Counter(r.get('error') for r in rows if r.get('error'))))
  if phase=='mixed':x.update(all_foreground_total=len(fg),all_foreground_success=sum(not r.get('error') for r in fg),background_total=len(bg),background_success=sum(r.get('complete',False) for r in bg))
  if phase=='idle-resume':x['median_actual_idle_seconds']=statistics.median([r['idle_us']/1e6 for r in rows]) if rows else None
  d[metric+'/'+phase]=x
 for metric,phase in [('single16','download'),('parallel4','parallel_download'),('parallel8','parallel_download'),('rolling','rolling_download')]:
  rows=[r for r in a if r.get('metric')==metric and r.get('phase')==phase];groups=[]
  for r in rows:
   one=phase=='download';done=int(r.get('complete',False)) if one else r['success'];jobs=1 if one else r.get('jobs',r['workers']);byt=(r.get('received_bytes',0) if done else 0) if one else r.get('verified_bytes',0);ms=r.get('total_ms',0) if one else r.get('elapsed_ms',0)
   groups.append(dict(source=r['source'],metric=metric,version=v,block=r['block'],dest_port=r['dest_port'],success=done,jobs=jobs,verified_bytes=byt,elapsed_ms=ms,mbps=byt*8/max(ms,1)/1000,error=r.get('error'),lane_usage=r.get('lane_usage')))
  G+=groups;rates=[r['mbps'] for r in groups];elapsed=sum(r['elapsed_ms'] for r in groups)
  d[metric]=dict(groups=len(groups),success=sum(r['success'] for r in groups),jobs=sum(r['jobs'] for r in groups),verified_bytes=sum(r['verified_bytes'] for r in groups),elapsed_ms=elapsed,aggregate_mbps=sum(r['verified_bytes'] for r in groups)*8/max(elapsed,1)/1000,median_mbps=statistics.median(rates) if rates else None,min_mbps=min(rates) if rates else None,max_mbps=max(rates) if rates else None)
 for workers in [1,4]:
  rows=[r for r in a if r.get('phase')=='timed_bulk' and r.get('workers')==workers];rates=[r.get('download_mbps') or 0 for r in rows];alloc=[r['alloc_bytes']/r['received_bytes'] for r in rows if r.get('received_bytes',0)>0];heap=[r['heap_live_bytes']/1048576 for r in rows if r.get('heap_live_bytes') is not None]
  d['echo'+str(workers)]=dict(groups=len(rows),workers=len(rows)*workers,success=sum(r.get('success',0) for r in rows),median_receive_mbps=statistics.median(rates) if rates else None,median_alloc_per_verified_byte=statistics.median(alloc) if alloc else None,median_heapalloc_mib=statistics.median(heap) if heap else None,errors=[e for r in rows for e in r.get('errors',[])])
 S[v]=d
P={}
for metric in ['latency','mixed','single16','parallel4','parallel8','rolling']:
 p={}
 for v in V:
  vv={}
  for port in [19451,19458]:
   if metric in ['latency','mixed']:
    phase='warm' if metric=='latency' else 'mixed';rr=[r for r in R if r.get('metric')==metric and r.get('version')==v and r.get('phase')==phase and r['dest_port']==port and (phase!='mixed' or r.get('background_active',0)>0)];good=[r['first_byte_us']/1000 for r in rr if not r.get('error') and r.get('first_byte_us',0)>0];vv[str(port)]=dict(total=len(rr),success=len(good),p95_ms=pct(good,.95))
   else:
    rr=[r for r in G if r['metric']==metric and r['version']==v and r['dest_port']==port];vv[str(port)]=dict(groups=len(rr),success=sum(r['success'] for r in rr),jobs=sum(r['jobs'] for r in rr),aggregate_mbps=sum(r['verified_bytes'] for r in rr)*8/max(sum(r['elapsed_ms'] for r in rr),1)/1000)
  p[v]=vv
 P[metric]=p
(O/'all-rows.json').write_text(json.dumps(R,indent=2));(O/'download-groups.json').write_text(json.dumps(G,indent=2));(O/'summary.json').write_text(json.dumps(S,indent=2));(O/'port-summary.json').write_text(json.dumps(P,indent=2))
if R:
 with (O/'all-rows.csv').open('w') as f:w=csv.DictWriter(f,sorted(set(k for r in R for k in r)));w.writeheader();w.writerows(R)
print(json.dumps({v:{k:S[v][k] for k in ['latency/cold','latency/warm','mixed/mixed','parallel4','rolling']} for v in V},indent=2))
