from pathlib import Path
import json,collections,statistics
D=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/optimization-2026-11-21')
S=json.loads((D/'latency-summary.json').read_text())
if not (D/'metadata.json').exists():raise RuntimeError('Main comparison incomplete')
P=[('vless-vision','tcp-tls','VLESS Vision'),('trojan','tcp-tls','Trojan'),('hysteria2','quic','Hysteria 2'),('tuic','quic','TUIC v5'),('anytls','tcp-tls','AnyTLS'),('v2','h2','v2 H2'),('v2','h3','v2 H3 Reno'),('v2-bbr','h3','v2 H3 BBR'),('v3-light-fast','h2','轻量版 H2'),('v3-light-fast','h3','轻量版 H3'),('next','h2','Next 优化 H2'),('next','quic','Next 优化 QUIC')]
labels={(v,p):label for v,p,label in P};labels['next-quic','quic']='Next QUIC 追加复核'
def read(n):return [json.loads(x) for x in (D/(n+'.jsonl')).read_text().splitlines() if x.startswith('{')]
def num(n):return '—' if n is None else f'{n:,.1f}'
def table(head,rows):return '| '+' | '.join(head)+' |\n| '+' | '.join(['---']*len(head))+' |\n'+''.join('| '+' | '.join(map(str,r))+' |\n' for r in rows)
def pick(w,v,p,phase):return next(r for r in S if (r['workload'],r['version'],r['protocol'],r['phase'])==(w,v,p,phase))
rr=[r for w in ['controlled','internet','singlepool','concurrent8','idle70'] for r in read(w) if r['phase'] not in ['prime','idle-prime']]
T=read('throughput');DL=[dict(workload=w,**r) for w in ['downloads1m','downloads10m','downloads100m','downloads100m-reference','post-reference100'] for r in read(w)]
rows=[]
for v,p,label in P:
 cold,warm,batch=[pick('internet',v,p,phase) for phase in ['cold','warm','batch']]
 tr=[r['download_mbps'] for r in T if (r['version'],r['protocol'],r['workers'])==(v,p,1) and not r.get('errors') and r.get('success')==1 and r.get('download_mbps') is not None]
 dl=[r for r in DL if (r['version'],r['protocol'],r['workload'])==(v,p,'downloads1m')]
 succ=sum(not bool(r.get('error')) for r in rr if (r['version'],r['protocol'])==(v,p));total=sum((r['version'],r['protocol'])==(v,p) for r in rr)
 cell=lambda s:f"{num(s['p50_ms'])}/{num(s['p95_ms'])} ({s['success']}/{s['total']})"
 rows.append([label,f'{succ}/{total}',cell(cold),cell(warm),cell(batch),num(statistics.median(tr)) if tr else '—',f"{sum(bool(r.get('complete')) and bool(r.get('checksum_ok')) for r in dl)}/{len(dl)}"])
intro='''已完成修复自检与本轮全部对照。**QUIC 的额外提前截止及建立连接时的锁等待已修复；H2 已增加坏入口连接退役保护，但高重传 TCP 链路造成的当前业务失速不能由此消除。小 TCP 报文未设为默认。**

主比较保留所有失败，不补样本、不自动重放业务。本轮仍是独立安卓核心与临时服务端测试，没有替换正式 App 或正式节点，也没有隐蔽性验收结论。

互联网目标核心结果：首字节为 P50/P95 ms（成功/总数），单流吞吐为 3 轮有效组中位数 Mbps；完整表与失败阶段见后文。

'''+table(['路径','全部短请求','冷启动','连续请求','4 并发','单流 Mbps','1 MiB完整'],rows)
# Describe comparisons as observations; do not extrapolate a winner globally.
near=[]
for phase,title in [('cold','冷启动'),('warm','连续请求'),('batch','4 并发')]:
 candidates=[r for r in S if r['workload']=='internet' and r['phase']==phase and r['success']==r['total'] and r['total']>0 and r['p50_ms'] is not None]
 candidates.sort(key=lambda r:r['p50_ms']);near.append([title,', '.join(labels[r['version'],r['protocol']]+' '+num(r['p50_ms'])+' ms' for r in candidates[:3])])
intro+='\n在该组全部成功的配置中，按 P50 观察到的前三项如下。它不考虑所有取舍，也不是跨网络总排名；必须同时看 P95 和失败情况。\n\n'+table(['负载','本轮 P50 前三'],near)
NQ=[r for r in rr if (r['version'],r['protocol'])==('next','quic')];NH=[r for r in rr if (r['version'],r['protocol'])==('next','h2')]
intro+=f"\n新协议 QUIC 正式短请求 {sum(not bool(r.get('error')) for r in NQ)}/{len(NQ)}；H2 为 {sum(not bool(r.get('error')) for r in NH)}/{len(NH)}。数值只覆盖本次网络与负载，不将修复后的某次成功解释为既有网络问题已经消失。\n"
critical=[]
for v,p,label in P:
 for name in ['downloads10m','downloads100m','downloads100m-reference','post-reference100']:
  dl=[r for r in DL if (r['version'],r['protocol'],r['workload'])==(v,p,name)]
  for r in dl:
   if not (r.get('complete') and r.get('checksum_ok')):critical.append([label,name,num(r['total_ms']/1000),num(r.get('received_bytes',0)/(1<<20)),r.get('error','')])
intro+='\n大文件未通过项（若表为空表示本轮尝试均完成；每项只有一次，不代表长期可靠性）：\n\n'+table(['路径','文件组','时长 s','收到 MiB','错误'],critical)
extra=read('post-reference100')
intro+='\n追加的紧邻 100 MiB 复核（各一次，原失败保留）：\n\n'+table(['路径','完整且校验','时长 s','收到 MiB','错误'],[[labels.get((r['version'],r['protocol']),r['version']),bool(r.get('complete')) and bool(r.get('checksum_ok')),num(r['total_ms']/1000),num(r.get('received_bytes',0)/(1<<20)),r.get('error','')] for r in extra])
intro+='\nTUIC 的晚期参考与追加复核帮助判断差异，但仍不是同时测量。不能将所有长传输超时归因于新协议消息格式，也不能直接断言只是网络普遍慢；共享 QUIC 实现、窗口/拥塞参数与连接/路径状态都需要后续逐项隔离。当前证据不足以发布新协议作为默认替代。\n'
report=(D/'REPORT.md').read_text().replace('FINAL_CONCLUSIONS',intro)
pairs=json.loads((D/'paired-round-analysis.json').read_text())
report+='\n## 配对轮次补充\n\n仅配对两方都成功的轮次；并发按批次做块。负数表示 Next QUIC 更低。参考区间针对本轮样本，不代表长期独立网络统计，失败仍应先看主表。\n\n'
report+=table(['目标','阶段','对照','Next更快/配对轮','轮差中位数 ms','参考95%区间 ms'],[[r['workload'],r['phase'],r['reference'],str(r['next_faster_rounds'])+'/'+str(r['rounds']),num(r['median_round_difference_ms']),'/'.join(num(v) for v in r['reference_bootstrap95_ms'])] for r in pairs])
report+='\n## 如何使用这份结果\n\n- 先按实际业务看成功率，再看首字节 P95 与中位数；下载和双向回环分开看。任何单次极快或极慢都不作为唯一结论。\n- v2 BBR 与原 v2 H3 都保留，用于识别拥塞配置带来的收益；Next 与它们同样采用成熟 TLS/QUIC 实现，不能把所有提升算成新消息格式的独有优势。\n- 本轮 VLESS 是 TCP+TLS+Vision，不是 REALITY。若现有“香港直连备用”使用其他组合，不能将本表当作它的实测结果。\n- 轻量版未修复的旧会话行为、各内核默认握手/心跳/窗口/填充与 TCP 内核算法都影响比较。独立协议名本身不能保证相同表现。\n- 是否替换正式入口，还需要 App/TUN、多网络和前置、账号计量、灰度回滚及隐私验证。本轮不进行生产替换。\n'
(D/'REPORT.md').write_text(report)
(D/'overview.json').write_text(json.dumps(dict(formal_short_requests=len(rr),short_request_success=sum(not bool(r.get('error')) for r in rr),profiles=len(P),download_attempts=len(DL),complete_verified_downloads=sum(bool(r.get('complete')) and bool(r.get('checksum_ok')) for r in DL),throughput_groups=len(T),valid_throughput_groups=sum(not r.get('errors') and r.get('success')==r['workers'] for r in T),production_modified=False),indent=2))
print((D/'overview.json').read_text())
