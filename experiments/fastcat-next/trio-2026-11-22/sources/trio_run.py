from lab import Lab,D
import lab,json,time,hashlib,itertools,statistics
from pathlib import Path
OUT=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/trio-2026-11-22');lab.OUT=OUT
V=['next-base','next-opt','tuic'];orders=list(itertools.permutations(V));fixed=['-target','191.223.214.8:19454','-target-server-name','zlhk.fastcat.ink']
metrics=[
 ('latency',3,['-samples','12','-pools','1','-batches','3','-workers','4'],False,450),
 ('batch8',3,['-workload','batch-only','-samples','1','-pools','1','-batches','3','-workers','8'],False,180),
 ('single16',6,['-download-bytes',str(16<<20),'-download-rounds','1','-download-timeout','90s'],True,120),
 ('parallel4',6,['-download-bytes',str(4<<20),'-download-workers','4','-download-rounds','1','-download-timeout','90s'],True,120),
 ('parallel8',6,['-download-bytes',str(2<<20),'-download-workers','8','-download-rounds','1','-download-timeout','90s'],True,120),
 ('rolling',6,['-download-bytes',str(4<<20),'-download-workers','4','-download-jobs','12','-download-rounds','1','-download-timeout','150s'],True,180),
 ('mixed',3,['-mixed-download-bytes',str(16<<20),'-samples','12','-download-rounds','1','-download-timeout','90s'],True,120),
 ('echo',3,['-bulk-only','-bulk-rounds','1','-bulk-seconds','10','-bulk-target','191.223.214.8:19445'],True,100),
 ('idle',3,['-idle-seconds','20'],False,100)]
plan=dict(date='2026-11-22',device='TFY-AN00 Android12',network='Wi-Fi required; prototype core CLI; App VPN temporarily disconnected',versions=V,orders=orders,metrics=metrics,services_restart_each_case=True,cooldown_seconds=5,trace=False,sha256={n:hashlib.sha256((D/n).read_bytes()).hexdigest() for n in ['compare','next-diagnostic']},notes='Same frozen binaries as previous experiment. No parameter tuning during run. Idle first resume distinguished from next 2 requests. Echo is simultaneous bidirectional echo, not pure upload. Resource readings are Go heap snapshots, not app power or OS peak RSS.')
(OUT/'plan.json').write_text(json.dumps(plan,indent=2));timeline=[]
with Lab('trio',full=True,trace=False) as x:
 x.start();x.cfg.update(NextOptimizedAddress=x.cfg['NextAddress'],NextOptimizedProfile='baseline',NextOptimizedCoalesce=False,NextOptimizedConnections=2,NextOptimizedAdaptive=True)
 p=x.privatefile('trio-config',x.cfg);x.adb('push',str(p),x.ad+'/config');x.adb('shell','chmod','600',x.ad+'/config');native=next(u for u in x.units if u.startswith('fc-opt-xray-'))
 (OUT/'battery-start.txt').write_text(x.adb('shell','dumpsys','battery'))
 for metric,n,args,bulk,timeout in metrics:
  for b in range(n):
   order=orders[b] if n==6 else [tuple(V[(b+i)%3] for i in range(3))][0]
   for pos,v in enumerate(order):
    x.ssh('systemctl restart '+x.nextunit+' '+native);time.sleep(5)
    name=f'{metric}-b{b+1}-p{pos+1}-{v}';start=time.time()
    x.phase(name,args+fixed,v,bulk=bulk,timeout=timeout)
    timeline.append(dict(name=name,metric=metric,block=b+1,position=pos+1,version=v,start=start,end=time.time()));(OUT/'timeline.json').write_text(json.dumps(timeline,indent=2))
 (OUT/'battery-end.txt').write_text(x.adb('shell','dumpsys','battery'))
print('TRIO COMPLETE',flush=True)
