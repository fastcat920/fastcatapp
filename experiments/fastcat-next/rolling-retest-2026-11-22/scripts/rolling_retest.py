from lab import Lab,D
import lab,json,time,hashlib
from pathlib import Path
OUT=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/rolling-retest-2026-11-22');OUT.mkdir(exist_ok=True);lab.OUT=OUT
V=['next-base','next-opt','next-primary','tuic'];W=[[0,1,3,2],[1,2,0,3],[2,3,1,0],[3,0,2,1]]
plan=[dict(cycle=c+1,block=b+1,order=[V[i] for i in order]) for c in range(2) for b,order in enumerate(W)]
(OUT/'plan.json').write_text(json.dumps(dict(design='two Williams cycles; 8 cases per mode',bytes_per_job=4<<20,jobs=12,workers=4,group_timeout_seconds=150,transport_restart_each_case=True,cooldown_seconds=5,blocks=plan,sha256={n:hashlib.sha256((D/n).read_bytes()).hexdigest() for n in ['compare','next-diagnostic']}),indent=2))
with Lab('rolling-retest',full=True,trace=False) as x:
 x.start();x.cfg.update(NextOptimizedAddress=x.cfg['NextAddress'],NextOptimizedProfile='baseline',NextOptimizedCoalesce=False,NextOptimizedConnections=2,NextOptimizedAdaptive=True)
 p=x.privatefile('rolling-config',x.cfg);x.adb('push',str(p),x.ad+'/config');x.adb('shell','chmod','600',x.ad+'/config')
 native=next(u for u in x.units if u.startswith('fc-opt-xray-'));timeline=[]
 for block in plan:
  for pos,v in enumerate(block['order']):
   x.ssh('systemctl restart '+x.nextunit+' '+native);time.sleep(5)
   name=f"rolling-c{block['cycle']}-b{block['block']}-p{pos+1}-{v}"
   start=time.time()
   x.phase(name,['-download-bytes',str(4<<20),'-download-workers','4','-download-jobs','12','-download-rounds','1','-download-timeout','150s','-target','191.223.214.8:19454','-target-server-name','zlhk.fastcat.ink'],v,bulk=True,timeout=180)
   timeline.append(dict(name=name,version=v,start=start,end=time.time()));(OUT/'timeline.json').write_text(json.dumps(timeline,indent=2))
 (OUT/'battery-end.txt').write_text(x.adb('shell','dumpsys','battery'))
print('ROLLING RETEST COMPLETE',flush=True)
