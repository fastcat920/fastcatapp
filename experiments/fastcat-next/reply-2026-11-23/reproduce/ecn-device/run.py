import sys,json,time,shlex,subprocess as sp,hashlib
from pathlib import Path
sys.path.insert(0,'/tmp/fc-next-primary');import lab
D=Path('/tmp/fc-next-ecn');O=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/reply-2026-11-23/ecn-device');O.mkdir(exist_ok=True);lab.D=D;lab.OUT=O
V=[('android-default','android',False),('android-noecn','android',True),('mac-default','mac',False),('mac-noecn','mac',True)];W=[[0,1,3,2],[1,2,0,3],[2,3,1,0],[3,0,2,1]]
(O/'plan.json').write_text(json.dumps(dict(conditions=V,orders=W,samples=12,reply_coalescing=0,GSO='default',PMTU='default',only_short_requests=True,sha256={n:hashlib.sha256((D/n).read_bytes()).hexdigest() for n in ['compare','compare-mac','next-diagnostic']}),indent=2));timeline=[]
with lab.Lab('ecn-device',full=False,trace=False) as x:
 x.start();x.cfg.update(NextOptimizedAddress=x.cfg['NextAddress'],NextOptimizedProfile='baseline',NextOptimizedCoalesce=False,NextOptimizedConnections=2,NextOptimizedAdaptive=True)
 p=x.privatefile('ecn-client',x.cfg);x.adb('push',str(p),x.ad+'/config');x.adb('shell','chmod','600',x.ad+'/config')
 cfg=dict(x.cfg);cfg['CA']='/etc/ssl/cert.pem';mac=x.privatefile('mac-client',cfg)
 (O/'android-route.txt').write_text(x.adb('shell','ip','route','get','191.223.214.8'));route=sp.check_output(['route','-n','get','191.223.214.8'],text=True);(O/'mac-route.txt').write_text(route)
 if 'utun' in route:raise RuntimeError('Mac target route uses VPN; device comparison not comparable')
 fixed=['-samples','12','-pools','1','-batches','1','-workers','1','-lane-diagnostics','-trace-prefix','-target','191.223.214.8:19454','-target-server-name','zlhk.fastcat.ink']
 for b,order in enumerate(W):
  for pos,i in enumerate(order):
   condition,device,off=V[i];name=f'{condition}-b{b+1}-p{pos+1}'
   code="import json,pathlib;p=pathlib.Path("+repr(x.remote+'/next')+");d=json.loads(p.read_text());d.update(Trace=True,PrefixTrace=True,DisableGSO=False,FixedPacketSize=0,ReplyCoalesceMillis=0,DisableECN="+repr(off)+");p.write_text(json.dumps(d))"
   x.ssh('python3 -c '+shlex.quote(code));x.ssh('systemctl restart '+x.nextunit);time.sleep(5);pid=x.ssh('systemctl show -p MainPID --value '+x.nextunit).strip();start=time.time()
   if device=='android':x.phase(name,fixed,'next-opt',bulk=False,timeout=450)
   else:
    with (O/(name+'.jsonl')).open('w') as a,(O/(name+'.log')).open('w') as e:sp.run([str(D/'compare-mac'),'-config',str(mac),'-versions','next-opt']+fixed,stdout=a,stderr=e,check=True,timeout=450)
    print('COMPLETE '+name,flush=True)
   (O/(name+'-server.log')).write_text(x.ssh('journalctl -u '+x.nextunit+' _PID='+pid+' --no-pager -o cat'));timeline.append(dict(name=name,condition=condition,device=device,disable_ecn=off,block=b+1,start=start,end=time.time()));(O/'timeline.json').write_text(json.dumps(timeline,indent=2))
print('ECN DEVICE COMPLETE',flush=True)
