import json,re,math,statistics,argparse
from collections import defaultdict,Counter
from pathlib import Path
parser=argparse.ArgumentParser(description='Summarize split v3 record write timings without credentials')
parser.add_argument('--client',type=Path,required=True)
parser.add_argument('--server',type=Path,required=True)
args=parser.parse_args()
def dist(v):
 v=sorted(v)
 if not v:return None
 return dict(p50_us=round(statistics.median(v),1),p95_us=v[math.ceil(len(v)*.95)-1],max_us=v[-1])
groups=defaultdict(list);flush=[]
for path in (args.client,args.server):
 for line in path.read_text().splitlines():
  if 'record_send ' not in line and 'carrier_flush ' not in line:continue
  fields=dict(re.findall(r'(\w+)=([^\s]+)',line))
  for k,v in list(fields.items()):
   if k.endswith('_us') or k in ('frames','bytes','kind','stream','session'):fields[k]=int(v)
  if 'record_send ' in line:groups[fields['role'],fields['carrier']].append(fields)
  else:flush.append(fields)
out=[]
for (role,carrier),rows in sorted(groups.items()):
 slow=[r for r in rows if r['total_us']>=20000]
 stages=['encode_us','lock_us','rotate_us','seal_us','write_us']
 for r in rows:r['other_us']=max(0,r['total_us']-sum(r[k] for k in stages))
 stages+=['other_us']
 out.append(dict(role=role,carrier=carrier,samples=len(rows),stages={k:dist([r[k] for r in rows]) for k in stages+['total_us']},slow_records=len(slow),slow_largest_component=dict(Counter(max(stages,key=lambda k:r[k]) for r in slow)),slowest=sorted(rows,key=lambda r:r['total_us'],reverse=True)[:6]))
result=dict(note='Wall-clock intervals. Lock includes scheduling pauses; write means local carrier API, not end-to-end delivery. Concurrent lock waits overlap and must not be summed as request latency.',groups=out,h2_server_flush=dict(samples=len(flush),stages={k:dist([r[k] for r in flush]) for k in ('buffer_us','flush_us')}))
print(json.dumps(result,indent=2))
