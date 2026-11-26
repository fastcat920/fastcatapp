# -*- coding: utf-8 -*-
exec(open('/tmp/fc-next-tuic/analyze.py').read().split('for r in summary:print(r)')[0])
import html,zipfile,hashlib,shutil
names={'next-base':'Next QUIC 原版','next-opt':'Next QUIC 候选版','tuic':'TUIC v5'}
def table(head, rr):
 return '<table><thead><tr>'+''.join('<th>'+html.escape(str(x))+'</th>' for x in head)+'</tr></thead><tbody>'+''.join('<tr>'+''.join('<td>'+html.escape(str(x))+'</td>' for x in r)+'</tr>' for r in rr)+'</tbody></table>'
lat=[]
for r in summary:
 lat.append([r['test'],names.get(r['version'],r['version']),r['phase'],str(r['success'])+'/'+str(r['total']),r['p50_ms'],r['p95_ms'],r['mean_ms']])
dls=[r for r in raw if r.get('phase')=='download'];bulk=[r for r in raw if r.get('phase')=='timed_bulk']
dlrows=[[r['expected_bytes']//(1<<20),names.get(r['version'],r['version']),r['round'],r.get('complete',False),r['total_ms']/1000,round(r['received_bytes']/(1<<20),3),r.get('checksum_ok','—'),r.get('error','')] for r in dls]
br=[]
for v in names:
 for w in [1,4]:
  g=[r for r in bulk if r['version']==v and r['workers']==w];good=[r for r in g if r.get('download_mbps') is not None]
  if g:br.append([names[v],w,len(good),len(g),q([r['download_mbps'] for r in good],.5),q([r['download_mbps'] for r in good],.95)])
screen=[]
for pattern in ['screen-*.jsonl','legacy-[1-5]*.jsonl','isolate-cc-*.jsonl']:
 for f in sorted(O.glob(pattern)):
  for r in rows(f):
   if r.get('phase')=='download':screen.append([f.stem,r.get('complete',False),r['total_ms']/1000,round(r['received_bytes']/(1<<20),3),r.get('error','')])
iso=[]
f=O/'isolate-coalesce.jsonl'
if f.exists():
 for v in names:
  for ph in ['cold','warm','batch']:
   g=[r for r in rows(f) if r.get('version')==v and r.get('phase')==ph];a=[r['first_byte_us']/1000 for r in g if not r.get('error')]
   if g:iso.append([names[v],ph,len(a),len(g),q(a,.5),q(a,.95)])
body='''<h1>Next QUIC 优化与 TUIC 对照</h1><p>2026-11-22 · 安卓真机核心测试 · 香港公网节点</p>
<h2>配置与验收原则</h2><p>原版：现有 BBR 实现、即时发送 OPEN、原接收窗口。候选版：bbr_meta_v1 实现 + OPEN 与首段业务合并，接收窗口不变。名称中的 meta_v1/v2 是依赖库实现名称，不能据此称作 BBR 算法的标准代际。TUIC v5 使用 CatNode/Xray 实际服务端，客户端为同一 Android 可执行文件里的 Mihomo TUIC，BBR、ReduceRtt=false、FastOpen=false。两种实现并非相同代码栈。</p>
<p>同一安卓 TFY-AN00（Android 12），同一 Wi-Fi、同一 VPS/IP、证书验证开启。正式对照关闭详细追踪；循环轮换协议先后顺序。原版 Next 端口 19458，候选版 19459，TUIC 19451。受控目标为同机 HTTPS；外网目标为 www.cloudflare.com。固定 IP 入口用于隔离 DNS 影响。本轮并非 App 界面、蜂窝或切网验收，也不代表隐蔽性检测结果。</p>
<p>首字节包含入口连接/复用、目标 TLS 与 HTTP 响应；冷启动每次新建池，连续请求轮换 3 个池，八路并发用单池。P50/P95 采用成功样本 nearest-rank 分位数，失败另列，不能把失败排除后称总体无尾延迟。大文件预算：1 MiB 60 秒、32 MiB 90 秒、100 MiB 180 秒；所有失败保留。MiB=1,048,576 字节。下载完成要求长度与内容校验通过；超时行只说明收到的部分字节。</p>
<h2>本轮实现</h2><ul><li>增加有界 QUIC 窗口和 BBR 实验配置，默认仍保留原值。</li><li>可选合并 OPEN 与最多 16 KiB 首段业务，保持服务端先发、半关闭与大流量双向并行；不重放业务。</li><li>增加可选连接级发送、丢失判定、PTO、窗口阻塞和 RTT/CWND 计数；只记录汇总，不包含凭证或载荷。</li><li>本地 race 与 vet 已通过，并额外验证 BBR 候选的并发回显。</li></ul>
<h2>短请求完整结果</h2>'''+table(['测试','实现','阶段','成功/总数','P50 ms','P95 ms','均值 ms'],lat)+'''<h2>大文件逐次结果</h2>'''+table(['MiB','实现','轮次','完整','耗时 s','收到 MiB','校验','错误'],dlrows)+'''<h2>固定 8 秒回显有效吞吐</h2><p>每组 3 轮、1/4 路。计收到且内容验证正确的载荷，报告 download_mbps；与单向 HTTP 下载口径不同，建立连接时间另计，不计入固定 8 秒窗口。成功准备不等于满速，无效/准备失败单独保留在原始数据。</p>'''+table(['实现','并发','有数值组','总组','中位 Mbps','P95 Mbps'],br)+'''<h2>拆分 OPEN 合并的影响</h2><p>这里两种 Next 共用 19458 和原 BBR；next-opt 仅打开合并，next-base 保持即时发送。TUIC 同轮用于观察时间波动，不与另一场测试直接拼接为一组样本。</p>'''+table(['实现','阶段','成功','总数','P50 ms','P95 ms'],iso)+'''<h2>筛选和同端口 BBR 复测</h2><p>wide 扩窗与 conservative 低初始窗口/低启动增益没有稳定改善，不设为默认。同端口 BBR 按“候选、原版、原版、候选”顺序，关闭首包合并，追踪开启仅作机制诊断，不能与正式关闭追踪的数据直接合并。筛选阶段少量样本不作显著性证明。</p>'''+table(['试验','完整','耗时 s','收到 MiB','错误'],screen)+'''<h2>解释与限制</h2><p>冷启动、连续请求、并发和下载会出现不同排名。只在部分指标变好，不足以升级默认。当前没有证明更宽窗口能解决失速，也没有证明首包合并全面降低延迟。诊断计数里有大量 recovery:packet_lost，但那是发送端的丢失判定，可能含重排序和误判，不能直接写成物理丢包率。没有两端抓包与 ACK 时间线时，不能把根因完全归到运营商、GFW 或 BBR。</p>
<p>单设备、单 Wi-Fi、单时段、不同服务端实现与不同 UDP 端口仍是限制；同端口 BBR 复测能减少端口混杂，不能消除时间波动。100 MiB 仅两轮，P95 不能用于稳定性承诺。未测试能耗、锁屏、蜂窝、正式 App、面板计量、ECH 或识别概率。生产 443/18447 配置不变。</p>
<h2>原始资料</h2><p>同目录 latency.csv、summary.json、all-final-rows.json、各阶段 jsonl、metadata.json、validation.txt、sources 保留统计、失败与复现材料。配置凭证不打包。</p>'''
css='body{font:16px/1.6 -apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif;max-width:1250px;margin:40px auto;padding:0 24px;color:#172536;background:#f7f9fc}h1,h2{color:#122d4e}table{border-collapse:collapse;background:white;width:100%;font-size:14px;margin:20px 0;display:block;overflow:auto}th,td{padding:8px 12px;border:1px solid #dae2ec;text-align:right;white-space:nowrap}th:first-child,td:first-child{text-align:left}thead{background:#e4edf7}p{max-width:1000px}'
(O/'REPORT.html').write_text('<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Next QUIC 与 TUIC 测试报告</title><style>'+css+'</style>'+body+'</html>')
print('REPORT HTML generated',len(raw),'rows')
