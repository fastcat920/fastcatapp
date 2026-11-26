import sys,json,time,hashlib,itertools,shlex,uuid,subprocess
from pathlib import Path
sys.path.insert(0,'/tmp/fc-new-trio');import lab
from runtime_lab import RuntimeLab
D=Path('/tmp/fc-new-trio');O=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/recovery-trio-newserver-2026-11-23');O.mkdir(parents=True,exist_ok=True);lab.D=D;lab.OUT=O
V=['next-opt','next-base','tuic'];orders=list(itertools.permutations(V));fixed=['-target','154.37.155.240:19454','-target-server-name','fc-lab.test']
metrics=[('latency',6,['-samples','12','-pools','1','-batches','3','-workers','4'],False,450),('batch8',6,['-workload','batch-only','-samples','1','-pools','1','-batches','3','-workers','8'],False,180),('single16',6,['-download-bytes',str(16<<20),'-download-rounds','1','-download-timeout','90s'],True,120),('parallel4',6,['-download-bytes',str(4<<20),'-download-workers','4','-download-rounds','1','-download-timeout','90s'],True,120),('parallel8',6,['-download-bytes',str(2<<20),'-download-workers','8','-download-rounds','1','-download-timeout','90s'],True,120),('rolling',6,['-download-bytes',str(4<<20),'-download-workers','4','-download-jobs','12','-download-rounds','1','-download-timeout','150s'],True,180),('mixed',6,['-mixed-ready','-mixed-download-bytes',str(16<<20),'-samples','12','-download-rounds','1','-download-timeout','90s'],True,120),('echo',6,['-bulk-only','-bulk-rounds','1','-bulk-seconds','5','-bulk-target','154.37.155.240:19445'],True,100),('idle',6,['-idle-seconds','20'],False,100),('web-example',2,['-mixed-ready','-mixed-download-bytes',str(16<<20),'-mixed-foreground-target','example.com:443','-samples','12','-download-rounds','1','-download-timeout','90s'],True,120),('web-google',2,['-mixed-ready','-mixed-download-bytes',str(16<<20),'-mixed-foreground-target','www.google.com:443','-samples','12','-download-rounds','1','-download-timeout','90s'],True,120)]
plan=dict(date='2026-11-23',variants={'next-opt':'recovery-aware two-lane adaptive Next, no prefix/budget','next-base':'Next single lane, baseline QUIC','tuic':'CatNode V2Core TUIC v5, explicit server BBR and client BBR; zero RTT and fast-open off'},orders=orders,metrics=metrics,trace=False,lane_diagnostics=False,request_snapshots=False,server_restart_each_case=True,cooldown_seconds=5,port_crossover='blocks 1/3/5: Next19458 TUIC19451; blocks2/4/6 swap ports; all 6 orders once per primary metric',client_go='1.26.2',server_go='1.27.3',readiness='mixed and web wait for each background to receive 256KiB, maximum 5 seconds',scope='Android native core CLI over Wi-Fi; formal App VPN temporarily off; no production changes; certificates verified',notes=['End-to-end firstbyte includes proxy/target TLS/HTTP, not ping','Cold creates new client; warm reuses entry but creates target TLS each request','No packet-level or lane JSON trace during performance','TUIC native pool vs Next1/2 lanes: not an equal-connection-count algorithm experiment','Echo is simultaneous bidirectional echo, not pure upload','No post-hoc removal of slow or incomplete cases'],sha256={n:hashlib.sha256((D/n).read_bytes()).hexdigest() for n in ['compare','next-diagnostic','tuic-server']})
(O/'resume-plan.json').write_text(json.dumps(plan,indent=2));timeline=json.loads((O/'timeline.json').read_text()) if (O/'timeline.json').exists() else [];completed={t['name'] for t in timeline}
with RuntimeLab('recovery-trio',full=False,trace=False) as x:
 x.start();uid=str(uuid.uuid4());tuic=x.service('tuic',D/'tuic-server',dict(UUID=uid,TuicPort=19451));x.cfg.update(TuicUUID=uid,TuicAddress='154.37.155.240:19451',NextOptimizedAddress=x.cfg['NextAddress'],NextOptimizedProfile='baseline',NextOptimizedCoalesce=False,NextOptimizedConnections=2,NextOptimizedAdaptive=True,NextRecoveryAware=True,NextPrefixRedundancy=False)
 def setup(b,name):
  np,tp=(19458,19451) if b%2==0 else (19451,19458)
  x.ssh('systemctl stop '+x.nextunit+' '+tuic)
  code="import json,pathlib;p=pathlib.Path("+repr(x.remote+'/next')+");d=json.loads(p.read_text());d.update(Listen="+repr('0.0.0.0:'+str(np)) +",Trace=False,PrefixTrace=False,DownstreamBudget=False,PrefixRedundancy=False,ReplyCoalesceMillis=0,DisableECN=False,DisableGSO=False,FixedPacketSize=0);p.write_text(json.dumps(d));p=pathlib.Path("+repr(x.remote+'/tuic')+");d=json.loads(p.read_text());d['TuicPort']="+str(tp)+";p.write_text(json.dumps(d))"
  x.ssh('python3 -c '+shlex.quote(code));x.ssh('systemctl start '+x.nextunit+' '+tuic);time.sleep(5)
  x.cfg.update(NextAddress='154.37.155.240:'+str(np),NextOptimizedAddress='154.37.155.240:'+str(np),TuicAddress='154.37.155.240:'+str(tp))
  p=x.privatefile(name,x.cfg);x.adb('push',str(p),x.ad+'/config');x.adb('shell','chmod','600',x.ad+'/config')
  if any(x.ssh('systemctl is-active '+u).strip()!='active' for u in [x.nextunit,tuic]):raise RuntimeError('lab server inactive')
  return dict(next_port=np,tuic_port=tp)
 # Pilots validate both port assignments; these are excluded from final rankings.
 for b in range(2):
  name=f'resume-pilot-ports{b+1}';ports=setup(b,name);x.phase(name,['-samples','1','-pools','1','-batches','1','-workers','4']+fixed,','.join(V),timeout=180)
  rows=[]
  for l in (O/(name+'.jsonl')).read_text().splitlines():
   try:r=json.loads(l)
   except:continue
   rows.append(r)
  for v in V:
   rr=[r for r in rows if r.get('version')==v and r.get('phase') in ['cold','warm','prime','batch']]
   if not rr or any(r.get('error') for r in rr):raise RuntimeError('pilot transport failed: '+v)
  timeline.append(dict(name=name,metric='pilot',block=b+1,ports=ports));(O/'timeline.json').write_text(json.dumps(timeline,indent=2))
 (O/'battery-start.txt').write_text(x.adb('shell','dumpsys','battery'))
 for metric,n,args,bulk,timeout in metrics:
  for b in range(n):
   order=orders[b] if n==6 else (V if b==0 else list(reversed(V)))
   for pos,v in enumerate(order):
    name=f'{metric}-b{b+1}-p{pos+1}-{v}'
    if name in completed:continue
    ports=setup(b,name);start=time.time();extra=['-target','fc-lab.test:19454'] if metric.startswith('web-') else fixed
    try:x.phase(name,args+extra,v,bulk=bulk,timeout=timeout)
    except subprocess.TimeoutExpired:
     x.adb('shell','pkill','-f',x.ad+'/compare')
     if metric not in ['single16','parallel4','parallel8','rolling']:raise
     jobs={'single16':1,'parallel4':4,'parallel8':8,'rolling':12}[metric];size={'single16':16<<20,'parallel4':4<<20,'parallel8':2<<20,'rolling':4<<20}[metric]
     phase={'single16':'download','parallel4':'parallel_download','parallel8':'parallel_download','rolling':'rolling_download'}[metric]
     row=dict(phase=phase,version=v,protocol='quic',round=1,workers=min(jobs,8),jobs=jobs,success=0,verified_bytes=0,received_bytes=0,expected_bytes_each=size,elapsed_ms=timeout*1000,error='harness deadline; no final completion report; unobserved bytes credited zero')
     with (O/(name+'.jsonl')).open('a') as f:f.write(json.dumps(row)+'\n')
     print('TIMEOUT '+name,flush=True)
    timeline.append(dict(name=name,metric=metric,block=b+1,position=pos+1,version=v,start=start,end=time.time(),ports=ports));(O/'timeline.json').write_text(json.dumps(timeline,indent=2))
 (O/'battery-end.txt').write_text(x.adb('shell','dumpsys','battery'))
print('RECOVERY TRIO COMPLETE',flush=True)
