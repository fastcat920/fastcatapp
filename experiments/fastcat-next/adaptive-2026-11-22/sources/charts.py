# -*- coding: utf-8 -*-
import json,pathlib,statistics,math,matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.font_manager import FontProperties
O=pathlib.Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/adaptive-2026-11-22');R=json.loads((O/'all-final-rows.json').read_text());font=FontProperties(fname='/System/Library/Fonts/STHeiti Light.ttc');versions=['next-base','next-fixed','next-opt','tuic','tuic-dual'];labels=['Next 单','Next 旧双','Next 新调度','TUIC 单','TUIC 双'];colors=['#3478b9','#8a96a9','#e59b32','#28a184','#8861b4']
fig,axs=plt.subplots(2,2,figsize=(15,9))
def bars(ax,groups,title,unit,nearest=False):
 for i,g in enumerate(groups):
  if not g:continue
  ax.bar(i,sorted(g)[math.ceil(len(g)*.5)-1] if nearest else statistics.median(g),width=.55,color=colors[i],alpha=.8)
  ax.scatter([i+(j-(len(g)-1)/2)*(.44/max(1,len(g)-1)) for j in range(len(g))],g,color='#203043',s=22,zorder=3)
 ax.set_title(title,fontproperties=font);ax.set_xticks(range(5),labels,fontproperties=font);ax.set_ylabel(unit);ax.set_ylim(bottom=0);ax.grid(axis='y',alpha=.18)
bars(axs[0,0],[[r['first_byte_us']/1000 for r in R if r.get('version')==v and r.get('phase')=='batch' and not r.get('error')] for v in versions],'四路短请求：首字节（柱为 P50，点为逐次）','ms',nearest=True)
bars(axs[0,1],[[r['download_mbps'] for r in R if r.get('version')==v and r.get('phase')=='timed_bulk' and r.get('workers')==4 and r.get('success')==4] for v in versions],'四路回显：有效吞吐（3 轮）','Mbps')
bars(axs[1,0],[[r['verified_mbps'] for r in R if r.get('version')==v and r.get('phase')=='parallel_download'] for v in versions],'四路下载：已校验字节 / 整组时间（含失败组）','Mbps')
bars(axs[1,1],[[r['total_ms']/1000 for r in R if r.get('version')==v and r.get('phase')=='download' and r.get('expected_bytes')==32<<20 and r.get('complete')] for v in versions],'32 MiB 单流：耗时（▲ 为超时预算）','seconds')
axs[1,1].scatter([4],[90],marker='^',color='#c94747',s=70,zorder=4)
axs[1,1].text(4,92,'超时',ha='center',fontproperties=font,color='#c94747')
axs[1,1].set_ylim(0,100)
fig.suptitle('新调度减少等待，吞吐没有全面提升',fontproperties=font,fontsize=18)
fig.text(.5,.014,'除左上外柱为中位数；失败组的已校验吞吐不等同于完整下载速度，详见报告。',ha='center',fontproperties=font,fontsize=11)
fig.tight_layout(rect=(0,.04,1,.95));fig.savefig(O/'comparison.png',dpi=150)
# Connection-level diagnosis is intentionally separate from performance samples.
sessions={}
for l in (O/'adaptive-server.jsonl').read_text().splitlines():
 try:r=json.loads(l)
 except:continue
 if r.get('stage') in ['server_quic_progress','server_quic_end']:
  sessions.setdefault(r['session'],[]).append(r)
fig,ax=plt.subplots(figsize=(10,4.8))
for sid,g in sessions.items():
 ax.plot([r['duration_us']/1e6 for r in g],[r.get('cwnd_bytes',0)/1e6 for r in g],marker='o',label='session '+str(sid))
ax.set_title('诊断组：慢连接的拥塞窗口爬升较慢',fontproperties=font);ax.set_xlabel('seconds since connection');ax.set_ylabel('CWND (million bytes)');ax.legend();ax.grid(alpha=.2);fig.tight_layout();fig.savefig(O/'diagnostic-cwnd.png',dpi=150)
