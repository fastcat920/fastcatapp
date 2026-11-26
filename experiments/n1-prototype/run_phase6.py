#!/usr/bin/env python3
"""Matched upstream sizes/causal phases; new held-out response sizes."""
from pathlib import Path
import json,random,subprocess
ROOT=Path(__file__).resolve().parent
OUT=ROOT/'results/phase6-2026-11-24';OUT.mkdir(parents=True,exist_ok=True)
if (OUT/'samples.json').exists():raise SystemExit('archive existing run explicitly before a full new run')
plan=[]
for split,sizes in [('train',[2048,20480,81920]),('holdout',[4096,40960,163840])]:
 block=[]
 for size in sizes:
  for shape,chunk,gap in [('burst',16384,0),('paced',4096,12)]:
   for repeat in range(2):block.append(dict(split=split,bytes=size,shape=shape,chunk=chunk,gap_ms=gap,repeat=repeat+1))
 random.Random(20261126+(split=='holdout')).shuffle(block);plan.extend(block)
features=['client_records','server_records','client_small_records','server_small_records','log_client_tcp_bytes','log_server_tcp_bytes']
(OUT/'declaration.json').write_text(json.dumps(dict(plan=plan,features=features,limitations='Synthetic length/phase-matched streaming job; fixed N1-first pair order; one device/network; not GFW detection probability'),indent=2))
BASE=['adb','-s','A3GMVB2110006859','shell','/data/local/tmp/fastcat-n1-lab/n1-systemdns','-config','/data/local/tmp/fastcat-n1-lab/phase5-coalesced.json']
rows=[]
for pair,item in enumerate(plan):
 matching=None
 for kind in ['n1','rpc']:
  args=['-mode','workload','-kind','matched-n1','-target','127.0.0.1:18462'] if kind=='n1' else ['-mode','matched-rpc','-match-shape',matching]
  result=subprocess.run(BASE+args+['-bytes',str(item['bytes']),'-chunk',str(item['chunk']),'-gap-ms',str(item['gap_ms'])],capture_output=True,text=True,timeout=45)
  parsed=[json.loads(x) for x in result.stdout.splitlines() if x.startswith('{')]
  row={**(parsed[-1] if parsed else {'error':'no metadata'}),**item,'kind':kind,'pair':pair,'index':len(rows),'exit_code':result.returncode}
  rows.append(row);(OUT/'samples.json').write_text(json.dumps(rows,indent=2))
  if result.stderr:(OUT/f'case-{row["index"]:02d}.stderr.txt').write_text(result.stderr)
  if result.returncode or 'error' in row:raise SystemExit('failed case '+str(row['index']))
  w=row['request_writes'];assert len(w)==3
  if kind=='n1':matching=f'{w[0]["bytes"]},{w[1]["body_bytes"]},{w[2]["body_bytes"]}'
  else:assert [x['bytes'] for x in w]==[x['bytes'] for x in rows[-2]['request_writes']], 'upstream write mismatch'
 if (pair+1)%3==0:print('completed',len(rows),'of 48',flush=True)
print('All 48 payloads, endings and matched upstream write lengths passed',flush=True)
