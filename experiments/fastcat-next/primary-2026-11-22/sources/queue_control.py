import time,subprocess,os
from pathlib import Path
p=Path('/tmp/fc-next-primary/run.log')
while 'PRIMARY COMPLETE' not in p.read_text():
 try:os.kill(66068,0)
 except ProcessLookupError:raise RuntimeError('Primary run did not complete; inspect before controlled follow-up')
 time.sleep(5)
subprocess.run(['python3','/tmp/fc-next-primary/control.py'],check=True)
