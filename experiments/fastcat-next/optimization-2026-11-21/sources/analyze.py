from pathlib import Path
import json,csv,collections,statistics,math,html,re
D=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/optimization-2026-11-21')
P=[('vless-vision','tcp-tls','VLESS Vision'),('trojan','tcp-tls','Trojan'),('hysteria2','quic','Hysteria 2'),('tuic','quic','TUIC v5'),('anytls','tcp-tls','AnyTLS'),('v2','h2','v2 H2'),('v2','h3','v2 H3 Reno'),('v2-bbr','h3','v2 H3 BBR'),('v3-light-fast','h2','轻量版 H2'),('v3-light-fast','h3','轻量版 H3'),('next','h2','Next 优化 H2'),('next','quic','Next 优化 QUIC')]
labels={(v,p):n for v,p,n in P};labels['next-quic','quic']='Next QUIC 追加复核'
def read(n):
 p=D/(n+'.jsonl');rr=[]
 if p.exists():
  for line in p.read_text().splitlines():
   try:rr.append(json.loads(line))
   except:pass
 return rr
names=['controlled','internet','singlepool','concurrent8','idle70']
rows=[dict(workload=w,**r) for w in names for r in read(w)]
def csvout(name,rr):
 if not rr:return
 fields=list(dict.fromkeys(k for r in rr for k in r))
 with (D/(name+'.csv')).open('w',encoding='utf-8-sig',newline='') as f:
  w=csv.DictWriter(f,fieldnames=fields);w.writeheader();w.writerows(rr)
csvout('requests',rows)
def pct(a,p):return a[max(0,math.ceil(len(a)*p)-1)] if a else None
groups=collections.defaultdict(list)
for r in rows:groups[r['workload'],r['version'],r['protocol'],r['phase']].append(r)
S=[]
for k,rr in sorted(groups.items()):
 a=sorted(r['first_byte_us']/1000 for r in rr if not r.get('error'));entry=sorted(r['entry_us']/1000 for r in rr if not r.get('error'))
 row=dict(zip(['workload','version','protocol','phase'],k));row.update(success=len(a),total=len(rr),failures=len(rr)-len(a),p50_ms=statistics.median(a) if a else None,p95_ms=pct(a,.95),p99_ms=pct(a,.99),mean_ms=statistics.mean(a) if a else None,max_ms=max(a) if a else None,min_ms=min(a) if a else None,stddev_ms=statistics.pstdev(a) if a else None,within_1000ms=sum(x<=1000 for x in a),within_2000ms=sum(x<=2000 for x in a))
 for key in ['client_ready_us','entry_us','target_tls_us','response_us']:
  b=[r.get(key,0)/1000 for r in rr if not r.get('error')];row[key.replace('_us','_p50_ms')]=statistics.median(b) if b else None
 S.append(row)
(D/'latency-summary.json').write_text(json.dumps(S,ensure_ascii=False,indent=2));csvout('latency-summary',S)
errors=collections.Counter((r['workload'],r['version'],r['protocol'],r['phase'],r['error']) for r in rows if r.get('error'))
csvout('errors',[dict(zip(['workload','version','protocol','phase','error'],k),count=n) for k,n in sorted(errors.items())])
T=read('throughput');downloads=[dict(workload=w,**r) for w in ['downloads1m','downloads10m','downloads100m','downloads100m-reference','post-reference100'] for r in read(w)];csvout('throughput',T);csvout('downloads',downloads)
(D/'downloads-summary.json').write_text(json.dumps(downloads,ensure_ascii=False,indent=2))
net=[]
for p in sorted(D.glob('*-network-*.txt')):
 text=p.read_text();active=re.findall(r'Active default network:\s*(\d+)',text);net.append(dict(file=p.name,default_network=active[0] if active else None,vpn='ni{VPN CONNECTED' in text))
(D/'network-summary.json').write_text(json.dumps(net,indent=2))
def num(n):return '—' if n is None else f'{n:,.1f}'
def table(head,rr):return '| '+' | '.join(head)+' |\n| '+' | '.join(['---']*len(head))+' |\n'+''.join('| '+' | '.join(str(x).replace('|','/') for x in r)+' |\n' for r in rr)
def latency(w,phases):
 rr=[]
 for v,p,label in P:
  cells=[label]
  for phase in phases:
   r=next((r for r in S if (r['workload'],r['version'],r['protocol'],r['phase'])==(w,v,p,phase)),None)
   cells.append('待完成' if not r else f"{r['success']}/{r['total']} · {num(r['p50_ms'])} / {num(r['p95_ms'])}")
  rr.append(cells)
 return table(['路径']+phases,rr)
formal=[r for r in rows if r['phase'] not in ['prime','idle-prime']]
g=collections.defaultdict(list)
for r in formal:g[r['version'],r['protocol']].append(r)
counts=table(['路径','正式成功/总数','失败'],[[labels[v,p],f"{sum(not bool(r.get('error')) for r in rr)}/{len(rr)}",sum(bool(r.get('error')) for r in rr)] for v,p,label in P for rr in [g[v,p]]])
report=f'''# 优化后八协议安卓对照报告

日期：2026-11-21。新协议为 FastCat Next / FCN/1 实现优化 0.2。本轮共 8 类协议、12 条具体配置路径；v2 分别保留 H2、原 H3 Reno 与 H3 BBR。

## 结论

FINAL_CONCLUSIONS

## 本轮修复及范围

1. QUIC 默认总入口预算由额外的 5 秒上限调整为 10 秒，与库最大握手限制对齐，仍受调用方更短截止和 5 秒无进展截止约束。受控测试持续投递握手报文：旧预算 5 秒失败，新预算约 5.21 秒完成。此证据复现实现弱点，不宣称已还原首轮那个公网失败的全部底层原因。
2. 连接建立移出全局锁；并发等待、Close 与网络 Reset 可及时取消，旧代际不会回填连接池。
3. H2 通过实际 TCP 与读写采样定位到高重传和下行背压，未发现接收窗口耗尽证据。读阻塞时合并检查入口 PING，只有入口也超时才为新业务退役旧连接；健康入口上的慢目标不误替换，已有业务不重放。此保护避免后续业务持续使用坏连接，不能修复已经在高丢包 TCP 链路上传输的文件。
4. 小 TCP 报文试验未成为默认：TCP_MAXSEG=1200 的 10 MiB 仅 2/3 完成，系统默认 1/3，仍有失速且样本不足。全组正式测试沿用系统默认 MSS，未改变 QUIC 初始包长。详见 OPTIMIZATION-0.2.md 与原始 mss-* 数据。

## 方法与可比性

- 同一安卓 TFY-AN00，Android 12/API 31，MT6833V/PNZA，同一 Wi-Fi；独立核心命令行程序，测试时 VPN 关闭。不是正式 App/TUN 或 iOS 的端到端测试。
- 同一香港 VPS 191.223.214.8，1 个在线 CPU、Linux 6.12.117，生产共用主机的独立入口；没有隔离其他用户流量。未修改正式 443/18447。
- 安卓 TCP 内核算法实测 BIC，服务端 TCP 为 BBR；QUIC 使用各实现自己的控制器。安卓客户端 Go 1.26.2，各服务端 Go 1.27.3。Next、v2、轻量版使用同一固定版本 metacubex/quic-go；原生协议使用 CatNode 当前 Xray 内核，其 QUIC 实现及参数不完全相同。
- 各路径使用同一有效证书域名 zlhk.fastcat.ink，严格验证证书，没有开启 TLS 0-RTT。协议路径与配置见下表；这比较的是实际实现及组合，不能把全部差值归因于线上消息格式。
- 主实验关闭诊断追踪；诊断/MSS 实验属于较早的独立阶段，不与主实验合并排名。
- 受控目标为同 VPS 独立 HTTPS，固定 IP、固定证书名、HEAD 200。Xray 嗅探可能将数值 IP 重新解释成 TLS 主机名，因此不能宣称所有实现都完全没有目标 DNS 工作。互联网目标为 example.com:443，未固定 CDN IP。
- 冷启动各 20 次；三池连续各 20 次；4 并发 5 批；单池连续另测 20 次；8 并发 3 批。短请求轮换载体/版本顺序，普通请求外层 12 秒，各实现仍有自身更短内部截止。预热单独保留，不计正式成功率。
- 首字节从本地开始到目标响应首字节，冷启动包含 factory/握手/认证。不同 Dial 返回语义不同，Next QUIC 不等待目标状态就允许排队业务数据；不应跨协议比较 entry_us 或将各阶段中位数相加。
- P50 是成功样本中位数，P95/P99 采用近邻秩；失败不记成零延迟。20 次样本的 P95 接近第二慢值，小样本和连续网络事件不能当作长期独立成功概率。
- 1 MiB 每路径 3 次，30 秒截止；10 MiB 每路径 1 次，90 秒截止；100 MiB 对 Next 两载体和 v2 BBR 各 1 次，240 秒截止。全部校验长度及 SHA-256，部分接收保留，不重试补样本。
- 主实验中长传输出现超时后，较晚追加 TUIC 与 VLESS Vision 各一次 100 MiB 参考（同样 240 秒）。它们单独标为 downloads100m-reference，不与早先样本合并统计，也不能消除测试时间差的影响。随后再追加一组紧邻的 Next QUIC/TUIC 100 MiB，单列为 post-reference100，避免用复测覆盖首次失败。
- 吞吐为入口及目标 TLS 建立后的 8 秒双向 TLS 回环，单流/四流各 3 轮，只计收到且验证通过的业务载荷。四流是聚合值；载体分块、块内轮换版本，并非完全随机顺序。不能等同单向长下载或链路带宽上限。

| 路径 | 实际组合 |
| --- | --- |
| VLESS Vision | VLESS + TCP + TLS + xtls-rprx-vision，无 REALITY、WS、gRPC、额外 VLESS 加密或多路复用 |
| Trojan | 原生 Trojan + TCP + TLS；即使 TLS ALPN 为 h2，载荷也不是 HTTP/2 隧道 |
| Hysteria 2 | QUIC + TLS 1.3 + BBR，无强制带宽/Brutal、obfs、端口跳跃 |
| TUIC v5 | TUIC v5 + QUIC + TLS 1.3 + BBR，0-RTT/FastOpen 关闭，默认心跳 |
| AnyTLS | TLS + 原生会话复用 + 默认填充；并发可能创建多条 TCP 会话 |
| v2 H2 | HTTP/2 + TCP + TLS 1.3 + 账号令牌 |
| v2 H3 Reno / BBR | HTTP/3 + QUIC + TLS 1.3 + 账号令牌；Reno 为库默认，BBR 为双端显式配置 |
| 轻量版 H2/H3 | 最新 v3-light-fast，TLS + Noise 授权 + 独立 HTTP 流，保留原实现与生命周期 |
| Next H2/QUIC | TLS 1.3 + exporter 绑定 OPEN 授权；原生 QUIC 独立流/数据报或真实 H2 POST；无 Noise 与载荷二次加密，QUIC 使用 BBR |

## 正式短请求总数

累计 {len(formal)} 次正式请求。下表合并不同负载仅用于核对总数，不是某个单一业务的长期成功率。

{counts}

## 受控目标首字节

单元格：成功/总数 · P50 / P95，单位 ms。cold=冷启动，warm=三池连续，batch=4 并发。

{latency('controlled',['cold','warm','batch'])}

## 互联网目标首字节

{latency('internet',['cold','warm','batch'])}

## 单池连续

{latency('singlepool',['batch'])}

## 8 并发

{latency('concurrent8',['batch'])}

## 完整下载

'''
for name in ['downloads1m','downloads10m','downloads100m','downloads100m-reference','post-reference100']:
 rr=read(name)
 report+=f'### {name}\n\n'+table(['路径','轮','完整+校验','总时长 s','收到 MiB','错误'],[[labels.get((r['version'],r['protocol']),r['version']),r['round'],bool(r.get('complete')) and bool(r.get('checksum_ok')),num(r['total_ms']/1000),num(r.get('received_bytes',0)/(1<<20)),r.get('error','')] for r in rr])+'\n'
report+='\n## 8 秒有效回环吞吐\n\n单位 Mbps，下面同时保留各轮数值和有效组数。\n\n'
tr=[]
for v,p,label in P:
 for workers in [1,4]:
  rr=[r for r in T if (r['version'],r['protocol'],r['workers'])==(v,p,workers)];a=[r['download_mbps'] for r in rr if not r.get('errors') and r.get('success')==workers and r.get('download_mbps') is not None]
  tr.append([label,workers,f'{len(a)}/{len(rr)}',num(statistics.median(a)) if a else '—',', '.join(num(r.get('download_mbps')) for r in rr)])
report+=table(['路径','流数','有效组','中位数','各轮'],tr)
report+='\n## 70 秒空闲恢复\n\n先逐路径预热，统一等待 70 秒后串行检查。首次恢复实际空闲时间以 idle_us 为准；其后两次不是独立空闲试验。Hysteria 2/TUIC 等仍有心跳，不能把通过与否直接解释为耗电优劣。\n\n'
ir=[]
for v,p,label in P:
 rr=[r for r in read('idle70') if (r['version'],r['protocol'],r['phase'])==(v,p,'idle-resume')];first=next((r for r in rr if r['round']==1),None)
 ir.append([label,num(first.get('idle_us',0)/1e6) if first else '—',first.get('error') or num(first['first_byte_us']/1000) if first else '—',f"{sum(not bool(r.get('error')) for r in rr if r['round']>1)}/2"])
report+=table(['路径','实际空闲 s','首次 ms 或错误','后续成功/2'],ir)
report+='\n## 失败分类\n\n'+table(['负载','路径','阶段','次数','原始错误'],[[k[0],labels.get((k[1],k[2]),k[1]),k[3],n,k[4]] for k,n in sorted(errors.items())])
report+='''
## 限制与尚未验收

- 本轮不测 GFW 识别率或隐蔽性。Next 实验 ALPN、TLS/QUIC 参数与流量模式仍可见；没有启用 ECH，不继承旧 v2 ECH 验收结论。
- 未更新正式 App、面板、订阅或生产节点；未测跨网、蜂窝、iOS、锁屏耗电及多人容量。固定载体不等于自动选路发布验证。
- 回环吞吐的堆、分配量与 goroutines 是整个测试进程在不同回收时点的数据，不是每账号成本。单个 VPS/网络不能推定全球性能。
- 原生协议由实际 CatNode Start/AddNode/AddUsers 启动，但使用临时无限额测试账号，没有面板计费或真实用户账号变更。
- H2 高重传链路仍可能导致当前业务大文件超时。连接退役只保护新业务，不能重放已经提交的 TCP 数据。

## 文件

requests.csv / latency-summary.csv 为原值与统计；errors.csv 为请求失败；downloads.csv、throughput.csv 为传输原值；diagnosis-*、mss-* 为修复依据；local/ 为自检；sources/ 为源码快照与复现参考；metadata.json、network-summary.json、SHA256SUMS 为配置与校验信息。sources 中脚本需要调整本机路径，不是公开安装器。

## 图表

![互联网首字节](latency.png)

![有效吞吐](throughput.png)
'''
(D/'REPORT.md').write_text(report)
htmlrows=''.join('<tr>'+''.join('<td>'+html.escape(str(x))+'</td>' for x in [r['workload'],labels.get((r['version'],r['protocol']),r['version']),r['phase'],f"{r['success']}/{r['total']}",num(r['p50_ms']),num(r['p95_ms']),num(r['max_ms'])])+'</tr>' for r in S if r['phase'] not in ['prime','idle-prime'])
(D/'DATA.html').write_text('''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>八协议优化对照</title><style>body{font:15px system-ui;margin:28px;background:#f5f7fa;color:#153044}h1{font-size:26px}table{border-collapse:collapse;background:white}td,th{padding:10px;border-bottom:1px solid #ddd;text-align:right}td:first-child,td:nth-child(2){text-align:left}th{position:sticky;top:0;background:#17394d;color:white}input{padding:12px;width:330px;margin:15px 0}img{max-width:100%}</style><h1>优化后的八协议安卓对照</h1><p>12 条配置路径；成功请求的延迟，失败单列。单位 ms。完整结论见 REPORT.md。</p><p><img src="latency.png"><img src="throughput.png"></p><input placeholder="筛选路径、负载、阶段" oninput="document.querySelectorAll('tbody tr').forEach(r=>r.hidden=!r.textContent.toLowerCase().includes(this.value.toLowerCase()))"><table><thead><tr>'''+''.join('<th>'+h+'</th>' for h in ['负载','路径','阶段','成功/总数','P50','P95','最大'])+'</tr></thead><tbody>'+htmlrows+'</tbody></table></html>')
print(json.dumps(dict(rows=len(rows),formal=len(formal),downloads=len(downloads),throughput=len(T)),ensure_ascii=False))
