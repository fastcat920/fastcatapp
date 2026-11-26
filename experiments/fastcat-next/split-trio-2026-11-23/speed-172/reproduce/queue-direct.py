from pathlib import Path
import time,subprocess
D=Path('/tmp/fc-split-speed');deadline=time.monotonic()+7200
while time.monotonic()<deadline:
 text=(D/'run.log').read_text()
 if 'RECOVERY TRIO COMPLETE' in text:break
 if 'Traceback (most recent call last)' in text:raise SystemExit('Main suite failed; direct control not started')
 time.sleep(2)
else:raise SystemExit('Main wait deadline exceeded')
with (D/'direct.log').open('w') as f:subprocess.run(['python3','-u',str(D/'direct.py')],stdout=f,stderr=subprocess.STDOUT,check=True)
print('DIRECT CONTROL COMPLETE',flush=True)
