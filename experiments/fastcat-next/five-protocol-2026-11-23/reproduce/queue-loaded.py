from pathlib import Path
import subprocess,time
B=Path('/tmp/fc-five');deadline=time.monotonic()+14400
while time.monotonic()<deadline:
 s=(B/'latency/run-base-resume.log').read_text()
 if 'FIVE LATENCY COMPLETE' in s:break
 if 'Traceback (most recent call last)' in s:raise SystemExit('Base resume failed; loaded suite not started')
 time.sleep(2)
else:raise SystemExit('base wait deadline')
with (B/'latency-loaded/run.log').open('w') as f:subprocess.run(['python3','-u',str(B/'run-loaded.py'),'latency-loaded'],stdout=f,stderr=subprocess.STDOUT,check=True)
print('ALL VALID SUITES COMPLETE',flush=True)
