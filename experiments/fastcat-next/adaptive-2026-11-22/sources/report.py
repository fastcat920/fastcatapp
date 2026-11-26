# -*- coding: utf-8 -*-
from pathlib import Path
import json,csv,statistics,math,html
O=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/adaptive-2026-11-22')
N={'next-base':'Next 单连接','next-fixed':'Next 上轮双连接','next-opt':'Next 新调度','tuic':'TUIC 默认','tuic-dual':'TUIC 双连接'}
def rows(f):
 a=[]
 for l in f.read_text().splitlines():
  try:r=json.loads(l)
  except:continue
  if isinstance(r,dict):a.append(dict(r,test=f.stem))
 return a
def quant(a,p):
 a=sorted(a);return round(a[max(0,math.ceil(len(a)*p)-1)],2) if a else None
def med(a):return round(statistics.median(a),2) if a else None
def table(h,a):return '<div class="scroll"><table><thead><tr>'+''.join('<th>'+html.escape(str(x))+'</th>' for x in h)+'</tr></thead><tbody>'+''.join('<tr>'+''.join('<td>'+html.escape(str(x))+'</td>' for x in r)+'</tr>' for r in a)+'</tbody></table></div>'
R=[]
for f in sorted(O.glob('final-*.jsonl')):R+=rows(f)
(O/'all-final-rows.json').write_text(json.dumps(R,indent=2))
lat=[];mixed=[];bulk=[];parallel=[];downloads=[]
for v in N:
 for p in ['cold','warm','batch']:
  g=[r for r in R if r.get('version')==v and r.get('phase')==p];a=[r['first_byte_us']/1000 for r in g if not r.get('error')]
  if g:lat.append([N[v],p,str(len(a))+'/'+str(len(g)),quant(a,.5),quant(a,.95)])
 allg=[r for r in R if r.get('version')==v and r.get('phase')=='mixed'];g=[r for r in allg if r.get('background_active',0)>0];a=[r['first_byte_us']/1000 for r in g if not r.get('error')];d=[r for r in R if r.get('version')==v and r.get('phase')=='mixed_background']
 if allg:mixed.append([N[v],str(len(a))+'/'+str(len(g)),len(allg),quant(a,.5),quant(a,.95),sum(r.get('complete')==True for r in d),len(d)])
 for w in [1,4]:
  g=[r for r in R if r.get('phase')=='timed_bulk' and r.get('version')==v and r.get('workers')==w];a=[r['download_mbps'] for r in g if r.get('success')==w]
  if g:bulk.append([N[v],w,str(len(a))+'/'+str(len(g)),med(a),', '.join(str(round(x,2)) for x in a)])
 g=[r for r in R if r.get('version')==v and r.get('phase')=='parallel_download'];a=[r['verified_mbps'] for r in g if r.get('success')==r.get('workers')]
 if g:parallel.append([N[v],sum(r['success'] for r in g),sum(r['workers'] for r in g),med([r['verified_mbps'] for r in g]),med(a),', '.join(str(round(r['verified_mbps'],2))+' ('+str(r['success'])+'/'+str(r['workers'])+')' for r in g)])
for r in R:
 if r.get('phase')=='download':downloads.append([N[r['version']],r['expected_bytes']//(1<<20),r['round'],r['complete'],r['total_ms']/1000,round(r.get('received_bytes',0)/(1<<20),2),r.get('checksum_ok','—'),r.get('error','')])
body='''<h1>Next QUIC 调度优化与 TUIC 对照</h1><p>2026-11-22 · 安卓 TFY-AN00 / Android 12 · 香港公网节点 · 同 Wi-Fi 原型核心测试</p>
<h2>这次改了什么</h2><p>新增可选 <code>AdaptiveLanes=true</code>（要求 <code>QUICLanes=2</code>），保留上轮按活跃流数量分配的模式用于对照。新调度优先使用已就绪的连接，未就绪的另一通道按需在后台准备，业务 Dial 不等待它；后台单次最多 1 秒、每通道每秒最多发起一次，随 Reset/Close/父上下文取消。主、次通道均可对称恢复。</p><p>两个通道都可用时，结合活跃流、近期有效读写字节速率、正在 Write 的应用字节量与入口 RTT 作有界权重调整。速率权重有限，空闲超过 3 秒失效，Reset 清空旧代数据，旧流关闭不能扣减新代计数。不会仅凭目标没有返回业务数据而判定入口坏掉。现有流不迁移、不重放、不跨连接拆分。</p><p>显式 Warm 会先准备主通道，再等待有界的可选副通道准备；第二条失败不使已经可用的主通道失败。普通冷启动/串行请求不主动创建副通道，并发时再后台准备。默认仍为单通道；没有改 BBR、接收窗口、密码或 FCN/1 消息格式。H2 与正式 App 未升级。</p>
<h2>对照口径</h2><p>同一 Android 原生可执行文件、同一 Wi-Fi、同一 VPS（191.223.214.8）。三种 Next 共用 UDP 19458 和标准 BBR；TUIC 使用实际 CatNode/Xray TUIC v5，19451、BBR、ReduceRtt=false、FastOpen=false。TUIC 双连接使用两个未改动的 TUIC 客户端按活跃流分配，以对照连接资源。协议轮换先后顺序；正式性能测试关闭详细追踪。</p><p>短请求每组冷启动 12、连续 12、四路 16、预热 3。混合负载每轮两条 16 MiB 后台下载，与 12 条顺序前台 HEAD 请求共享一个客户端，共两轮；表中另列开始时至少一条下载仍活跃的前台样本数，不能把背景已经完成的请求当作持续负载样本。各组负载活跃时长不同，比较不是精确相同利用率。</p><p>回显每组单路/四路各 3 轮、每轮 10 秒，统计收到并校验正确的载荷，握手准备另计。单向四路下载每任务 8 MiB、共 3 轮、共享一个客户端；失败组的已校验字节除以整组耗时仍保留，另列仅完整组的中位数，不能忽略完成率。显式 Warm 的准备时间和校验耗时均包含在整组总耗时中。32 MiB 每组两轮、预算 90 秒；100 MiB 仅 Next 单连接、新调度和 TUIC 默认各一轮、预算 180 秒。单流的新调度仍只用主通道，不应将一次快慢差异归因于双连接。MiB=1,048,576 字节。</p><p>P50/P95 使用成功样本 nearest-rank，失败另列；12 个样本的 P95 是该组最大值。吞吐中位数使用通常的中位数定义，仅 2–3 轮，不作显著性或长期稳定保证。</p>
<h2>短请求结果</h2>'''+table(['实现','阶段','成功/总数','首字节 P50 ms','首字节 P95 ms'],lat)+'''<h2>混合负载：后台下载时的前台请求</h2>'''+table(['实现','有后台时成功/样本','前台总样本','加载时 P50 ms','加载时 P95 ms','后台下载完整','后台总数'],mixed)+'''<h2>固定时长有效回显吞吐</h2>'''+table(['实现','并发','有效组/总组','中位 Mbps','各轮 Mbps'],bulk)+'''<h2>四路单向下载</h2>'''+table(['实现','完整任务','总任务','全部组有效中位 Mbps','完整组中位 Mbps','各轮有效 Mbps (完成/总数)'],parallel)+'''<h2>单路下载逐次结果</h2>'''+table(['实现','MiB','轮次','完整','秒','收到 MiB','校验','错误'],downloads)+'''<h2>单流诊断：定位到哪一步</h2><p>独立追踪组四次 32 MiB 均完成：单连接原版 8.833 / 23.688 秒；新调度单流 8.277 / 25.538 秒。该候选为修正边界问题之前的诊断构建，涉及的单流路径未使用被修正的双通道恢复/过期分支；不并入最终性能样本。它们都只使用一个通道。追踪显示：快组第 5 秒 CWND 约 1.48 / 1.59 MB，慢组约 0.237 / 0.305 MB；慢组随后缓慢增长到约 0.74 MB。慢组 RTT 仍约 96–117 ms，未出现持续的大 RTT 膨胀。</p><p>四次服务端下载 Write 最大等待约 132 / 381 / 251 / 135 ms，没有捕获超过半秒的下行写阻塞；慢组前 15 秒窗口阻塞帧为零。因此本轮没有证据支持“接收窗口卡死”或“服务端一次写操作卡住十几秒”。线索更符合早期恢复/发送节奏较低、拥塞窗口爬升慢，但未确定底层触发因素，也没有直接复现此前那次 77 秒的完整时间线。<strong>单流失速未宣告修复。</strong></p><p>快组发送的 QUIC 包字节约 42.1/42.8 MB，慢组约 49.1/46.2 MB，业务载荷均为 32 MiB。该计数不含 UDP/IP 外层，含重传；丢失判定次数也不等于物理丢包率。上传 Read 长等待是 GET 发完后等待响应期间的正常现象，不能当入口故障。</p>
<h2>验证与限制</h2><p>本地 race/vet 通过：覆盖未就绪副通道、主通道失效、后台握手取消、代际计数、速率过期、半关闭、UDP association 和共享下载客户端归属。仍只有单台设备、单 Wi-Fi、单节点；没有蜂窝、多网络、锁屏耗电或识别概率验收。多连接有额外握手与缓冲成本；两个通道轮换期间沿用每池最多两条物理连接的边界，总上限四条。</p><p>初次性能采样期间自检发现主通道恢复不对称及旧速率样本复用问题，已停止该次运行并修正。<code>superseded-*</code> 是保留的被替代数据，主动停止造成的退出 143 不计入最终协议失败；它们未并入以上成绩。<code>diagnostic-single</code> 和早期 server 追踪只作诊断；最终 <code>final-*</code> 使用重新编译并冻结的版本。二进制 SHA256、源码、原始 JSONL、CSV 与验证输出均保留；不打包凭证。</p>'''
css='body{font:16px/1.65 -apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif;max-width:1250px;margin:35px auto;padding:0 24px;background:#f7f9fc;color:#193047}h1,h2{color:#173d61}table{border-collapse:collapse;background:white;margin:18px 0;width:100%;font-size:14px}td,th{border:1px solid #d9e2ed;padding:9px 12px;text-align:right;white-space:nowrap}td:first-child,th:first-child{text-align:left}th{background:#e5edf6}.scroll{overflow:auto}p{max-width:1080px}code{background:#e5ecf5;padding:2px 5px}'
(O/'REPORT.html').write_text('<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Next QUIC 新调度与 TUIC 对照</title><style>'+css+'</style>'+body+'</html>')
for phases,name in [({'cold','warm','prime','batch'},'latency'),({'mixed'},'mixed-latency'),({'mixed_background','mixed_summary'},'mixed-downloads'),({'timed_bulk'},'throughput'),({'parallel_download'},'parallel-downloads'),({'download'},'downloads')]:
 a=[r for r in R if r.get('phase') in phases]
 if a:
  with (O/(name+'.csv')).open('w') as f:
   w=csv.DictWriter(f,fieldnames=sorted({k for r in a for k in r}));w.writeheader();w.writerows(a)
print('Updated report',len(R),'formal rows')
