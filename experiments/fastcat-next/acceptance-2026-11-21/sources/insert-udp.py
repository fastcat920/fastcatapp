import subprocess as sp,os,signal,time,json,hashlib
from pathlib import Path
pid=27167;serial='A3GMVB2110006859';adb=['adb','-s',serial];D=Path('/tmp/fc-next');out=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/acceptance-2026-11-21')
os.kill(pid,signal.SIGSTOP)
try:
 deadline=time.time()+900
 while sp.run(adb+['shell','pidof','compare'],capture_output=True).returncode==0:
  if time.time()>deadline:raise RuntimeError('Active phase did not finish')
  time.sleep(1)
 sp.run(adb+['push',str(D/'check-matrix'),'/data/local/tmp/fc-next/check-matrix'],check=True)
 sp.run(adb+['shell','chmod','700','/data/local/tmp/fc-next/check-matrix'],check=True)
 with (out/'udp-matrix.jsonl').open('w') as f,(out/'udp-matrix.log').open('w') as e:sp.run(adb+['shell','/data/local/tmp/fc-next/check-matrix','-config','/data/local/tmp/fc-next/config','-udp-matrix'],stdout=f,stderr=e,check=True,timeout=100)
 print('UDP matrix recorded',flush=True)
 # Recheck the fixed server with short requests. Initial pilot is retained separately.
 with (out/'pilot-fixed.jsonl').open('w') as f,(out/'pilot-fixed.log').open('w') as e:sp.run(adb+['shell','/data/local/tmp/fc-next/compare','-config','/data/local/tmp/fc-next/config','-versions','next','-pools','1','-samples','2','-batches','1','-workers','2','-target','191.223.214.8:19454','-target-server-name','zlhk.fastcat.ink'],stdout=f,stderr=e,check=True,timeout=150)
 rows=[json.loads(x) for x in (out/'pilot-fixed.jsonl').read_text().splitlines() if x.startswith('{')]
 print('Fixed-server pilot failures: '+str(sum(bool(r.get('error')) for r in rows)),flush=True)
finally:
 sp.run(adb+['shell','toybox','rm','-f','/data/local/tmp/fc-next/check-matrix'],capture_output=True)
 os.kill(pid,signal.SIGCONT)
