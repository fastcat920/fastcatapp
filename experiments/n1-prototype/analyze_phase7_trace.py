#!/usr/bin/env python3
"""Align bounded plaintext write metadata to full encrypted TLS records."""
from pathlib import Path
from collections import Counter
import json,sys
root=Path(__file__).resolve().parent/'results/phase7-2026-11-24'
rows=json.loads((root/'samples.json').read_text());capture=json.loads((root/'capture-analysis.json').read_text())['client_hellos']
groups={}
for line in (root/'server-write-trace.txt').read_text().splitlines():
 if 'WRITE_TRACE ' not in line:continue
 item=json.loads(line.split('WRITE_TRACE ',1)[1]);groups.setdefault(item['id'],[]).append(item)
assert len(groups)==len(rows)==len(capture)==32
counts={};out=[]
for row,flow,events in zip(rows,capture,groups.values()):
 assert events[0]['kind']==row['kind'] and all(e['kind']==row['kind'] for e in events)
 encrypted=[r['length'] for r in flow['server_tls_records'] if r['type']==23]
 # Go TLS1.3 fixture: four protected handshake records precede handler output;
 # the final 2-byte close alert encrypts to 19 bytes. Validate alignment, rather
 # than assigning every short record to a protocol message.
 assert len(encrypted)>=5 and encrypted[-1]==19
 app=encrypted[4:-1];index=0;stages=[]
 for event in events:
  plain=event['plain_bytes'];parts=[];total=0
  while total<plain:
   assert index<len(app),'missing TLS application record'
   length=app[index];assert length>17
   parts.append(length);total+=length-17;index+=1
  assert total==plain,'write boundary does not align; refuse attribution'
  stage=event['stage'];small=sum(n<=256 for n in parts)
  key=row['arm']+'/'+stage;v=counts.setdefault(key,dict(writes=0,small_records=0,records=0,plaintext_bytes=[],small_whole_write_records=0,small_fragment_records=0,over_16k_writes=0,over_16k_small_records=0,fragment_examples=[]))
  v['writes']+=1;v['small_records']+=small;v['records']+=len(parts);v['plaintext_bytes'].append(plain)
  v['small_whole_write_records']+=small if plain<=239 else 0
  v['small_fragment_records']+=small if plain>239 else 0
  v['over_16k_writes']+=plain>16384
  v['over_16k_small_records']+=small if plain>16384 else 0
  if row['arm']=='capped':assert plain<=16384, 'capped complete write overflow'
  if small and plain>239 and len(v['fragment_examples'])<6:v['fragment_examples'].append(dict(plaintext_bytes=plain,encrypted_lengths=parts))
  stages.append(dict(stage=stage,plain_bytes=plain,encrypted_lengths=parts))
 assert index==len(app),'unattributed app record'
 out.append(dict(index=row['index'],pair=row['pair'],kind=row['kind'],arm=row['arm'],stages=stages,handshake_small_records=sum(n<=256 for n in encrypted[:4]),closing_small_records=1))
for value in counts.values():
 value['plaintext_range']=[min(value['plaintext_bytes']),max(value['plaintext_bytes'])];del value['plaintext_bytes']
result=dict(flows=len(out),stage_totals=counts,attribution_scope='Validated Go TLS1.3 laboratory fixture and +17 byte overhead; no decryption, not a general traffic parser',flows_detail=out)
(root/'trace-analysis.json').write_text(json.dumps(result,indent=2));print(json.dumps(dict(flows=len(out),stage_totals=counts),indent=2))
