from lab import Lab,D,OUT
import json,time,hashlib,subprocess as sp
V='next,v2,v2-bbr,v3-light-fast,vless-vision,trojan,hysteria2,tuic,anytls'
with Lab('full',full=True,trace=False) as lab:
 lab.start();fixed=['-target','191.223.214.8:19454','-target-server-name','zlhk.fastcat.ink']
 lab.phase('pilot',['-pools','1','-samples','1','-batches','1','-workers','1']+fixed,V,timeout=500)
 rows=[json.loads(x) for x in (OUT/'pilot.jsonl').read_text().splitlines() if x.startswith('{')]
 paths={(r['version'],r['protocol']) for r in rows};success={(r['version'],r['protocol']) for r in rows if not r.get('error')}
 if len(paths)!=12 or paths-success:raise RuntimeError('Pilot lacks a successful path; full comparison stopped')
 lab.phase('controlled',['-pools','3','-samples','20','-batches','5','-workers','4']+fixed,V)
 lab.phase('internet',['-pools','3','-samples','20','-batches','5','-workers','4'],V)
 lab.phase('singlepool',['-workload','batch-only','-pools','1','-batches','20','-workers','1']+fixed,V)
 lab.phase('concurrent8',['-workload','batch-only','-pools','1','-batches','3','-workers','8']+fixed,V)
 lab.phase('idle70',['-idle-seconds','70']+fixed,V,timeout=500)
 lab.phase('downloads1m',['-download-bytes',str(1<<20),'-download-rounds','3','-download-timeout','30s']+fixed,V,bulk=True,timeout=1500)
 lab.phase('throughput',['-bulk-only','-bulk-rounds','3','-bulk-seconds','8','-bulk-target','191.223.214.8:19445'],V,bulk=True,timeout=1800)
 # One medium-size completion attempt per path, keeping the fixed deadline.
 lab.phase('downloads10m',['-download-bytes',str(10<<20),'-download-rounds','1','-download-timeout','90s']+fixed,V,bulk=True,timeout=1500)
 lab.phase('downloads100m',['-download-bytes',str(100<<20),'-download-rounds','1','-download-timeout','240s']+fixed,'next,v2-bbr',bulk=True,timeout=900)
 meta=dict(date='2026-11-21',versions=V.split(','),paths=sorted([list(p) for p in paths]),device='A3GMVB2110006859',client='independent Android core CLI, VPN disabled; not formal App/TUN',client_go='1.26.2',servers_go='1.27.3',next_mss=0,mss_experiment_not_default=True,trace_enabled=False,production_modified=False,start_unix=lab.starttime,end_unix=time.time(),sha256={n:hashlib.sha256((D/n).read_bytes()).hexdigest() for n in ['compare','next-diagnostic']},other_binaries={n:hashlib.sha256(p.read_bytes()).hexdigest() for n,p in [('v2',__import__('pathlib').Path('/tmp/fc-next/v2')),('light',__import__('pathlib').Path('/tmp/fc-seven-way/v3')),('xray',__import__('pathlib').Path('/tmp/fc-seven-way/xray-lab'))]})
 (OUT/'metadata.json').write_text(json.dumps(meta,indent=2));print('ALL EIGHT PROTOCOL COMPARISONS COMPLETE',flush=True)
