from lab import Lab,D,OUT
import json,subprocess as sp,time
with Lab('screen',full=True,trace=True) as lab:
 lab.start();fixed=['-target','191.223.214.8:19454','-target-server-name','zlhk.fastcat.ink'];windows=[]
 lab.phase('screen-pilot',['-pools','1','-samples','2','-batches','1','-workers','2']+fixed,'next-quic,tuic',timeout=150)
 cfgfile=D/('next-'+lab.stamp+'.json');cfg=json.loads(cfgfile.read_text())
 for round,order in enumerate([['baseline','wide','conservative','tuic'],['tuic','conservative','wide','baseline']]):
  for profile in order:
   if profile!='tuic':
    cfg['QUICProfile']=profile;cfgfile.write_text(json.dumps(cfg));cfgfile.chmod(0o600)
    sp.run(['scp','-q','-o','ControlPath='+lab.sock,str(cfgfile),lab.host+':'+lab.remote+'/next'],check=True);lab.ssh('systemctl restart '+lab.nextunit);time.sleep(.2)
   start=time.time();name='screen-'+str(round+1)+'-'+profile
   args=['-download-bytes',str(32<<20),'-download-rounds','1','-download-timeout','90s']+fixed
   if profile!='tuic':args+=['-next-quic-profile',profile,'-trace-next']
   lab.phase(name,args,'tuic' if profile=='tuic' else 'next-quic',timeout=120,bulk=True)
   windows.append(dict(name=name,profile=profile,round=round+1,start=start,end=time.time()));(OUT/'screen-windows.json').write_text(json.dumps(windows,indent=2))
print('SCREEN COMPLETE',flush=True)
