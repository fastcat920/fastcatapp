from pathlib import Path
import json,math,statistics,collections
O=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/primary-2026-11-22')
V=['next-base','next-opt','next-primary','tuic','tuic-dual']
def rows(f):
 a=[]
 for l in f.read_text().splitlines():
  try:r=json.loads(l)
  except:continue
  if isinstance(r,dict):a.append(dict(r,test=f.stem))
 return a
def q(a,p):
 a=sorted(a);return round(a[max(0,math.ceil(len(a)*p)-1)],2) if a else None
R=[]
for f in sorted(O.glob('final-*.jsonl')):R+=rows(f)
(O/'all-final-rows.json').write_text(json.dumps(R,indent=2))
for v in V:
 g=[r for r in R if r.get('version')==v]
 if not g:continue
 print(v)
 for p in ['cold','warm','batch','mixed']:
  a=[r for r in g if r.get('phase')==p and (p!='mixed' or r.get('background_active',0)>0)];good=[r['first_byte_us']/1000 for r in a if not r.get('error')];
  if a:print(p,len(good),len(a),q(good,.5),q(good,.95))
 for p in ['parallel_download','rolling_download']:
  a=[r for r in g if r.get('phase')==p]
  if a:
   print(p,len(a),sum(r['success'] for r in a),sum(r.get('jobs',r['workers']) for r in a),'median',statistics.median(r['verified_mbps'] for r in a),'rates',[round(r['verified_mbps'],2) for r in a]);print('usage',[r.get('lane_usage') for r in a])
 for w in [1,4]:
  a=[r for r in g if r.get('phase')=='timed_bulk' and r.get('workers')==w]
  if a:print('echo',w,[round(r['download_mbps'],2) for r in a])
 a=[r for r in g if r.get('phase')=='download']
 if a:print('download',[(r['expected_bytes']//(1<<20),r.get('complete'),r['total_ms']) for r in a])
