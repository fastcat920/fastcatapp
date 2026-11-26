from lab import Lab,D,OUT
import json,time,subprocess as sp
with Lab('mss',trace=True) as lab:
 lab.start();lab.monitor_tcp();windows=[]
 cfgfile=D/('next-'+lab.stamp+'.json');cfg=json.loads(cfgfile.read_text())
 for i,mss in enumerate([0,1200,1200,0,0,1200]):
  cfg['TCPMaxSegment']=mss;cfgfile.write_text(json.dumps(cfg));cfgfile.chmod(0o600)
  sp.run(['scp','-q','-o','ControlPath='+lab.sock,str(cfgfile),lab.host+':'+lab.remote+'/next'],check=True)
  lab.ssh('systemctl restart '+lab.nextunit);time.sleep(.3)
  start=time.time();name='mss-'+str(i+1)+'-'+str(mss)
  lab.phase(name,['-download-bytes',str(10<<20),'-download-rounds','1','-download-timeout','90s','-target','191.223.214.8:19454','-target-server-name','zlhk.fastcat.ink','-trace-next'],'next-h2',bulk=True,timeout=110)
  windows.append(dict(name=name,mss=mss,start=start,end=time.time()));(OUT/'mss-windows.json').write_text(json.dumps(windows,indent=2))
