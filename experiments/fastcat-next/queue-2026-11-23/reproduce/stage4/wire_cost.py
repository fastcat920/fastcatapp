from pathlib import Path
import json
O=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/queue-2026-11-23/stage4/performance');S={}
for v in ['baseline','prefix']:
 d={}
 for phase in ['mixed_summary','parallel_download','rolling_download']:
  a=[]
  for f in O.glob('*'+v+'*-b*-p*.jsonl'):
   for l in f.read_text().splitlines():
    try:r=json.loads(l)
    except:continue
    if r.get('phase')==phase:a.append(r)
  usage=[r.get('lane_usage') or {} for r in a];verified=sum(r.get('verified_bytes',0) for r in a);rx=sum(x.get('live_wire_received',0) for x in usage)
  d[phase]=dict(groups=len(a),live_session_counts=[x.get('live_sessions',0) for x in usage],received_wire_bytes=rx,verified_business_bytes=verified,wire_per_business_byte=rx/verified if verified else None)
 S[v]=d
(O/'wire-cost.json').write_text(json.dumps(S,indent=2));print(json.dumps(S,indent=2))
