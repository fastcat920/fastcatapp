import sys,json,time,shlex,subprocess as sp,re,hashlib
from pathlib import Path
sys.path.insert(0,'/tmp/fc-next-primary');import lab
D=Path('/tmp/fc-next-reply');O=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/reply-2026-11-23/cross-network');O.mkdir(exist_ok=True);lab.D=D;lab.OUT=O
(O/'plan.json').write_text(json.dumps(dict(purpose='small request route comparison; no bulk downloads on cellular',networks=['wifi-before','cellular','wifi-after'],samples=12,policy='next-opt unchanged',sha256={n:hashlib.sha256((D/n).read_bytes()).hexdigest() for n in ['compare','next-diagnostic']}),indent=2));timeline=[]
def transport(x):
 state=x.adb('shell','dumpsys','connectivity');m=re.search(r'Active default network: (\d+)',state)
 if not m:return 'NONE',state
 a=next((l for l in state.splitlines() if 'network{'+m.group(1)+'}' in l and 'Transports:' in l),'')
 a=a.split('Capabilities:',1)[0]
 if 'VPN' in a:return 'VPN',state
 return ('WIFI' if 'WIFI' in a else 'CELLULAR' if 'CELLULAR' in a else 'OTHER'),state
with lab.Lab('cross',full=False,trace=False) as x:
 x.start();x.cfg.update(NextOptimizedAddress=x.cfg['NextAddress'],NextOptimizedProfile='baseline',NextOptimizedCoalesce=False,NextOptimizedConnections=2,NextOptimizedAdaptive=True)
 p=x.privatefile('cross-client',x.cfg);x.adb('push',str(p),x.ad+'/config');x.adb('shell','chmod','600',x.ad+'/config')
 def case(network,variant,pilot=False):
  want='CELLULAR' if network=='cellular' else 'WIFI';kind,state=transport(x)
  if kind!=want:raise RuntimeError('wrong active network '+kind)
  delay=0 if variant=='baseline' else 5
  code="import json,pathlib;p=pathlib.Path("+repr(x.remote+'/next')+");d=json.loads(p.read_text());d.update(Trace=True,PrefixTrace=True,ReplyCoalesceMillis="+repr(delay)+");p.write_text(json.dumps(d))"
  x.ssh('python3 -c '+shlex.quote(code));x.ssh('systemctl restart '+x.nextunit);time.sleep(5);pid=x.ssh('systemctl show -p MainPID --value '+x.nextunit).strip();name=network+'-'+variant+('-pilot' if pilot else '')
  (O/(name+'-network-before.txt')).write_text(state);args=['-samples','1' if pilot else '12','-pools','1','-batches','1','-workers','1','-lane-diagnostics','-trace-prefix','-target','191.223.214.8:19454','-target-server-name','zlhk.fastcat.ink'];start=time.time()
  with (O/(name+'.jsonl')).open('w') as a,(O/(name+'.log')).open('w') as b:sp.run(x.adbbase+['shell',x.ad+'/compare','-config',x.ad+'/config','-versions','next-opt']+args,stdout=a,stderr=b,check=True,timeout=450)
  kind,after=transport(x);(O/(name+'-network-after.txt')).write_text(after);(O/(name+'-server.log')).write_text(x.ssh('journalctl -u '+x.nextunit+' _PID='+pid+' --no-pager -o cat'))
  timeline.append(dict(name=name,network=network,variant=variant,pilot=pilot,start=start,end=time.time(),active_after=kind));(O/'timeline.json').write_text(json.dumps(timeline,indent=2));print('COMPLETE '+name,flush=True)
  if kind!=want:raise RuntimeError('network changed during short probe')
  rows=[json.loads(l) for l in (O/(name+'.jsonl')).read_text().splitlines()];return any(r.get('first_byte_us',0)>0 and not r.get('error') for r in rows)
 try:
  case('wifi-before','baseline');case('wifi-before','coalesce5')
  x.adb('shell','svc','wifi','disable')
  ready=False
  for _ in range(20):
   time.sleep(2)
   if transport(x)[0]=='CELLULAR':ready=True;break
  if ready and case('cellular','baseline',pilot=True):case('cellular','coalesce5');case('cellular','baseline')
  else:(O/'cellular-unavailable.txt').write_text('No usable cellular default route or pilot request; no bulk attempted.\n')
 finally:
  x.adb('shell','svc','wifi','enable')
  for _ in range(25):
   time.sleep(2)
   if transport(x)[0]=='WIFI':break
  if transport(x)[0]!='WIFI':raise RuntimeError('Wi-Fi did not restore')
 case('wifi-after','coalesce5');case('wifi-after','baseline')
print('CROSS COMPLETE',flush=True)
