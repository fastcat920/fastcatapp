import json,csv,sys
from pathlib import Path
O=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/reply-2026-11-23/mechanism')
def read(p):
 out=[]
 if not p.exists():return out
 for line in p.read_text().splitlines():
  try:r=json.loads(line)
  except:continue
  if isinstance(r,dict):out.append(r)
 return out
results=[]
for f in sorted(O.glob('*-b*-p*.jsonl')):
 name=f.stem;R=read(f)+read(O/(name+'.log'));S=read(O/(name+'-server.log'))
 for r in R:
  if r.get('phase') not in ['mixed','warm','cold'] or not r.get('transport_tls'):continue
  t=r['transport_tls'];end=r.get('transport_end') or t;tag=t.get('request_tag');stream=t.get('stream',0);cs=t.get('session');dial=next((e for e in S if e.get('request_tag')==tag and e.get('stage')=='server_target_dial'),None)
  if not dial:continue
  ss=dial.get('session');c=[e for e in R if e.get('session')==cs and e.get('stream',0)==stream];s=[e for e in S if e.get('session')==ss and e.get('stream',0)==stream]
  def evidence(sentEvents,receivedEvents,lostEvents,ptoEvents,until):
   tx=sorted(sentEvents,key=lambda e:e['at_unix_us']);rx=[e for e in receivedEvents if e['at_unix_us']<=until+100000];rxkeys={(e.get('packet_space'),e.get('packet',0)) for e in rx};losskeys={(e.get('packet_space'),e.get('packet',0)) for e in lostEvents};proof=[]
   for i,a in enumerate(tx):
    ak=(a.get('packet_space'),a.get('packet',0));start=a.get('frame_offset',0);stop=start+a.get('frame_length',0)
    if ak in rxkeys:continue
    for b in tx[i+1:]:
     bk=(b.get('packet_space'),b.get('packet',0));bs=b.get('frame_offset',0);be=bs+b.get('frame_length',0)
     if bk==ak or bk not in rxkeys or max(start,bs)>=min(stop,be):continue
     lost=ak in losskeys;ptos=[e for e in ptoEvents if a['at_unix_us']<=e['at_unix_us']<=b['at_unix_us']+10000]
     if not lost and not ptos:continue
     arrived=next(e for e in rx if (e.get('packet_space'),e.get('packet',0))==bk)
     proof.append(dict(original_packet=ak[1],repeat_packet=bk[1],space=bk[0],overlap_start=max(start,bs),overlap_end=min(stop,be),original_declared_lost=lost,pto_between=bool(ptos),sender_repeat_after_ms=(b['at_unix_us']-a['at_unix_us'])/1000,receiver_at_us=arrived['at_unix_us']));break
   return proof
  stx=[e for e in s if e.get('stage')=='server_stream_prefix_sent'];crx=[e for e in c if e.get('stage')=='client_stream_prefix_received'];slost=[e for e in S if e.get('session')==ss and e.get('stage')=='server_stream_prefix_lost'];spto=[e for e in S if e.get('session')==ss and e.get('stage')=='server_pto_raised']
  downstream=evidence(stx,crx,slost,spto,end['at_unix_us'])
  ctx=[e for e in c if e.get('stage')=='client_stream_prefix_sent'];srx=[e for e in s if e.get('stage')=='server_stream_prefix_received'];clost=[e for e in R if e.get('session')==cs and e.get('stage')=='client_stream_prefix_lost'];cpto=[e for e in R if e.get('session')==cs and e.get('stage')=='client_pto_raised']
  # Receiver bound is in server time; avoid clock mixing for the upstream query.
  upstream=evidence(ctx,srx,clost,cpto,max([e.get('at_unix_us',0) for e in srx]+[0]))
  first_status=min([e['at_unix_us'] for e in crx if e.get('frame_offset',0)==0]+[10**30])
  status=[e for e in downstream if e['overlap_start']==0 and e['receiver_at_us']==first_status and t['status_start_us']<=first_status<=t['status_end_us'] and 0<=t['status_end_us']-first_status<=20000 and t['status_wait_us']>=1000]
  results.append(dict(source=name,phase=r['phase'],worker=r.get('worker'),request_tag=tag,stream=stream,client_session=cs,server_session=ss,first_ms=r['first_byte_us']/1000,status_wait_ms=t['status_wait_us']/1000,target_tls_combined_ms=r['target_tls_us']/1000,response_ms=r['response_us']/1000,server_dial_ms=dial.get('duration_us',0)/1000,downstream_recovery=downstream,upstream_recovery=upstream,status_recovery_at_unblock=status,client_meta_dropped=(end.get('counters') or {}).get('meta_dropped',0),server_meta_dropped=max([e.get('meta_dropped',0) for e in S if e.get('session')==ss]+[0])))
(O/'proofs.json').write_text(json.dumps(results,indent=2))
if results:
 with (O/'proofs.csv').open('w') as f:w=csv.DictWriter(f,list(results[0]));w.writeheader();w.writerows(results)
print(dict(requests=len(results),with_downstream_recovery=sum(bool(r['downstream_recovery']) for r in results),with_upstream_recovery=sum(bool(r['upstream_recovery']) for r in results),status_unblocked_on_recovery=sum(bool(r['status_recovery_at_unblock']) for r in results),meta_drops=sum(r['client_meta_dropped']+r['server_meta_dropped'] for r in results)))
for r in sorted([r for r in results if r['status_recovery_at_unblock']],key=lambda r:r['status_wait_ms'],reverse=True)[:3]:print(json.dumps(r))
