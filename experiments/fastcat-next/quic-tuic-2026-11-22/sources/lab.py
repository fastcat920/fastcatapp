import subprocess as sp,os,time,json,gzip,secrets,uuid,hashlib,threading
from pathlib import Path
ROOT=Path('/Users/pizihu/Projects/FastCatAPP');D=Path('/tmp/fc-next-tuic');OUT=ROOT/'experiments/fastcat-next/quic-tuic-2026-11-22';OUT.mkdir(parents=True,exist_ok=True)
class Lab:
 def __init__(self,name,full=False,trace=False):
  self.name=name;self.full=full;self.trace=trace;self.stamp=str(int(time.time()));self.remote='/run/fc-opt-'+self.stamp;self.units=[];self.files=[];self.bins=[];self.private=[];self.created=False;self.was_vpn=False;self.stayon=None;self.ad='/data/local/tmp/fc-opt-'+self.stamp;self.sock=os.path.expanduser('~/.ssh/fastcat-v2-test.sock');self.host='root@zlhk.fastcat.ink';self.adbbase=['adb','-s','A3GMVB2110006859'];self.monitor_stop=threading.Event();self.monitor=None
 def __enter__(self):return self
 def ssh(self,c):return sp.check_output(['ssh','-S',self.sock,'-o','ConnectTimeout=10',self.host,c],text=True,timeout=60)
 def adb(self,*a):return sp.check_output(self.adbbase+list(a),text=True,timeout=30)
 def connected(self):return 'ni{VPN CONNECTED' in self.adb('shell','dumpsys','connectivity')
 def toggle(self):
  self.adb('shell','input','keyevent','KEYCODE_WAKEUP');self.adb('shell','input','keyevent','82');self.adb('shell','am','start','-n','com.fastcat.app.debug/com.fastcat.app.MainActivity');time.sleep(1);self.adb('shell','input','tap','100','2235');time.sleep(1);self.adb('shell','input','tap','540','1220');time.sleep(3)
 def privatefile(self,name,data):
  p=D/(name+'-'+self.stamp+'.json');p.write_text(json.dumps(data));p.chmod(0o600);self.private.append(p);return p
 def uploadfile(self,p,name):
  target=self.remote+'/'+name;sp.run(['scp','-q','-o','ControlPath='+self.sock,str(p),self.host+':'+target],check=True);self.files.append(target);return target
 def uploadbin(self,source,name):
  path='/usr/local/bin/fc-opt-'+name+'-'+self.stamp;sp.run(['ssh','-S',self.sock,self.host,'gzip -dc > '+path],input=gzip.compress(Path(source).read_bytes()),check=True);self.ssh('chmod 755 '+path);self.bins.append(path);return path
 def service(self,name,source,cfg,kind='json'):
  unit='fc-opt-'+name+'-'+self.stamp;cred='/run/credentials/'+unit+'.service';cfg=dict(cfg);cfg.update(Cert=cred+'/cert',Key=cred+'/key');path=self.uploadfile(self.privatefile(name,cfg),name);binary=self.uploadbin(source,name);cert='/etc/letsencrypt/live/zlhk.fastcat.ink/'
  args=('-config '+cred+'/config') if kind=='next' else cred+'/config'
  self.ssh('systemd-run --unit='+unit+' -p DynamicUser=yes -p NoNewPrivileges=yes -p RuntimeMaxSec=150m -p LoadCredential=cert:'+cert+'fullchain.pem -p LoadCredential=key:'+cert+'privkey.pem -p LoadCredential=config:'+path+' '+binary+' '+args);self.units.append(unit);return unit
 def start(self):
  ports=self.ssh('ss -H -lntu');testports=[19440,19442,19444,19445,19446,19448,19450,19451,19452,19454,19456,19457,19458]
  if any(':'+str(p)+' ' in ports for p in testports):raise RuntimeError('A lab port is already occupied')
  self.was_vpn=self.connected();self.ssh('mkdir -m 700 '+self.remote);self.created=True
  token=secrets.token_hex(32);secret=secrets.token_hex(32);account='lab-'+secrets.token_hex(8)
  self.cfg=dict(V2Address='191.223.214.8:19442',V2BBRAddress='191.223.214.8:19440',NextAddress='191.223.214.8:19458',NextAccount=account,NextSecret=secret,ServerName='zlhk.fastcat.ink',V2Token=token,CA=self.ad+'/ca.pem',BulkTLSName='zlhk.fastcat.ink')
  backend=self.uploadfile(D/'backend.py','backend.py');unit='fc-opt-backend-'+self.stamp;self.ssh('systemd-run --unit='+unit+' -p RuntimeMaxSec=150m -p NoNewPrivileges=yes /usr/bin/python3 '+backend);self.units.append(unit)
  self.nextunit=self.service('next',D/'next-diagnostic',dict(Listen='0.0.0.0:19458',Account=account,Secret=secret,Congestion='bbr',Trace=self.trace),kind='next')
  if self.full:
   uid=str(uuid.uuid4());password=secrets.token_hex(32)
   self.service('xray','/tmp/fc-seven-way/xray-lab',dict(UUID=uid,Password=password,VlessPort=19446,TrojanPort=19448,HysteriaPort=19450,TuicPort=19451,AnyPort=19452))
   self.cfg.update(VlessAddress='191.223.214.8:19446',TrojanAddress='191.223.214.8:19448',HysteriaAddress='191.223.214.8:19450',TuicAddress='191.223.214.8:19451',AnyAddress='191.223.214.8:19452',UUID=uid,TrojanPassword=password,HysteriaPassword=password,TuicUUID=uid,AnyPassword=password)
  self.adb('shell','mkdir','-p',self.ad);self.adb('shell','chmod','700',self.ad)
  for source,name in [(D/'compare','compare'),(self.privatefile('client',self.cfg),'config'),(Path('/etc/ssl/cert.pem'),'ca.pem')]:self.adb('push',str(source),self.ad+'/'+name)
  self.adb('shell','chmod','700',self.ad+'/compare');self.adb('shell','chmod','600',self.ad+'/config')
  if self.was_vpn:self.toggle()
  if self.connected():raise RuntimeError('VPN did not disconnect')
  self.stayon=self.adb('shell','settings','get','global','stay_on_while_plugged_in').strip();self.adb('shell','svc','power','stayon','usb');self.starttime=time.time()
 def phase(self,name,args,versions,timeout=3000,bulk=False):
  (OUT/(name+'-network-before.txt')).write_text(self.adb('shell','dumpsys','connectivity'))
  with (OUT/(name+'.stdout' if bulk else name+'.jsonl')).open('w') as o,(OUT/(name+'.jsonl' if bulk else name+'.log')).open('w') as e:
   sp.run(self.adbbase+['shell',self.ad+'/compare','-config',self.ad+'/config','-versions',versions]+args,stdout=o,stderr=e,check=True,timeout=timeout)
  (OUT/(name+'-network-after.txt')).write_text(self.adb('shell','dumpsys','connectivity'));print('COMPLETE '+name,flush=True)
 def monitor_tcp(self):
  def run():
   with (OUT/(self.name+'-tcp.jsonl')).open('w') as f:
    while not self.monitor_stop.is_set():
     try:r=self.ssh("ss -tinm '( sport = :19458 or sport = :19442 or sport = :19454 )'");f.write(json.dumps(dict(unix=time.time(),ss=r))+'\n');f.flush()
     except Exception:pass
     self.monitor_stop.wait(1)
  self.monitor=threading.Thread(target=run,daemon=True);self.monitor.start()
 def __exit__(self,*exc):
  self.monitor_stop.set()
  if self.monitor:self.monitor.join(timeout=5)
  if self.trace and hasattr(self,'nextunit'):
   try:(OUT/(self.name+'-server.jsonl')).write_text(self.ssh('journalctl -u '+self.nextunit+' --no-pager -o cat'))
   except Exception:pass
  if self.stayon is not None:self.adb('shell','settings','put','global','stay_on_while_plugged_in',self.stayon)
  try:
   if self.was_vpn and not self.connected():self.toggle()
   print('VPN restored: '+str(self.connected()),flush=True)
  except Exception:pass
  if self.units:
   try:self.ssh('systemctl stop '+' '.join(self.units))
   except Exception:pass
  if self.created:
   for p in self.files+self.bins:
    try:self.ssh('test ! -e '+p+' || unlink '+p)
    except Exception:pass
   try:self.ssh('rmdir '+self.remote)
   except Exception:pass
  try:self.adb('shell','toybox','rm','-f',self.ad+'/config',self.ad+'/compare',self.ad+'/ca.pem');self.adb('shell','rmdir',self.ad)
  except Exception:pass
  for p in self.private:p.unlink(missing_ok=True)
  if hasattr(self,'lightdir'):self.lightdir.rmdir()
