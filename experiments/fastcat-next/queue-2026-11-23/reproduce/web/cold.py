import sys,json,time,shlex,hashlib
from pathlib import Path
sys.path.insert(0,'/tmp/fc-next-primary');import lab
D=Path('/tmp/fc-next-web');O=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/queue-2026-11-23/cold-confirm');O.mkdir(parents=True,exist_ok=True);lab.D=D;lab.OUT=O
(O/'plan.json').write_text(json.dumps(dict(purpose='confirm observed cold P95 regression; original stage3 results retained',local_udp_port=30880,limits='fixed local source port does not prove identical public mapping or intermediate route; no packet tracing',samples=8,paired_blocks=6,variants=['baseline','recovery'],gate=dict(cold_success_not_lower=True,cold_p95_ratio_max=1.1,min_cold=48),sha256={n:hashlib.sha256((D/n).read_bytes()).hexdigest() for n in ['compare','next-diagnostic']}),indent=2));timeline=[]
with lab.Lab('next-cold-confirm',full=False,trace=False) as x:
 x.start();x.cfg.update(NextOptimizedAddress=x.cfg['NextAddress'],NextOptimizedProfile='baseline',NextOptimizedCoalesce=False,NextOptimizedConnections=2,NextOptimizedAdaptive=True,NextPrefixRedundancy=False)
 for b in range(6):
  for pos,v in enumerate(['baseline','recovery'] if b%2==0 else ['recovery','baseline']):
   name=f'cold-{v}-b{b+1}-p{pos+1}';x.cfg['NextRecoveryAware']=v=='recovery'
   p=x.privatefile(name,x.cfg);x.adb('push',str(p),x.ad+'/config');x.adb('shell','chmod','600',x.ad+'/config');start=time.time()
   x.phase(name,['-samples','8','-pools','1','-batches','1','-workers','1','-next-local-port','30880','-lane-diagnostics','-transport-snapshots','-target','191.223.214.8:19454','-target-server-name','zlhk.fastcat.ink'],'next-opt',bulk=False,timeout=450)
   timeline.append(dict(name=name,variant=v,block=b+1,start=start,end=time.time()));(O/'timeline.json').write_text(json.dumps(timeline,indent=2))
print('NEXT COLD CONFIRM COMPLETE',flush=True)
