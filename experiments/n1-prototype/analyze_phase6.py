#!/usr/bin/env python3
"""Train-only decision rules; held-out labels never select a threshold."""
from pathlib import Path
import json
import math
import statistics
import sys

root=Path(__file__).resolve().parent/'results/phase6-2026-11-24'
declaration=json.loads((root/'declaration.json').read_text())
samples=json.loads((root/'samples.json').read_text())
capture=json.loads(Path(sys.argv[1]).read_text())['client_hellos']
assert len(capture)==len(samples)==48, 'extra/missing flows; refuse positional label matching'
assert all(r['payload_verified'] and r['shutdown_eof_observed'] and r['exit_code']==0 for r in samples)
assert len({r['normalized_feature_hash'] for r in capture})==1, 'client-stack mismatch between controls'
data=[]
for sample,flow in zip(samples,capture):
    assert flow['server_tcp_capture_contiguous'] and flow['client_tcp_capture_contiguous']
    assert flow['client_syn_seen']
    assert flow['server_tls_unparsed_bytes']==0 and flow['client_tls_unparsed_bytes']==0
    c=[r['length'] for r in flow['client_tls_records'] if r['type']==23]
    s=[r['length'] for r in flow['server_tls_records'] if r['type']==23]
    features={'client_records':len(c),'server_records':len(s),
        'client_small_records':sum(n<=256 for n in c),'server_small_records':sum(n<=256 for n in s),
        'log_client_tcp_bytes':math.log1p(flow['client_unique_tcp_payload_bytes']),
        'log_server_tcp_bytes':math.log1p(flow['server_unique_tcp_payload_bytes'])}
    data.append({**sample,'features':features,'label':int(sample['kind']!='rpc'),
        'server_rst':flow['server_rst_packets'],'client_rst':flow['client_rst_packets']})

def metrics(rows,predict):
    tp=tn=fp=fn=0
    for r in rows:
        actual=r['label'];p=predict(r)
        tp+=bool(actual and p);tn+=bool(not actual and not p)
        fp+=bool(not actual and p);fn+=bool(actual and not p)
    tpr=tp/(tp+fn) if tp+fn else None;fpr=fp/(fp+tn) if fp+tn else None
    return {'tp':tp,'tn':tn,'fp':fp,'fn':fn,'tpr':tpr,'fpr':fpr,
            'balanced_accuracy':(tpr+1-fpr)/2 if tpr is not None and fpr is not None else None}

def fit(rows, feature_names):
    best=None
    for feature in feature_names:
        values=sorted({r['features'][feature] for r in rows})
        thresholds=[values[0]-1]+[(a+b)/2 for a,b in zip(values,values[1:])]+[values[-1]+1]
        for threshold in thresholds:
            for sign in [1,-1]:
                rule={'feature':feature,'threshold':threshold,'sign':sign}
                pred=lambda r:sign*(r['features'][feature]-threshold)>0
                score=metrics(rows,pred)['balanced_accuracy']
                if best is None or score>best[0]:best=(score,rule)
    return best[1]

report={'samples':48,'scope':declaration['limitations'],'models':{},'workloads':{}}
train=[r for r in data if r['split']=='train'];test=[r for r in data if r['split']=='holdout']
for feature_set,names in [('counts_only',declaration['features'][:4]),('all',declaration['features']),('upstream_only',['client_records','client_small_records','log_client_tcp_bytes'])]:
    rule=fit(train,names)
    def predict(r):return rule['sign']*(r['features'][rule['feature']]-rule['threshold'])>0
    report['models'][feature_set]={'rule':rule,'train':metrics(train,predict),'holdout':metrics(test,predict)}
for split in ['train','holdout']:
    for kind in ['n1','rpc']:
        v=[r for r in data if r['split']==split and r['kind']==kind]
        report['workloads'][split+'-'+kind]={'samples':len(v),
            'server_records_p50':statistics.median(r['features']['server_records'] for r in v),
            'client_records':sorted({r['features']['client_records'] for r in v}),
            'rst_packets':sum(r['server_rst']+r['client_rst'] for r in v)}
# Exact upstream matches are a design check, not a selected model feature.
for i in range(0,len(data),2):
    n1,rpc=data[i:i+2]
    assert n1['pair']==rpc['pair'] and n1['kind']=='n1' and rpc['kind']=='rpc'
    assert [e['bytes'] for e in n1['request_writes']]==[e['bytes'] for e in rpc['request_writes']]
    assert capture[i]['client_tls_records']==capture[i+1]['client_tls_records']
    assert n1['features']['client_records']==rpc['features']['client_records']
    assert n1['features']['log_client_tcp_bytes']==rpc['features']['log_client_tcp_bytes']
report['exact_upstream_matches']=len(data)//2
report['exact_upstream_record_length_matches']=len(data)//2
(root/'features.json').write_text(json.dumps(data,indent=2))
(root/'analysis.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
