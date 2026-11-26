# -*- coding: utf-8 -*-
from pathlib import Path
import json,math,statistics,csv,html,collections
O=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/trio-2026-11-22')
V=['next-base','next-opt','tuic'];L=['Next 单连接','Next 当前新调度','TUIC'];names=dict(zip(V,L))
R=[]
for p in sorted(O.glob('*.jsonl')):
 for line in p.read_text().splitlines():
  try:r=json.loads(line)
  except:continue
  if not isinstance(r,dict):continue
  r.update(source=p.name,metric=p.name.split('-b')[0]);R.append(r)
(O/'all-rows.json').write_text(json.dumps(R,ensure_ascii=False,indent=2))
keys=sorted(set(k for r in R for k in r))
with (O/'all-rows.csv').open('w') as f:
 w=csv.DictWriter(f,keys);w.writeheader();w.writerows(R)
def pick(v,phase=None,metric=None):return [r for r in R if r.get('version')==v and (phase is None or r.get('phase')==phase) and (metric is None or r.get('metric')==metric)]
def pct(a,p):return sorted(a)[max(0,math.ceil(len(a)*p)-1)] if a else None
def fmt(n):return '—' if n is None else f'{n:.2f}'
def table(head,rows):return '<div class="scroll"><table><tr>'+''.join('<th>'+html.escape(str(x))+'</th>' for x in head)+'</tr>'+''.join('<tr>'+''.join('<td>'+html.escape(str(x))+'</td>' for x in r)+'</tr>' for r in rows)+'</table></div>'
lat=[]
for metric,phase,label in [('latency','cold','冷启动'),('latency','warm','连续请求'),('latency','batch','四路短请求'),('batch8','batch','八路短请求'),('mixed','mixed','下载期间前台请求'),('idle','idle-resume','闲置20秒后首请求')]:
 for v in V:
  a=pick(v,phase,metric)
  if phase=='mixed':a=[r for r in a if r.get('background_active',0)>0]
  if phase=='idle-resume':a=[r for r in a if r.get('round')==1]
  good=[r for r in a if not r.get('error') and r.get('first_byte_us',0)>0];values=[r['first_byte_us']/1000 for r in good]
  if a:lat.append([label,names[v],f'{len(good)}/{len(a)}',fmt(pct(values,.5)),fmt(pct(values,.95)),fmt(max(values) if values else None)])
trans=[];groups=[]
for metric,phase,label in [('single16','download','单文件16MiB'),('parallel4','parallel_download','四路下载'),('parallel8','parallel_download','八路下载'),('rolling','rolling_download','四路滚动12文件')]:
 for v in V:
  a=pick(v,phase,metric);rates=[];done=jobs=byt=ms=0
  for r in a:
   single=phase=='download';n=(1 if r.get('complete') else 0) if single else r.get('success',0);j=1 if single else r.get('jobs',r.get('workers',0));b=(r.get('received_bytes',0) if n else 0) if single else r.get('verified_bytes',0);t=r.get('total_ms',0) if single else r.get('elapsed_ms',0);rate=b*8/max(t,1)/1000
   rates.append(rate);done+=n;jobs+=j;byt+=b;ms+=t
   groups.append(dict(metric=metric,version=v,source=r['source'],success=n,jobs=j,elapsed_ms=t,verified_mbps=rate,lane_usage=r.get('lane_usage')))
  if a:trans.append([label,names[v],len(a),f'{done}/{jobs}',fmt(statistics.median(rates)),fmt(byt*8/max(ms,1)/1000),fmt(min(rates)),fmt(max(rates))])
(O/'download-groups.json').write_text(json.dumps(groups,indent=2))
echo=[]
for workers in [1,4]:
 for v in V:
  a=[r for r in pick(v,'timed_bulk') if r.get('workers')==workers];rates=[r.get('download_mbps',0) or 0 for r in a];alloc=[r['alloc_bytes']/max(r.get('received_bytes',0),1) for r in a if r.get('received_bytes',0)>0];heap=[r['heap_live_bytes']/1048576 for r in a if 'heap_live_bytes' in r]
  if a:echo.append([names[v],workers,len(a),str(sum(r.get('success',0) for r in a))+'/'+str(workers*len(a)),fmt(pct(rates,.5)),fmt(pct(alloc,.5)),fmt(pct(heap,.5))])
stages=[]
for v in V:
 a=[r for r in pick(v,'cold','latency') if not r.get('error')]
 if a:stages.append([names[v]]+[fmt(pct([r.get(k,0)/1000 for r in a],.5)) for k in ['entry_us','target_tls_us','response_us','first_byte_us']])
body='<h1>Next 单连接 / 当前新调度 / TUIC：安卓完整对照</h1><p>2026-11-22 · TFY-AN00 / Android12 · 同 Wi-Fi、香港 VPS · 相同冻结二进制，测试中未调参。</p>'
body+='<h2>测试边界</h2><p>三项均为 QUIC + TLS 1.3，BBR。Next 当前新调度最多两条连接，单连接一条，TUIC 使用默认连接策略且 ReduceRtt/FastOpen 关闭。目标为同一 VPS 的可校验 HTTPS 测试服务，减少外站、CDN 与 DNS 差异；不能代表真实互联网网站和所有网络。正式 App 未改，使用安卓原型核心程序。</p><p>每例前重启两个隧道测试服务并等待五秒，目标服务保持运行。下载每种六组，覆盖全部六种顺序排列；其他项目每种三组循环先后位置，位置均衡但相邻顺序不完全均衡。短请求分组统计，聚合请求并非全部统计独立。下载组预算：单文件/四路/八路90秒、滚动150秒。各工作流共享同一客户端池，每个业务独立流，不把文件拆包并行。</p><p>下载有效吞吐只计完整校验文件，包含握手和等待；未完成的部分字节不计成功。中位数为逐组吞吐，总体有效吞吐为总完整字节/总耗时，失败保留。延迟百分位仅基于成功请求，失败另列，不把失败当0ms；P95使用nearest-rank。样本数有限且网络有时间波动，排名为描述性结果。闲置恢复每种仅3次，P95等于最大样本，不代表长期尾部；本轮未测试切网、锁屏耗电或丢包注入。</p>'
for image in ['latency.png','downloads.png','stability.png','loaded-idle.png','echo-resources.png','stages.png']:
 if (O/image).exists():body+=f'<img src="{image}" alt="{image}">'
body+='<h2>首字节延迟</h2>'+table(['场景','方案','成功/请求','P50 ms','P95 ms','最大 ms'],lat)
body+='<h2>下载吞吐与完成率</h2>'+table(['场景','方案','组数','完整文件','组中位Mbps','总体有效Mbps','最低组','最高组'],trans)
mixed=[]
for v in V:
 a=pick(v,'mixed','mixed');b=pick(v,'mixed_background','mixed');loaded=[r for r in a if r.get('background_active',0)>0]
 if a:mixed.append([names[v],str(sum(not r.get('error') for r in a))+'/'+str(len(a)),str(len(loaded)),str(sum(r.get('complete',False) for r in b))+'/'+str(len(b))])
body+='<h2>混合负载完成情况</h2><p>每组两条16MiB后台下载，十二条前台请求。当前新调度有三条请求开始时后台已结束，因此负载延迟表只计其余33条；三种方案全部36条前台请求均成功。后台完成率独立列出，不能用前台成功掩盖后台停滞。</p>'+table(['方案','全部前台成功','发起时仍有后台的请求','后台完整文件'],mixed)
body+='<h2>固定10秒双向回显与资源观察</h2><p>回显是同时发送并接收相同数据，计校验后的接收吞吐，不是纯上传测速。分配倍率=测量阶段Go累计分配字节/校验接收字节，包含高吞吐引起的正常分配；堆是阶段末快照，受GC时机影响，不是峰值内存、系统RSS或耗电。仅作为辅助观察。</p>'+table(['方案','流数','组数','成功流','接收中位Mbps','分配字节/接收字节','末态堆中位MiB'],echo)
body+='<h2>冷启动阶段拆分</h2><p>入口阶段包含连接、协议处理及目标建立，不等于纯QUIC握手；目标TLS是代理后的目标HTTPS握手。各阶段中位数不能相加当作整体中位数。</p>'+table(['方案','入口P50ms','目标TLSP50ms','响应P50ms','总首字节P50ms'],stages)
body+='<h2>原始资料</h2><p><a href="all-rows.csv">完整CSV</a> · <a href="all-rows.json">完整JSON</a> · <a href="download-groups.json">逐组下载</a> · <a href="plan.json">计划与构建哈希</a> · <a href="timeline.json">时间线</a>。所有原始JSONL、网络状态及失败记录均保留。</p>'
(O/'REPORT.html').write_text('<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Next 与 TUIC 安卓对照</title><style>body{font:16px/1.7 -apple-system,sans-serif;max-width:1300px;margin:35px auto;padding:0 22px;color:#20344b;background:#f7f9fc}h1,h2{color:#183d61}.scroll{overflow:auto}table{border-collapse:collapse;width:100%;background:white;margin:18px 0}td,th{border:1px solid #d5dee9;padding:8px;text-align:right;white-space:nowrap}td:first-child,th:first-child{text-align:left}th{background:#e8eff8}img{width:100%;height:auto;margin:18px 0}</style>'+body+'</html>')
print(json.dumps(dict(rows=len(R),downloads=trans,latency=lat),ensure_ascii=False),flush=True)
