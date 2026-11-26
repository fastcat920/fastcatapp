import subprocess as sp,os,time,json,gzip,secrets,hashlib
from pathlib import Path
D=Path('/tmp/fc-next');O=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/acceptance-2026-11-21');sock=os.path.expanduser('~/.ssh/fastcat-v2-test.sock');host='root@zlhk.fastcat.ink';adb=['adb','-s','A3GMVB2110006859'];stamp=str(int(time.time()));unit='fc-next-sameport-'+stamp;backendunit=unit+'-backend';remote='/run/'+unit;binary='/usr/local/bin/'+unit;ad='/data/local/tmp/fc-next-sameport';started=[];created=False;was_vpn=False;stayon=None

def ssh(c):return sp.check_output(['ssh','-S',sock,host,c],text=True,timeout=60)
def a(*args):return sp.check_output(adb+list(args),text=True,timeout=30)
def connected():return 'ni{VPN CONNECTED' in a('shell','dumpsys','connectivity')
def toggle():
 a('shell','input','keyevent','KEYCODE_WAKEUP');a('shell','input','keyevent','82');a('shell','am','start','-n','com.fastcat.app.debug/com.fastcat.app.MainActivity');time.sleep(1);a('shell','input','tap','100','2235');time.sleep(1);a('shell','input','tap','540','1220');time.sleep(3)
try:
 if any(':'+str(p)+' ' in ssh('ss -H -lntu') for p in [19442,19454,19445,19456,19457,19458]):raise RuntimeError('Same-port test ports occupied')
 was_vpn=connected();ssh('mkdir -m 700 '+remote);created=True
 sp.run(['ssh','-S',sock,host,'gzip -dc > '+binary],input=gzip.compress((D/'v2').read_bytes()),check=True);ssh('chmod 755 '+binary)
 sp.run(['scp','-q','-o','ControlPath='+sock,str(D/'backend.py'),host+':'+remote+'/backend.py'],check=True)
 ssh('systemd-run --unit='+backendunit+' -p RuntimeMaxSec=35m -p NoNewPrivileges=yes /usr/bin/python3 '+remote+'/backend.py');started.append(backendunit)
 token=secrets.token_hex(32);cred='/run/credentials/'+unit+'.service';server=dict(Listen='0.0.0.0:19442',Cert=cred+'/cert',Key=cred+'/key',Token=token,Congestion='')
 cfg=dict(V2Address='191.223.214.8:19442',V2BBRAddress='191.223.214.8:19442',ServerName='zlhk.fastcat.ink',V2Token=token,CA=ad+'/ca.pem',BulkTLSName='zlhk.fastcat.ink')
 (D/'sameport-client.json').write_text(json.dumps(cfg));(D/'sameport-client.json').chmod(0o600)
 a('shell','mkdir','-p',ad);a('shell','chmod','700',ad)
 for source,target in [(D/'compare','compare'),(D/'sameport-client.json','config'),(Path('/etc/ssl/cert.pem'),'ca.pem')]:a('push',str(source),ad+'/'+target)
 a('shell','chmod','700',ad+'/compare');a('shell','chmod','600',ad+'/config')
 if was_vpn:toggle()
 if connected():raise RuntimeError('VPN did not disconnect')
 stayon=a('shell','settings','get','global','stay_on_while_plugged_in').strip();a('shell','svc','power','stayon','usb');(O/'large-setup-network-before.txt').write_text(a('shell','dumpsys','connectivity'))
 results=[]
 server['Congestion']='bbr'
 (D/'sameport-server.json').write_text(json.dumps(server));(D/'sameport-server.json').chmod(0o600)
 sp.run(['scp','-q','-o','ControlPath='+sock,str(D/'sameport-server.json'),host+':'+remote+'/config'],check=True)
 cert='/etc/letsencrypt/live/zlhk.fastcat.ink/'
 ssh('systemd-run --unit='+unit+' -p DynamicUser=yes -p NoNewPrivileges=yes -p RuntimeMaxSec=35m -p LoadCredential=cert:'+cert+'fullchain.pem -p LoadCredential=key:'+cert+'privkey.pem -p LoadCredential=config:'+remote+'/config '+binary+' '+cred+'/config');started.append(unit)
 (O/'large-setup-network-after.txt').write_text(a('shell','dumpsys','connectivity'))
 # Independent 10/100 MiB completion gate, after same-port checks. Each case is
 # kept as one attempt; timeout/partial bytes are not retried or replaced.
 nextunit=unit+'-next';nextbin=binary+'-next';nextcred='/run/credentials/'+nextunit+'.service'
 serverNext=dict(Listen='0.0.0.0:19458',Cert=nextcred+'/cert',Key=nextcred+'/key',Account='large-test',Secret=secrets.token_hex(32),Congestion='bbr',IdleSeconds=60)
 (D/'large-server.json').write_text(json.dumps(serverNext));(D/'large-server.json').chmod(0o600)
 sp.run(['ssh','-S',sock,host,'gzip -dc > '+nextbin],input=gzip.compress((D/'next').read_bytes()),check=True);ssh('chmod 755 '+nextbin)
 sp.run(['scp','-q','-o','ControlPath='+sock,str(D/'large-server.json'),host+':'+remote+'/next-config'],check=True)
 cert='/etc/letsencrypt/live/zlhk.fastcat.ink/'
 ssh('systemd-run --unit='+nextunit+' -p DynamicUser=yes -p NoNewPrivileges=yes -p RuntimeMaxSec=25m -p LoadCredential=cert:'+cert+'fullchain.pem -p LoadCredential=key:'+cert+'privkey.pem -p LoadCredential=config:'+remote+'/next-config '+nextbin+' -config '+nextcred+'/config');started.append(nextunit)
 cfg.update(NextAddress='191.223.214.8:19458',NextAccount=serverNext['Account'],NextSecret=serverNext['Secret'])
 (D/'large-client.json').write_text(json.dumps(cfg));(D/'large-client.json').chmod(0o600)
 a('push',str(D/'large-client.json'),ad+'/config');a('push',str(D/'compare-large'),ad+'/compare-large');a('shell','chmod','600',ad+'/config');a('shell','chmod','700',ad+'/compare-large')
 for size,budget in [(10<<20,90),(100<<20,240)]:
  (O/('large-'+str(size)+'-network-before.txt')).write_text(a('shell','dumpsys','connectivity'))
  with (O/('large-'+str(size)+'.stdout')).open('w') as out,(O/('large-'+str(size)+'.jsonl')).open('w') as err:
   sp.run(adb+['shell',ad+'/compare-large','-config',ad+'/config','-versions','v2-bbr,next','-download-bytes',str(size),'-download-rounds','1','-download-timeout',str(budget)+'s','-target','191.223.214.8:19454','-target-server-name','zlhk.fastcat.ink'],stdout=out,stderr=err,check=True,timeout=budget*3+60)
  (O/('large-'+str(size)+'-network-after.txt')).write_text(a('shell','dumpsys','connectivity'))
  print('Large transfer gate complete: '+str(size)+' bytes',flush=True)
 (O/'large-transfer-metadata.json').write_text(json.dumps(dict(compare_sha256=hashlib.sha256((D/'compare-large').read_bytes()).hexdigest(),server_sha256=hashlib.sha256((D/'next').read_bytes()).hexdigest(),profiles=['next/h2','v2-bbr/h3','next/quic'],sizes=[10<<20,100<<20],attempts_each=1,whole_download_deadlines_seconds=[90,240],no_automatic_retry=True,backend_cap_bytes=128<<20),indent=2))
finally:
 if stayon is not None:a('shell','settings','put','global','stay_on_while_plugged_in',stayon)
 if was_vpn and not connected():toggle()
 print('VPN restored: '+str(connected()),flush=True)
 if started:
  try:ssh('systemctl stop '+' '.join(started))
  except Exception:pass
 if created:
  for p in [binary,binary+'-next',remote+'/config',remote+'/backend.py',remote+'/next-config']:
   try:ssh('test ! -e '+p+' || unlink '+p)
   except Exception:pass
  try:ssh('rmdir '+remote)
  except Exception:pass
 try:a('shell','toybox','rm','-f',ad+'/config',ad+'/compare',ad+'/ca.pem',ad+'/compare-large');a('shell','rmdir',ad)
 except Exception:pass
 for p in [D/'sameport-server.json',D/'sameport-client.json',D/'large-client.json',D/'large-server.json']:p.unlink(missing_ok=True)
