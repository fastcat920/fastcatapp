# -*- coding: utf-8 -*-
from pathlib import Path
import json,html,math
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.font_manager import FontProperties
O=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/queue-2026-11-23');plt.rcParams.update({'font.family':FontProperties(fname='/System/Library/Fonts/STHeiti Light.ttc').get_name(),'axes.unicode_minus':False})
def table(head,rows):return '<table><tr>'+''.join('<th>'+html.escape(str(v))+'</th>' for v in head)+'</tr>'+''.join('<tr>'+''.join('<td>'+html.escape(str(v))+'</td>' for v in r)+'</tr>' for r in rows)+'</table>'
sections=[]
for stage,label,candidate in [('stage12','1、2：分段诊断与后台写入预算','budget'),('stage3','3：恢复状态选路','recovery'),('stage4','4：首段有限冗余','prefix')]:
 control='同期第3项方案' if stage=='stage4' else '同期原方案'
 p=O/stage/'performance/summary.json'
 if not p.exists():continue
 a=json.loads(p.read_text());b=a['summary']['baseline'];c=a['summary'][candidate];passed=a.get('gate',{}).get('passed',False);friendly={'budget':'写入预算','recovery':'恢复状态选路','prefix':'恢复选路＋首段冗余'}[candidate]
 fig,axs=plt.subplots(1,2,figsize=(11,4.2),layout='constrained')
 for ax,labels,x,y,unit in [(axs[0],['冷启动 P95','连续请求 P95','负载前台 P95'],[b['cold']['p95'],b['warm']['p95'],b['loaded_p95']],[c['cold']['p95'],c['warm']['p95'],c['loaded_p95']],'ms，越低越好'),(axs[1],['四路下载','滚动下载'],[b['parallel']['aggregate_mbps'],b['rolling']['aggregate_mbps']],[c['parallel']['aggregate_mbps'],c['rolling']['aggregate_mbps']],'Mbps，越高越好')]:
  if any(v is None for v in x+y):continue
  for off,vals,col,name in [(-.18,x,'#5476aa',control),(.18,y,'#55a185',friendly)]:
   bars=ax.bar([i+off for i in range(len(labels))],vals,.34,color=col,label=name);ax.bar_label(bars,fmt='%.1f',padding=3,fontsize=9)
  ax.set_xticks(range(len(labels)),labels);ax.set_ylim(0,max(x+y)*1.23);ax.set_ylabel(unit);ax.spines[['top','right']].set_visible(False)
 axs[0].legend();fig.savefig(O/(stage+'.png'),dpi=170);plt.close(fig)
 rows=[['带载前台 P50 / P95',f"{b['loaded_p50']} / {b['loaded_p95']} ms",f"{c['loaded_p50']} / {c['loaded_p95']} ms",f"{b['loaded_success']}/{b['loaded_total']}；{c['loaded_success']}/{c['loaded_total']}"],['冷启动 P50 / P95',f"{b['cold']['p50']} / {b['cold']['p95']} ms",f"{c['cold']['p50']} / {c['cold']['p95']} ms",'每版本36次'],['连续请求 P50 / P95',f"{b['warm']['p50']} / {b['warm']['p95']} ms",f"{c['warm']['p50']} / {c['warm']['p95']} ms",'每版本36次'],['背景下载完成',f"{b['background_success']}/{b['background_total']}",f"{c['background_success']}/{c['background_total']}",'每版本6轮，2×16MiB']]
 for k,name in [('parallel','四路下载'),('rolling','滚动下载')]:
  x,y=b[k],c[k];rows.append([name,f"{x['aggregate_mbps']:.2f} Mbps ({x['success']}/{x['jobs']})",f"{y['aggregate_mbps']:.2f} Mbps ({y['success']}/{y['jobs']})",'每版本6轮；4MiB/文件；滚动12文件、4并发'])
 sections.append('<h2>'+label+'</h2><p><b>主验收：'+('通过' if passed else '未通过')+'</b>。'+html.escape(str(a.get('gate',{}).get('checks',{})))+'</p><img src="'+stage+'.png">'+table(['指标',control,friendly,'成功数 / 样本'],rows)+'<p><a href="'+stage+'/performance/plan.json">事先验收计划</a> · <a href="'+stage+'/performance/summary.json">机器可读汇总</a></p>')
s=json.loads((O/'stage12/mechanism/stage-summary.json').read_text());diag=[]
for v,a in s.items():diag.append([v,a['requests'],a['slow_ge500ms'],a['slow_with_downstream_recovery'],a['slow_status_recovery'],a['first_packetize_wait_ms']['p95'],a['budget_total_yields']])
page='''<!doctype html><html lang="zh"><meta charset="utf-8"><title>Next 分阶段恢复与排队优化验收</title><style>body{max-width:1160px;margin:38px auto;padding:0 24px;font:16px/1.75 system-ui;color:#223349}h1,h2{line-height:1.35}h2{margin-top:38px}table{border-collapse:collapse;width:100%;font-size:14px}th,td{text-align:left;padding:10px;border-bottom:1px solid #d9e1e8}th{background:#eff4f8}img{width:100%}.note{padding:18px;background:#eef4fa;border-left:5px solid #5476aa}a{color:#245b98}</style><h1>Next：分段诊断与分阶段优化验收</h1><p>2026-11-23 · 安卓 TFY-AN00 原生核心独立对照程序 · 公网隔离入口。未以正式 App 全链路或其他网络的成绩替代本轮验收。</p><div class="note">执行顺序：先实现 1、2，未达标再继续 3、4。各阶段使用同期原方案、交替先后；默认 ECN / GSO / PMTU 不变，成功标记合并关闭。只有完整样本通过门槛才作为通过；诊断数据不混入正式性能数据。</div><h2>诊断确定了什么</h2>'''+table(['条件','前台请求','≥500ms 慢请求','慢请求有下行恢复证据','慢请求状态在恢复时解除','首段组包等待 P95 ms','预算让出次数'],diag)+'''<p>组包等待由同一服务端的数据就绪事件到首段业务帧 PacketSent 事件计算，不是网卡实际发出的时间。恢复证据按两端包号、包号空间和流偏移关联；“有恢复证据”不能直接解释为全部慢时长都由丢包造成。原方案12个慢请求都观察到下行恢复，3个可直接关联到状态读取在流头恢复时解除；首段组包等待P95仅约3.8ms，因此仍需关注恢复路径。物理延迟/丢失发生在哪一跳尚未确定。</p><p>服务器目标首读等待包含客户端业务首段尚未到达的时间，不能全部归为目标处理。状态读等待是目标TLS阶段的子集；各列分位数不可相加，也不能将两台设备的绝对时钟直接相减。机制轮实际为每条件3组：2×8MiB下载与12次前台请求，保留原计划描述的更正文件。</p><h2>写入预算的边界</h2><p>每条 QUIC 连接共享 16KiB / 2ms 的新数据组包预算，仅在已发送至少256KiB的大流与新流共存时限制大流。新流最多保留500ms优先机会，独占下载不受预算节流。写入按最多16KiB切分；WriteWithLimit 在组包时扣减额度，重传不重复扣减。它不是ACK窗口，也不能回收已经在途的数据或保证独占带宽。状态字节和业务线格式不变，已有业务不迁移、不重放。默认关闭。</p><p>自检覆盖竞争、共享额度、取消、优先机会过期、完整大流内容、认证/目标错误与计数既有测试；race和vet记录随包附上。诊断每流新增有界首读、首次写入接受和慢读写记录，性能轮关闭逐包与转发追踪，仅保留两边一致的轻量选路记录。</p>'''+''.join(sections)+'''<h2>恢复状态选路的边界</h2><p>第3项仅为新流修正原自适应选择：依据本端已发包判丢计数的新增量和入口RTT膨胀，短时避开不佳连接；近期信号300–1000ms过期，额外恢复触发的跨通道切换间隔至少500ms。对端都不佳时保留原选择，不关闭或迁移既有流，也不重放。这里只直接观测本端发包与RTT，没有新增服务端下行恢复反馈，不能声称覆盖全部下行恢复。诊断42次选择中3次观察到恢复状态并选中另一条健康通道，不能据此把全部改善都归因于某一种丢包原因。第3项6对带载轮中5对P95改善，保留逐轮数据。</p><h2>有限冗余的边界</h2><p>第4项是在第3项候选上进行增量对照，两边均启用恢复状态选路；没有叠加未通过的第2项预算。Kind2通过已有exporter HMAC认证，服务端与客户端必须显式启用且支持QUIC DATAGRAM。冗余采用现有QUIC AEAD加密，不改变密码算法或自行处理nonce。每流最多8193字节（状态1字节+业务前8KiB）和12次副本尝试；可靠流仍是完整规范字节序列，客户端按偏移交付一次，并检查重叠内容一致性。旧端不支持时报错，不自动降级重发。仅作为实验选项，默认关闭。详见 <a href="PREFIX-EXTENSION.txt">扩展说明</a>。</p><h2>测量与验收口径</h2><p>带载前台P95至少降低20%；连续请求P95恶化不超过10%；四路与滚动有效吞吐保留至少90%；前台、背景及下载完成率不降低；每条件至少48个带载样本。本轮计划使用各72个带载请求、36个冷启动、36个连续请求，四路/滚动各6轮。P95为最近秩法；吞吐为校验通过字节总量除以各轮总耗时，失败时间不剔除。</p><p>冷启动新建入口；连续请求复用入口，但每次仍新建目标TLS并发HEAD。本地主目标为VPS上的TLS1.3测试服务，减少第三方波动；真实远端网站另组核对，不混合统计。不同阶段的原方案数值受网络时段变化影响，只与该阶段候选比较，不能横跨阶段按绝对值排名。小样本分位数不宣称统计显著或能推广到全部网络。</p><p><a href="validation.txt">自检与清理记录</a> · <a href="reproduce/README.txt">复现材料</a></p></html>'''
(O/'REPORT.html').write_text(page)
print(O/'REPORT.html')
