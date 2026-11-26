import sys,json,time,shlex,hashlib
from pathlib import Path
sys.path.insert(0,'/tmp/fc-next-primary');import lab
D=Path('/tmp/fc-next-wire');O=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/wire-2026-11-22');O.mkdir(exist_ok=True);lab.D=D;lab.OUT=O
V=[('default',False,0),('no-gso',True,0),('fixed1200',False,1200),('no-gso-fixed1200',True,1200)];W=[[0,1,3,2],[1,2,0,3],[2,3,1,0],[3,0,2,1]]
(O/'plan.json').write_text(json.dumps(dict(conditions=V,orders=W,foreground_samples=12,policy='next-opt unchanged',capture='sanitized timestamps/direction/UDP payload lengths only; no pcap or payload saved',sha256={n:hashlib.sha256((D/n).read_bytes()).hexdigest() for n in ['compare','next-diagnostic']}),indent=2));timeline=[]
with lab.Lab('wire',full=False,trace=True) as x:
 x.start();x.cfg.update(NextOptimizedAddress=x.cfg['NextAddress'],NextOptimizedProfile='baseline',NextOptimizedCoalesce=False,NextOptimizedConnections=2,NextOptimizedAdaptive=True)
 p=x.privatefile('wire-client',x.cfg);x.adb('push',str(p),x.ad+'/config');x.adb('shell','chmod','600',x.ad+'/config')
 helper=x.uploadfile(D/'capture.py','capture.py');capunit='fc-opt-capture-'+x.stamp;x.ssh('systemd-run --unit='+capunit+' -p RuntimeMaxSec=60m -p NoNewPrivileges=yes /usr/bin/python3 '+helper);x.units.append(capunit)
 for b,order in enumerate(W):
  for pos,i in enumerate(order):
   name,off,size=V[i];case=f'{name}-b{b+1}-p{pos+1}'
   code="import json,pathlib;p=pathlib.Path("+repr(x.remote+'/next')+");d=json.loads(p.read_text());d.update(Trace=True,PrefixTrace=True,DisableGSO="+repr(off)+",FixedPacketSize="+repr(size)+");p.write_text(json.dumps(d))"
   x.ssh('python3 -c '+shlex.quote(code));x.ssh('systemctl restart '+x.nextunit);time.sleep(5);pid=x.ssh('systemctl show -p MainPID --value '+x.nextunit).strip();(O/(case+'-snmp-before.txt')).write_text(x.ssh('cat /proc/net/snmp'));start=time.time()
   x.phase(case,['-samples','12','-pools','1','-batches','1','-workers','1','-lane-diagnostics','-trace-prefix','-target','191.223.214.8:19454','-target-server-name','zlhk.fastcat.ink'],'next-opt',bulk=False,timeout=450)
   (O/(case+'-snmp-after.txt')).write_text(x.ssh('cat /proc/net/snmp'));(O/(case+'-server.log')).write_text(x.ssh('journalctl -u '+x.nextunit+' _PID='+pid+' --no-pager -o cat'));timeline.append(dict(name=case,condition=name,block=b+1,start=start,end=time.time()));(O/'timeline.json').write_text(json.dumps(timeline,indent=2))
(O/'capture.log').write_text(x.ssh('journalctl -u '+capunit+' --no-pager -o cat'))
print('WIRE DIAGNOSTIC COMPLETE',flush=True)
