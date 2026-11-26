import subprocess as sp,os,signal,time,json,hashlib
from pathlib import Path
D=Path('/tmp/fc-next-primary');O=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/primary-2026-11-22');parent=66068;paused=False
adb=['adb','-s','A3GMVB2110006859'];remote='/data/local/tmp/fc-primary-local-profile'
try:
 lines=sp.check_output(['ps','-Ao','pid,ppid,command'],text=True).splitlines();child=None
 for line in lines:
  a=line.strip().split(None,2)
  if len(a)==3 and a[1]==str(parent) and 'adb -s A3GMVB2110006859 shell /data/local/tmp/fc-opt-' in a[2]:child=int(a[0]);break
 if child is None:raise RuntimeError('No active cohort boundary available')
 os.kill(parent,signal.SIGSTOP);paused=True
 # Keep the active cohort running; do not add CPU load until its process exits.
 end=time.time()+1200
 while time.time()<end:
  try:state=sp.check_output(['ps','-p',str(child),'-o','stat='],text=True).strip()
  except sp.CalledProcessError:break
  if state.startswith('Z'):break
  time.sleep(3)
 else:raise RuntimeError('Active cohort did not finish in the diagnostic wait budget')
 sp.run(adb+['push',str(D/'android-profile'),remote],check=True,stdout=sp.DEVNULL)
 sp.run(adb+['shell','chmod','700',remote],check=True)
 with (O/'android-local-profile.txt').open('w') as f:
  r=sp.run(adb+['shell','env','FASTCAT_LOCAL_PROFILE=1',remote,'-test.run=^TestLocalPrimarySamplerCost$','-test.v'],stdout=f,stderr=sp.STDOUT,timeout=240)
 (O/'local-profile-metadata.json').write_text(json.dumps(dict(kind='Android loopback, separate from WAN scores',exit_code=r.returncode,sha256=hashlib.sha256((D/'android-profile').read_bytes()).hexdigest()),indent=2));print('ANDROID LOCAL PROFILE COMPLETE',r.returncode,flush=True)
finally:
 sp.run(adb+['shell','rm','-f',remote],stdout=sp.DEVNULL,stderr=sp.DEVNULL)
 if paused:
  try:os.kill(parent,signal.SIGCONT)
  except ProcessLookupError:pass
  print('Public comparison resumed',flush=True)
