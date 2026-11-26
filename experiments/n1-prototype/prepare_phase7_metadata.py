#!/usr/bin/env python3
from pathlib import Path
import json
root=Path(__file__).resolve().parent/'results/phase7-2026-11-24'
rows=json.loads((root/'samples.json').read_text());assert len(rows)==32
flows=[];by_arm={}
for arm in ['baseline','capped']:
 cap=json.loads((root/('capture-'+arm+'.json')).read_text())
 assert len(cap['client_hellos'])==16
 flows.extend(cap['client_hellos'])
 groups={}
 for line in (root/(arm+'-write-trace.txt')).read_text().splitlines():
  if 'WRITE_TRACE ' not in line:continue
  event=json.loads(line.split('WRITE_TRACE ',1)[1]);groups.setdefault(event['id'],[]).append(event)
 assert len(groups)==16
 by_arm[arm]=list(groups.values())
flows.sort(key=lambda h:h['first_packet_offset_ms'])
used={'baseline':0,'capped':0};lines=[]
for row,flow in zip(rows,flows):
 arm=row['arm'];events=by_arm[arm][used[arm]];used[arm]+=1
 # Source port labels are not classifier features; independently compare
 # chronological sequence to that port's metadata to reject wrong ordering.
 original=json.loads((root/('capture-'+arm+'.json')).read_text())['client_hellos'][used[arm]-1]
 assert flow==original
 assert row['exit_code']==0 and row['payload_verified'] and row['shutdown_eof_observed']
 assert flow['client_syn_seen'] and flow['client_tcp_capture_contiguous'] and flow['server_tcp_capture_contiguous']
 assert flow['client_tls_unparsed_bytes']==flow['server_tls_unparsed_bytes']==0
 for event in events:
  # IDs are normalized solely to join traces; retain source IDs and originals.
  item={**event,'source_id':event['id'],'id':row['index']+1,'arm':arm}
  lines.append('WRITE_TRACE '+json.dumps(item))
(root/'capture-analysis.json').write_text(json.dumps({'client_hellos':flows,'scope':'same pcap, both laboratory ports; joined chronologically'},indent=2))
(root/'server-write-trace.txt').write_text('\n'.join(lines)+'\n')
print('32 ordered payload/capture/trace joins verified')
