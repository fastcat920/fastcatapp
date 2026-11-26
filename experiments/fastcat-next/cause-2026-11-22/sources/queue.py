from pathlib import Path
import time,json,subprocess as sp,shutil
D=Path('/tmp/fc-next-cause')
while 'CAUSE COMPLETE' not in (D/'run.log').read_text():
 if 'Traceback' in (D/'run.log').read_text():raise RuntimeError('diagnostic run failed')
 time.sleep(2)
assert 'FAIL' not in (D/'race-prefix.txt').read_text()
shutil.copy2(D/'compare-prefix',D/'compare');shutil.copy2(D/'next-prefix',D/'next-diagnostic')
with (D/'prefix.log').open('w') as f:sp.run(['python3',str(D/'prefix.py')],check=True,stdout=f,stderr=sp.STDOUT)
print('DIAGNOSTICS COMPLETE',flush=True)
