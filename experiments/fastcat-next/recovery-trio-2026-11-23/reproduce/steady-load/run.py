import sys,json,time,hashlib,itertools,shlex,uuid
from pathlib import Path
sys.path.insert(0,'/tmp/fc-next-primary');import lab
from runtime_lab import RuntimeLab
D=Path('/tmp/fc-recovery-steady');O=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/recovery-trio-2026-11-23/steady-load');O.mkdir(parents=True,exist_ok=True);lab.D=D;lab.OUT=O
V=['next-opt','next-base','tuic'];orders=list(itertools.permutations(V));fixed=['-target','191.223.214.8:19454','-target-server-name','zlhk.fastcat.ink']
metrics=[('steady',6,['-mixed-ready','-mixed-download-bytes',str(16<<20),'-samples','12','-download-rounds','1','-download-timeout','90s'],True,120)]
plan=dict(date='2026-11-23',variants={'next-opt':'recovery-aware two-lane adaptive Next, no prefix/budget','next-base':'Next single lane, baseline QUIC','tuic':'CatNode V2Core TUIC v5, explicit server BBR and client BBR; zero RTT and fast-open off'},orders=orders,metrics=metrics,trace=False,lane_diagnostics=False,request_snapshots=False,server_restart_each_case=True,cooldown_seconds=5,port_crossover='blocks 1/3/5: Next19458 TUIC19451; blocks2/4/6 swap ports; all 6 orders once per primary metric',client_go='1.26.2',server_go='1.27.3',scope='Android native core CLI over Wi-Fi; formal App VPN temporarily off; no production changes; certificates verified',readiness='wait until each background receives256KiB or 5s; record count before each foreground; final file hash still required',notes=['End-to-end firstbyte includes proxy/target TLS/HTTP, not ping','Cold creates new client; warm reuses entry but creates target TLS each request','No packet-level or lane JSON trace during performance','TUIC native pool vs Next1/2 lanes: not an equal-connection-count algorithm experiment','Echo is simultaneous bidirectional echo, not pure upload','No post-hoc removal of slow or incomplete cases'],sha256={n:hashlib.sha256((D/n).read_bytes()).hexdigest() for n in ['compare','next-diagnostic','tuic-server']})
(O/'plan.json').write_text(json.dumps(plan,indent=2));timeline=[]
with RuntimeLab('recovery-steady',full=False,trace=False) as x:
 x.start();uid=str(uuid.uuid4());tuic=x.service('tuic',D/'tuic-server',dict(UUID=uid,TuicPort=19451));x.cfg.update(TuicUUID=uid,TuicAddress='191.223.214.8:19451',NextOptimizedAddress=x.cfg['NextAddress'],NextOptimizedProfile='baseline',NextOptimizedCoalesce=False,NextOptimizedConnections=2,NextOptimizedAdaptive=True,NextRecoveryAware=True,NextPrefixRedundancy=False)
 def setup(b,name):
  np,tp=(19458,19451) if b%2==0 else (19451,19458)
  x.ssh('systemctl stop '+x.nextunit+' '+tuic)
  code="import json,pathlib;p=pathlib.Path("+repr(x.remote+'/next')+");d=json.loads(p.read_text());d.update(Listen="+repr('0.0.0.0:'+str(np)) +",Trace=False,PrefixTrace=False,DownstreamBudget=False,PrefixRedundancy=False,ReplyCoalesceMillis=0,DisableECN=False,DisableGSO=False,FixedPacketSize=0);p.write_text(json.dumps(d));p=pathlib.Path("+repr(x.remote+'/tuic')+");d=json.loads(p.read_text());d['TuicPort']="+str(tp)+";p.write_text(json.dumps(d))"
  x.ssh('python3 -c '+shlex.quote(code));x.ssh('systemctl start '+x.nextunit+' '+tuic);time.sleep(5)
  x.cfg.update(NextAddress='191.223.214.8:'+str(np),NextOptimizedAddress='191.223.214.8:'+str(np),TuicAddress='191.223.214.8:'+str(tp))
  p=x.privatefile(name,x.cfg);x.adb('push',str(p),x.ad+'/config');x.adb('shell','chmod','600',x.ad+'/config')
  if any(x.ssh('systemctl is-active '+u).strip()!='active' for u in [x.nextunit,tuic]):raise RuntimeError('lab server inactive')
  return dict(next_port=np,tuic_port=tp)
 # Verify the new measurement callback for each protocol before the strict cohort.
 for i,v in enumerate(V):
  name='ready-pilot-'+v;ports=setup(0,name)
  x.phase(name,['-mixed-ready','-mixed-download-bytes',str(1<<20),'-samples','1','-download-rounds','1','-download-timeout','30s']+fixed,v,bulk=True,timeout=60)
  rr=[]
  for line in (O/(name+'.jsonl')).read_text().splitlines():
   try:rr.append(json.loads(line))
   except:pass
  summary=[r for r in rr if r.get('phase')=='mixed_summary']
  if len(summary)!=1 or summary[0].get('background_ready')!=2 or summary[0].get('success')!=2:raise RuntimeError('readiness pilot failed: '+v)
  timeline.append(dict(name=name,metric='pilot',block=1,ports=ports));(O/'timeline.json').write_text(json.dumps(timeline,indent=2))
 (O/'battery-start.txt').write_text(x.adb('shell','dumpsys','battery'))
 for metric,n,args,bulk,timeout in metrics:
  for b in range(n):
   order=orders[b] if n==6 else (V if b==0 else list(reversed(V)))
   for pos,v in enumerate(order):
    name=f'{metric}-b{b+1}-p{pos+1}-{v}';ports=setup(b,name);start=time.time();extra=['-target','zlhk.fastcat.ink:19454'] if metric.startswith('web-') else fixed
    x.phase(name,args+extra,v,bulk=bulk,timeout=timeout)
    timeline.append(dict(name=name,metric=metric,block=b+1,position=pos+1,version=v,start=start,end=time.time(),ports=ports));(O/'timeline.json').write_text(json.dumps(timeline,indent=2))
 (O/'battery-end.txt').write_text(x.adb('shell','dumpsys','battery'))
print('RECOVERY STEADY COMPLETE',flush=True)
