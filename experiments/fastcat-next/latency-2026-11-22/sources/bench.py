import sys,json,time,hashlib,itertools
from pathlib import Path
sys.path.insert(0,'/tmp/fc-next-primary')
import lab
D=Path('/tmp/fc-next-latency');ROOT=Path('/Users/pizihu/Projects/FastCatAPP')
STAGE=sys.argv[1] if len(sys.argv)>1 else 'stage12';OUT=ROOT/'experiments/fastcat-next/latency-2026-11-22'/STAGE;OUT.mkdir(parents=True,exist_ok=True);lab.D=D;lab.OUT=OUT
V=['next-opt','next-latency'] if STAGE=='stage12' else ['next-opt','next-latency','next-reserve']
orders=list(itertools.permutations(V));metrics=[('mixed',6,['-mixed-download-bytes',str(16<<20),'-samples','12','-download-rounds','1','-download-timeout','90s'],True,120),('parallel',6,['-download-bytes',str(4<<20),'-download-workers','4','-download-rounds','1','-download-timeout','90s'],True,120),('rolling',6,['-download-bytes',str(4<<20),'-download-workers','4','-download-jobs','12','-download-rounds','1','-download-timeout','150s'],True,180),('latency',3,['-samples','12','-pools','1','-batches','3','-workers','4'],False,450)]
plan=dict(stage=STAGE,versions=V,metrics=metrics,orders=orders,restart_before_each_case=True,cooldown=5,lane_diagnostics=True,packet_trace=False,gate=dict(loaded_p95_ratio_max=.8,throughput_ratio_min=.9,completion_not_lower=True,minimum_loaded_requests=48),sha256={n:hashlib.sha256((D/n).read_bytes()).hexdigest() for n in ['compare','next-diagnostic']})
(OUT/'plan.json').write_text(json.dumps(plan,indent=2));timeline=[]
with lab.Lab('latency-'+STAGE,full=False,trace=False) as x:
 x.start();x.cfg.update(NextOptimizedAddress=x.cfg['NextAddress'],NextOptimizedProfile='baseline',NextOptimizedCoalesce=False,NextOptimizedConnections=2,NextOptimizedAdaptive=True)
 p=x.privatefile('latency-config',x.cfg);x.adb('push',str(p),x.ad+'/config');x.adb('shell','chmod','600',x.ad+'/config')
 for metric,n,args,bulk,timeout in metrics:
  for b in range(n):
   order=orders[b%len(orders)] if n==6 else tuple(V[(b+i)%len(V)] for i in range(len(V)))
   for pos,v in enumerate(order):
    x.ssh('systemctl restart '+x.nextunit);time.sleep(5);name=f'{metric}-b{b+1}-p{pos+1}-{v}';start=time.time()
    x.phase(name,args+['-lane-diagnostics','-target','191.223.214.8:19454','-target-server-name','zlhk.fastcat.ink'],v,bulk=bulk,timeout=timeout)
    timeline.append(dict(name=name,metric=metric,block=b+1,position=pos+1,version=v,start=start,end=time.time()));(OUT/'timeline.json').write_text(json.dumps(timeline,indent=2))
 (OUT/'battery-end.txt').write_text(x.adb('shell','dumpsys','battery'))
print('COMPLETE '+STAGE,flush=True)
