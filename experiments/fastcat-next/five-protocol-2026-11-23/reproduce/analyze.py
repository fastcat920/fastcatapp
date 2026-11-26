# -*- coding: utf-8 -*-
from pathlib import Path
from functools import lru_cache
import sys,json,math,statistics,hashlib,csv,collections
MODE=sys.argv[1];O=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/five-protocol-2026-11-23')/MODE;V=['next-opt','next-base','tuic','hysteria2','vless-vision'];T=json.loads((O/'timeline.json').read_text()) if (O/'timeline.json').exists() else [];R=[];C=[]
def pct(a,q):return sorted(a)[math.ceil(len(a)*q)-1] if a else None
def read(p):
 rows=[]
 if not p.exists():return rows
 for l in p.read_text().splitlines():
  try:r=json.loads(l)
  except:continue
  if isinstance(r,dict):rows.append(r)
 return rows
@lru_cache(None)
def expected(n):
 if n<0 or n>1<<30:return None
 h=hashlib.sha256();block=bytes(range(4))*8192
 for _ in range(n//len(block)):h.update(block)
 h.update(block[:n%len(block)]);return h.hexdigest()
for t in T:
 if t['metric']=='pilot':continue
 C.append(t)
 for r in read(O/(t['name']+'.jsonl')):
  r.update(source=t['name'],metric=t['metric'],block=t['block'],position=t['position'],dest_port=t['dest_port'],outer_transport='TCP/TLS/Vision' if t['version']=='vless-vision' else 'QUIC/TLS')
  if 'received_sha256' in r:
   n=int(r.get('received_bytes',0));r['offline_prefix_verified']=r.get('received_prefix_ok') is True and r['received_sha256']==expected(n)
  R.append(r)
S={};G=[]
for v in V:
 a=[r for r in R if r.get('version')==v];cases=[c for c in C if c['version']==v];d={}
 for m,phase,want in [('latency','cold',6),('latency','warm',6),('latency','batch',8),('batch8','batch',16),('mixed','mixed',6),('idle','idle-resume',1),('web-example','mixed',12),('web-google','mixed',12)]:
  rr=[r for r in a if r['metric']==m and r.get('phase')==phase]
  if phase=='idle-resume':rr=[r for r in rr if r.get('round')==1]
  allfg=rr;expected_count=sum(c['metric']==m for c in cases)*want
  if phase=='mixed':rr=[r for r in rr if r.get('background_ready')==2 and r.get('background_active',0)>0]
  good=[r for r in rr if not r.get('error') and r.get('first_byte_us',0)>0];vals=[r['first_byte_us']/1000 for r in good]
  item=dict(total=len(rr) if phase=='mixed' else expected_count,observed_rows=len(rr),success=len(good),p50_ms=pct(vals,.5),p95_ms=pct(vals,.95),max_ms=max(vals) if vals else None,errors=dict(collections.Counter(r['error'] for r in rr if r.get('error'))),missing_rows=max(0,expected_count-len(allfg)))
  if phase=='mixed':
   bg=[r for r in a if r['metric']==m and r.get('phase')=='mixed_background'];item.update(all_foreground_total=expected_count,all_foreground_observed=len(allfg),all_foreground_success=sum(not r.get('error') and r.get('first_byte_us',0)>0 for r in allfg),background_total=2*sum(c['metric']==m for c in cases),background_success=sum(r.get('complete') is True for r in bg),background_prefix_verified_bytes=sum(r.get('received_bytes',0) for r in bg if r.get('offline_prefix_verified')))
  d[m+'/'+phase]=item
 for m,phase,stream,jobs in [('single32','download','download',1),('parallel4','parallel_download','parallel_download_stream',4),('parallel8','parallel_download','parallel_download_stream',8),('rolling','rolling_download','rolling_download_stream',12)]:
  groups=[]
  for c in [c for c in cases if c['metric']==m]:
   rr=[r for r in a if r['source']==c['name']];one=m=='single32';streams=[r for r in rr if r.get('phase')==stream];summary=[r for r in rr if r.get('phase')==phase];row=summary[-1] if summary else {};ms=row.get('total_ms' if one else 'elapsed_ms')
   if ms is None:ms=next((r['elapsed_ms'] for r in rr if r.get('phase')=='case_timeout'),int((c['end']-c['start'])*1000))
   full=[r for r in streams if r.get('complete') is True and r.get('checksum_ok') is True];fullbytes=sum(r.get('received_bytes',0) for r in full);prefixbytes=sum(r.get('received_bytes',0) for r in streams if r.get('offline_prefix_verified'));badprefix=sum('received_sha256' in r and not r.get('offline_prefix_verified') for r in streams)
   groups.append(dict(source=c['name'],metric=m,version=v,block=c['block'],dest_port=c['dest_port'],jobs=jobs,success=len(full),observed_streams=len(streams),verified_bytes=fullbytes,prefix_verified_bytes=prefixbytes,elapsed_ms=ms,complete_mbps=fullbytes*8/max(ms,1)/1000,prefix_mbps=prefixbytes*8/max(ms,1)/1000,received_bytes=sum(r.get('received_bytes',0) for r in streams),prefix_validation_failures=badprefix,errors=[r['error'] for r in streams if r.get('error')],status=c['status']))
  G+=groups;rates=[g['prefix_mbps'] for g in groups];elapsed=sum(g['elapsed_ms'] for g in groups)
  d[m]=dict(groups=len(groups),jobs=sum(g['jobs'] for g in groups),success=sum(g['success'] for g in groups),verified_bytes=sum(g['verified_bytes'] for g in groups),prefix_verified_bytes=sum(g['prefix_verified_bytes'] for g in groups),elapsed_ms=elapsed,aggregate_prefix_mbps=sum(g['prefix_verified_bytes'] for g in groups)*8/max(elapsed,1)/1000,aggregate_complete_mbps=sum(g['verified_bytes'] for g in groups)*8/max(elapsed,1)/1000,median_prefix_mbps=statistics.median(rates) if rates else None,min_prefix_mbps=min(rates) if rates else None,max_prefix_mbps=max(rates) if rates else None,prefix_validation_failures=sum(g['prefix_validation_failures'] for g in groups),harness_timeouts=sum(g['status']=='harness_timeout' for g in groups),stream_errors=sum(len(g['errors']) for g in groups))
 for w in [1,4]:
  rr=[r for r in a if r.get('phase')=='timed_bulk' and r.get('workers')==w];rates=[r.get('download_mbps',0) for r in rr];d['echo'+str(w)]=dict(groups=len(rr),workers=len(rr)*w,success=sum(r.get('success',0) for r in rr),median_receive_mbps=statistics.median(rates) if rates else None,errors=[e for r in rr for e in r.get('errors',[])])
 S[v]=d
(O/'summary.json').write_text(json.dumps(S,indent=2));(O/'all-rows.json').write_text(json.dumps(R,indent=2));(O/'download-groups.json').write_text(json.dumps(G,indent=2))
if R:
 with (O/'all-rows.csv').open('w') as f:w=csv.DictWriter(f,sorted({k for r in R for k in r}));w.writeheader();w.writerows(R)
print(json.dumps({v:({m:(S[v][m]['groups'],round(S[v][m]['aggregate_prefix_mbps'],2),S[v][m]['success'],S[v][m]['jobs']) for m in ['single32','parallel4','parallel8','rolling']} if MODE=='speed' else {m:S[v][m] for m in ['latency/cold','latency/warm','mixed/mixed']}) for v in V},indent=2))
