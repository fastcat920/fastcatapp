# -*- coding: utf-8 -*-
import json,math,statistics,random,csv,shutil,hashlib,html,datetime
from pathlib import Path
D=Path('/tmp/fc-seven-way');OUT=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-v3/seven-way-2026-11-21')
CASES=[('vless-vision','tcp-tls','VLESS + TCP + TLS + Vision'),('trojan','tcp-tls','Trojan + TCP + TLS'),('hysteria2','quic','Hysteria 2'),('tuic','quic','TUIC v5'),('anytls','tcp-tls','AnyTLS'),('v2','h2','FastCat v2 · H2'),('v2','h3','FastCat v2 · H3'),('v3-light-fast','h2','最新轻量版 · H2'),('v3-light-fast','h3','最新轻量版 · H3')]
LABEL={(v,p):n for v,p,n in CASES}
FILES={'controlled':567,'singlepool':189,'internet':567,'concurrent8':153,'idle35':36,'idle70':36,'downloads':18,'throughput':54,'pilot':36}
LATENCY=['controlled','singlepool','internet','concurrent8','idle35','idle70']
def read(name):
 p=D/(name+'.jsonl');rows=[json.loads(s) for s in p.read_text().splitlines() if s.strip()]
 if len(rows)!=FILES[name]:raise ValueError(f'{name}: {len(rows)} != {FILES[name]}')
 return rows

def pct(values,q):
 if not values:return None
 return sorted(values)[max(0,math.ceil(len(values)*q)-1)]
def dist(values):
 if not values:return {k:None for k in ['min_ms','mean_ms','p50_ms','p90_ms','p95_ms','p99_ms','max_ms','stdev_ms']}
 values=[x/1000 for x in values]
 return {k:round(v,3) for k,v in dict(min_ms=min(values),mean_ms=statistics.mean(values),p50_ms=statistics.median(values),p90_ms=pct(values,.9),p95_ms=pct(values,.95),p99_ms=pct(values,.99),max_ms=max(values),stdev_ms=statistics.stdev(values) if len(values)>1 else 0).items()}
def logical(dataset,r):
 if r['phase'] in ['prime','idle-prime']:return 'prime'
 if dataset=='singlepool':return 'continuous_pool1'
 if dataset=='concurrent8':return 'concurrent8'
 if dataset in ['idle35','idle70']:return 'idle_first' if r['round']==1 else 'idle_followups'
 return {'cold':'cold','warm':'continuous_pool3','batch':'concurrent4'}.get(r['phase'],r['phase'])
def stage(error):
 if not error:return ''
 if 'preparation failed' in error:return 'client preparation'
 for tag in ['entry','target TLS','response']:
  if error.startswith(tag+':'):return tag
 return 'request/client initialization'
def median_ci(rows):
 blocks={}
 for r in rows:
  if not r.get('error'):blocks.setdefault(r.get('round',0),[]).append(r['first_byte_us']/1000)
 if len(blocks)<2:return [None,None]
 rng=random.Random(73121);blocks=list(blocks.values());medians=[]
 for _ in range(2000):
  sample=[]
  for __ in blocks:sample.extend(rng.choice(blocks))
  if sample:medians.append(statistics.median(sample))
 return [round(pct(medians,.025),3),round(pct(medians,.975),3)]
def wilson(k,n):
 z=1.95996398454;p=k/n;den=1+z*z/n;center=(p+z*z/(2*n))/den;half=z*math.sqrt(p*(1-p)/n+z*z/(4*n*n))/den
 return [round(100*(center-half),2),round(100*(center+half),2)]
def writecsv(name,rows):
 keys=list(dict.fromkeys(k for r in rows for k in r));
 with (OUT/name).open('w',encoding='utf-8-sig',newline='') as f:
  w=csv.DictWriter(f,fieldnames=keys);w.writeheader()
  for r in rows:w.writerow({k:json.dumps(v,ensure_ascii=False) if isinstance(v,(dict,list)) else v for k,v in r.items()})

def main():
 if not (D/'metadata.json').exists():raise ValueError('Runner has not completed')
 OUT.mkdir(exist_ok=True,parents=True);raw={n:read(n) for n in FILES}
 for n in FILES:shutil.copyfile(D/(n+'.jsonl'),OUT/(n+'.jsonl'))
 for n in ['metadata.json','environment.json','singlepool-orchestration.json','idle70-orchestration.json','tcp-socket-counts.jsonl']:
  if (D/n).exists():shutil.copyfile(D/n,OUT/n)
 summaries=[];requests=[]
 for dataset in LATENCY:
  groups={}
  for r in raw[dataset]:
   phase=logical(dataset,r);v,p=r['version'],r['protocol'];label=LABEL[v,p]
   request={'dataset':dataset,'phase':phase,'original_phase':r['phase'],'path':label,'version':v,'carrier':p,'round':r.get('round'),'pool':r.get('pool'),'worker':r.get('worker'),'start_unix_us':r['start_unix_us'],'success':not bool(r.get('error')),'error_stage':stage(r.get('error','')),'error':r.get('error','')}
   for key in ['client_ready_us','entry_us','target_tls_us','response_us','first_byte_us','elapsed_us','idle_us']:
    request[key.replace('_us','_ms')]=r.get(key,0)/1000
   request.update({k:r.get(k) for k in ['gateway_tls','gateway_cipher','gateway_alpn']});requests.append(request)
   if phase!='prime':groups.setdefault((phase,v,p),[]).append(r)
  for (phase,v,p),group in groups.items():
   good=[r for r in group if not r.get('error')];ci=median_ci(group)
   item=dict(dataset=dataset,phase=phase,path=LABEL[v,p],version=v,carrier=p,attempts=len(group),success=len(good),failures=len(group)-len(good),success_percent=round(100*len(good)/len(group),2),success_reference_wilson95=wilson(len(good),len(group)),median_round_bootstrap95_ms=ci)
   item.update(dist([r['first_byte_us'] for r in good]))
   for sec in [1,2,5]:item['success_within_'+str(sec)+'s_percent']=round(100*sum(r['first_byte_us']<=sec*1000000 for r in good)/len(group),2)
   for key in ['entry_us','target_tls_us','response_us']:
    item[key.replace('_us','_p50_ms')]=round(statistics.median(r[key] for r in good)/1000,3) if good else None
    item[key.replace('_us','_p95_ms')]=round(pct([r[key] for r in good],.95)/1000,3) if good else None
   counts={}
   for r in group:
    if r.get('error'):counts[r['error']]=counts.get(r['error'],0)+1
   item['errors']=counts;summaries.append(item)
 writecsv('requests.csv',requests);writecsv('latency-summary.csv',summaries)
 (OUT/'latency-summary.json').write_text(json.dumps(summaries,ensure_ascii=False,indent=2)+'\n')
 tstats=[]
 for v,p,label in CASES:
  for workers in [1,4]:
   g=[r for r in raw['throughput'] if r['version']==v and r['protocol']==p and r['workers']==workers];rates=[r['download_mbps'] for r in g if r.get('download_mbps') is not None]
   item=dict(path=label,version=v,carrier=p,workers=workers,rounds=len(g),valid_groups=sum(not r.get('errors') and r.get('success')==workers for r in g),requested_streams=workers*len(g),valid_streams=sum(r.get('success',0) for r in g),measured_groups=len(rates),raw_download_mbps=[round(x,6) for x in rates],mean_mbps=statistics.mean(rates) if rates else None,p50_mbps=statistics.median(rates) if rates else None,min_mbps=min(rates) if rates else None,max_mbps=max(rates) if rates else None,received_mib=sum(r.get('received_bytes',0) for r in g)/(1<<20),median_alloc_mib=statistics.median([r['alloc_bytes']/(1<<20) for r in g if 'alloc_bytes' in r]) if any('alloc_bytes' in r for r in g) else None,max_heap_snapshot_mib=max((r.get('heap_live_bytes',0)/(1<<20) for r in g),default=0),errors=[e for r in g for e in r.get('errors',[])])
   tstats.append(item)
 writecsv('throughput-summary.csv',tstats);(OUT/'throughput-summary.json').write_text(json.dumps(tstats,ensure_ascii=False,indent=2)+'\n')
 dstats=[]
 for v,p,label in CASES:
  g=[r for r in raw['downloads'] if r['version']==v and r['protocol']==p];good=[r for r in g if r['complete']]
  dstats.append(dict(path=label,version=v,carrier=p,attempts=len(g),complete=len(good),raw_total_ms=[r.get('total_ms') for r in g],median_complete_total_ms=statistics.median(r['total_ms'] for r in good) if good else None,median_complete_e2e_mbps=statistics.median(r['end_to_end_mbps'] for r in good) if good else None,received_mib=sum(r.get('received_bytes',0) for r in g)/(1<<20),errors=[r['error'] for r in g if r.get('error')]))
 writecsv('download-summary.csv',dstats);(OUT/'download-summary.json').write_text(json.dumps(dstats,ensure_ascii=False,indent=2)+'\n')
 idle=[]
 for window in ['idle35','idle70']:
  for v,p,label in CASES:
   g=[r for r in raw[window] if r['version']==v and r['protocol']==p and r['phase']=='idle-resume'];first=next(r for r in g if r['round']==1)
   idle.append(dict(dataset=window,path=label,version=v,carrier=p,actual_idle_ms=first['idle_us']/1000,first_success=not bool(first.get('error')),first_ms=first['first_byte_us']/1000 if not first.get('error') else None,first_error=first.get('error',''),followup_success=sum(not r.get('error') for r in g if r['round']>1),followup_attempts=2))
 writecsv('idle-summary.csv',idle);(OUT/'idle-summary.json').write_text(json.dumps(idle,ensure_ascii=False,indent=2)+'\n')
 overview=dict(total_latency_rows=len(requests),formal_latency_attempts=sum(r['phase']!='prime' for r in requests),prime_rows=sum(r['phase']=='prime' for r in requests),pilot_rows=len(raw['pilot']),throughput_groups=len(raw['throughput']),throughput_requested_streams=sum(r['workers'] for r in raw['throughput']),download_attempts=len(raw['downloads']))
 (OUT/'overview.json').write_text(json.dumps(overview,indent=2)+'\n')
 # One searchable HTML table retains every distribution and error group.
 header={'dataset':'测试组','phase':'场景','path':'路径','success':'成功数','attempts':'次数','success_percent':'成功率 %','mean_ms':'均值 ms','p50_ms':'首字节 P50 ms','p90_ms':'P90 ms','p95_ms':'P95 ms','p99_ms':'P99 ms','max_ms':'最大值 ms','stdev_ms':'标准差 ms','success_within_1s_percent':'1秒内成功 %','success_within_2s_percent':'2秒内成功 %','median_round_bootstrap95_ms':'中位数轮次重采样95%区间','entry_p50_ms':'入口阶段 P50 ms','target_tls_p50_ms':'目标TLS阶段 P50 ms','response_p50_ms':'响应阶段 P50 ms','errors':'错误','workers':'并发数','valid_groups':'有效组数','rounds':'轮数','mean_mbps':'均值 Mbps','p50_mbps':'中位 Mbps','min_mbps':'最低 Mbps','max_mbps':'最高 Mbps','raw_download_mbps':'每轮 Mbps','median_alloc_mib':'传输期分配中位 MiB','max_heap_snapshot_mib':'最大堆快照 MiB','complete':'完整下载数','raw_total_ms':'每轮总耗时 ms','median_complete_total_ms':'完整下载总耗时中位 ms','median_complete_e2e_mbps':'完整下载端到端速率中位 Mbps','actual_idle_ms':'实际业务空闲 ms','first_success':'首次成功','first_ms':'首次首字节 ms','followup_success':'后两次成功数','first_error':'首次错误'}
 display={'controlled':'受控HTTPS','internet':'真实网站','singlepool':'单池串行','concurrent8':'八路并发','idle35':'空闲至少35秒','idle70':'空闲至少70秒','cold':'冷连接','continuous_pool1':'单池连续','continuous_pool3':'三池轮换','concurrent4':'四路并发','idle_first':'空闲后首次','idle_followups':'空闲后后续'}
 def table(data,keys):
  parts=['<table><thead><tr>'+''.join('<th>'+html.escape(header.get(k,k))+'</th>' for k in keys)+'</tr></thead><tbody>']
  for r in data:
   cells=[]
   for k in keys:
    value=r.get(k);value=display.get(value,value) if isinstance(value,str) else value;value='—' if value is None else str(round(value,3)) if isinstance(value,float) else json.dumps(value,ensure_ascii=False) if isinstance(value,(dict,list)) else str(value)
    cells.append('<td>'+html.escape(value)+'</td>')
   parts.append('<tr>'+''.join(cells)+'</tr>')
  parts.append('</tbody></table>');return ''.join(parts)
 page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>七类协议测试数据</title><style>body{font:14px/1.55 system-ui;margin:24px;background:#f6f8fa;color:#17202a}h1{font-size:24px}table{border-collapse:collapse;background:white;display:block;overflow:auto;max-height:75vh}td,th{padding:8px 12px;border:1px solid #dde3e8;text-align:right;white-space:nowrap}th{position:sticky;top:0;background:#eaf0f7;cursor:pointer}td:first-child{text-align:left}input{padding:10px;width:360px;max-width:90%;margin:12px 0}.note{padding:12px;background:#fff2d9;max-width:1000px}a{color:#135aa3}</style><h1>七类协议 / 九条路径：完整数据</h1><p>2026-11-21 · 安卓独立核心 · 同网同服务器 · 可点击表头排序，或搜索筛选。</p><p class="note">延迟仅统计成功请求；失败不为零延迟。P95/P99小样本精度有限。分段定义跨协议不同，不能直接归因为某一层开销。吞吐为8秒TLS回显窗口、3轮，文件下载1MiB两轮；均不能代表长期极限带宽或正式App耗电。完整方法和结论见报告。</p><p><a href="REPORT.md">完整报告</a> · <a href="requests.csv">逐请求 CSV</a> · <a href="latency-summary.csv">延迟汇总 CSV</a> · <a href="throughput-summary.csv">吞吐汇总 CSV</a></p><input placeholder="筛选协议、场景或错误" oninput="document.querySelectorAll('tbody tr').forEach(r=>r.hidden=!r.innerText.toLowerCase().includes(this.value.toLowerCase()))"><h2>延迟和可靠性</h2>'''
 page+=table(summaries,['dataset','phase','path','success','attempts','success_percent','mean_ms','p50_ms','p90_ms','p95_ms','p99_ms','max_ms','stdev_ms','success_within_1s_percent','success_within_2s_percent','median_round_bootstrap95_ms','entry_p50_ms','target_tls_p50_ms','response_p50_ms','errors'])
 page+='<h2>吞吐和资源快照</h2>'+table(tstats,['path','workers','valid_groups','rounds','mean_mbps','p50_mbps','min_mbps','max_mbps','raw_download_mbps','median_alloc_mib','max_heap_snapshot_mib','errors'])
 page+='<h2>1MiB下载</h2>'+table(dstats,['path','complete','attempts','raw_total_ms','median_complete_total_ms','median_complete_e2e_mbps','errors'])
 page+='<h2>空闲恢复</h2>'+table(idle,['dataset','path','actual_idle_ms','first_success','first_ms','followup_success','first_error'])
 page+='''<script>document.querySelectorAll('th').forEach(th=>th.onclick=()=>{let t=th.closest('table'),i=[...th.parentNode.children].indexOf(th),rows=[...t.tBodies[0].rows],d=th.dataset.desc==='1'?-1:1;th.dataset.desc=d===1?'1':'0';rows.sort((a,b)=>{let x=a.cells[i].innerText,y=b.cells[i].innerText;if(x==='—')return 1;if(y==='—')return -1;return d*(x.trim()!==''&&y.trim()!==''&&!isNaN(+x)&&!isNaN(+y)?(+x)-(+y):x.localeCompare(y))});rows.forEach(r=>t.tBodies[0].appendChild(r))});</script></html>'''
 (OUT/'DATA.html').write_text(page)
 print(json.dumps(overview));print('Saved',OUT)
if __name__=='__main__':main()
