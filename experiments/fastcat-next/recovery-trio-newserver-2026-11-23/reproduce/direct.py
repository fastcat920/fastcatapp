import sys,json,subprocess
from pathlib import Path
sys.path.insert(0,'/tmp/fc-new-trio');import lab
from runtime_lab import RuntimeLab
D=Path('/tmp/fc-new-trio');O=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/recovery-trio-newserver-2026-11-23');lab.D=D;lab.OUT=O
with RuntimeLab('direct-control') as x:
 x.start();x.adb('push',str(D/'direct'),x.ad+'/direct');x.adb('shell','chmod','700',x.ad+'/direct')
 with (O/'direct-control.jsonl').open('w') as f:subprocess.run(x.adbbase+['shell',x.ad+'/direct',x.ad+'/ca.pem'],stdout=f,check=True,timeout=150)
 x.adb('shell','rm','-f',x.ad+'/direct')
