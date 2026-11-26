import json,math,statistics,csv
from pathlib import Path
O=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/cause-2026-11-22')
clock=json.loads((O/'clocks.json').read_text());a=min(clock,key=lambda r:r['server_rtt_ns']);b=min(clock,key=lambda r:r['android_rtt_ns']);offset=(int(a['server_ns'])-a['server_local_mid_ns']-int(b['android_ns'])+b['android_local_mid_ns'])/1000;uncertainty=(a['server_rtt_ns']+b['android_rtt_ns'])/2000
rows=[];details=[]
def read(p):
 a=[]
 if not p.exists():return a
 for l in p.read_text().splitlines():
  try:r=json.loads(l)
  except:continue
  if isinstance(r,dict):a.append(r)
 return a
def pct(a,q):return sorted(a)[math.ceil(len(a)*q)-1] if a else None
for f in sorted(O.glob('*-b*-p*.jsonl')):
 if '-server' in f.name:continue
 name=f.stem;condition=name.split('-b')[0];R=read(f);server=read(O/(name+'-server.log'))
 for r in R:
  if r.get('phase') not in ['mixed','warm','cold','mixed_summary']:continue
  r.update(source=name,condition=condition);rows.append(r)
  if r.get('phase') not in ['mixed','warm','cold'] or not r.get('transport_tls'):continue
  begin=r['transport_before'];end=r['transport_tls'];final=r.get('transport_end',{});tag=end.get('request_tag');events=[e for e in server if e.get('request_tag')==tag];dial=next((e for e in events if e.get('stage')=='server_target_dial'),None);sid=dial.get('session') if dial else None
  lo=r['start_unix_us']+r['entry_us']+offset;hi=lo+r['target_tls_us'];samples=sorted([e for e in server if sid is not None and e.get('session')==sid and e.get('stage')=='server_quic_progress'],key=lambda e:e.get('at_unix_us',0))
  before=[e for e in samples if e.get('at_unix_us',0)<=lo-uncertainty];after=[e for e in samples if e.get('at_unix_us',0)>=hi+uncertainty];left=before[-1] if before else {};right=after[0] if after else {}
  dc={k:(right.get(k,0)-left.get(k,0) if right and left else None) for k in ['declared_lost','pto_events','blocked_sent','blocked_received','window_updates_sent','packets_sent']}
  bc=begin.get('counters') or {};ec=end.get('counters') or {}
  detail=dict(source=name,condition=condition,phase=r['phase'],worker=r.get('worker'),first_ms=r.get('first_byte_us',0)/1000,entry_ms=r['entry_us']/1000,target_tls_combined_ms=r['target_tls_us']/1000,status_read_wait_ms=end.get('status_wait_us',0)/1000,tls_minus_status_wait_ms=(r['target_tls_us']-end.get('status_wait_us',0))/1000,response_ms=r['response_us']/1000,request_tag=tag,client_session=end.get('session'),server_session=sid,server_dial_ms=dial.get('duration_us',0)/1000 if dial else None,client_pto_delta=ec.get('pto_events',0)-bc.get('pto_events',0),client_lost_delta=ec.get('declared_lost',0)-bc.get('declared_lost',0),client_blocked_delta=ec.get('blocked_sent',0)-bc.get('blocked_sent',0),client_cwnd_end=ec.get('cwnd_bytes'),client_inflight_end=ec.get('bytes_in_flight'),server_window_us=(right.get('at_unix_us',0)-left.get('at_unix_us',0) if left and right else None),**{'server_'+k+'_delta':v for k,v in dc.items()})
  details.append(detail)
summary={}
for condition in ['loaded-on','unloaded-on','loaded-off','unloaded-off']:
 phase='mixed' if condition.startswith('loaded') else 'warm';a=[r for r in rows if r['condition']==condition and r['phase']==phase and (phase!='mixed' or r.get('background_active',0)>0)];good=[r for r in a if not r.get('error') and r.get('first_byte_us',0)>0];d=[r for r in details if r['condition']==condition and r['phase']==phase];summary[condition]=dict(samples=len(a),success=len(good),p50_ms=pct([r['first_byte_us']/1000 for r in good],.5),p95_ms=pct([r['first_byte_us']/1000 for r in good],.95),max_ms=max([r['first_byte_us']/1000 for r in good],default=None),status_p95_ms=pct([r['status_read_wait_ms'] for r in d],.95),server_dial_max_ms=max([r['server_dial_ms'] for r in d if r['server_dial_ms'] is not None],default=None))
(O/'measurements.json').write_text(json.dumps(rows,indent=2));(O/'request-details.json').write_text(json.dumps(details,indent=2));(O/'summary.json').write_text(json.dumps(dict(clock_server_minus_android_us=offset,clock_uncertainty_us=uncertainty,conditions=summary),indent=2))
if details:
 with (O/'request-details.csv').open('w') as f:w=csv.DictWriter(f,list(details[0]));w.writeheader();w.writerows(details)
print(json.dumps(summary,indent=2));print('details',len(details),'joined',sum(r['server_session'] is not None for r in details))
