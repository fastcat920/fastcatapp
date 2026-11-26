import time,subprocess as sp,json,shutil
from pathlib import Path
D=Path('/tmp/fc-next-latency');log=D/'stage12.log'
while 'COMPLETE stage12' not in log.read_text():
 if 'Traceback' in log.read_text():raise RuntimeError('stage12 harness failed')
 time.sleep(2)
sp.run(['python3',str(D/'analyze.py'),'stage12'],check=True,stdout=(D/'summary12.json').open('w'))
s=json.loads((D/'summary12.json').read_text());assert not s['gate']['next-latency']['passed']
race=(D/'race-stage34.txt').read_text();assert 'FAIL' not in race and 'ok  ' in race
shutil.copy2(D/'compare34',D/'compare')
with (D/'stage34.log').open('w') as f:sp.run(['python3',str(D/'bench.py'),'stage34'],check=True,stdout=f,stderr=sp.STDOUT)
print('ALL PHASES FINISHED',flush=True)
