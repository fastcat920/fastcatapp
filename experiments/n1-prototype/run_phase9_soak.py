#!/usr/bin/env python3
from pathlib import Path
import subprocess,time,json
root=Path(__file__).resolve().parent/'results/phase9-2026-11-24'
if (root/'soak-status.json').exists():raise SystemExit('preserve prior soak')
processes={};files={};start=time.time()
for arm in ['baseline','capped']:
 out=(root/('soak-'+arm+'.jsonl')).open('w');err=(root/('soak-'+arm+'.stderr.txt')).open('w');files[arm]=(out,err)
 cmd=['adb','-s','A3GMVB2110006859','shell','/data/local/tmp/fastcat-n1-lab/n1-systemdns','-mode','diagnose','-config','/data/local/tmp/fastcat-n1-lab/phase9-'+arm+'.json','-kind','matched-n1','-target','127.0.0.1:18462','-bytes','8192','-chunk','16384','-gap-ms','0','-count','200','-workers','1','-budget','30','-run-seconds','600','-interval-ms','4000','-metrics-file','/data/local/tmp/fastcat-n1-lab/phase9-soak-'+arm+'-runtime.jsonl']
 processes[arm]=subprocess.Popen(cmd,stdout=out,stderr=err)
while any(p.poll() is None for p in processes.values()):
 time.sleep(10)
 elapsed=round(time.time()-start)
 if elapsed%30<10:print('soak elapsed',elapsed,'seconds',flush=True)
 if elapsed>660:
  for p in processes.values():
   if p.poll() is None:p.terminate()
  break
status={arm:dict(exit_code=p.wait(timeout=10)) for arm,p in processes.items()}
for a,b in files.values():a.close();b.close()
(root/'soak-status.json').write_text(json.dumps(dict(elapsed_seconds=time.time()-start,processes=status),indent=2))
print('soak finished',status,flush=True)
