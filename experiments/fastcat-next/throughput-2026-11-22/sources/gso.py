from lab import Lab,D,OUT
import json,subprocess as sp,time
with Lab('gso',full=True,trace=False) as lab:
 lab.start();fixed=['-target','191.223.214.8:19454','-target-server-name','zlhk.fastcat.ink'];cf=D/('next-'+lab.stamp+'.json');cfg=json.loads(cf.read_text())
 for i,off in enumerate([False,True,True,False]):
  cfg['DisableGSO']=off;cf.write_text(json.dumps(cfg));cf.chmod(0o600);sp.run(['scp','-q','-o','ControlPath='+lab.sock,str(cf),lab.host+':'+lab.remote+'/next'],check=True);lab.ssh('systemctl restart '+lab.nextunit);time.sleep(.2)
  lab.phase('gso-'+str(i+1)+'-'+('off' if off else 'on'),['-bulk-only','-bulk-rounds','1','-bulk-seconds','8','-bulk-target','191.223.214.8:19445'],'next-base,tuic',bulk=True)
print('GSO COMPLETE',flush=True)
