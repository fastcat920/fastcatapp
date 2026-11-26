import subprocess as sp,os,signal,gzip,json,hashlib,time
from pathlib import Path
pid=27167;D=Path('/tmp/fc-next');out=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/acceptance-2026-11-21');sock=os.path.expanduser('~/.ssh/fastcat-v2-test.sock');host='root@zlhk.fastcat.ink';adb=['adb','-s','A3GMVB2110006859'];unit='fc-next-next-1795263025';dest='/usr/local/bin/'+unit
try:
 if sp.run(adb+['shell','pidof','compare'],capture_output=True).returncode==0:raise RuntimeError('Benchmark child still active')
 sp.run(['ssh','-S',sock,host,'gzip -dc > '+dest+'.new'],input=gzip.compress((D/'next-fixed').read_bytes()),check=True)
 sp.run(['ssh','-S',sock,host,'chmod 755 '+dest+'.new && mv '+dest+'.new '+dest+' && systemctl restart '+unit],check=True)
 (D/'next-initial').write_bytes((D/'next').read_bytes());(D/'next').write_bytes((D/'next-fixed').read_bytes())
 sp.run(adb+['push',str(D/'check'),'/data/local/tmp/fc-next/check'],check=True)
 sp.run(adb+['shell','chmod','700','/data/local/tmp/fc-next/check'],check=True)
 with (out/'functional-android.jsonl').open('w') as f,(out/'functional-android.log').open('w') as e:sp.run(adb+['shell','/data/local/tmp/fc-next/check','-config','/data/local/tmp/fc-next/config'],stdout=f,stderr=e,check=True,timeout=100)
 rows=[json.loads(x) for x in (out/'functional-android.jsonl').read_text().splitlines() if x.startswith('{')]
 if len(rows)!=27 or not all(r['ok'] for r in rows):raise RuntimeError('Functional checks failed; inspect rows')
 # Original pilot was on the initial server. Keep it explicitly apart from fixed-server checks.
 (out/'pilot-initial.jsonl').write_bytes((out/'pilot.jsonl').read_bytes());(out/'pilot.jsonl').unlink()
 with (out/'pilot.jsonl').open('w') as f,(out/'pilot.log').open('w') as e:sp.run(adb+['shell','/data/local/tmp/fc-next/compare','-config','/data/local/tmp/fc-next/config','-versions','next','-pools','1','-samples','2','-batches','1','-workers','2','-target','191.223.214.8:19454','-target-server-name','zlhk.fastcat.ink'],stdout=f,stderr=e,check=True,timeout=150)
 rows=[json.loads(x) for x in (out/'pilot.jsonl').read_text().splitlines() if x.startswith('{')]
 if any(r.get('error') for r in rows):raise RuntimeError('Fixed-server pilot failed')
 (out/'orchestration.json').write_text(json.dumps(dict(runner_paused_for='waited for active v2 ablation download child to finish; fixed-server deployment and Android functional checks then next-only pilot; no concurrent benchmarks',server_sha256=hashlib.sha256((D/'next').read_bytes()).hexdigest(),checks=len(rows))))
 print('Fixed-server Android checks and pilot passed',flush=True)
finally:
 sp.run(adb+['shell','toybox','rm','-f','/data/local/tmp/fc-next/check'],capture_output=True)
 os.kill(pid,signal.SIGCONT)
