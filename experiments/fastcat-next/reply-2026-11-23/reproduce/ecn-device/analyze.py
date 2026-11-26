import json,math,collections
from pathlib import Path
O=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/reply-2026-11-23/ecn-device');R=[];summary={}
def read(p):
 a=[]
 if not p.exists():return a
 for l in p.read_text().splitlines():
  try:r=json.loads(l)
  except:continue
  if isinstance(r,dict):a.append(r)
 return a
def p(a,q):return sorted(a)[math.ceil(len(a)*q)-1] if a else None
for c in ['android-default','android-noecn','mac-default','mac-noecn']:
 a=[];events=[];server=[]
 for f in O.glob(c+'-b*-p*.jsonl'):
  rr=read(f);a += [dict(r,source=f.stem,condition=c) for r in rr if r.get('phase') in ['warm','cold']];events+=rr+read(O/(f.stem+'.log'));server+=read(O/(f.stem+'-server.log'))
 R+=a;warm=[r for r in a if r.get('phase')=='warm'];good=[r for r in warm if not r.get('error') and r.get('first_byte_us',0)>0]
 summary[c]=dict(warm_samples=len(warm),success=len(good),p50_ms=p([r['first_byte_us']/1000 for r in good],.5),p95_ms=p([r['first_byte_us']/1000 for r in good],.95),status_p95_ms=p([r['transport_tls']['status_wait_us']/1000 for r in good if r.get('transport_tls')],.95),client_drops=dict(collections.Counter(e.get('drop_reason') for e in events if e.get('stage')=='client_packet_dropped')),server_drops=dict(collections.Counter(e.get('drop_reason') for e in server if e.get('stage')=='server_packet_dropped')),server_ecn_states=dict(collections.Counter(e.get('ecn_state') for e in server if e.get('stage')=='server_ecn_state')),server_sent_marks=dict(collections.Counter(e.get('ecn_mark','unsupported') for e in server if e.get('stage')=='server_stream_prefix_sent')),client_received_marks=dict(collections.Counter(e.get('ecn_mark','unsupported') for e in events if e.get('stage')=='client_stream_prefix_received')))
(O/'summary.json').write_text(json.dumps(summary,indent=2));(O/'requests.json').write_text(json.dumps(R,indent=2));print(json.dumps(summary,indent=2))
