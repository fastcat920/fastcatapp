from pathlib import Path
import json,statistics,math,collections
O=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/throughput-2026-11-22')
def rows(p):
 out=[]
 for l in p.read_text().splitlines():
  try:r=json.loads(l)
  except:continue
  if isinstance(r,dict):out.append(dict(r,test=p.stem))
 return out
def q(a,p):
 a=sorted(a);return round(a[max(0,math.ceil(len(a)*p)-1)],3) if a else None
raw=[]
for f in O.glob('final-*.jsonl'):raw+=rows(f)
(O/'all-final-rows.json').write_text(json.dumps(raw,indent=2))
for v in ['next-base','next-opt','tuic']:
 print(v)
 for phase in ['cold','warm','batch']:
  g=[r for r in raw if r.get('phase')==phase and r.get('version')==v];a=[r['first_byte_us']/1000 for r in g if not r.get('error')];print(phase,len(a),len(g),q(a,.5),q(a,.95))
 for w in [1,4]:
  g=[r for r in raw if r.get('phase')=='timed_bulk' and r.get('version')==v and r.get('workers')==w];a=[r['download_mbps'] for r in g if r.get('success')==w];print('echo',w,[round(x,3) for x in a],q(a,.5))
 g=[r for r in raw if r.get('phase')=='parallel_download' and r.get('version')==v];print('parallel',[(r['success'],r['workers'],round(r['verified_mbps'],3),r['elapsed_ms']) for r in g])
 g=[r for r in raw if r.get('phase')=='download' and r.get('version')==v];print('download',[(r['expected_bytes']//(1<<20),r['complete'],r['total_ms']) for r in g])
