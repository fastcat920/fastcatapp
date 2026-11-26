#!/usr/bin/env python3
"""Predeclared 72-flow, same-endpoint study with unseen-size holdout."""
from pathlib import Path
import json
import random
import subprocess

ROOT=Path(__file__).resolve().parent
OUT=ROOT/'results/phase4-2026-11-24'
OUT.mkdir(parents=True,exist_ok=True)
if (OUT/'samples.json').exists():raise SystemExit('Existing samples found; archive the previous run before collecting again')
plan=[]
for split,sizes in [('train',[512,8192,65536]),('holdout',[1024,16384,131072])]:
    block=[]
    for size in sizes:
        for shape,chunk,gap in [('burst',16384,0),('paced',4096,30)]:
            for kind in ['n1','get','rpc']:
                for repeat in range(2):
                    block.append({'split':split,'bytes':size,'shape':shape,'chunk':chunk,
                                  'gap_ms':gap,'kind':kind,'repeat':repeat+1})
    random.Random(20261124+(split=='holdout')).shuffle(block)
    plan.extend(block)
declaration={'plan':plan,'features':['client_records','server_records','client_small_records',
    'server_small_records','log_client_tcp_bytes','log_server_tcp_bytes'],
    'model':'one-level decision stump; threshold/polarity chosen on train only by balanced accuracy',
    'evaluations':['train N1 vs GET, evaluate GET and unseen RPC negatives',
                   'train N1 vs GET+RPC, evaluate held-out sizes'],
    'limitations':'Synthetic implementations, one network/device; not a GFW detection probability estimate'}
(OUT/'declaration.json').write_text(json.dumps(declaration,indent=2))
base=['adb','-s','A3GMVB2110006859','shell','/data/local/tmp/fastcat-n1-lab/n1-systemdns',
      '-mode','workload','-config','/data/local/tmp/fastcat-n1-lab/domain.json',
      '-target','127.0.0.1:18462']
rows=[]
for index,item in enumerate(plan):
    result=subprocess.run(base+['-kind',item['kind'],'-bytes',str(item['bytes']),
        '-chunk',str(item['chunk']),'-gap-ms',str(item['gap_ms'])],capture_output=True,text=True,timeout=45)
    parsed=[json.loads(s) for s in result.stdout.splitlines() if s.startswith('{')]
    row={**item,'index':index,'exit_code':result.returncode,
         **(parsed[-1] if parsed else {'error':'missing metadata row'})}
    rows.append(row)
    (OUT/'samples.json').write_text(json.dumps(rows,indent=2))
    if result.stderr:(OUT/f'case-{index:02d}.stderr.txt').write_text(result.stderr)
    if result.returncode or 'error' in row:
        print('failed case',index,item,flush=True)
        raise SystemExit(1)  # No quiet retries or dropping failed cases.
    if (index+1)%6==0:print('completed',index+1,'of',len(plan),flush=True)
print('All 72 payloads and closing flows passed',flush=True)
