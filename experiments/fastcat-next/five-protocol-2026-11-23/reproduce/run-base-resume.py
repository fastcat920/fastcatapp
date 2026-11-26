# -*- coding: utf-8 -*-
import sys,json,time,hashlib,shlex,uuid,subprocess,collections
from pathlib import Path
MODE=sys.argv[1];D=Path('/tmp/fc-five/'+MODE);O=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/five-protocol-2026-11-23')/MODE;O.mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(D));import lab
from runtime_lab import RuntimeLab
lab.D=D;lab.OUT=O
IP='172.104.55.44' if MODE=='speed' else '154.37.155.240';V=['next-opt','next-base','tuic','hysteria2','vless-vision'];base=[0,1,4,2,3];orders=[[V[(j+i)%5] for j in base] for i in range(5)];orders += [list(reversed(r)) for r in orders[:5]]
assert all(collections.Counter(r[i] for r in orders)=={v:2 for v in V} for i in range(5))
fixed=['-target',IP+':19454','-target-server-name','fc-lab.test']
if MODE=='speed':metrics=[('single32',10,['-download-bytes',str(32<<20),'-download-rounds','1','-download-timeout','30s'],True,50),('parallel4',10,['-download-bytes',str(8<<20),'-download-workers','4','-download-rounds','1','-download-timeout','30s'],True,50),('parallel8',10,['-download-bytes',str(4<<20),'-download-workers','8','-download-rounds','1','-download-timeout','30s'],True,50),('rolling',10,['-download-bytes',str(4<<20),'-download-workers','4','-download-jobs','12','-download-rounds','1','-download-timeout','45s'],True,70),('echo',10,['-bulk-only','-bulk-rounds','1','-bulk-seconds','5','-bulk-target',IP+':19445'],True,60)]
else:metrics=[('latency',10,['-samples','6','-pools','1','-batches','2','-workers','4'],False,240),('batch8',10,['-workload','batch-only','-samples','1','-pools','1','-batches','2','-workers','8'],False,180),('mixed',10,['-mixed-ready','-mixed-download-bytes',str(2<<20),'-samples','6','-download-rounds','1','-download-timeout','90s'],True,115),('idle',10,['-idle-seconds','20'],False,90),('web-example',2,['-mixed-ready','-mixed-download-bytes',str(2<<20),'-mixed-foreground-target','example.com:443','-samples','12','-download-rounds','1','-download-timeout','90s'],True,115),('web-google',2,['-mixed-ready','-mixed-download-bytes',str(2<<20),'-mixed-foreground-target','www.google.com:443','-samples','12','-download-rounds','1','-download-timeout','90s'],True,115)]
metrics=[m for m in metrics if m[0]=='idle']
plan=dict(date='2026-11-23',mode=MODE,server=IP,variants=dict(zip(V,['Next2lanes adaptiveRecoveryAware,BBR','Next1lane,BBR','CatNodeTUICv5,Mihomo,BBR','CatNodeHysteria2,Mihomo,noBrutalBandwidth,BBRpath','CatNodeVLESS+TCP+TLS+XTLSVision,systemTCPCC'])),orders=orders,metrics=metrics,port_schedule='all variants SAME numeric entry port each block;19458 odd/19451 even;10blocks gives5perport pervariant',order_design='Williams10 sequences for5conditions, eachposition2times, bothdirections; casesrestart5s cooldown; realweb2rounds use forward/reverse only',sha256={n:hashlib.sha256((D/n).read_bytes()).hexdigest() for n in ['compare','next-diagnostic','catnode-server']},client_go='1.26.2',server_go='1.27.3',trace=False,measurement_changes=['recordSHA256andverifyreceivedprefix evenifpartial file; completefile checked separately','strictmixed wait15s max forbothreceive256KiB'],scope='AndroidnativeWiFi,AppVPNoff,noAppupdate,certverified;not equalpool/congestionimplementations',notes=['legacy raw protocol=quic is comparison family label for native variants; VLESS actualcarrierTCP','prefixverified throughput and completefile throughput separate; partial not counted complete','No earlier data pooled; no failed case replacement'])
if (O/'base-resume-plan.json').exists():assert json.loads((O/'base-resume-plan.json').read_text())==json.loads(json.dumps(plan))
else:(O/'base-resume-plan.json').write_text(json.dumps(plan,indent=2))
timeline=json.loads((O/'timeline.json').read_text()) if (O/'timeline.json').exists() else [];completed={t['name'] for t in timeline if t.get('metric')!='pilot'}
with RuntimeLab('five-'+MODE,full=False,trace=False) as x:
 x.start();uid=str(uuid.uuid4());node=x.service('node',D/'catnode-server',dict(Kind='tuic',UUID=uid,Port=19446));x.cfg.update(UUID=uid,TuicUUID=uid,HysteriaPassword=uid,NextOptimizedProfile='baseline',NextOptimizedCoalesce=False,NextOptimizedConnections=2,NextOptimizedAdaptive=True,NextRecoveryAware=True,NextPrefixRedundancy=False)
 def setup(b,name,v):
  port=19458 if b%2==0 else 19451;x.ssh('systemctl stop '+x.nextunit+' '+node)
  kind={'tuic':'tuic','hysteria2':'hysteria2','vless-vision':'vless'}.get(v,'tuic')
  code="import json,pathlib;p=pathlib.Path("+repr(x.remote+'/next')+");d=json.loads(p.read_text());d.update(Listen="+repr('0.0.0.0:'+str(port))+",Trace=False,PrefixTrace=False,DownstreamBudget=False,PrefixRedundancy=False,ReplyCoalesceMillis=0,DisableECN=False,DisableGSO=False,FixedPacketSize=0);p.write_text(json.dumps(d));p=pathlib.Path("+repr(x.remote+'/node')+");d=json.loads(p.read_text());d.update(Kind="+repr(kind)+",Port="+str(port)+");p.write_text(json.dumps(d))"
  x.ssh('python3 -c '+shlex.quote(code));active=x.nextunit if v.startswith('next-') else node;x.ssh('systemctl start '+active);time.sleep(5)
  addr=IP+':'+str(port);x.cfg.update(NextAddress=addr,NextOptimizedAddress=addr,TuicAddress=addr,HysteriaAddress=addr,VlessAddress=addr)
  p=x.privatefile(name,x.cfg);x.adb('push',str(p),x.ad+'/config');x.adb('shell','chmod','600',x.ad+'/config')
  if x.ssh('systemctl is-active '+active).strip()!='active':raise RuntimeError('test server inactive')
  return port,active
 def save(r):timeline.append(r);(O/'timeline.json').write_text(json.dumps(timeline,indent=2))
 for b in range(2):
  for v in V:
   name=f'pilot-{x.stamp}-ports{b+1}-{v}';port,_=setup(b,name,v);x.phase(name,['-samples','1','-pools','1','-batches','1','-workers','2']+fixed,v,timeout=100);rows=[]
   for l in (O/(name+'.jsonl')).read_text().splitlines():
    try:rows.append(json.loads(l))
    except:pass
   rr=[r for r in rows if r.get('version')==v and r.get('phase') in ['cold','warm','prime','batch']]
   if not rr or any(r.get('error') for r in rr):raise RuntimeError('pilot transport failed: '+v)
   save(dict(name=name,metric='pilot',block=b+1,version=v,dest_port=port))
 (O/('battery-start-'+x.stamp+'.txt')).write_text(x.adb('shell','dumpsys','battery'))
 for metric,n,args,bulk,timeout in metrics:
  for b in range(n):
   order=orders[b] if n==10 else (V if b==0 else list(reversed(V)))
   for pos,v in enumerate(order):
    name=f'{metric}-b{b+1}-p{pos+1}-{v}'
    if name in completed:continue
    port,active=setup(b,name,v);start=time.time();extra=['-target','fc-lab.test:19454'] if metric.startswith('web-') else fixed;status='returned'
    try:x.phase(name,args+extra,v,bulk=bulk,timeout=timeout)
    except subprocess.TimeoutExpired:
     subprocess.run(x.adbbase+['shell','pkill','-f',x.ad+'/compare'],check=False);status='harness_timeout'
     row=dict(phase='case_timeout',version=v,error='harness deadline; final rows missing; no inferred verified bytes',elapsed_ms=timeout*1000)
     with (O/(name+'.jsonl')).open('a') as f:f.write(json.dumps(row)+'\n')
     print('TIMEOUT '+name,flush=True)
    except subprocess.CalledProcessError:status='client_nonzero';print('CLIENT NONZERO '+name,flush=True)
    (O/(name+'-server-resource.txt')).write_text(x.ssh('systemctl show '+active+' -p CPUUsageNSec -p MemoryPeak -p TasksCurrent'))
    save(dict(name=name,metric=metric,block=b+1,position=pos+1,version=v,start=start,end=time.time(),dest_port=port,status=status,expected_args=args))
 (O/('battery-end-'+x.stamp+'.txt')).write_text(x.adb('shell','dumpsys','battery'))
print('FIVE '+MODE.upper()+' COMPLETE',flush=True)
