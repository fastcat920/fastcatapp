import json,math,statistics,csv
from pathlib import Path
O=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/wire-2026-11-22')
def read(p):
 r=[]
 if not p.exists():return r
 for l in p.read_text().splitlines():
  try:v=json.loads(l)
  except:continue
  if isinstance(v,dict):r.append(v)
 return r
R=[];packetRows=[];features=[]
for f in sorted(O.glob('*-b*-p*.jsonl')):
 name=f.stem;condition=name.split('-b')[0];client=read(f)+read(O/(name+'.log'));server=read(O/(name+'-server.log'))
 for r in client:
  if r.get('phase') in ['cold','warm','batch']:
   r.update(source=name,condition=condition);R.append(r)
 for e in server:
  if e.get('stage')=='server_features':features.append(dict(source=name,condition=condition,gso=e.get('gso')))
 pairs={}
 for r in client:
  t=r.get('transport_tls')
  if not t:continue
  tag=t.get('request_tag');se=next((e for e in server if e.get('request_tag')==tag and e.get('stage')=='server_target_dial'),None)
  if se:pairs[se['session']]=t['session']
 sent={};received=set()
 for e in server:
  if e.get('stage')=='server_stream_prefix_sent':
   key=(e['session'],e.get('packet_space'),e.get('packet',0));sent[key]=e
 for e in client:
  if e.get('stage')=='client_stream_prefix_received':received.add((e['session'],e.get('packet_space'),e.get('packet',0)))
 for key,e in sent.items():
  cs=pairs.get(key[0])
  if cs is None:continue
  matched=(cs,key[1],key[2]) in received
  packetRows.append(dict(source=name,condition=condition,session=key[0],packet=key[2],space=key[1],packet_bytes=e.get('packet_bytes',0),received=matched,frame_offset=e.get('frame_offset',0),frame_length=e.get('frame_length',0)))
def p(a,q):return sorted(a)[math.ceil(len(a)*q)-1] if a else None
S={}
for c in ['default','no-gso','fixed1200','no-gso-fixed1200']:
 a=[r for r in R if r['condition']==c and r['phase']=='warm'];good=[r for r in a if not r.get('error') and r.get('first_byte_us',0)>0];packets=[r for r in packetRows if r['condition']==c];missing=[r for r in packets if not r['received']];obs=[r.get('transport_tls') or {} for r in good]
 S[c]=dict(warm_success=len(good),warm_total=len(a),p50_ms=p([r['first_byte_us']/1000 for r in good],.5),p95_ms=p([r['first_byte_us']/1000 for r in good],.95),status_p95_ms=p([r.get('status_wait_us',0)/1000 for r in obs],.95),gso_values=sorted(set(e['gso'] for e in features if e['condition']==c and e['gso'] is not None)),prefix_packets=len(packets),prefix_packets_unobserved=len(missing),sender_sizes=sorted(set(r['packet_bytes'] for r in packets)),unobserved_sizes=sorted(set(r['packet_bytes'] for r in missing)))
(O/'summary.json').write_text(json.dumps(S,indent=2));(O/'requests.json').write_text(json.dumps(R,indent=2));(O/'prefix-packets.json').write_text(json.dumps(packetRows,indent=2))
with (O/'prefix-packets.csv').open('w') as f:
 if packetRows:w=csv.DictWriter(f,list(packetRows[0]));w.writeheader();w.writerows(packetRows)
for c,s in S.items():print(c,{k:s[k] for k in ['warm_total','p50_ms','p95_ms','status_p95_ms','gso_values','prefix_packets','prefix_packets_unobserved']},'missing sizes',s['unobserved_sizes'][:25])
