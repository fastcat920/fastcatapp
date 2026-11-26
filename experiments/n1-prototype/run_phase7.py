#!/usr/bin/env python3
"""Predeclared same-binary baseline vs complete-write-capped downlink."""
from pathlib import Path
import json,random,subprocess
ROOT=Path(__file__).resolve().parent;OUT=ROOT/'results/phase7-2026-11-24';OUT.mkdir(parents=True,exist_ok=True)
if (OUT/'samples.json').exists():raise SystemExit('preserve and archive prior run explicitly')
rng=random.Random(20261127);pairs=[]
for size in [5003,33331,131101,1048576]:
 for shape,chunk,gap in [('burst',16384,0),('paced',4096,8)]:
  for repeat in range(2):
   arms=['baseline','capped'];rng.shuffle(arms)
   pairs.append(dict(bytes=size,shape=shape,chunk=chunk,gap_ms=gap,repeat=repeat+1,arms=arms))
rng.shuffle(pairs)
(OUT/'declaration.json').write_text(json.dumps(dict(pairs=pairs,seed=20261127,scope='Implementation A/B; no classifier; not a censorship probability'),indent=2))
base=['adb','-s','A3GMVB2110006859','shell','/data/local/tmp/fastcat-n1-lab/n1-systemdns','-mode','workload','-kind','matched-n1','-target','127.0.0.1:18462']
rows=[]
for pair,item in enumerate(pairs):
 for arm in item['arms']:
  cfg='phase5-coalesced.json' if arm=='baseline' else 'phase7-capped.json'
  r=subprocess.run(base+['-config','/data/local/tmp/fastcat-n1-lab/'+cfg,'-bytes',str(item['bytes']),'-chunk',str(item['chunk']),'-gap-ms',str(item['gap_ms'])],text=True,capture_output=True,timeout=45)
  parsed=[json.loads(x) for x in r.stdout.splitlines() if x.startswith('{')]
  row={**(parsed[-1] if parsed else {'error':'no metadata'}),**{k:v for k,v in item.items() if k!='arms'},'arm':arm,'pair':pair,'kind':'n1','index':len(rows),'exit_code':r.returncode}
  rows.append(row);(OUT/'samples.json').write_text(json.dumps(rows,indent=2))
  if r.stderr:(OUT/f'case-{row["index"]:02d}.stderr.txt').write_text(r.stderr)
  if r.returncode or 'error' in row:raise SystemExit('failed case '+str(row['index']))
 if (pair+1)%2==0:print('completed',len(rows),'of 32',flush=True)
print('All 32 payloads and endings passed',flush=True)
