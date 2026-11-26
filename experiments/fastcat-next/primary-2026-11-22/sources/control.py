from lab import Lab,D,OUT
import json,time
# Williams design: each treatment occurs in each position, each directed
# predecessor pair once per cycle. Two cycles give eight cases per mode.
V=['next-base','next-opt','next-primary','tuic']
W=[[0,1,3,2],[1,2,0,3],[2,3,1,0],[3,0,2,1]]
plan=[dict(cycle=c+1,block=b+1,order=[V[i] for i in order]) for c in range(2) for b,order in enumerate(W)]
(OUT/'controlled-plan.json').write_text(json.dumps(dict(design='two Williams cycles',cooldown_seconds=5,fresh_transport_process_each_case=True,blocks=plan),indent=2))
with Lab('controlled',full=True,trace=False) as lab:
 lab.start();lab.cfg.update(NextOptimizedAddress=lab.cfg['NextAddress'],NextOptimizedProfile='baseline',NextOptimizedCoalesce=False,NextOptimizedConnections=2,NextOptimizedAdaptive=True)
 p=lab.privatefile('client-control',lab.cfg);lab.adb('push',str(p),lab.ad+'/config');lab.adb('shell','chmod','600',lab.ad+'/config')
 native=next(u for u in lab.units if u.startswith('fc-opt-xray-'));units=lab.nextunit+' '+native
 fixed=['-target','191.223.214.8:19454','-target-server-name','zlhk.fastcat.ink'];times=[]
 for block in plan:
  for pos,v in enumerate(block['order']):
   lab.ssh('systemctl restart '+units);time.sleep(5)
   unit=native if v=='tuic' else lab.nextunit;port=19451 if v=='tuic' else 19458
   for _ in range(20):
    if ':'+str(port)+' ' in lab.ssh('ss -H -lun'):break
    time.sleep(.2)
   else:raise RuntimeError('Controlled transport listener not ready')
   name='controlled-c'+str(block['cycle'])+'-b'+str(block['block'])+'-p'+str(pos+1)+'-'+v;start=time.time()
   lab.phase(name,['-download-bytes',str(4<<20),'-download-workers','4','-download-rounds','1','-download-timeout','90s']+fixed,v,bulk=True,timeout=110)
   times.append(dict(name=name,version=v,cycle=block['cycle'],block=block['block'],position=pos+1,start=start,end=time.time()));(OUT/'controlled-timeline.json').write_text(json.dumps(times,indent=2))
print('CONTROLLED COMPLETE',flush=True)
