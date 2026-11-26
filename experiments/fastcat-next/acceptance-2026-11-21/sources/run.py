import subprocess as sp,os,json,time,gzip,secrets,hashlib,shutil
from pathlib import Path
D=Path('/tmp/fc-next');OUT=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/acceptance-2026-11-21');OUT.mkdir(parents=True,exist_ok=True)
host='root@zlhk.fastcat.ink';sock=os.path.expanduser('~/.ssh/fastcat-v2-test.sock');serial='A3GMVB2110006859';stamp=str(int(time.time()));remote='/run/fc-next-'+stamp
units={n:'fc-next-'+n+'-'+stamp for n in ['reno','bbr','next','light','backend']};bins={n:'/usr/local/bin/fc-next-'+n+'-'+stamp for n in ['v2','next','light']};started=[];created=False;was_vpn=False;stayon=None
adbdir='/data/local/tmp/fc-next'
def ssh(cmd):return sp.check_output(['ssh','-S',sock,'-o','ConnectTimeout=10',host,cmd],text=True,timeout=60)
def adb(*a):return sp.check_output(['adb','-s',serial,*a],text=True,timeout=30)
def connected():return 'ni{VPN CONNECTED' in adb('shell','dumpsys','connectivity')
def toggle():
 adb('shell','input','keyevent','KEYCODE_WAKEUP');adb('shell','input','keyevent','82');adb('shell','am','start','-n','com.fastcat.app.debug/com.fastcat.app.MainActivity');time.sleep(1);adb('shell','input','tap','100','2235');time.sleep(1);adb('shell','input','tap','540','1220');time.sleep(3)
def phase(name,args,timeout=1800,stderr_json=False,versions='v2-reno,v2-bbr,next,v3-light-fast'):
 (OUT/(name+'-network-before.txt')).write_text(adb('shell','dumpsys','connectivity'))
 base=['adb','-s',serial,'shell',adbdir+'/compare','-config',adbdir+'/config','-versions',versions]
 with (OUT/(name+'.stdout' if stderr_json else name+'.jsonl')).open('w') as o,(OUT/(name+'.jsonl' if stderr_json else name+'.log')).open('w') as e:
  sp.run(base+args,stdout=o,stderr=e,check=True,timeout=timeout)
 (OUT/(name+'-network-after.txt')).write_text(adb('shell','dumpsys','connectivity'))
 print('COMPLETE '+name,flush=True)
try:
 ports=ssh('ss -H -lntu')
 if any(':'+str(p)+' ' in ports for p in [19440,19442,19444,19445,19454,19456,19457,19458]):raise RuntimeError('A test port is occupied')
 was_vpn=connected()
 sp.run(['/tmp/fc-seven-way/init','init','-dir',str(D/'lightconfig')],check=True)
 token=secrets.token_hex(32);secret=secrets.token_hex(32);account='lab-'+secrets.token_hex(6)
 cfg=dict(V2Address='191.223.214.8:19442',V2BBRAddress='191.223.214.8:19440',IndependentAddress='191.223.214.8:19444',NextAddress='191.223.214.8:19458',NextAccount=account,NextSecret=secret,ServerName='zlhk.fastcat.ink',V2Token=token,V3=json.loads((D/'lightconfig/client.json').read_text()),CA=adbdir+'/ca.pem',BulkTLSName='zlhk.fastcat.ink')
 (D/'config.json').write_text(json.dumps(cfg));(D/'config.json').chmod(0o600)
 ssh('mkdir -m 700 '+remote);created=True
 for n in bins:
  source=D/n if n!='light' else Path('/tmp/fc-seven-way/v3')
  sp.run(['ssh','-S',sock,host,'gzip -dc > '+bins[n]],input=gzip.compress(source.read_bytes()),check=True)
 ssh('chmod 755 '+' '.join(bins.values()))
 backend=Path('/tmp/fc-seven-way/backends.py').read_text()
 backend=backend.replace('threading.Event().wait()', '''class Plain(socketserver.BaseRequestHandler):
 def handle(self):
  while True:
   b=self.request.recv(65536)
   if not b:break
   self.request.sendall(b)
class UDP(socketserver.BaseRequestHandler):
 def handle(self):
  b,s=self.request;s.sendto(b,self.client_address)
server=S(('0.0.0.0',19457),Plain);threading.Thread(target=server.serve_forever,daemon=True).start()
udp=socketserver.ThreadingUDPServer(('0.0.0.0',19456),UDP);threading.Thread(target=udp.serve_forever,daemon=True).start()
threading.Event().wait()''')
 (D/'backend.py').write_text(backend)
 sp.run(['scp','-q','-o','ControlPath='+sock,str(D/'backend.py'),host+':'+remote+'/backend.py'],check=True)
 print(ssh('systemd-run --unit='+units['backend']+' -p RuntimeMaxSec=90m -p NoNewPrivileges=yes /usr/bin/python3 '+remote+'/backend.py'),flush=True);started.append(units['backend'])
 cert='/etc/letsencrypt/live/zlhk.fastcat.ink/'
 for n in ['reno','bbr','next','light']:
  cred='/run/credentials/'+units[n]+'.service';c={'Listen':'0.0.0.0:'+str({'reno':19442,'bbr':19440,'next':19458,'light':19444}[n]),'Cert':cred+'/cert','Key':cred+'/key','Token':token,'Congestion':'bbr' if n in ['bbr','next'] else ''}
  if n=='next':c.update(Account=account,Secret=secret,IdleSeconds=60)
  (D/(n+'.json')).write_text(json.dumps(c) if n!='light' else (D/'lightconfig/server.json').read_text());(D/(n+'.json')).chmod(0o600)
  sp.run(['scp','-q','-o','ControlPath='+sock,str(D/(n+'.json')),host+':'+remote+'/'+n],check=True)
  options=' -p DynamicUser=yes -p NoNewPrivileges=yes -p RuntimeMaxSec=90m -p LoadCredential=cert:'+cert+'fullchain.pem -p LoadCredential=key:'+cert+'privkey.pem -p LoadCredential=config:'+remote+'/'+n
  args=('-config '+cred+'/config') if n=='next' else (cred+'/config')
  if n=='light':args='serve -profile independent -config '+cred+'/config -listen 0.0.0.0:19444 -cert '+cred+'/cert -key '+cred+'/key'
  print(ssh('systemd-run --unit='+units[n]+options+' '+bins[n if n in ['next','light'] else 'v2']+' '+args),flush=True);started.append(units[n])
 time.sleep(1)
 adb('shell','mkdir','-p',adbdir);adb('shell','chmod','700',adbdir)
 for source,target in [(D/'compare','compare'),(D/'config.json','config'),(Path('/etc/ssl/cert.pem'),'ca.pem')]:adb('push',str(source),adbdir+'/'+target)
 adb('shell','chmod','700',adbdir+'/compare');adb('shell','chmod','600',adbdir+'/config')
 if was_vpn:toggle()
 if connected():raise RuntimeError('VPN did not disconnect')
 stayon=adb('shell','settings','get','global','stay_on_while_plugged_in').strip();adb('shell','svc','power','stayon','usb')
 fixed=['-target','191.223.214.8:19454','-target-server-name','zlhk.fastcat.ink']
 phase('pilot',['-pools','1','-samples','1','-batches','1','-workers','1']+fixed)
 rows=[json.loads(x) for x in (OUT/'pilot.jsonl').read_text().splitlines() if x.startswith('{')]
 if any(r.get('error') for r in rows):raise RuntimeError('Pilot failed; see saved raw rows')
 phase('ablation',['-pools','1','-samples','12','-batches','3','-workers','4']+fixed,versions='v2-reno,v2-bbr')
 phase('ablation-download',['-download-bytes','1048576','-download-rounds','3']+fixed,stderr_json=True,versions='v2-reno,v2-bbr')
 phase('ablation-throughput',['-bulk-only','-bulk-rounds','3','-bulk-seconds','8','-bulk-target','191.223.214.8:19445'],stderr_json=True,versions='v2-reno,v2-bbr')
 phase('controlled',['-pools','3','-samples','20','-batches','5','-workers','4']+fixed)
 phase('internet',['-pools','3','-samples','20','-batches','5','-workers','4'])
 phase('singlepool',['-workload','batch-only','-pools','1','-batches','20','-workers','1']+fixed)
 phase('concurrent8',['-workload','batch-only','-pools','1','-batches','3','-workers','8']+fixed)
 phase('idle70',['-idle-seconds','70']+fixed)
 phase('downloads',['-download-bytes','1048576','-download-rounds','3']+fixed,stderr_json=True)
 phase('throughput',['-bulk-only','-bulk-rounds','3','-bulk-seconds','8','-bulk-target','191.223.214.8:19445'],stderr_json=True)
 meta=dict(date='2026-11-21',device=serial,server='191.223.214.8',profiles=['v2-reno/h3','v2-bbr/h3','next/h2','next/quic','v3-light-fast/h2','v3-light-fast/h3'],production_modified=False,client='independent Android CLI, VPN disabled, same native core',sha256={n:hashlib.sha256((D/n).read_bytes()).hexdigest() for n in ['compare','v2','next']},light_sha256=hashlib.sha256(Path('/tmp/fc-seven-way/v3').read_bytes()).hexdigest())
 (OUT/'metadata.json').write_text(json.dumps(meta,indent=2));print('ALL BENCHMARK PHASES COMPLETE',flush=True)
finally:
 if stayon is not None:adb('shell','settings','put','global','stay_on_while_plugged_in',stayon)
 try:
  if was_vpn and not connected():toggle()
  print('VPN restored: '+str(connected()),flush=True)
 except Exception as e:print('VPN restore needs attention: '+type(e).__name__,flush=True)
 if started:
  try:ssh('systemctl stop '+' '.join(started))
  except Exception as e:print('Server cleanup '+type(e).__name__)
 if created:
  for p in list(bins.values())+[remote+'/'+n for n in ['reno','bbr','next','light','backend.py']]:
   try:ssh('test ! -e '+p+' || unlink '+p)
   except Exception:pass
  try:ssh('rmdir '+remote)
  except Exception:pass
 try:adb('shell','toybox','rm','-f',adbdir+'/config',adbdir+'/compare',adbdir+'/ca.pem');adb('shell','rmdir',adbdir)
 except Exception:pass
 for p in [D/'config.json']+[D/(n+'.json') for n in ['reno','bbr','next','light']]+[D/'lightconfig/client.json',D/'lightconfig/server.json']:p.unlink(missing_ok=True)
 if (D/'lightconfig').exists():(D/'lightconfig').rmdir()
