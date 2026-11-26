from pathlib import Path
import json,shutil
r=Path(__file__).resolve().parent;out=r/'combined';out.mkdir(exist_ok=True);(out/'raw').mkdir(exist_ok=True)
rows=[];batches=[]
for folder,blockoff,batchoff,phaseoff in [(r,0,0,0),(r/'throughput-recheck',3,54,3)]:
 rs=json.loads((folder/'samples.json').read_text());bs=json.loads((folder/'batches.json').read_text())
 for x in rs:rows.append({**x,'block':x['block']+blockoff,'batch':x['batch']+batchoff,'phase_index':x['phase_index']+phaseoff,'source':folder.name,'source_batch':x['batch']})
 for b in bs:
  new={**b,'block':b['block']+blockoff,'batch':b['batch']+batchoff,'phase_index':b['phase_index']+phaseoff,'source':folder.name,'source_batch':b['batch']};batches.append(new)
  before='%02d-%s-%s-w%d-b%d'%(b['batch'],b['protocol'],b['phase'],b['workers'],b['block']);after='%02d-%s-%s-w%d-b%d'%(new['batch'],new['protocol'],new['phase'],new['workers'],new['block'])
  f=folder/'raw'/(before+'-resources.jsonl')
  if f.exists():shutil.copy2(f,out/'raw'/(after+'-resources.jsonl'))
(out/'samples.json').write_text(json.dumps(rows,indent=2));(out/'batches.json').write_text(json.dumps(batches,indent=2));shutil.copy2(r/'analyze.py',out/'analyze.py');shutil.copy2(r/'charts.py',out/'charts.py');print('combined',len(rows),'samples, original sources unchanged')
