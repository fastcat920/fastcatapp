from lab import Lab,D,OUT
import shutil,json,subprocess as sp,time
shutil.copy2(D/'next-gso',D/'next-diagnostic');shutil.copy2(D/'compare-candidates',D/'compare')
with Lab('isolate',full=True,trace=False) as lab:
 lab.start()
 fixed=['-target','191.223.214.8:19454','-target-server-name','zlhk.fastcat.ink']
 lab.cfg.update(NextOptimizedAddress=lab.cfg['NextAddress'],NextOptimizedProfile='baseline',NextOptimizedCoalesce=True)
 p=lab.privatefile('client-isolate',lab.cfg);lab.adb('push',str(p),lab.ad+'/config');lab.adb('shell','chmod','600',lab.ad+'/config')
 lab.phase('isolate-coalesce',['-samples','16','-pools','3','-batches','4','-workers','4']+fixed,'next-base,next-opt,tuic')
 # Same port / single-variable CC check; pack OPEN immediately in both groups.
 cfile=D/('next-'+lab.stamp+'.json');cfg=json.loads(cfile.read_text());cfg['Trace']=True;lab.trace=True
 for i,profile in enumerate(['bbr-legacy','baseline','baseline','bbr-legacy']):
  cfg['QUICProfile']=profile;cfile.write_text(json.dumps(cfg));cfile.chmod(0o600);sp.run(['scp','-q','-o','ControlPath='+lab.sock,str(cfile),lab.host+':'+lab.remote+'/next'],check=True);lab.ssh('systemctl restart '+lab.nextunit);time.sleep(.2)
  lab.phase('isolate-cc-'+str(i+1)+'-'+profile,['-download-bytes',str(32<<20),'-download-rounds','1','-download-timeout','75s','-next-quic-profile',profile,'-trace-next']+fixed,'next-quic',bulk=True,timeout=100)
print('ISOLATE COMPLETE',flush=True)
