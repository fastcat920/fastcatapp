from pathlib import Path
import json,statistics,collections,html
D=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/acceptance-2026-11-21')
def load(n):return [json.loads(x) for x in (D/(n+'.jsonl')).read_text().splitlines() if x.startswith('{')]
def table(head,rows):return '| '+' | '.join(head)+' |\n| '+' | '.join(['---']*len(head))+' |\n'+''.join('| '+' | '.join(map(str,r))+' |\n' for r in rows)
def num(x):return f'{x:,.1f}' if x is not None else '—'
rs=[dict(workload=w,**r) for w in ['controlled','internet','singlepool','concurrent8','idle70'] for r in load(w)]
formal=[r for r in rs if r['phase'] not in ('prime','idle-prime')];g=collections.defaultdict(list)
for r in formal:g[r['version'],r['protocol']].append(r)
counts=table(['路径','正式短请求成功/总数','失败数'],[[v+'/'+p,f"{sum(not bool(r.get('error')) for r in rr)}/{len(rr)}",sum(bool(r.get('error')) for r in rr)] for (v,p),rr in sorted(g.items())])
summary=json.loads((D/'latency-summary.json').read_text());pick=lambda w,v,p,phase:next(r for r in summary if (r['workload'],r['version'],r['protocol'],r['phase'])==(w,v,p,phase))
comparison=[]
for w,phase,title in [('internet','cold','互联网冷启动'),('internet','warm','互联网连续'),('internet','batch','互联网4并发'),('concurrent8','batch','受控8并发'),('singlepool','batch','受控单池连续')]:
 a=pick(w,'next','quic',phase);b=pick(w,'v2-bbr','h3',phase);comparison.append([title,num(a['p50_ms'])+' / '+num(a['p95_ms']),num(b['p50_ms'])+' / '+num(b['p95_ms'])])
DL=load('downloads');nextdl=[r for r in DL if r['version']=='next'];rawdl=[r for r in nextdl if r['protocol']=='quic'];h2dl=[r for r in nextdl if r['protocol']=='h2'];passdl=lambda rr:sum(bool(r.get('complete')) and bool(r.get('checksum_ok')) for r in rr)
same=load('ablation-sameport-download');sametable=table(['同端口模式','校验通过/总数','每轮时长 s','失败收到字节'],[[v,f"{passdl([r for r in same if r['version']==v])}/3",', '.join(num(r['total_ms']/1000) for r in same if r['version']==v),', '.join(str(r.get('received_bytes',0)) for r in same if r['version']==v and not r.get('complete')) or '无'] for v in ['v2-reno','v2-bbr']])
T=load('throughput');tg=collections.defaultdict(list)
for r in T:tg[r['version'],r['protocol'],r['workers']].append(r)
def med(v,p,w):
 a=[r['download_mbps'] for r in tg[v,p,w] if not r.get('errors') and r.get('success')==w and r.get('download_mbps') is not None];return num(statistics.median(a)) if a else '—'
intro=f'''本轮交付了独立的 FCN/1 协议原型、Linux 服务端、安卓核心测试工具和规范；完成了 {len(formal)} 次正式短请求、主对照 18 次 1 MiB 下载、另外 12 次 1 MiB 拥塞配置验证、6 次 10/100 MiB 传输、36 组单/四流吞吐、空闲恢复与 UDP 对照。**原型 TCP 功能验证通过，生产替换验收尚未通过，保持 v2 正式入口不变。**

判断依据：

- Next H2 与原生 QUIC 的正式短请求均为 167/167，半关闭、错误凭证拦截、网络代际重置、证书验证、取消隔离与空闲后新会话重建通过。
- Next 原生 QUIC 的 1 MiB 下载为 {passdl(rawdl)}/3：一次入口在 5 秒总截止前未完成，尚未从抓包定位原因；H2 为 {passdl(h2dl)}/3，但一次耗时 12.879 秒。失败和慢样本全部保留。
- Next 在本轮 4/8 并发的首字节表现较好；单池串行和连续请求 P95 没有全面优势。不能以“新格式”解释所有改善：v2 BBR 本身的吞吐也大幅提高。
- 原生 UDP 已连通，1100 B 上限与超限拒绝正常；同网出现明显丢包，尚不具备稳定实时业务的上线证据。
- 原型未接正式 App/面板/自动选路/ECH。原生 QUIC 使用可见实验 ALPN，**没有隐蔽性优于 v2 或避免 GFW 识别的验收结论**。

{counts}

本轮关键首字节对照（ms，P50 / P95；各组样本数见下文）：

{table(['场景','Next 原生 QUIC BBR','v2 H3 BBR'],comparison)}

原生 QUIC 8 秒有效吞吐中位数：Next 单流 {med('next','quic',1)} / 四流聚合 {med('next','quic',4)} Mbps；v2 BBR 为 {med('v2-bbr','h3',1)} / {med('v2-bbr','h3',4)} Mbps。每组仅三轮，波动与完整下载结果必须一起看。

'''
p=D/'REPORT.md';s=p.read_text().replace('待所有测试完成后补充最终结论。',intro)
extra=f'''## 同端口追加验证

为排除首轮 19440/19442 端口不同这一因素，在全部主测试结束并清理后，重新使用 **同一 19442 入口**、同一服务端程序、同一证书/目标/账号。仅在双端 Reno 与 BBR 间切换，轮次顺序为 Reno→BBR、BBR→Reno、Reno→BBR，各下载 1 MiB。每次重启测试服务获得新连接，目标数据都校验长度与 SHA-256，30 秒截止。没有修改生产服务。

{sametable}

这组是在主测试之后的另一时间段，不能与前面的下载时长直接合并成同一次样本。它用于检查同端口下现象能否重现；不代表所有网络或所有 BBR 实现都得到同样收益。

## 如何解释收益和失败

1. **先修配置，再评估协议。** 原 v2 走库默认 Reno，与 Hysteria 2/TUIC 的 BBR 不在同一条件。首轮与同端口追加组是独立验证。新协议不能把换拥塞控制的收益都算到新消息格式上。
2. **Next 的结构收益在减少等待与独立流。** 原生 QUIC 完成 TLS 后即可将授权 OPEN 和首个业务数据连续排队，无需额外 Noise 授权往返或等待 HTTP CONNECT 成功后才开始业务握手。没有应用层二次多路复用与逐记录加密。这提供省去等待的机会；当前实现、窗口和 Go 版本也存在差异，不能把全部毫秒差视作格式本身的因果效果。
3. **并发收益更一致，串行仍有取舍。** 对每轮做配对、并发按批次聚合后，互联网 4 并发 5/5 批 Next 更快；其他冷启动/连续组的配对中位数差参考区间仍跨零。详见 paired-round-analysis.json，不能据一次 P50 就宣称全面领先。
4. **入口失败已定位到预算层，网络根因仍未知。** 原生 QUIC 下载失败行是约 5002 ms 的 entry 错误，尚未建立目标 TLS，没有收到部分文件。源码 acquire 将解析、建 socket 与 QUIC 握手放在一个 5 秒总预算下，另外 QUIC 还有 5 秒无进展握手截止；两者语义不同。本轮没有该次失败的逐包记录，不能断言是 DNS、MTU、丢包或服务器算力。没有通过延长超时、自动重试或删除样本把它变成“成功”。后续应拆分时序与 QUIC 丢包/PTO 记录，并验证业务提交前的 H2 选路与回退。
5. **空闲恢复是明确的功能改善。** Next 发现物理连接不再可用时，为新业务重新建连接、重新计算 exporter 绑定证明；轻量版继续复用已关闭会话的行为在本轮重现。已有业务没有自动重放。
6. **UDP 是连通性验证，不是无损承诺。** 首轮 17/20 个 1100 B 报文收到回显；追加矩阵给出直接 UDP 与隧道的各 30 次结果。它们没有应用层重传，仍需多网络、长时与方向抓包才能定位丢失；目前不建议把本轮结果当作语音/游戏稳定性保证。
7. **资源字段只用于诊断。** 吞吐行的 heap、分配量和 goroutines 属于测试进程，不是每账号成本；服务端快照承受不同数量的载体与请求，也不能据此下耗电或多用户容量结论。

## 后续交付顺序

- 在原型增加入口分阶段与 QUIC 丢包/PTO 诊断，复现入口超时；保留原始失败，验证新业务选路/回退与证书、认证失败的停止条件。
- 原生 QUIC 与真实 HTTP/3 载体并列验证，测量 HTTP 层开销和真实握手行为；复用 v2 的入口加密 DNS/ECH，但必须对新载体重新验收，不继承旧实验结论。
- 完成账号动态撤销、每账号限额与计量接口、正式 App/TUN 接入，再做锁屏、多网络、多前置与面板灰度/回滚。达到门槛后才替换正式入口。

上轮七协议报告用于提出候选机制；本轮只同网重测 v2 两种拥塞配置、最新轻量版与 Next，不把不同时间的 Hysteria 2/TUIC 等结果拼成同一张速度排行。上轮报告位于 ../../fastcat-v3/seven-way-2026-11-21/REPORT.md。

'''
large=load('large-10485760')+load('large-104857600')
largeTable=table(['路径','目标 MiB','完整且校验通过','收到 MiB','时长 s','预算 s','错误'],[[r['version']+'/'+r['protocol'],r['expected_bytes']//(1<<20),bool(r.get('complete')) and bool(r.get('checksum_ok')),num(r.get('received_bytes',0)/(1<<20)),num(r['total_ms']/1000),r.get('deadline_seconds'),r.get('error','')] for r in large])
extra+='## 10 MiB / 100 MiB 完整传输门槛\n\n每路径、每文件大小各一次，不重试、不补成成功样本；10 MiB 总预算 90 秒，100 MiB 240 秒。扩容的是目标文件大小和测试工具截止，没有修改协议实现。该阶段晚于主对照，不能与之前 1 MiB 时长合并统计。原 Reno 与轻量版 H3 在 1 MiB 阶段已暴露持续失败，因此只对 Next 两种载体和 v2 BBR 做大文件门槛。\n\n'+largeTable+'\nNext 原生 QUIC 的 10/100 MiB 均通过；Next H2 的 10 MiB 在 90 秒只收到 2.5 MiB，100 MiB 后续却在 87.462 秒通过。两条结果全部保留，不能用较晚一次成功证明较早问题已解决。100 MiB 单向下载中 Next QUIC 23.785 秒、v2 BBR 24.171 秒，差异很小，且每组只有一次。8 秒双向回环与长时间单向下载不是同一负载，不能把短窗口吞吐倍数推广为长期带宽能力。\n\n'
s=s.replace('## 尚未验收的生产功能',extra+'## 尚未验收的生产功能')
s+='\n## 图表\n\n![首字节对照](latency.png)\n\n![有效吞吐对照](throughput.png)\n'
p.write_text(s)
h=D/'DATA.html';text=h.read_text().replace('<input id=q','<p><strong>验收结论：TCP 原型功能通过，生产替换尚未通过。</strong>原生 QUIC 下载有一次入口超时；UDP 送达不稳定；未验收隐蔽性。</p><p><img src="latency.png" style="max-width:100%"><img src="throughput.png" style="max-width:100%"></p><input id=q');h.write_text(text)
(D/'overview.json').write_text(json.dumps(dict(formal_short_requests=len(formal),raw_short_requests=len(rs),next_download_complete=passdl(nextdl),next_download_total=len(nextdl),sameport_downloads=len(same),throughput_groups=len(T),valid_throughput_groups=sum(not r.get('errors') and r.get('success')==r['workers'] for r in T),large_download_attempts=len(large),large_download_complete=passdl(large),production_replacement_accepted=False),indent=2))
print((D/'overview.json').read_text())
