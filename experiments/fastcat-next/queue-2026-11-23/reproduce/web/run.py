import sys,json,time,shlex,hashlib
from pathlib import Path
sys.path.insert(0,'/tmp/fc-next-primary');import lab
D=Path('/tmp/fc-next-web');O=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/queue-2026-11-23/remote-web');O.mkdir(parents=True,exist_ok=True);lab.D=D;lab.OUT=O
base=O.parent
s3=json.loads((base/'stage3/performance/summary.json').read_text());s4=json.loads((base/'stage4/performance/summary.json').read_text())
assert len(json.loads((base/'stage4/performance/timeline.json').read_text()))==42
assert s3['gate']['passed'];prefix=s4['gate']['passed'];selected='recovery+prefix' if prefix else 'recovery'
(O/'plan.json').write_text(json.dumps(dict(selected=selected,selection_rule='stage3 passed; add prefix only if stage4 full gate passed',targets=['example.com:443','www.google.com:443'],background='2 x 16MiB from zlhk.fastcat.ink:19454 matching certificate; shared same client',samples=12,paired_blocks_per_target=2,trace=False,variants=['baseline-original','selected'],gate=dict(foreground_completion_not_lower=True,background_completion_not_lower=True,loaded_p95_ratio_max=1.1,min_loaded_samples_per_condition_per_target=12),sha256={n:hashlib.sha256((D/n).read_bytes()).hexdigest() for n in ['compare','next-diagnostic']}),indent=2));timeline=[]
with lab.Lab('next-remote',full=False,trace=False) as x:
 x.start();x.cfg.update(NextOptimizedAddress=x.cfg['NextAddress'],NextOptimizedProfile='baseline',NextOptimizedCoalesce=False,NextOptimizedConnections=2,NextOptimizedAdaptive=True)
 for ti,target in enumerate(['example.com:443','www.google.com:443']):
  for b in range(2):
   for pos,v in enumerate(['baseline','selected'] if b%2==0 else ['selected','baseline']):
    on=v=='selected';name=f'web{ti+1}-{v}-b{b+1}-p{pos+1}';x.cfg['NextRecoveryAware']=on;x.cfg['NextPrefixRedundancy']=on and prefix
    code="import json,pathlib;p=pathlib.Path("+repr(x.remote+'/next')+");d=json.loads(p.read_text());d.update(Trace=False,PrefixTrace=False,DisableGSO=False,FixedPacketSize=0,ReplyCoalesceMillis=0,DisableECN=False,DownstreamBudget=False,PrefixRedundancy="+repr(on and prefix)+");p.write_text(json.dumps(d))"
    x.ssh('python3 -c '+shlex.quote(code));x.ssh('systemctl restart '+x.nextunit);time.sleep(5)
    p=x.privatefile(name,x.cfg);x.adb('push',str(p),x.ad+'/config');x.adb('shell','chmod','600',x.ad+'/config');start=time.time()
    x.phase(name,['-mixed-download-bytes',str(16<<20),'-mixed-foreground-target',target,'-samples','12','-download-rounds','1','-download-timeout','90s','-transport-snapshots','-lane-diagnostics','-target','zlhk.fastcat.ink:19454'],'next-opt',bulk=True,timeout=120)
    timeline.append(dict(name=name,variant=v,target=target,block=b+1,start=start,end=time.time()));(O/'timeline.json').write_text(json.dumps(timeline,indent=2))
print('NEXT REMOTE WEB COMPLETE',flush=True)
