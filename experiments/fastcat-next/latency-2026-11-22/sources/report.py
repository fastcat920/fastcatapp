# -*- coding: utf-8 -*-
from pathlib import Path
import json,html,csv,collections,math,statistics
O=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/latency-2026-11-22')
N={'next-opt':'原调度','next-latency':'第1、2项：评分版','next-reserve':'第1—4项：保留通道＋滞后'}
def esc(x):return html.escape(str(x))
def table(head,rows):return '<div class="scroll"><table><tr>'+''.join('<th>'+esc(x)+'</th>' for x in head)+'</tr>'+''.join('<tr>'+''.join('<td>'+esc(x)+'</td>' for x in row)+'</tr>' for row in rows)+'</table></div>'
body='<h1>Next 调度优化：从记录、评分到通道准入与滞后</h1><p>Android TFY-AN00 · 同一 Wi-Fi / 香港 VPS · 原型核心 · 未修改加密、BBR或线格式。</p>'
body+='<h2>预定验收条件</h2><p>每种策略至少6组混合负载、48条发起时后台仍活跃的请求；前台请求全部成功，负载首字节P95≤同轮原调度的80%；后台文件完成数不低于对照；四路与滚动下载各6组，完成数不低于对照且总体有效吞吐≥对照90%。全部条件同时满足才通过。条件为本轮工程门槛，不是统计显著性证明。</p>'
body+='<h2>具体实现</h2><ol><li>轻量记录选择时两个通道的RTT、活跃/等待首字节/已读超过256KiB的流数、待写字节、建立与首次读取等待EWMA；每个请求保留入口/目标TLS/响应阶段。记录不含目标、凭证或载荷，未开启逐包qlog。</li><li>评分不再把大流吞吐高作为新业务的容量优惠，加入RTT、近期成功建立/首读等待、活跃数、等待首包数、大流数及待写负载。样本10秒过期，等待样本与权重有上界，目标差异仍可能影响估计。</li><li>两个通道都可用且路径相近时，至多把最初两条并发、尚未首读的未知业务短暂放在同一通道，窗口≤250ms；已有大流时优先接纳到另一条健康通道。业务大小未知，不按内容分类，也不保证专属带宽。</li><li>分数改善不足15%时可保留上次选择至200ms以内；连续分配达到3次后，若另一条分数在25%以内则允许其承接。显著更好的路径与故障路径不被冷却强行阻挡。已有流不迁移、不重放。</li></ol>'
for stage in ['stage12','stage34']:
 d=O/stage
 if not (d/'summary.json').exists():continue
 S=json.loads((d/'summary.json').read_text());R=json.loads((d/'all-rows.json').read_text());P=json.loads((d/'plan.json').read_text())
 fields=sorted(set(k for r in R for k in r))
 with (d/'all-rows.csv').open('w') as f:w=csv.DictWriter(f,fields);w.writeheader();w.writerows(R)
 body+='<h2>'+('第一阶段：第1、2项' if stage=='stage12' else '第二阶段：三组同期对照')+'</h2>'
 rr=[]
 for v,s in S['summary'].items():
  rr.append([N[v],s['mixed_groups'],f"{s['foreground_success']}/{s['foreground_total']}",s['loaded_total'],s['loaded_p50'],s['loaded_p95'],f"{s['background_success']}/{s['background_total']}"])
 body+=table(['策略','混合组数','全部前台成功','真正带载样本','带载P50ms','带载P95ms','后台完整文件'],rr)
 rr=[]
 for v,s in S['summary'].items():
  for k,label in [('parallel','四路4×4MiB'),('rolling','四路滚动12×4MiB')]:
   a=s[k];rr.append([N[v],label,a['groups'],f"{a['success']}/{a['jobs']}",f"{a['median_mbps']:.2f}" if a['median_mbps'] is not None else '—',f"{a['aggregate_mbps']:.2f}"])
 body+=table(['策略','负载','组数','完整文件','逐组中位Mbps','总体有效Mbps'],rr)
 gates=[]
 for v,g in S['gate'].items():
  for k,val in g['checks'].items():gates.append([N[v],k,'通过' if val else '未通过'])
 body+=table(['策略','门槛','结果'],gates)
 for name in ['latency','throughput','distribution','stages']:
  if (O/(stage+'-'+name+'.png')).exists():body+=f'<img src="{stage}-{name}.png" alt="{stage} {name}">'
 body+='<h3>短请求复核</h3>'
 rows=[]
 for v,s in S['summary'].items():
  for k in ['cold','warm','batch']:
   a=s[k];rows.append([N[v],k,f"{a['success']}/{a['total']}",a['p50'],a['p95']])
 body+=table(['策略','场景','成功','P50ms','P95ms'],rows)
 body+='<h3>慢请求与选择时状态（每种最慢三条）</h3>'
 rows=[]
 for v in S['summary']:
  a=sorted([r for r in R if r.get('version')==v and r.get('phase')=='mixed' and not r.get('error')],key=lambda r:r.get('first_byte_us',0),reverse=True)[:3]
  for r in a:
   sel=(r.get('lane') or {}).get('selection',{});lanes=sel.get('lanes',[]);chosen=sel.get('lane');state=lanes[chosen] if chosen is not None and len(lanes)>chosen else {}
   rows.append([N[v],r['source'],r.get('worker'),round(r['entry_us']/1000,2),round(r['target_tls_us']/1000,2),round(r['response_us']/1000,2),round(r['first_byte_us']/1000,2),chosen,state.get('rtt_us'),state.get('active'),state.get('opening'),state.get('heavy')])
 body+=table(['策略','来源','请求','入口ms','目标TLSms','响应ms','总首字节ms','通道','RTTμs','活跃','待首包','大流'],rows)
 body+='<p><a href="'+stage+'/summary.json">验收汇总JSON</a> · <a href="'+stage+'/all-rows.csv">完整CSV</a> · <a href="'+stage+'/all-rows.json">原始合并JSON</a> · <a href="'+stage+'/plan.json">计划与哈希</a></p>'
body+='<h2>方法和限制</h2><p>两条16MiB后台下载与每组12个前台HEAD请求共享同一客户端。仅统计发起时后台仍活跃的请求作为带载延迟，其余前台请求仍计成功率；两组带载样本数可能不同。P95为成功请求nearest-rank，不把失败记为0。各阶段中位数不可直接相加。入口含目标建立，不等于纯QUIC握手。</p><p>四路预算90秒、滚动150秒。有效吞吐只计完整校验的文件，分母包含握手和超时等待；部分字节不冒充成功。每例前重启测试隧道、等待5秒，目标服务持续运行，开始前确认默认网络为Wi-Fi。第一阶段双组交替先后；第二阶段六种排列，每种占每个位置两次。延迟复核每种3组，位置均衡但非全排列。</p><p>两阶段测试时段、记录字段与二进制不同，不能合并吞吐或直接用第一阶段基线判第二阶段通过。只在各阶段同期比较；阶段间关系只说明实现递进。原调度在记录里显示的score_us是新评分的影子观察值，并非原调度实际采用的旧公式。合并JSON/CSV来自主测量JSONL；短请求的辅助事件仍保留在同名.log中。request编号只在一个客户端内唯一，应结合来源文件、客户端生命周期和记录本身解释，不跨文件强行关联。</p><p>单个慢请求的阶段和状态可以定位等待发生处，不能独自证明拥塞、丢包或运营商策略是根因。没有测试识别率、锁屏耗电、多网络长期运行；实验开关保持可回退，不代表正式App已发布。</p>'
(O/'REPORT.html').write_text('<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Next 调度优化验收</title><style>body{font:16px/1.7 -apple-system,sans-serif;max-width:1350px;margin:30px auto;padding:0 22px;color:#20344b;background:#f7f9fc}table{border-collapse:collapse;width:100%;background:white;margin:16px 0}td,th{border:1px solid #d2dce8;padding:8px;text-align:right;white-space:nowrap}td:first-child,th:first-child{text-align:left}th{background:#e6eef8}.scroll{overflow:auto}img{width:100%;height:auto;margin:16px 0}</style>'+body+'</html>')
print('Built detailed report')
