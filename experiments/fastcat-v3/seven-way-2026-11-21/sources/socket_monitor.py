import os,subprocess as sp,time,json
from pathlib import Path
D=Path('/tmp/fc-seven-way');ssh=['ssh','-S',os.path.expanduser('~/.ssh/fastcat-v2-test.sock'),'-o','ConnectTimeout=6','root@zlhk.fastcat.ink']
parent=None
for line in sp.check_output(['ps','-Ao','pid,command'],text=True).splitlines():
 if line.strip().endswith('/tmp/fc-seven-way/run.py'):parent=int(line.split()[0]);break
with (D/'tcp-socket-counts.jsonl').open('w') as f:
 for _ in range(720):
  if (D/'metadata.json').exists():break
  try:os.kill(parent,0)
  except (ProcessLookupError,TypeError):break
  try:
   text=sp.check_output(ssh+["ss -Htn state established '( sport = :19442 or sport = :19444 or sport = :19446 or sport = :19448 or sport = :19452 )'"],text=True,timeout=10)
   counts={str(p):0 for p in [19442,19444,19446,19448,19452]}
   for line in text.splitlines():
    fields=line.split()
    if len(fields)>=4:
     port=fields[2].rsplit(':',1)[-1]
     if port in counts:counts[port]+=1
   f.write(json.dumps({'at':time.time(),'established_tcp_counts':counts})+'\n');f.flush()
  except Exception:pass
  time.sleep(5)
print('TCP socket count monitor completed')
