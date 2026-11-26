import sys,json,time,shlex,subprocess as sp,hashlib
from pathlib import Path
sys.path.insert(0,'/tmp/fc-next-primary');import lab
D=Path('/tmp/fc-next-cause');OUT=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/cause-2026-11-22');OUT=OUT/'prefix';OUT.mkdir(exist_ok=True);lab.D=D;lab.OUT=OUT
V=['loaded-on','unloaded-on'];W=[[0,1],[1,0],[0,1]]
(OUT/'plan.json').write_text(json.dumps(dict(conditions=V,orders=W,blocks=3,foreground_samples=12,background_each_bytes=16<<20,policy='next-opt unchanged; both new policy flags off',trace_progress_ms=250,trace_packet_payloads=False,server_go='1.27.3',client_go='1.26.2',sha256={n:hashlib.sha256((D/n).read_bytes()).hexdigest() for n in ['compare','next-diagnostic']},purpose='bounded prefix packet/range correlation; metadata only; not a performance acceptance run'),indent=2))
timeline=[]
with lab.Lab('cause',full=False,trace=True) as x:
 x.start();x.cfg.update(NextOptimizedAddress=x.cfg['NextAddress'],NextOptimizedProfile='baseline',NextOptimizedCoalesce=False,NextOptimizedConnections=2,NextOptimizedAdaptive=True)
 p=x.privatefile('cause-client',x.cfg);x.adb('push',str(p),x.ad+'/config');x.adb('shell','chmod','600',x.ad+'/config')
 clock=[]
 for _ in range(3):
  a=time.time_ns();server=x.ssh('date +%s%N').strip();b=time.time_ns();c=time.time_ns();android=x.adb('shell','date','+%s%N').strip();d=time.time_ns();clock.append(dict(server_ns=server,server_local_mid_ns=(a+b)//2,server_rtt_ns=b-a,android_ns=android,android_local_mid_ns=(c+d)//2,android_rtt_ns=d-c))
 (OUT/'clocks.json').write_text(json.dumps(clock,indent=2))
 fixed=['-lane-diagnostics','-target','191.223.214.8:19454','-target-server-name','zlhk.fastcat.ink']
 for b,order in enumerate(W):
  for pos,i in enumerate(order):
   condition=V[i];on=condition.endswith('-on');loaded=condition.startswith('loaded-')
   code="import json,pathlib;p=pathlib.Path("+repr(x.remote+'/next')+");d=json.loads(p.read_text());d['Trace']="+repr(on)+";d['PrefixTrace']=True;p.write_text(json.dumps(d))"
   x.ssh('python3 -c '+shlex.quote(code));x.ssh('systemctl restart '+x.nextunit);time.sleep(5);pid=x.ssh('systemctl show -p MainPID --value '+x.nextunit).strip()
   name=f'{condition}-b{b+1}-p{pos+1}';args=(['-mixed-download-bytes',str(16<<20),'-samples','12','-download-rounds','1','-download-timeout','90s'] if loaded else ['-samples','12','-pools','1','-batches','1','-workers','1'])+fixed+(['-trace-next','-trace-prefix'] if on else [])
   start=time.time();x.phase(name,args,'next-opt',bulk=loaded,timeout=450)
   server=x.ssh('journalctl -u '+x.nextunit+' _PID='+pid+' --no-pager -o cat');(OUT/(name+'-server.log')).write_text(server)
   timeline.append(dict(name=name,condition=condition,block=b+1,position=pos+1,trace=on,loaded=loaded,start=start,end=time.time()));(OUT/'timeline.json').write_text(json.dumps(timeline,indent=2))
print('PREFIX COMPLETE',flush=True)
