from lab import Lab,D,OUT
import shutil
shutil.copy2(D/'compare-final',D/'compare');shutil.copy2(D/'next-final',D/'next-diagnostic')
with Lab('final',full=True,trace=False) as lab:
 lab.start();lab.cfg.update(NextOptimizedAddress=lab.cfg['NextAddress'],NextOptimizedProfile='baseline',NextOptimizedCoalesce=False,NextOptimizedConnections=2,NextOptimizedAdaptive=True)
 p=lab.privatefile('client-final',lab.cfg);lab.adb('push',str(p),lab.ad+'/config');lab.adb('shell','chmod','600',lab.ad+'/config')
 fixed=['-target','191.223.214.8:19454','-target-server-name','zlhk.fastcat.ink'];versions='next-base,next-fixed,next-opt,tuic,tuic-dual'
 lab.phase('final-latency',['-samples','12','-pools','3','-batches','4','-workers','4']+fixed,versions)
 lab.phase('final-mixed',['-mixed-download-bytes',str(16<<20),'-samples','12','-download-rounds','2','-download-timeout','90s']+fixed,versions,bulk=True,timeout=1100)
 lab.phase('final-throughput',['-bulk-only','-bulk-rounds','3','-bulk-seconds','10','-bulk-target','191.223.214.8:19445'],versions,bulk=True)
 lab.phase('final-parallel-download',['-download-bytes',str(8<<20),'-download-workers','4','-download-rounds','3','-download-timeout','90s']+fixed,versions,bulk=True,timeout=1500)
 lab.phase('final-download-32',['-download-bytes',str(32<<20),'-download-rounds','2','-download-timeout','90s']+fixed,versions,bulk=True,timeout=1000)
 lab.phase('final-download-100',['-download-bytes',str(100<<20),'-download-rounds','1','-download-timeout','180s']+fixed,'next-base,next-opt,tuic',bulk=True,timeout=600)
 (OUT/'battery-end.txt').write_text(lab.adb('shell','dumpsys','battery'))
print('FINAL COMPLETE',flush=True)
