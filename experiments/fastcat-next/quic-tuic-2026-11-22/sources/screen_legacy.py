from lab import Lab,D,OUT
import json,subprocess as sp,time,shutil
shutil.copy2(D/'next-expanded',D/'next-diagnostic');shutil.copy2(D/'compare-expanded',D/'compare')
with Lab('legacy',full=True,trace=True) as lab:
 lab.start();fixed=['-target','191.223.214.8:19454','-target-server-name','zlhk.fastcat.ink'];cfgfile=D/('next-'+lab.stamp+'.json');cfg=json.loads(cfgfile.read_text());windows=[]
 for i,profile in enumerate(['bbr-legacy','tuic','baseline','tuic','bbr-legacy']):
  if profile!='tuic':
   cfg['QUICProfile']=profile;cfgfile.write_text(json.dumps(cfg));cfgfile.chmod(0o600);sp.run(['scp','-q','-o','ControlPath='+lab.sock,str(cfgfile),lab.host+':'+lab.remote+'/next'],check=True);lab.ssh('systemctl restart '+lab.nextunit);time.sleep(.2)
  start=time.time();name='legacy-'+str(i+1)+'-'+profile;args=['-download-bytes',str(32<<20),'-download-rounds','1','-download-timeout','90s']+fixed
  if profile!='tuic':args+=['-next-quic-profile',profile,'-trace-next']
  lab.phase(name,args,'tuic' if profile=='tuic' else 'next-quic',timeout=120,bulk=True)
  windows.append(dict(name=name,profile=profile,start=start,end=time.time()));(OUT/'legacy-windows.json').write_text(json.dumps(windows,indent=2))
print('LEGACY SCREEN COMPLETE',flush=True)
