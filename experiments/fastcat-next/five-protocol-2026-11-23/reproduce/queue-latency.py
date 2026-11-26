from pathlib import Path
import time,subprocess
D=Path('/tmp/fc-five');deadline=time.monotonic()+14400
while time.monotonic()<deadline:
 text=(D/'speed/run.log').read_text()
 if 'FIVE SPEED COMPLETE' in text:break
 if 'Traceback (most recent call last)' in text:raise SystemExit('Speed suite failed; latency not started')
 time.sleep(2)
else:raise SystemExit('Speed wait exceeded')
with (D/'latency/run.log').open('w') as f:subprocess.run(['python3','-u',str(D/'run.py'),'latency'],stdout=f,stderr=subprocess.STDOUT,check=True)
print('BOTH SUITES COMPLETE',flush=True)
