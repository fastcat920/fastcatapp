from lab import Lab,D,OUT
import json,subprocess as sp,time
with Lab('adaptive',full=True,trace=True) as lab:
 lab.start();lab.cfg.update(NextOptimizedAddress=lab.cfg['NextAddress'],NextOptimizedProfile='baseline',NextOptimizedCoalesce=False,NextOptimizedConnections=2,NextOptimizedAdaptive=True)
 p=lab.privatefile('client-adaptive',lab.cfg);lab.adb('push',str(p),lab.ad+'/config');lab.adb('shell','chmod','600',lab.ad+'/config')
 fixed=['-target','191.223.214.8:19454','-target-server-name','zlhk.fastcat.ink'];versions='next-base,next-fixed,next-opt,tuic,tuic-dual'
 lab.phase('diagnostic-single',['-download-bytes',str(32<<20),'-download-rounds','2','-download-timeout','90s','-trace-next']+fixed,'next-base,next-opt',bulk=True,timeout=420)
 cf=D/('next-'+lab.stamp+'.json');cfg=json.loads(cf.read_text());cfg['Trace']=False;cf.write_text(json.dumps(cfg));cf.chmod(0o600);sp.run(['scp','-q','-o','ControlPath='+lab.sock,str(cf),lab.host+':'+lab.remote+'/next'],check=True);lab.ssh('systemctl restart '+lab.nextunit);time.sleep(.2)
 lab.phase('final-latency',['-samples','12','-pools','3','-batches','4','-workers','4']+fixed,versions)
 lab.phase('final-throughput',['-bulk-only','-bulk-rounds','3','-bulk-seconds','10','-bulk-target','191.223.214.8:19445'],versions,bulk=True)
 lab.phase('final-parallel-download',['-download-bytes',str(8<<20),'-download-workers','4','-download-rounds','3','-download-timeout','90s']+fixed,versions,bulk=True,timeout=1500)
 lab.phase('final-download-32',['-download-bytes',str(32<<20),'-download-rounds','2','-download-timeout','90s']+fixed,versions,bulk=True,timeout=1000)
 lab.phase('final-download-100',['-download-bytes',str(100<<20),'-download-rounds','1','-download-timeout','180s']+fixed,'next-base,next-opt,tuic',bulk=True,timeout=600)
 (OUT/'battery-end.txt').write_text(lab.adb('shell','dumpsys','battery'))
print('ADAPTIVE COMPLETE',flush=True)
