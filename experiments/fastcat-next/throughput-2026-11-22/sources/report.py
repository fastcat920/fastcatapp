# -*- coding: utf-8 -*-
from pathlib import Path
import json,csv,statistics,math,html,shutil,hashlib,zipfile
O=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/throughput-2026-11-22')
names={'next-base':'Next 原版（单通道）','next-opt':'Next 吞吐版（双通道）','tuic':'TUIC 默认','tuic-dual':'TUIC 双连接对照'}
def rows(p):
 a=[]
 for l in p.read_text().splitlines():
  try:r=json.loads(l)
  except:continue
  if isinstance(r,dict):a.append(dict(r,test=p.stem))
 return a
def q(a,p):
 a=sorted(a);return round(a[max(0,math.ceil(len(a)*p)-1)],2) if a else None
def tab(head,a):
 return '<div class="scroll"><table><thead><tr>'+''.join('<th>'+html.escape(str(v))+'</th>' for v in head)+'</tr></thead><tbody>'+''.join('<tr>'+''.join('<td>'+html.escape(str(v))+'</td>' for v in r)+'</tr>' for r in a)+'</tbody></table></div>'
raw=[]
for f in sorted(O.glob('final-*.jsonl')):raw+=rows(f)
control=[]
for f in sorted(O.glob('control-*.jsonl')):control+=rows(f)
(O/'all-final-rows.json').write_text(json.dumps(raw,indent=2));(O/'all-control-rows.json').write_text(json.dumps(control,indent=2))
lat=[]
for v in ['next-base','next-opt','tuic']:
 for phase in ['cold','warm','batch']:
  g=[r for r in raw if r.get('version')==v and r.get('phase')==phase];a=[r['first_byte_us']/1000 for r in g if not r.get('error')]
  if g:lat.append([names[v],phase,str(len(a))+'/'+str(len(g)),q(a,.5),q(a,.95)])
def bulk(data):
 rr=[]
 for v in names:
  for w in [1,4]:
   g=[r for r in data if r.get('phase')=='timed_bulk' and r.get('version')==v and r.get('workers')==w];a=[r['download_mbps'] for r in g if r.get('success')==w]
   if g:rr.append([names[v],w,str(len(a))+'/'+str(len(g)),round(statistics.median(a),2) if a else None,', '.join(str(round(x,2)) for x in a)])
 return rr
def pd(data):
 rr=[]
 for v in names:
  g=[r for r in data if r.get('phase')=='parallel_download' and r.get('version')==v];a=[r['verified_mbps'] for r in g if r.get('success')==r.get('workers')]
  if g:rr.append([names[v],sum(r['success'] for r in g),sum(r['workers'] for r in g),round(statistics.median(a),2) if a else None,', '.join(str(round(x,2)) for x in a)])
 return rr
down=[]
for r in raw:
 if r.get('phase')=='download':down.append([names[r['version']],r['expected_bytes']//(1<<20),r['round'],r.get('complete'),r['total_ms']/1000,round(r.get('received_bytes',0)/(1<<20),3),r.get('checksum_ok','—'),r.get('error','')])
gso=[]
for f in sorted(O.glob('gso-[1-4]*.jsonl')):
 for r in rows(f):
  if r.get('phase')=='timed_bulk':gso.append([f.stem,names[r['version']],r['workers'],round(r['download_mbps'],2),r.get('success')])
body='''<h1>Next QUIC 吞吐优化与 TUIC 对照</h1><p class="muted">2026-11-22 · 安卓 TFY-AN00 / Android 12 · 同 Wi-Fi 与香港 VPS · 原型核心测试</p>
<h2>实现与配置</h2><p>本轮保留原 BBR、接收窗口、即时 OPEN、TLS 与认证格式，新增 <code>Config.QUICLanes=2</code>：新 TCP 流按活跃流数量分配到两个独立连接池；串行请求优先使用主通道，并发时按需创建第二条连接。已经开始的流固定在原连接，不迁移、不重放，不把一条 TCP 流拆到两条 QUIC 连接。UDP 控制与数据仍交给主通道，避免错误的 association 归属。</p><p>默认值 0/1 维持单通道。双通道平时至多两条 QUIC 连接，每个池在请求数耗尽轮换时沿用原先至多两条物理连接的边界，因此轮换期间总上限为四条；所有池随 Close、Reset、上层取消一起关闭或重置。额外连接会增加握手、缓冲和资源成本。本轮没有能耗验收，不能声称更省电。</p>
<h2>测试口径</h2><p>原版与吞吐版共用同一服务端与 UDP 19458，唯一主差异为连接分配；TUIC 默认用 19451，实际 CatNode/Xray TUIC v5，BBR、ReduceRtt=false、FastOpen=false。两端证书验证开启。Android 同一原生对照程序运行，应用 VPN 在测试时断开，结束后恢复。未改正式 App、生产 443/18447 或面板。</p><p>协议按轮次轮换顺序，正式追踪关闭。单/四路回显固定 10 秒，统计收到且模式校验通过的载荷，连接/TLS 准备不计入这 10 秒；上传方向与下行共享公网，因此它不是纯单向下载测速。四路单向下载则是每任务 8 MiB、四任务共享一个协议客户端，统计从客户端创建到四任务校验完成的总耗时和已校验字节。TUIC 默认仍为一个客户端池；双连接对照明确使用两个未改动的 TUIC 客户端，将新流按活跃数量分配，而非改变 TUIC 协议。</p><p>32 MiB 单路下载三轮、每轮预算 90 秒；100 MiB 只做一轮、预算 180 秒，不能算 P95 或稳定性承诺。MiB=1,048,576 字节。失败逐次保留，下载必须校验内容才算完整。短请求每组冷启动 12、连续 12、四路 16、预热 3；P50/P95 用成功样本 nearest-rank，12 个样本的 P95 实际为该组最大值。单路吞吐版仅使用主通道，观察到的差异不能归因为双连接提速。</p>
<h2>主对照：有效回显吞吐</h2>'''+tab(['实现','并发','有效组/总组','中位 Mbps','各轮 Mbps'],bulk(raw))+'''<h2>主对照：四路单向下载</h2>'''+tab(['实现','完整任务','总任务','总吞吐中位 Mbps','各轮总吞吐 Mbps'],pd(raw))+'''<h2>连接数相同的补充对照</h2><p>以下是后续独立轮次，用来区分增加拥塞窗口与协议效率，不能与前一场不同时间的数据直接拼为一轮。TUIC 双连接同样承担额外资源成本。</p>'''+tab(['实现','并发','有效组/总组','中位 Mbps','各轮 Mbps'],bulk(control))+tab(['实现','完整任务','总任务','总吞吐中位 Mbps','各轮总吞吐 Mbps'],pd(control))+'''<h2>短请求回归</h2>'''+tab(['实现','阶段','成功/总数','首字节 P50 ms','首字节 P95 ms'],lat)+'''<h2>单路文件逐次结果</h2>'''+tab(['实现','MiB','轮次','完整','耗时 s','收到 MiB','校验','错误'],down)+'''<h2>未采用的批处理调整</h2><p>同端口保持 BBR 不变，按 GSO 开/关/关/开筛选。关闭服务端 GSO 的四路结果一次提升、一次较小，单路没有稳定改善；未纳入正式吞吐版，也没有更改系统网络参数。以下 8 秒筛选不能与正式 10 秒样本合并。</p>'''+tab(['试验','实现','并发','Mbps','成功流'],gso)+'''<h2>判断边界</h2><p>双通道本质上引入第二个拥塞控制域和源端口，收益可能来自避免一个连接失速、分散 ACK/拥塞恢复或路径按五元组处理差异，不能仅凭本轮数据确定是哪一种，也不能称其为新加密算法的收益。不是在相同连接资源下证明 Next 超越 TUIC。</p><p>只有一台安卓、一个 Wi-Fi 和一个香港节点，吞吐组仅 2–3 轮；没有跨蜂窝、长期锁屏、能耗或抗识别测量。默认仍保留单通道，双通道为显式可选吞吐模式；不把一次局部改进推广为所有网络都更快。</p>
<h2>验证与资料</h2><p>本地 race/vet 通过；覆盖双向大载荷、半关闭、活跃流 Reset、关闭后拒绝新流、UDP association 归属以及并发下载不关闭共享客户端。各阶段 jsonl、汇总 CSV、metadata.json、sources、validation.txt 保留复现信息，不打包授权密钥。</p>'''
css='body{font:16px/1.65 -apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif;max-width:1240px;margin:35px auto;padding:0 24px;color:#172b40;background:#f7f9fc}h1,h2{color:#153b60}.muted{color:#63758b}table{border-collapse:collapse;width:100%;font-size:14px;background:white;margin:18px 0}th,td{padding:9px 13px;border:1px solid #d9e3ed;text-align:right;white-space:nowrap}th:first-child,td:first-child{text-align:left}th{background:#e6eef7}.scroll{overflow:auto}p{max-width:1060px}code{background:#e4ecf6;padding:2px 5px}'
(O/'REPORT.html').write_text('<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Next QUIC 吞吐优化</title><style>'+css+'</style>'+body+'</html>')
for data,name in [(raw,'final'),(control,'control')]:
 for phases,file in [({'timed_bulk'},'throughput'),({'parallel_download'},'parallel-downloads'),({'download'},'downloads')]:
  rr=[r for r in data if r.get('phase') in phases];keys=sorted({k for r in rr for k in r})
  if rr:
   with (O/(name+'-'+file+'.csv')).open('w') as f:
    w=csv.DictWriter(f,fieldnames=keys);w.writeheader();w.writerows(rr)
print('Report updated:',len(raw),'main rows,',len(control),'control rows')
