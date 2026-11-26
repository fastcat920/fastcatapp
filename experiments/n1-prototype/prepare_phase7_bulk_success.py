#!/usr/bin/env python3
"""Attribution on complete supplemental flows; failed flow stays in full data."""
from pathlib import Path
import json
base=Path(__file__).resolve().parent/'results/phase7-2026-11-24';out=base/'bulk-success';out.mkdir(exist_ok=True)
rows=json.loads((base/'bulk-samples.json').read_text());assert len(rows)==8 and rows[-1]['exit_code']!=0
flows={};groups={}
for arm in ['baseline','capped']:
 flows[arm]=json.loads((base/'bulk'/('capture-'+arm+'.json')).read_text())['client_hellos']
 assert len(flows[arm])==4
 g={}
 for line in (base/'bulk'/(arm+'-write-trace.txt')).read_text().splitlines():
  e=json.loads(line.split('WRITE_TRACE ',1)[1]);g.setdefault(e['id'],[]).append(e)
 assert len(g)==4;groups[arm]=list(g.values())
used={'baseline':0,'capped':0};kept=[];caps=[];lines=[]
for r in rows:
 arm=r['arm'];i=used[arm];used[arm]+=1
 if r['exit_code']!=0:continue
 assert r['payload_verified'] and r['shutdown_eof_observed']
 kept.append({**r,'pair':r['repeat']-1});caps.append(flows[arm][i])
 for e in groups[arm][i]:lines.append('WRITE_TRACE '+json.dumps({**e,'source_id':e['id'],'id':r['index']+1,'arm':arm}))
assert len(kept)==7
(out/'samples.json').write_text(json.dumps(kept,indent=2));(out/'capture-analysis.json').write_text(json.dumps({'client_hellos':caps},indent=2));(out/'server-write-trace.txt').write_text('\n'.join(lines)+'\n')
(out/'SCOPE.txt').write_text('Only seven complete supplemental flows used for write-to-record attribution. All eight attempts, including final baseline timeout, remain in parent bulk-samples.json and bulk-wire-summary.json. No success-rate computation is based on this subset.\n')
