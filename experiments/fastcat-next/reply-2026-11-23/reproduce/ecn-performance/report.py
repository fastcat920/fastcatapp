# -*- coding: utf-8 -*-
import json,sys
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.font_manager import FontProperties
O=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/reply-2026-11-23')
s=json.loads((O/'ecn-performance/performance/summary.json').read_text());b=s['summary']['baseline'];c=s['summary']['noecn']
plt.rcParams.update({'font.family':FontProperties(fname='/System/Library/Fonts/STHeiti Light.ttc').get_name(),'axes.unicode_minus':False})
fig,axs=plt.subplots(1,2,figsize=(11,4.2),layout='constrained')
for ax,labels,bv,cv,unit in [(axs[0],['冷启动 P95','连续请求 P95','负载下前台 P95'],[b['cold']['p95'],b['warm']['p95'],b['loaded_p95']],[c['cold']['p95'],c['warm']['p95'],c['loaded_p95']],'毫秒，越低越好'),(axs[1],['四路下载','滚动下载'],[b['parallel']['aggregate_mbps'],b['rolling']['aggregate_mbps']],[c['parallel']['aggregate_mbps'],c['rolling']['aggregate_mbps']],'Mbps，越高越好')]:
 for off,v,col,label in [(-.18,bv,'#5476aa','默认 ECN'),(.18,cv,'#58a48a','仅服务端关闭 ECN')]:
  bars=ax.bar([i+off for i in range(len(labels))],v,.34,color=col,label=label);ax.bar_label(bars,fmt='%.1f',padding=3,fontsize=9)
 ax.set_xticks(range(len(labels)),labels);ax.set_ylabel(unit);ax.set_ylim(0,max(bv+cv)*1.24);ax.spines[['top','right']].set_visible(False)
axs[0].legend(fontsize=9);fig.savefig(O/'ecn-comparison.png',dpi=170);plt.close(fig)
headers=['关闭诊断后的 ECN 性能验收','默认','仅服务端关闭','样本']
rows=[['冷启动首字节 P50 / P95',f"{b['cold']['p50']:.1f} / {b['cold']['p95']:.1f} ms",f"{c['cold']['p50']:.1f} / {c['cold']['p95']:.1f} ms",'各36次'],['连续请求 P50 / P95',f"{b['warm']['p50']:.1f} / {b['warm']['p95']:.1f} ms",f"{c['warm']['p50']:.1f} / {c['warm']['p95']:.1f} ms",'各36次'],['负载下前台 P50 / P95',f"{b['loaded_p50']:.1f} / {b['loaded_p95']:.1f} ms",f"{c['loaded_p50']:.1f} / {c['loaded_p95']:.1f} ms",'各72次'],['背景完成率',f"{b['background_success']}/{b['background_total']}",f"{c['background_success']}/{c['background_total']}",'各6轮，2×16MiB'],['四路下载',f"{b['parallel']['aggregate_mbps']:.2f} Mbps",f"{c['parallel']['aggregate_mbps']:.2f} Mbps",'各6轮，4×4MiB'],['滚动下载',f"{b['rolling']['aggregate_mbps']:.2f} Mbps",f"{c['rolling']['aggregate_mbps']:.2f} Mbps",'各6轮，12×4MiB /4并发']]
t='<table><tr>'+''.join('<th>'+x+'</th>' for x in headers)+'</tr>'+''.join('<tr>'+''.join('<td>'+x+'</td>' for x in r)+'</tr>' for r in rows)+'</table>'
g=s['gate'];section='<h2>7. ECN 关闭逐包诊断后的独立性能复测</h2><img src="ecn-comparison.png">'+t+'<p>各轮交替先后，两边保持成功标记立即发送、原 next-opt 调度、默认 GSO / PMTU。该轮使用默认随机源端口，测试真实默认连接生命周期；固定端口实验只用于前一节路径诊断。门槛与合并发送轮相同，独立统计，未混合两个时段。</p><p><b>验收：'+('通过' if g['passed'] else '未通过')+'。</b>逐项结果：'+str(g['checks'])+'。短请求诊断中的改善不能替代负载验收，未在生产入口关闭 ECN。</p>'
p=O/'REPORT.html';a=p.read_text().replace('<h2>7. 当前处理与后续边界</h2>',section+'<h2>8. 当前处理与后续边界</h2>');p.write_text(a)
print(json.dumps(s,indent=2))
