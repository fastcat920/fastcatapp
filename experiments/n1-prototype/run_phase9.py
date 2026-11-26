#!/usr/bin/env python3
from pathlib import Path
import json,random,subprocess,sys,time
root=Path(__file__).resolve().parent/'results/phase9-2026-11-24';root.mkdir(parents=True,exist_ok=True)
phase=sys.argv[1];assert phase in ['matrix','concurrency','cache','wifi']
from phone_network import state
expected='wifi' if phase=='wifi' else 'cellular'
current=state()
if current['transport']!=expected or not current['validated']:raise SystemExit('wrong active validated network: '+json.dumps(current))
output=root/(phase+'-samples.json')
if output.exists():raise SystemExit('preserve existing batch')
rng=random.Random(20261130+['matrix','concurrency','cache','wifi'].index(phase));plan=[]
if phase=='matrix':
 pairs=[]
 for size in [7001,49157,131119,1048576,4194304]:
  for repeat in range(3 if size==4194304 else 2):
   arms=['baseline','capped'];rng.shuffle(arms);pairs.append(dict(bytes=size,repeat=repeat+1,arms=arms))
 rng.shuffle(pairs)
 for pair,p in enumerate(pairs):
  for arm in p['arms']:plan.append(dict(arm=arm,pair=pair,bytes=p['bytes'],repeat=p['repeat'],count=1,workers=1))
elif phase=='concurrency':
 arms=['baseline','capped'];rng.shuffle(arms)
 for arm in arms:plan.append(dict(arm=arm,bytes=131119,count=16,workers=4))
elif phase=='cache':
 arms=['capped','cached']*2;rng.shuffle(arms)
 for block,arm in enumerate(arms):plan.append(dict(arm=arm,block=block,bytes=32768,count=8,workers=1))
else:
 arms=['baseline','capped'];rng.shuffle(arms)
 for arm in arms:
  plan.append(dict(arm=arm,bytes=32768,count=8,workers=1))
  plan.append(dict(arm=arm,bytes=1048576,count=2,workers=1))
(root/(phase+'-declaration.json')).write_text(json.dumps(dict(phase=phase,plan=plan),indent=2))
rows=[];batchmeta=[]
for index,p in enumerate(plan):
 m=subprocess.run(['ssh','-o','BatchMode=yes','-o','ConnectTimeout=8','-S','/tmp/n1-phase9-ssh.sock','root@zlhk.fastcat.ink',"python3 -c 'import time;print(time.time())'"],capture_output=True,text=True,timeout=20)
 begin=float(m.stdout.strip()) if m.returncode==0 else None
 cfg='phase9-'+p['arm']+'.json';budget=60 if p['bytes']>1048576 else 30
 r=subprocess.run(['adb','-s','A3GMVB2110006859','shell','/data/local/tmp/fastcat-n1-lab/n1-systemdns','-mode','diagnose','-config','/data/local/tmp/fastcat-n1-lab/'+cfg,'-kind','matched-n1','-target','127.0.0.1:18462','-bytes',str(p['bytes']),'-chunk','16384','-gap-ms','0','-count',str(p['count']),'-workers',str(p['workers']),'-budget',str(budget)],capture_output=True,text=True,timeout=budget*(p['count']//p['workers']+1)+10)
 parsed=[json.loads(x) for x in r.stdout.splitlines() if x.startswith('{')]
 found={x['sample'] for x in parsed};assert len(found)==len(parsed)
 for missing in set(range(1,p['count']+1))-found:parsed.append(dict(sample=missing,error='missing diagnostic row'))
 for row in parsed:rows.append({**row,**p,'phase':phase,'batch':index,'server_begin_unix':begin,'exit_code':0 if row.get('full_lifecycle_verified') else 1})
 batchmeta.append(dict(index=index,process_exit_code=r.returncode,server_begin_unix=begin,rows=len(parsed)))
 output.write_text(json.dumps(rows,indent=2));(root/(phase+'-batches.json')).write_text(json.dumps(batchmeta,indent=2))
 if r.stderr:(root/(phase+'-'+str(index)+'.stderr.txt')).write_text(r.stderr)
 print(phase,index+1,'of',len(plan),p['arm'],p['bytes'],'full',sum(x.get('full_lifecycle_verified',False) for x in parsed),'/',len(parsed),flush=True)
