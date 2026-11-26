#!/usr/bin/env python3
from pathlib import Path
import subprocess,json,random,time,sys
root=Path(__file__).resolve().parent/"throughput-recheck"
sys.path.insert(0,str(root.parent.parent));from phone_network import state
plan=json.loads((root/'plan.json').read_text());rng=random.Random(plan['seed']);jobs=[]
for phase_index,work in enumerate(plan['per_block']):
 order=plan['protocols'][:];rng.shuffle(order)
 for block in range(plan['blocks']):
  rotated=order[block:]+order[:block]
  for position,proto in enumerate(rotated):jobs.append({**work,'protocol':proto,'block':block+1,'position':position+1,'phase_index':phase_index})
# Keep measurement classes grouped; rotate protocol position in each class/block.
(root/'declaration.json').write_text(json.dumps({'jobs':jobs,'created_unix':time.time()},indent=2))
records=[];batches=[]
for index,job in enumerate(jobs):
 if (root/'STOP').exists():raise SystemExit('stopped between blocks for preflight diagnosis')
 label='%02d-%s-%s-w%d-b%d'%(index+1,job['protocol'],job['phase'],job['workers'],job['block']);before=state()
 if before['transport']!='wifi' or not before['validated']:raise SystemExit('network changed; stop before '+label)
 metrics='/data/local/tmp/fastcat-n1-lab/threeway-recheck-metrics-'+str(index)+'.jsonl'
 args=['adb','-s','A3GMVB2110006859','shell','/data/local/tmp/fastcat-n1-lab/threeway','-mode','compare','-kind',job['protocol'],'-config','/data/local/tmp/fastcat-n1-lab/threeway-'+job['protocol']+'.json','-target','127.0.0.1:18476','-bench-phase',job['phase'],'-bytes',str(job['bytes']),'-count',str(job['count']),'-workers',str(job['workers']),'-metrics-file',metrics]
 stamp=time.time();r=subprocess.run(args,capture_output=True,text=True,timeout=45*((job['count']+job['workers']-1)//job['workers'])+35);end=time.time();after=state();raw=root/'raw';raw.mkdir(exist_ok=True);(raw/(label+'.jsonl')).write_text(r.stdout);(raw/(label+'.stderr.txt')).write_text(r.stderr)
 objects=[json.loads(x) for x in r.stdout.splitlines() if x.startswith('{')];rows=[x for x in objects if 'sample' in x];found={x['sample'] for x in rows}
 for missing in set(range(1,job['count']+1))-found:rows.append({'sample':missing,'success':False,'error_stage':'missing-row','protocol':job['protocol'],'phase':job['phase'],'bytes':job['bytes']})
 matched=after['transport']=='wifi' and after['validated']
 for row in rows:records.append({**row,'block':job['block'],'position':job['position'],'workers':job['workers'],'phase_index':job['phase_index'],'batch':index+1,'network_valid':matched,'first_in_batch':row['sample']==1})
 pull=subprocess.run(['adb','-s','A3GMVB2110006859','shell','cat',metrics],capture_output=True,text=True);(raw/(label+'-resources.jsonl')).write_text(pull.stdout)
 batch=next((x for x in objects if x.get('event')=='batch-ended'),{});batches.append({**job,**batch,'batch':index+1,'start_unix':stamp,'end_unix':end,'network_before':before,'network_after':after,'exit_code':r.returncode})
 (root/'samples.json').write_text(json.dumps(records,indent=2));(root/'batches.json').write_text(json.dumps(batches,indent=2));print(label,'success',sum(x.get('success',False) for x in rows),'/',len(rows),'wall_s',round(end-stamp,2),flush=True)
 if not matched:raise SystemExit('network changed during '+label)
print('ALL MAIN COMPARISON BLOCKS FINISHED',flush=True)
