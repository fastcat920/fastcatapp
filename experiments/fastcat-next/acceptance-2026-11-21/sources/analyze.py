import json,csv,math,statistics,collections,html,hashlib,shutil
from pathlib import Path
D=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/acceptance-2026-11-21')
def load(name):
 p=D/(name+'.jsonl');out=[]
 if p.exists():
  for l in p.read_text().splitlines():
   try:out.append(json.loads(l))
   except json.JSONDecodeError:pass
 return out
names=['controlled','internet','singlepool','concurrent8','idle70','ablation','ablation-crossover']
raw=[dict(workload=name,**r) for name in names for r in load(name)]
fields=list(dict.fromkeys(k for r in raw for k in r))
with (D/'requests.csv').open('w',encoding='utf-8-sig',newline='') as f:
 w=csv.DictWriter(f,fieldnames=fields);w.writeheader();w.writerows(raw)
def pct(a,p):return a[max(0,math.ceil(len(a)*p)-1)] if a else None
summary=[]
groups=collections.defaultdict(list)
for r in raw:groups[r['workload'],r['version'],r['protocol'],r['phase']].append(r)
for k,rr in sorted(groups.items()):
 a=sorted(r['first_byte_us']/1000 for r in rr if not r.get('error'))
 row=dict(zip(['workload','version','protocol','phase'],k));row.update(total=len(rr),success=len(a),failures=len(rr)-len(a),p50_ms=statistics.median(a) if a else None,p95_ms=pct(a,.95),p99_ms=pct(a,.99),mean_ms=statistics.mean(a) if a else None,min_ms=min(a) if a else None,max_ms=max(a) if a else None,stddev_ms=statistics.pstdev(a) if a else None,within_1000ms=sum(x<=1000 for x in a),within_2000ms=sum(x<=2000 for x in a),errors=dict(collections.Counter(r['error'] for r in rr if r.get('error'))))
 for stage in ['entry_us','target_tls_us','response_us']:
  v=[r[stage]/1000 for r in rr if not r.get('error')];row[stage.replace('_us','_p50_ms')]=statistics.median(v) if v else None
 summary.append(row)
(D/'latency-summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2))
with (D/'latency-summary.csv').open('w',encoding='utf-8-sig',newline='') as f:
 w=csv.DictWriter(f,fieldnames=list(summary[0]) if summary else ['workload']);w.writeheader();w.writerows(summary)
other={n:load(n) for n in ['downloads','ablation-download','ablation-crossover-download','ablation-sameport-download','throughput','ablation-throughput','ablation-crossover-throughput','functional-android','udp-matrix','large-10485760','large-104857600']}
for name,rows in other.items():
 if not rows:continue
 fields=list(dict.fromkeys(k for r in rows for k in r))
 with (D/(name+'.csv')).open('w',encoding='utf-8-sig',newline='') as f:w=csv.DictWriter(f,fieldnames=fields);w.writeheader();w.writerows(rows)
net=[]
for p in sorted(D.glob('*-network-*.txt')):
 import re
 text=p.read_text();active=re.findall(r'Active default network:\s*(\d+)',text);net.append(dict(file=p.name,default_network=active[0] if active else None,vpn_connected='ni{VPN CONNECTED' in text))
(D/'network-summary.json').write_text(json.dumps(net,indent=2))
labels={'v2-reno/h3':'v2 · H3 Reno','v2-bbr/h3':'v2 · H3 BBR','next/quic':'Next · 原生 QUIC BBR','next/h2':'Next · H2','v3-light-fast/h2':'轻量版 · H2','v3-light-fast/h3':'轻量版 · H3'}
order=list(labels)
def num(x):return '—' if x is None else f'{x:,.1f}'
def table(headers,rows):return '| '+' | '.join(headers)+' |\n| '+' | '.join(['---']*len(headers))+' |\n'+''.join('| '+' | '.join(map(str,r))+' |\n' for r in rows)
def phase_table(workload,phases):
 result=[]
 for path in order:
  v,p=path.split('/');rows=[r for r in summary if r['workload']==workload and r['version']==v and r['protocol']==p and r['phase'] in phases]
  cells=[labels[path]]
  for phase in phases:
   row=next((r for r in rows if r['phase']==phase),None);cells.append('待完成' if row is None else f"{row['success']}/{row['total']} · {num(row['p50_ms'])} / {num(row['p95_ms'])}")
  result.append(cells)
 return table(['路径']+phases,result)
report='''# FastCat Next 原型验收与对照报告

日期：2026-11-21。完整结果以本目录原始 JSONL、CSV 为准。

## 结论与验收边界

待所有测试完成后补充最终结论。

本轮交付是 FCN/1 独立原型：原生 QUIC/TLS 1.3 的独立 TCP 流与 UDP 数据报，加 HTTP/2/TLS 1.3 的 TCP 备用载体。采用 TLS exporter 绑定的账号 HMAC 授权，不叠加 Noise 和载荷二次加密。它不是自创密码算法，也不是浏览器 HTTP/3。

## 环境与方法

- 实机：安卓 TFY-AN00，序列号 A3GMVB2110006859，Android 12/API 31；同一 Wi-Fi。独立核心命令行程序，测试时 VPN 关闭；不是正式 App/TUN 的整链路性能。
- 服务端：zlhk.fastcat.ink / 191.223.214.8，同一生产共用 VPS 的独立测试端口。正式 443/18447 未变更；负载、无线信号与公网拥塞没有被隔离。
- Go 版本：安卓客户端 1.26.2；v2/轻量版服务器 1.27.3；Next 服务器 1.26.2。因此该对照是实现与配置的比较，不是仅改变线上消息格式的因果实验。
- 同一有效证书、严格域名验证；Next 与 v2 客户端 QUIC 接收窗口均为流 2/6 MiB、连接 3/15 MiB。全部未开启 TLS 0-RTT；Next 不周期保活。v2 服务端沿用库默认接收窗口，Next 服务端显式使用上述窗口，也属于实现配置差异。
- v2 Reno 和 BBR 使用同一 CatNode H3 handler 的实验包装，同一服务端程序，仅配置不同。双端 BBR 均采用 Mihomo 的同一实现，标准 profile，初始拥塞窗 32 包。第一轮端口为 Reno 19442 / BBR 19440；因此不能把首轮称为严格同端口的因果实验。
- Next H2 使用固定物理 TLS 的 http2.ClientConn，避免透明重连复用旧 exporter；原生 QUIC 使用 fcn-lab/1 实验 ALPN。最新轻量版为 v3-light-fast，未修改协议实现。
- 受控目标：服务器独立 HTTPS HEAD，固定 IP + zlhk.fastcat.ink 证书名。互联网目标 example.com:443，未固定其 CDN IP。
- 短请求交错轮换载体和版本顺序；吞吐按载体分块，块内轮换版本，未做完全随机顺序。普通请求外层 12 秒预算，入口自身可能有更短截止。冷启动含入口建立；连续 20 次分散到 3 个池；单池连续另测 20 次；4 并发 5 批、8 并发 3 批。prime 行保留，不算正式结果。
- 各载体 Dial 返回的完成阶段不同，尤其 Next 原生 QUIC 的目标状态延迟到 Read。应比较完整首字节，不能把不同协议的 entry_us 直接解释为同一工作量。
- P50 为成功样本中位数，P95 为成功样本近邻秩；失败单独计数，绝不记成零延迟。20 次的 P95 接近第二慢样本，不能推定长期稳定性。

## 受控目标首字节

表格单元格：成功/总数 · P50 / P95，单位 ms。

'''
report+=phase_table('controlled',['cold','warm','batch'])+'\n## 互联网目标首字节\n\n'+phase_table('internet',['cold','warm','batch'])
report+='\n## 单池连续与 8 并发\n\n'+phase_table('singlepool',['batch'])+'\n'+phase_table('concurrent8',['batch'])
report+='\n## 拥塞控制对照\n\n'
for name in ['ablation','ablation-crossover']:
 rr=[r for r in summary if r['workload']==name and r['phase']!='prime']
 if rr:report+='\n'+name+'\n\n'+table(['路径','阶段','成功/总数','P50 ms','P95 ms'],[[r['version'],r['phase'],f"{r['success']}/{r['total']}",num(r['p50_ms']),num(r['p95_ms'])] for r in rr])
report+='\n## 1 MiB 下载完整性\n\n固定 Content-Length、32 KiB 周期数据与 SHA-256 校验，单次 30 秒预算。超时即失败，保留收到的部分字节，不用定时吞吐替代完整下载。\n\n'
for name in ['ablation-download','ablation-crossover-download','ablation-sameport-download','downloads']:
 rr=other[name]
 if not rr:continue
 report+=name+'\n\n'+table(['路径','轮','完整且校验通过','总时长 s','收到字节','错误'],[[r['version']+'/'+r['protocol'],r['round'],r.get('complete',False) and r.get('checksum_ok',False),num(r['total_ms']/1000),r.get('received_bytes',0),r.get('error','')] for r in rr])+'\n'
report+='\n## 8 秒回环有效吞吐\n\n入口和目标 TLS 建立后计时，单流与 4 流分别 3 轮。只计收到且模式校验通过的业务字节；4 流值是聚合值，非每流速率。每组全部流无早期错误才作为有效组，失败组保留。单位 Mbps。\n\n'
for name in ['ablation-throughput','ablation-crossover-throughput','throughput']:
 rr=other[name]
 if not rr:continue
 groups=collections.defaultdict(list)
 for r in rr:groups[r['version'],r['protocol'],r['workers']].append(r)
 rows=[]
 for k,rs in sorted(groups.items()):
  valid=[r['download_mbps'] for r in rs if not r.get('errors') and r.get('success')==r['workers'] and r.get('download_mbps') is not None]
  rows.append([k[0]+'/'+k[1],k[2],f'{len(valid)}/{len(rs)}',num(statistics.median(valid)) if valid else '—',', '.join(num(r.get('download_mbps')) for r in rs)])
 report+=name+'\n\n'+table(['路径','并发流','有效组','中位数','各轮值'],rows)+'\n'
report+='\n## 空闲后恢复\n\n标称等待 70 秒；因各路径预热/恢复检查串行，使用每行 idle_us 的实际值。idle-resume 的 round=1 是首个新请求，round=2/3 是其后两次，不是三次独立空闲试验。轻量版保留原生命周期行为。\n\n'
idle=load('idle70');report+=table(['路径','阶段','实际 idle 秒','成功','首字节 ms / 错误'],[[r['version']+'/'+r['protocol'],r['phase']+' #'+str(r.get('round',0)),num(r.get('idle_us',0)/1e6) if r.get('round')==1 else '—',not bool(r.get('error')),r.get('error') or num(r.get('first_byte_us',0)/1000)] for r in idle if r['phase'] not in ('prime','idle-prime')])
report+='\n## 安卓协议功能与 UDP\n\n'
rr=other['functional-android'];report+=table(['载体','检查','结果','耗时 ms'],[[r['carrier'],r['check'],'通过' if r['ok'] else r.get('error','失败'),r['elapsed_ms']] for r in rr])
udp=other['udp-matrix'];ug=collections.defaultdict(list)
for r in udp:ug[r['mode'],r['payload_bytes']].append(r)
report+='\nUDP 额外同网对照：直接 UDP 与 FCN QUIC 数据报，32/1100 字节各 30 次，交错发送，无隐式重传，1 秒接收预算。丢失方向、网络拥塞和策略尚未通过抓包完全定位；直接 UDP 本身与 QUIC 的传输开销/拥塞控制不同，不能只看它们的平均值推断协议缺陷。\n\n'
report+=table(['路径','载荷 B','送达/总数','P50 ms','P95 ms'],[[k[0],k[1],f"{sum(r['ok'] for r in rs)}/{len(rs)}",num(statistics.median([r['elapsed_us']/1000 for r in rs if r['ok']])) if any(r['ok'] for r in rs) else '—',num(pct(sorted(r['elapsed_us']/1000 for r in rs if r['ok']),.95))] for k,rs in sorted(ug.items())])
report+='''
## 本地自检与修复

- 8 并发、每流 256 KiB 回环，内容逐字节检查，正确处理发送半关闭。
- 空闲连接关闭后新业务重新握手；显式网络代际 Reset 后新业务恢复；已有业务不重放。
- 错误密钥不得拨目标；exporter 跨连接证明、重复 nonce、篡改消息和畸形长度拒绝；私网/保留目标与超限 nonce 集合拒绝。
- UDP 1100 字节、零字节、超限拒绝；证书不信任必须失败；单个业务取消不影响其他流。
- 重复 race 测试发现 H2 清理回调可能在 handler 返回后仍访问响应对象。已改为等待已启动回调结束后返回，并重复 race 5 轮通过。正式 Next 数据使用修复后的服务器；initial pilot 单独保留，不算最终验收样本。
- FuzzHeader 5 秒覆盖畸形长度/消息解析；详细输出见 local/。本轮未做外部安全审计。

## 尚未验收的生产功能

本轮强制指定路径，未验收自动选路、交互/批量连接分组、正式 App/TUN、iOS、蜂窝与 Wi-Fi 切换、多前置、锁屏耗电、ECH、真实 HTTPS 站点共用、面板动态账号撤销/套餐计量/订阅灰度。H2 流截止采用取消整条请求，尚无独立可恢复的读写超时。原型 UDP 载荷上限 1100 B，没有分片，不是完整任意 UDP VPN。

TLS 与 QUIC 参数由现有实现生成，实验 ALPN、连接行为和包长仍可见。没有受控 GFW 识别率测试，不能据此承诺比 v2 更隐蔽或不会被封锁。

## 文件说明

- requests.csv / latency-summary.csv：逐请求与统计；JSONL 保留失败、prime 与原始计时。
- downloads.csv / throughput.csv：完整下载与定时有效吞吐原值。
- functional-android.jsonl / udp-matrix.jsonl：真机功能与数据报原值。
- metadata.json / network-summary.json / SHA256SUMS：构建与校验信息。
- SPEC-0.1.md 位于上级目录，sources/ 为本轮源码快照，均不含账号密钥。
'''
(D/'REPORT.md').write_text(report)
headers=['测试','路径','阶段','成功/总数','P50 ms','P95 ms','最大 ms']
body=''.join('<tr>'+''.join('<td>'+html.escape(str(v))+'</td>' for v in [r['workload'],labels.get(r['version']+'/'+r['protocol'],r['version']+'/'+r['protocol']),r['phase'],f"{r['success']}/{r['total']}",num(r['p50_ms']),num(r['p95_ms']),num(r['max_ms'])])+'</tr>' for r in summary if r['phase'] not in ('prime','idle-prime'))
(D/'DATA.html').write_text('''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>FastCat Next 原型测试数据</title><style>body{font:15px system-ui;margin:32px;color:#172c3c;background:#f5f7fa}table{border-collapse:collapse;background:white}td,th{padding:10px;border-bottom:1px solid #ddd;text-align:right}td:first-child,td:nth-child(2){text-align:left}th{position:sticky;top:0;background:#17394d;color:white}input{padding:10px;width:320px;margin:16px 0}h1{font-size:26px}</style><h1>FastCat Next 原型测试数据</h1><p>首字节仅统计成功请求，失败单列。完整分析见 REPORT.md。单位 ms。</p><input id=q placeholder="筛选路径、测试或阶段" oninput="document.querySelectorAll('tbody tr').forEach(r=>r.hidden=!r.textContent.toLowerCase().includes(this.value.toLowerCase()))"><table><thead><tr>'''+''.join('<th>'+x+'</th>' for x in headers)+'</tr></thead><tbody>'+body+'</tbody></table></html>')
print(json.dumps(dict(latency_rows=len(raw),summary_groups=len(summary),other={n:len(r) for n,r in other.items()}),ensure_ascii=False))
