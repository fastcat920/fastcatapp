from lab import Lab,D,OUT
import shutil
shutil.copy2(D/'compare-control',D/'compare')
with Lab('control',full=True,trace=False) as lab:
 lab.start()
 lab.cfg.update(NextOptimizedAddress=lab.cfg['NextAddress'],NextOptimizedProfile='baseline',NextOptimizedCoalesce=False,NextOptimizedConnections=2)
 p=lab.privatefile('client-control',lab.cfg);lab.adb('push',str(p),lab.ad+'/config');lab.adb('shell','chmod','600',lab.ad+'/config')
 versions='next-opt,tuic,tuic-dual';fixed=['-target','191.223.214.8:19454','-target-server-name','zlhk.fastcat.ink']
 lab.phase('control-pilot',['-samples','1','-pools','1','-batches','1','-workers','1']+fixed,versions)
 lab.phase('control-throughput',['-bulk-only','-bulk-rounds','2','-bulk-seconds','10','-bulk-target','191.223.214.8:19445'],versions,bulk=True)
 lab.phase('control-parallel-download',['-download-bytes',str(8<<20),'-download-workers','4','-download-rounds','3','-download-timeout','90s']+fixed,versions,bulk=True,timeout=1000)
print('CONTROL COMPLETE',flush=True)
