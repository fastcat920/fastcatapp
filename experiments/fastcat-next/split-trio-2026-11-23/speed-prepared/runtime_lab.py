import sys,json,shlex
from pathlib import Path
sys.path.insert(0,'/tmp/fc-split-speed');import lab
class RuntimeLab(lab.Lab):
 def service(self,name,source,cfg,kind='json'):
  unit='fc-opt-'+name+'-'+self.stamp;cred='/run/credentials/'+unit+'.service';cfg=dict(cfg);cfg.update(Cert=cred+'/cert',Key=cred+'/key');path=self.uploadfile(self.privatefile(name,cfg),name);binary=self.uploadbin(source,name);cert='/run/fc-trio-cert/'
  args=('-config '+cred+'/config') if kind=='next' else cred+'/config'
  body='[Unit]\nDescription=Isolated FastCat comparison\n[Service]\nType=simple\nDynamicUser=yes\nNoNewPrivileges=yes\nRuntimeMaxSec=150m\nLoadCredential=cert:'+cert+'fullchain.pem\nLoadCredential=key:'+cert+'privkey.pem\nLoadCredential=config:'+path+'\nExecStart='+binary+' '+args+'\n'
  unitfile='/run/systemd/system/'+unit+'.service'
  if not hasattr(self,'runtime_units'):self.runtime_units=[]
  self.runtime_units.append(unitfile);self.units.append(unit)
  code='import pathlib;p=pathlib.Path('+repr(unitfile)+');p.write_text('+repr(body)+');p.chmod(0o644)'
  self.ssh('python3 -c '+shlex.quote(code));self.ssh('systemctl daemon-reload');self.ssh('systemctl start '+unit);return unit
 def __exit__(self,*exc):
  try:super().__exit__(*exc)
  finally:
   for p in getattr(self,'runtime_units',[]):
    try:self.ssh('rm -f '+shlex.quote(p))
    except Exception:pass
   try:self.ssh('systemctl daemon-reload')
   except Exception:pass
