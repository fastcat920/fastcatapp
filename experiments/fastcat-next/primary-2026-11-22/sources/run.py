from lab import Lab,D,OUT
import json,statistics,time
V=['next-base','next-opt','next-primary','tuic'];decisions=[]
def read(name):
 out=[]
 for l in (OUT/(name+'.jsonl')).read_text().splitlines():
  try:r=json.loads(l)
  except:continue
  if isinstance(r,dict):out.append(r)
 return out
def noisy(name,phase,maxratio,cvlimit):
 rr=[r for r in read(name) if r.get('phase')==phase];why=[]
 for v in V:
  gg=[r for r in rr if r.get('version')==v]
  if any(r.get('success')!=r.get('jobs',r.get('workers')) for r in gg):why.append(v+': incomplete group')
  for w in sorted({r.get('workers') for r in gg}):
   a=[r.get('verified_mbps',r.get('download_mbps',0)) for r in gg if r.get('workers')==w]
   if len(a)<3:continue
   mean=statistics.mean(a);ratio=max(a)/max(min(a),.0001);cv=statistics.pstdev(a)/max(mean,.0001)
   if ratio>maxratio or cv>cvlimit:why.append(v+': workers='+str(w)+' range-ratio='+str(round(ratio,2))+' CV='+str(round(cv,3)))
 decision=dict(test=name,extend=bool(why),reasons=why);decisions.append(decision);(OUT/'repeat-decisions.json').write_text(json.dumps(decisions,indent=2));return bool(why)
with Lab('primary',full=True,trace=False) as lab:
 lab.start();lab.cfg.update(NextOptimizedAddress=lab.cfg['NextAddress'],NextOptimizedProfile='baseline',NextOptimizedCoalesce=False,NextOptimizedConnections=2,NextOptimizedAdaptive=True)
 p=lab.privatefile('client-primary',lab.cfg);lab.adb('push',str(p),lab.ad+'/config');lab.adb('shell','chmod','600',lab.ad+'/config')
 fixed=['-target','191.223.214.8:19454','-target-server-name','zlhk.fastcat.ink'];versions=','.join(V);reverse=','.join(reversed(V))
 lab.phase('pilot',['-samples','1','-pools','1','-batches','1','-workers','1']+fixed,versions)
 if any(not any(r.get('version')==v and not r.get('error') for r in read('pilot')) for v in V):raise RuntimeError('Pilot failed for at least one mode')
 lab.phase('pilot-rolling',['-download-bytes',str(1<<20),'-download-workers','2','-download-jobs','4','-download-rounds','1','-download-timeout','30s']+fixed,'next-primary,tuic',bulk=True)
 if any(r.get('success')!=4 for r in read('pilot-rolling') if r.get('phase')=='rolling_download'):raise RuntimeError('Rolling pilot failed')
 lab.phase('final-latency',['-samples','24','-pools','3','-batches','6','-workers','4']+fixed,versions)
 args=['-download-bytes',str(4<<20),'-download-workers','4','-download-rounds','6','-download-timeout','90s']+fixed
 lab.phase('final-parallel-6',args,versions,bulk=True,timeout=2400)
 if noisy('final-parallel-6','parallel_download',2.5,.45):
  lab.phase('final-parallel-repeat-6',args,reverse,bulk=True,timeout=2400)
 lab.phase('final-rolling',['-download-bytes',str(4<<20),'-download-workers','4','-download-jobs','12','-download-rounds','2','-download-timeout','150s']+fixed,versions,bulk=True,timeout=1300)
 lab.phase('final-mixed',['-mixed-download-bytes',str(16<<20),'-samples','12','-download-rounds','2','-download-timeout','90s']+fixed,versions+',tuic-dual',bulk=True,timeout=1100)
 echo=['-bulk-only','-bulk-rounds','3','-bulk-seconds','10','-bulk-target','191.223.214.8:19445']
 lab.phase('final-echo-3',echo,versions,bulk=True)
 if noisy('final-echo-3','timed_bulk',3,.60):
  lab.phase('final-echo-repeat-2',['-bulk-only','-bulk-rounds','2','-bulk-seconds','10','-bulk-target','191.223.214.8:19445'],reverse,bulk=True)
 lab.phase('final-download-32',['-download-bytes',str(32<<20),'-download-rounds','3','-download-timeout','90s']+fixed,versions,bulk=True,timeout=1200)
 lab.phase('final-download-100',['-download-bytes',str(100<<20),'-download-rounds','1','-download-timeout','180s']+fixed,'next-base,next-primary,tuic',bulk=True,timeout=600)
 (OUT/'battery-end.txt').write_text(lab.adb('shell','dumpsys','battery'))
print('PRIMARY COMPLETE',flush=True)
