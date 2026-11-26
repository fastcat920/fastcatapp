from pathlib import Path
import json,random,collections,statistics
D=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/optimization-2026-11-21');rng=random.Random(20261121);out=[]
for work in ['controlled','internet']:
 rr=[json.loads(x) for x in (D/(work+'.jsonl')).read_text().splitlines() if x.startswith('{')]
 for phase in ['cold','warm','batch']:
  for other,carrier in [('v2-bbr','h3'),('hysteria2','quic'),('tuic','quic')]:
   a=collections.defaultdict(list);b=collections.defaultdict(list)
   for r in rr:
    if r.get('error') or r['phase']!=phase:continue
    if (r['version'],r['protocol'])==('next','quic'):a[r['round']].append(r['first_byte_us']/1000)
    if (r['version'],r['protocol'])==(other,carrier):b[r['round']].append(r['first_byte_us']/1000)
   diffs=[statistics.median(a[k])-statistics.median(b[k]) for k in sorted(set(a)&set(b))]
   if not diffs:continue
   samples=sorted(statistics.median(rng.choices(diffs,k=len(diffs))) for _ in range(5000))
   out.append(dict(workload=work,phase=phase,reference=other+'/'+carrier,rounds=len(diffs),next_faster_rounds=sum(d<0 for d in diffs),median_round_difference_ms=statistics.median(diffs),reference_bootstrap95_ms=[samples[124],samples[4874]],note='success-paired rounds only; concurrency blocked by batch; these rounds are not independent evidence of long-term network superiority'))
(D/'paired-round-analysis.json').write_text(json.dumps(out,indent=2))
