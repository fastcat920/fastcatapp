import json,math,collections
from pathlib import Path
O=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/queue-2026-11-23/stage12/mechanism')
def read(p):
 out=[]
 for l in p.read_text().splitlines():
  try:r=json.loads(l)
  except:continue
  if isinstance(r,dict):out.append(r)
 return out
def pct(a,q):return sorted(a)[math.ceil(len(a)*q)-1] if a else None
R=[];S={}
proofs=json.loads((O/'proofs.json').read_text());pm={(p['source'],p['request_tag']):p for p in proofs}
for f in O.glob('*-b*-p*.jsonl'):
 variant='budget' if '-budget-' in f.stem else 'baseline';events=read(O/(f.stem+'-server.log'));q=collections.defaultdict(dict)
 for e in events:
  tag=e.get('request_tag')
  if tag:q[tag].setdefault(e.get('stage'),e)
 for r in read(f):
  if r.get('phase')!='mixed' or not r.get('transport_tls'):continue
  t=r['transport_tls'];tag=t.get('request_tag');ev=q[tag];ready=ev.get('download_first_data_ready');accepted=ev.get('download_first_write_accepted');dial=ev.get('server_target_dial');end=ev.get('download_end');pr=pm.get((f.stem,tag),{});sent=[e['at_unix_us'] for e in events if dial and e.get('session')==dial.get('session') and e.get('stream',0)==dial.get('stream',0) and e.get('stage')=='server_stream_prefix_sent' and e.get('frame_offset',0)+e.get('frame_length',0)>1]
  R.append(dict(source=f.stem,variant=variant,tag=tag,first_ms=r.get('first_byte_us',0)/1000,status_wait_ms=t.get('status_wait_us',0)/1000,tls_after_status_ms=max(0,t.get('at_unix_us',0)-t.get('status_end_us',0))/1000,response_ms=r.get('response_us',0)/1000,server_dial_ms=dial.get('duration_us',0)/1000 if dial else None,target_first_read_ms=ready.get('read_wait_us',0)/1000 if ready else None,first_write_wait_ms=accepted.get('write_wait_us',0)/1000 if accepted else None,first_packetize_wait_ms=(min(sent)-ready['at_unix_us'])/1000 if sent and ready else None,total_server_write_wait_ms=end.get('total_write_wait_us',0)/1000 if end else None,downstream_recovery=bool(pr.get('downstream_recovery')),status_recovery_at_unblock=bool(pr.get('status_recovery_at_unblock')),error=r.get('error')))
for v in ['baseline','budget']:
 a=[r for r in R if r['variant']==v];good=[r for r in a if not r['error']];slow=[r for r in good if r['first_ms']>=500];d=dict(requests=len(a),success=len(good),slow_ge500ms=len(slow),slow_with_downstream_recovery=sum(r['downstream_recovery'] for r in slow),slow_status_recovery=sum(r['status_recovery_at_unblock'] for r in slow))
 for k in ['first_ms','status_wait_ms','tls_after_status_ms','response_ms','server_dial_ms','target_first_read_ms','first_write_wait_ms','first_packetize_wait_ms']:
  vals=[r[k] for r in good if r[k] is not None];d[k]=dict(p50=pct(vals,.5),p95=pct(vals,.95))
 yields=[]
 for f in O.glob('*'+v+'*-server.log'):yields += [e for e in read(f) if e.get('stage')=='download_budget']
 d['budget_flows_yielded']=sum(e.get('budget_yields',0)>0 for e in yields);d['budget_total_yields']=sum(e.get('budget_yields',0) for e in yields)
 S[v]=d
(O/'stages.json').write_text(json.dumps(R,indent=2));(O/'stage-summary.json').write_text(json.dumps(S,indent=2));print(json.dumps(S,indent=2))
