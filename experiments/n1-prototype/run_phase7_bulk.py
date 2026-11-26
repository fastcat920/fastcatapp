#!/usr/bin/env python3
from pathlib import Path
import json,subprocess,random
root=Path(__file__).resolve().parent/'results/phase7-2026-11-24'
if (root/'bulk-samples.json').exists():raise SystemExit('preserve existing bulk sample run')
rng=random.Random(20261128);plan=[]
for repeat in range(4):
 arms=['baseline','capped'];rng.shuffle(arms);plan.append(dict(repeat=repeat+1,arms=arms))
(root/'bulk-declaration.json').write_text(json.dumps(dict(reason='primary baseline 1MiB burst body-read rates 0.50 vs 9.83 Mbps; follow-up predeclared after seeing anomaly, not independent holdout',plan=plan,size=1048576,source_chunk=16384,gap_ms=0,ports=dict(baseline=18463,capped=18465)),indent=2))
rows=[]
for pair in plan:
 for arm in pair['arms']:
  cfg='phase7-capped.json' if arm=='baseline' else 'phase7-bulk-capped.json'
  r=subprocess.run(['adb','-s','A3GMVB2110006859','shell','/data/local/tmp/fastcat-n1-lab/n1-systemdns','-mode','workload','-kind','matched-n1','-config','/data/local/tmp/fastcat-n1-lab/'+cfg,'-target','127.0.0.1:18462','-bytes','1048576','-chunk','16384','-gap-ms','0'],capture_output=True,text=True,timeout=45)
  parsed=[json.loads(x) for x in r.stdout.splitlines() if x.startswith('{')]
  row={**(parsed[-1] if parsed else {'error':'missing metadata'}),'kind':'n1','arm':arm,'repeat':pair['repeat'],'index':len(rows),'exit_code':r.returncode}
  rows.append(row);(root/'bulk-samples.json').write_text(json.dumps(rows,indent=2))
  if r.stderr:(root/f'bulk-{row["index"]}.stderr.txt').write_text(r.stderr)
  if r.returncode or 'error' in row:raise SystemExit('bulk failure '+str(row['index']))
 print('bulk pairs complete',pair['repeat'],'of 4',flush=True)
