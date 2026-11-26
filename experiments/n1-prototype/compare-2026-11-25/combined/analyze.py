#!/usr/bin/env python3
from pathlib import Path
import json,statistics,collections,math
root=Path(__file__).resolve().parent
rows=json.loads((root/'samples.json').read_text());batches=json.loads((root/'batches.json').read_text())
def quant(v,p):
 if not v:return None
 v=sorted(v);i=(len(v)-1)*p;lo=math.floor(i);hi=math.ceil(i);return round(v[lo]+(v[hi]-v[lo])*(i-lo),3)
def stats(v):return {'n':len(v),'p50':quant(v,.5),'p95':quant(v,.95),'mean':round(statistics.mean(v),3) if v else None,'min':min(v) if v else None,'max':max(v) if v else None}
result={}
for proto in ['n1','hysteria2','tuic']:
 v=[x for x in rows if x['protocol']==proto];r={'completed':len(v),'success':sum(x['success'] for x in v),'failures':[x for x in v if not x['success']],'cleanup_errors':[x for x in v if x.get('cleanup_error')],'network_valid':all(x['network_valid'] for x in v)}
 for index,label in enumerate(['cold','warm','concurrent','download_single','download_4','upload']):
  group=[x for x in v if x['phase_index']==index];good=[x for x in group if x['success']];reused=[x for x in good if not x['first_in_batch']] if label=='warm' else good
  s={'success':len(good),'total':len(group),'first_byte_ms':stats([x['first_byte_ms'] for x in reused]),'total_ms':stats([x['total_ms'] for x in reused]),'entry_ms':stats([x['entry_ms'] for x in reused]),'e2e_mbps':stats([x['e2e_mbps'] for x in good]),'cleanup_ms':stats([x['cleanup_ms'] for x in good]),'per_block':[]}
  if label=='warm':s['first_sample_first_byte_ms']=[x['first_byte_ms'] for x in good if x['first_in_batch']]
  for b in [x for x in batches if x['protocol']==proto and x['phase_index']==index]:
   samples=[x for x in group if x['batch']==b['batch']];success_bytes=sum(x['bytes'] for x in samples if x['success']);agg=success_bytes*8/(b['elapsed_ms']/1000)/1e6 if b.get('elapsed_ms') else None
   timed=[x for x in samples if 'start_unix_ms' in x and 'total_ms' in x];span=max((x['start_unix_ms']+x['total_ms'] for x in timed),default=0)-min((x['start_unix_ms'] for x in timed),default=0);payload_agg=success_bytes*8/span/1000 if span>0 else None
   s['per_block'].append({'payload_makespan_ms':span,'payload_aggregate_mbps':payload_agg,'block':b['block'],'success':sum(x['success'] for x in samples),'total':len(samples),'elapsed_ms':b.get('elapsed_ms'),'aggregate_verified_mbps':agg,'first_byte_p50_ms':quant([x['first_byte_ms'] for x in samples if x['success'] and (label!='warm' or not x['first_in_batch'])],.5)})
  s['payload_aggregate_mbps']=stats([x['payload_aggregate_mbps'] for x in s['per_block'] if x['payload_aggregate_mbps'] is not None]);s['batch_aggregate_mbps']=stats([x['aggregate_verified_mbps'] for x in s['per_block'] if x['aggregate_verified_mbps'] is not None]);r[label]=s
 resources=[]
 for b in [x for x in batches if x['protocol']==proto]:
  label='%02d-%s-%s-w%d-b%d'%(b['batch'],proto,b['phase'],b['workers'],b['block']);f=root/'raw'/(label+'-resources.jsonl')
  if f.exists():resources.extend(json.loads(x) for x in f.read_text().splitlines() if x.startswith('{'))
 r['client_resources']={'sample_rows':len(resources),'peak_rss_mib':round(max((x.get('rss_kib',0) for x in resources),default=0)/1024,2),'peak_heap_mib':round(max((x['heap_alloc'] for x in resources),default=0)/1048576,2),'peak_fds':max((x['fd_count'] for x in resources),default=0),'peak_goroutines':max((x['goroutines'] for x in resources),default=0)}
 result[proto]=r
(root/'summary.json').write_text(json.dumps(result,indent=2))
print(json.dumps({k:{'success':v['success'],'total':v['completed'],'cold':v['cold']['first_byte_ms'],'warm':v['warm']['first_byte_ms'],'single_mbps':v['download_single']['e2e_mbps'],'four_mbps':v['download_4']['batch_aggregate_mbps'],'upload':v['upload']['e2e_mbps']} for k,v in result.items()},indent=2))
