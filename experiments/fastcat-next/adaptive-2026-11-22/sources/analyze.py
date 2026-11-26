from pathlib import Path
import json,statistics,math,collections
O=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/adaptive-2026-11-22')
def rows(p):
 a=[]
 for l in p.read_text().splitlines():
  try:r=json.loads(l)
  except:continue
  if isinstance(r,dict):a.append(dict(r,test=p.stem))
 return a
def q(a,p):
 a=sorted(a);return round(a[max(0,math.ceil(len(a)*p)-1)],2) if a else None
raw=[]
for f in sorted(O.glob('final-*.jsonl')):raw+=rows(f)
(O/'all-final-rows.json').write_text(json.dumps(raw,indent=2))
for v in ['next-base','next-fixed','next-opt','tuic','tuic-dual']:
 print(v)
 for ph in ['cold','warm','batch','mixed']:
  g=[r for r in raw if r.get('version')==v and r.get('phase')==ph and (ph!='mixed' or r.get('background_active',0)>0)];a=[r['first_byte_us']/1000 for r in g if not r.get('error')];print(ph,len(a),len(g),q(a,.5),q(a,.95))
 for w in [1,4]:
  g=[r for r in raw if r.get('phase')=='timed_bulk' and r.get('version')==v and r.get('workers')==w];a=[r['download_mbps'] for r in g if r.get('success')==w];print('echo',w,[round(x,2) for x in a],statistics.median(a) if a else None)
 g=[r for r in raw if r.get('phase')=='parallel_download' and r.get('version')==v];print('parallel',[(r['success'],round(r['verified_mbps'],2)) for r in g])
 g=[r for r in raw if r.get('phase')=='download' and r.get('version')==v];print('download',[(r['expected_bytes']//(1<<20),r['complete'],r['total_ms']) for r in g])
