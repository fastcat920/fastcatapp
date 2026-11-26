from lab import Lab,D,OUT
import json,shutil,time
shutil.copy2(D/'next-gso',D/'next-diagnostic');shutil.copy2(D/'compare-candidates',D/'compare')
with Lab('final',full=True,trace=False) as lab:
 lab.start()
 lab.service('next-candidate',D/'next-gso',dict(Listen='0.0.0.0:19459',Account=lab.cfg['NextAccount'],Secret=lab.cfg['NextSecret'],Congestion='bbr',QUICProfile='bbr-legacy'),kind='next')
 lab.cfg.update(NextOptimizedAddress='191.223.214.8:19459',NextOptimizedProfile='bbr-legacy',NextOptimizedCoalesce=True)
 p=lab.privatefile('client-final',lab.cfg);lab.adb('push',str(p),lab.ad+'/config');lab.adb('shell','chmod','600',lab.ad+'/config')
 versions='next-base,next-opt,tuic';fixed=['-target','191.223.214.8:19454','-target-server-name','zlhk.fastcat.ink']
 lab.phase('final-controlled',['-samples','24','-pools','3','-batches','8','-workers','4']+fixed,versions)
 lab.phase('final-internet',['-samples','20','-pools','3','-batches','5','-workers','4','-target','www.cloudflare.com:443'],versions)
 lab.phase('final-eight',['-workload','batch-only','-pools','1','-batches','6','-workers','8']+fixed,versions)
 lab.phase('final-idle',['-samples','1','-pools','1','-batches','1','-workers','1','-idle-seconds','70']+fixed,versions)
 for size,rounds,budget in [(1,3,60),(32,2,90),(100,2,180)]:
  lab.phase('final-download-'+str(size),['-download-bytes',str(size<<20),'-download-rounds',str(rounds),'-download-timeout',str(budget)+'s']+fixed,versions,bulk=True,timeout=rounds*3*(budget+10))
 lab.phase('final-throughput',['-bulk-only','-bulk-rounds','3','-bulk-seconds','8','-bulk-target','191.223.214.8:19445'],versions,bulk=True)
print('FINAL COMPLETE',flush=True)
