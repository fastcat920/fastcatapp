import sys,json,time,shlex,hashlib
from pathlib import Path
sys.path.insert(0,'/tmp/fc-next-primary');import lab
D=Path('/tmp/fc-next-prefix');ROOT=Path('/Users/pizihu/Projects/FastCatAPP');O=ROOT/'experiments/fastcat-next/queue-2026-11-23/stage4';O.mkdir(parents=True,exist_ok=True);lab.D=D
METRICS=[('mixed',6,['-mixed-download-bytes',str(16<<20),'-samples','12','-download-rounds','1','-download-timeout','90s'],True,120),('parallel',6,['-download-bytes',str(4<<20),'-download-workers','4','-download-rounds','1','-download-timeout','90s'],True,120),('rolling',6,['-download-bytes',str(4<<20),'-download-workers','4','-download-jobs','12','-download-rounds','1','-download-timeout','150s'],True,180),('latency',3,['-samples','12','-pools','1','-batches','3','-workers','4'],False,450)]
V=['baseline','prefix'];hashes={n:hashlib.sha256((D/n).read_bytes()).hexdigest() for n in ['compare','next-diagnostic']};fixed=['-transport-snapshots','-lane-diagnostics','-target','191.223.214.8:19454','-target-server-name','zlhk.fastcat.ink']
with lab.Lab('prefix',full=False,trace=False) as x:
 x.start();x.cfg.update(NextOptimizedAddress=x.cfg['NextAddress'],NextOptimizedProfile='baseline',NextOptimizedCoalesce=False,NextOptimizedConnections=2,NextOptimizedAdaptive=True)
 p=x.privatefile('reply-client',x.cfg);x.adb('push',str(p),x.ad+'/config');x.adb('shell','chmod','600',x.ad+'/config')
 for phase in ['mechanism','performance']:
  OUT=O/phase;OUT.mkdir(exist_ok=True);lab.OUT=OUT
  plan=dict(phase=phase,variants=dict(baseline='stage3 recovery-aware control; no prefix copies',prefix='same recovery-aware control plus explicit kind2; 8193 payload bytes /12 DATAGRAM attempts max'),sha256=hashes,client_policy='both variants recovery-aware next-opt; GSO ECN PMTU defaults unchanged; boundary snapshots on both; packet trace off in performance',trace=phase=='mechanism',gate=dict(loaded_p95_ratio_max=.8,warm_p95_ratio_max=1.1,throughput_ratio_min=.9,completion_not_lower=True,min_loaded_samples=48),metrics=METRICS if phase=='performance' else ['3 paired mixed-load diagnostics: 2x8MiB +12HEAD per variant'])
  (OUT/'plan.json').write_text(json.dumps(plan,indent=2));timeline=[]
  runs=METRICS if phase=='performance' else [('latency',3,['-mixed-download-bytes',str(8<<20),'-samples','12','-download-rounds','1','-download-timeout','90s'],True,120)]
  for metric,n,args,bulk,timeout in runs:
   for b in range(n):
    order=V if b%2==0 else V[::-1]
    for pos,v in enumerate(order):
     on=phase=='mechanism';delay=0;budget=False
     code="import json,pathlib;p=pathlib.Path("+repr(x.remote+'/next')+");d=json.loads(p.read_text());d.update(Trace="+repr(on)+",PrefixTrace="+repr(on)+",DisableGSO=False,FixedPacketSize=0,ReplyCoalesceMillis=0,DisableECN=False,DownstreamBudget=False,PrefixRedundancy="+repr(v=='prefix')+");p.write_text(json.dumps(d))"
     x.ssh('python3 -c '+shlex.quote(code));x.ssh('systemctl restart '+x.nextunit);time.sleep(5);pid=x.ssh('systemctl show -p MainPID --value '+x.nextunit).strip();name=f'{metric}-{v}-b{b+1}-p{pos+1}';x.cfg['NextRecoveryAware']=True;x.cfg['NextPrefixRedundancy']=v=='prefix';p=x.privatefile(name,x.cfg);x.adb('push',str(p),x.ad+'/config');x.adb('shell','chmod','600',x.ad+'/config');start=time.time()
     x.phase(name,args+fixed+(['-trace-prefix'] if on else []),'next-opt',bulk=bulk,timeout=timeout)
     if on:(OUT/(name+'-server.log')).write_text(x.ssh('journalctl -u '+x.nextunit+' _PID='+pid+' --no-pager -o cat'))
     timeline.append(dict(name=name,variant=v,metric=metric,block=b+1,start=start,end=time.time()));(OUT/'timeline.json').write_text(json.dumps(timeline,indent=2))
print('PREFIX STAGE4 COMPLETE',flush=True)
