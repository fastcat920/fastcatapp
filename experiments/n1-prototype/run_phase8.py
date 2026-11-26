#!/usr/bin/env python3
from pathlib import Path
import json,random,subprocess,sys
root=Path(__file__).resolve().parent/'results/phase8-2026-11-24';network=sys.argv[1]
assert network in ['wifi','cellular'];out=root/(network+'-samples.json')
if out.exists():raise SystemExit('preserve existing sample batch')
plan=[]
for case in ['n1','ip','x25519','https','retry']:
 for i in range(4):plan.append(dict(case=case,bytes=32768,repeat=i+1))
for case in ['n1','https','retry']:
 for i in range(2):plan.append(dict(case=case,bytes=1048576,repeat=i+1))
random.Random(20261129+(network=='cellular')).shuffle(plan)
(root/(network+'-declaration.json')).write_text(json.dumps(dict(plan=plan,network=network,scope='new TCP/TLS; total30s; includes failures; X25519 diagnostic only'),indent=2))
rows=[]
for i,item in enumerate(plan):
 marker=subprocess.run(['ssh','-o','BatchMode=yes','-o','ConnectTimeout=8','-S','/tmp/n1-analysis-ssh.sock','root@zlhk.fastcat.ink',"python3 -c 'import time;print(time.time())'"],capture_output=True,text=True,timeout=20)
 server_begin=float(marker.stdout.strip()) if marker.returncode==0 else None
 cfg={'n1':'default','ip':'ip','x25519':'x25519','https':'default','retry':'retry'}[item['case']]
 r=subprocess.run(['adb','-s','A3GMVB2110006859','shell','/data/local/tmp/fastcat-n1-lab/n1-systemdns','-mode','diagnose','-config','/data/local/tmp/fastcat-n1-lab/phase8-'+cfg+'.json','-target','127.0.0.1:18462','-kind',('get' if item['case']=='https' else 'matched-n1'),'-bytes',str(item['bytes']),'-chunk','16384','-gap-ms','0','-count','1','-budget','30'],capture_output=True,text=True,timeout=40)
 parsed=[json.loads(x) for x in r.stdout.splitlines() if x.startswith('{')]
 row={**(parsed[-1] if parsed else {'error':'missing diagnostic row'}),**item,'network':network,'server_begin_unix':server_begin,'index':i,'exit_code':r.returncode}
 rows.append(row);out.write_text(json.dumps(rows,indent=2))
 # Diagnostic mode stderr contains an aggregate count only, no raw peer names.
 if r.stderr:(root/(network+'-'+str(i)+'.stderr.txt')).write_text(r.stderr)
 print(network,i+1,'of26',item['case'],'ok' if r.returncode==0 else row.get('error'),flush=True)
