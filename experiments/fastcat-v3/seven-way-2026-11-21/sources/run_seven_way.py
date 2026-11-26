import subprocess as sp,os,json,time,gzip,secrets,hashlib,uuid
from pathlib import Path
D=Path('/tmp/fc-seven-way');host='root@zlhk.fastcat.ink';sock=os.path.expanduser('~/.ssh/fastcat-v2-test.sock');stamp=str(int(time.time()));remote='/run/fc-seven-'+stamp
units=['fc-seven-'+n+'-'+stamp for n in ['v2','light','xray','echo']];bins=['/usr/local/bin/fc-seven-'+n+'-'+stamp for n in ['v2','v3','xray-lab']]
def ssh(cmd):return sp.check_output(['ssh','-S',sock,'-o','ConnectTimeout=10',host,cmd],text=True,timeout=60)
def adb(*a):return sp.check_output(['adb','-s','A3GMVB2110006859',*a],text=True,timeout=30)
def connected():return 'ni{VPN CONNECTED' in adb('shell','dumpsys','connectivity')
def toggle():
 adb('shell','input','keyevent','KEYCODE_WAKEUP');adb('shell','input','keyevent','82');adb('shell','am','start','-n','com.fastcat.app.debug/com.fastcat.app.MainActivity');time.sleep(1);adb('shell','input','tap','100','2235');time.sleep(1);adb('shell','input','tap','540','1220');time.sleep(3)
was_vpn=connected();created=False;started=[];stayon=None
try:
 ports=ssh('ss -H -lntu')
 if any(':'+str(p)+' ' in ports for p in (19442,19444,19445,19446,19448,19450,19451,19452,19454)):raise RuntimeError('Test ports occupied')
 sp.run([str(D/'init'),'init','-dir',str(D/'config')],check=True)
 token=secrets.token_hex(32);(D/'token').write_text(token);(D/'token').chmod(0o600)
 cfg=dict(V2Address='191.223.214.8:19442',IndependentAddress='191.223.214.8:19444',ServerName='zlhk.fastcat.ink',V2Token=token,V3=json.loads((D/'config/client.json').read_text()),CA='/data/local/tmp/fc-seven-way/ca.pem',BulkTLSName='zlhk.fastcat.ink',VlessAddress='191.223.214.8:19446',TrojanAddress='191.223.214.8:19448',UUID=str(uuid.uuid4()),TrojanPassword=secrets.token_hex(32),HysteriaAddress='191.223.214.8:19450',TuicAddress='191.223.214.8:19451',AnyAddress='191.223.214.8:19452')
 cfg['HysteriaPassword']=cfg['TrojanPassword'];cfg['TuicUUID']=cfg['UUID'];cfg['AnyPassword']=cfg['TrojanPassword']
 (D/'config.json').write_text(json.dumps(cfg));(D/'config.json').chmod(0o600)
 cred='/run/credentials/'+units[2]+'.service'
 lab=dict(Cert=cred+'/cert',Key=cred+'/key',UUID=cfg['UUID'],Password=cfg['TrojanPassword'],VlessPort=19446,TrojanPort=19448,HysteriaPort=19450,TuicPort=19451,AnyPort=19452)
 (D/'lab.json').write_text(json.dumps(lab));(D/'lab.json').chmod(0o600)
 ssh('mkdir -m 700 '+remote);created=True
 for name,path in zip(['v2','v3','xray-lab'],bins):
  sp.run(['ssh','-S',sock,host,'gzip -dc > '+path],input=gzip.compress((D/name).read_bytes(),compresslevel=6),check=True)
 for source,target in [(D/'token','token'),(D/'config/server.json','config'),(D/'lab.json','lab')]:sp.run(['scp','-q','-o','ControlPath='+sock,str(source),host+':'+remote+'/'+target],check=True)
 ssh('chmod 755 '+' '.join(bins)+'; chmod 600 '+remote+'/*')
 (D/'echo.py').write_text(Path(__file__).with_name('backends.py').read_text())
 sp.run(['scp','-q','-o','ControlPath='+sock,str(D/'echo.py'),host+':'+remote+'/echo.py'],check=True)
 ssh('systemd-run --unit='+units[3]+' -p RuntimeMaxSec=90m -p NoNewPrivileges=yes /usr/bin/python3 '+remote+'/echo.py');started.append(units[3])
 cert='/etc/letsencrypt/live/zlhk.fastcat.ink/'
 for index in range(3):
  unit=units[index];cred='/run/credentials/'+unit+'.service'
  options=' -p DynamicUser=yes -p NoNewPrivileges=yes -p RuntimeMaxSec=90m -p LoadCredential=cert:'+cert+'fullchain.pem -p LoadCredential=key:'+cert+'privkey.pem -p LoadCredential=token:'+remote+'/token -p LoadCredential=config:'+remote+'/config -p LoadCredential=lab:'+remote+'/lab'
  if index==0:args='-h2-tokens '+cred+'/token -h3-tokens '+cred+'/token -listen 0.0.0.0:19442 -cert '+cred+'/cert -key '+cred+'/key'
  elif index==1:args='serve -profile independent -config '+cred+'/config -listen 0.0.0.0:19444 -cert '+cred+'/cert -key '+cred+'/key'
  else:args=cred+'/lab'
  print(ssh('systemd-run --unit='+unit+options+' '+bins[index]+' '+args),flush=True);started.append(unit)
 time.sleep(1)
 if ssh('systemctl is-active '+units[2]).strip()!='active':raise RuntimeError('CatNode lab not active')
 assert (D/'compare').exists(), 'Build the benchmark client first'
 adb('shell','mkdir','-p','/data/local/tmp/fc-seven-way');adb('shell','chmod','700','/data/local/tmp/fc-seven-way')
 for source,target in [(D/'compare','compare'),(D/'config.json','config'),(Path('/etc/ssl/cert.pem'),'ca.pem')]:adb('push',str(source),'/data/local/tmp/fc-seven-way/'+target)
 adb('shell','chmod','700','/data/local/tmp/fc-seven-way/compare');adb('shell','chmod','600','/data/local/tmp/fc-seven-way/config')
 if was_vpn:toggle()
 if connected():raise RuntimeError('VPN did not disconnect')
 stayon=adb('shell','settings','get','global','stay_on_while_plugged_in').strip();adb('shell','svc','power','stayon','usb')
 (D/'network-before.txt').write_text(adb('shell','dumpsys','connectivity'))
 base=['adb','-s','A3GMVB2110006859','shell','/data/local/tmp/fc-seven-way/compare','-config','/data/local/tmp/fc-seven-way/config','-versions','v2,v3-light-fast,vless-vision,trojan,hysteria2,tuic,anytls']
 with (D/'pilot.jsonl').open('w') as out,(D/'pilot.log').open('w') as err:
  sp.run(base+['-pools','1','-samples','1','-batches','1','-workers','1'],stdout=out,stderr=err,check=True,timeout=240)
 pilot=[json.loads(s) for s in (D/'pilot.jsonl').read_text().splitlines() if s.startswith('{')]
 for version in ['v2','v3-light-fast','vless-vision','trojan','hysteria2','tuic','anytls']:
  if not any(r['version']==version and not r.get('error') for r in pilot):raise RuntimeError('Pilot has no successful '+version+' samples; credentials/transport need diagnosis')
 print('All seven protocol pilot checks passed',flush=True)
 def phase(name,args,timeout=2200,stderr_json=False):
  (D/(name+'-network-before.txt')).write_text(adb('shell','dumpsys','connectivity'))
  with (D/(name+'.stdout' if stderr_json else name+'.jsonl')).open('w') as out,(D/(name+'.jsonl' if stderr_json else name+'.log')).open('w') as err:
   sp.run(base+args,stdout=out,stderr=err,check=True,timeout=timeout)
  (D/(name+'-network-after.txt')).write_text(adb('shell','dumpsys','connectivity'))
  print('PHASE COMPLETE: '+name,flush=True)
 phase('controlled',['-pools','3','-samples','20','-batches','5','-workers','4','-target','191.223.214.8:19454','-target-server-name','zlhk.fastcat.ink'])
 phase('singlepool',['-workload','batch-only','-pools','1','-batches','20','-workers','1','-target','191.223.214.8:19454','-target-server-name','zlhk.fastcat.ink'])
 phase('internet',['-pools','3','-samples','20','-batches','5','-workers','4'])
 phase('concurrent8',['-workload','batch-only','-pools','1','-batches','2','-workers','8','-target','191.223.214.8:19454','-target-server-name','zlhk.fastcat.ink'])
 phase('idle35',['-idle-seconds','35','-target','191.223.214.8:19454','-target-server-name','zlhk.fastcat.ink'])
 phase('downloads',['-download-bytes','1048576','-download-rounds','2','-target','191.223.214.8:19454','-target-server-name','zlhk.fastcat.ink'],timeout=900,stderr_json=True)
 phase('throughput',['-bulk-only','-bulk-rounds','3','-bulk-seconds','8','-bulk-target','191.223.214.8:19445'],timeout=1800,stderr_json=True)
 phase('idle70',['-idle-seconds','70','-target','191.223.214.8:19454','-target-server-name','zlhk.fastcat.ink'])
 (D/'network-after.txt').write_text(adb('shell','dumpsys','connectivity'))
 meta=dict(versions=['v2','v3-light-fast','vless-vision','trojan','hysteria2','tuic','anytls'],pools=3,samples=20,batches=5,workers=4,bulk_seconds=8,bulk_rounds=3,client_go='1.26.2',server_go='1.27.3',device='A3GMVB2110006859',xray_module='github.com/xtls/xray-core v1.261031.0 => github.com/wyx2685/xray-core v0.0.0-20261105071511-0061c59f331a',server_uses='CatNode V2Core.Start/AddNode/AddUsers and custom dispatcher/limiter; synthetic unrestricted users; no panel',sha256={n:hashlib.sha256((D/n).read_bytes()).hexdigest() for n in ['v2','v3','xray-lab','compare']})
 (D/'metadata.json').write_text(json.dumps(meta,indent=2));print('BENCHMARK COMPLETE',flush=True)
finally:
 if stayon is not None:adb('shell','settings','put','global','stay_on_while_plugged_in',stayon)
 try:
  adb('shell','input','keyevent','KEYCODE_WAKEUP');adb('shell','input','keyevent','82')
  if was_vpn and not connected():toggle()
  print('VPN restored:',connected(),flush=True)
 except Exception as e:print('VPN restore requires attention:',type(e).__name__,flush=True)
 if started:
  try:ssh('systemctl stop '+' '.join(started))
  except Exception as e:print('Service cleanup:',type(e).__name__)
 if created:
  for name in bins+[remote+'/token',remote+'/config',remote+'/lab',remote+'/echo.py']:
   try:ssh('test ! -e '+name+' || unlink '+name)
   except Exception:pass
  try:ssh('rmdir '+remote)
  except Exception:pass
 try:adb('shell','toybox','rm','-f','/data/local/tmp/fc-seven-way/config','/data/local/tmp/fc-seven-way/compare','/data/local/tmp/fc-seven-way/ca.pem');adb('shell','rmdir','/data/local/tmp/fc-seven-way')
 except Exception:pass
 for p in [D/'config.json',D/'token',D/'lab.json',D/'config/client.json',D/'config/server.json']:p.unlink(missing_ok=True)
 if (D/'config').exists():(D/'config').rmdir()
