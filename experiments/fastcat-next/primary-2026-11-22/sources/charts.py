# -*- coding: utf-8 -*-
from pathlib import Path
import json,statistics,math,matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.font_manager import FontProperties
O=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/primary-2026-11-22');R=json.loads((O/'all-main-rows.json').read_text());C=json.loads((O/'all-controlled-rows.json').read_text());V=['next-base','next-opt','next-primary','tuic'];L=['Next 单连接','当前新调度','主连接优先','TUIC 默认'];colors=['#3478b9','#8861b4','#e59b32','#28a184'];font=FontProperties(fname='/System/Library/Fonts/STHeiti Light.ttc')
fig,axs=plt.subplots(2,2,figsize=(14,9))
def draws(ax,data,phase,title):
 for i,v in enumerate(V):
  g=[r for r in data if r.get('version')==v and r.get('phase')==phase];a=[r['verified_mbps'] for r in g]
  if not a:continue
  ax.bar(i,statistics.median(a),width=.5,color=colors[i],alpha=.75)
  for j,r in enumerate(g):
   good=r.get('success')==r.get('jobs',r.get('workers'));ax.scatter(i+(j-(len(g)-1)/2)*(.4/max(len(g)-1,1)),r['verified_mbps'],color='#263544' if good else '#c44848',marker='o' if good else 'x',s=28,zorder=3)
 ax.set_title(title,fontproperties=font);ax.set_xticks(range(4),L,fontproperties=font);ax.set_ylabel('Mbps');ax.set_ylim(bottom=0);ax.grid(axis='y',alpha=.18)
draws(axs[0,0],R,'parallel_download','共享服务四路下载：12 轮')
draws(axs[0,1],C,'parallel_download','均衡顺序＋每组重启服务：8 轮')
draws(axs[1,0],R,'rolling_download','滚动下载：仅 2 轮，柱为中位数')
ax=axs[1,1]
for i,v in enumerate(V):
 a=sorted(r['first_byte_us']/1000 for r in R if r.get('version')==v and r.get('phase')=='batch' and not r.get('error'))
 ax.bar(i-.15,a[math.ceil(len(a)*.5)-1],width=.28,color=colors[i]);ax.bar(i+.15,a[math.ceil(len(a)*.95)-1],width=.28,color=colors[i],alpha=.4)
ax.set_title('四路短请求首字节：左 P50 / 右 P95',fontproperties=font);ax.set_xticks(range(4),L,fontproperties=font);ax.set_ylabel('ms');ax.set_ylim(bottom=0);ax.grid(axis='y',alpha=.18)
fig.suptitle('主连接优先已实现，性能合并尚未通过验收',fontproperties=font,fontsize=18)
fig.text(.5,.012,'点为逐组值，红叉为任务不完整；共享与重启服务条件不同，不合并排名。',ha='center',fontproperties=font,fontsize=11)
fig.tight_layout(rect=(0,.04,1,.95));fig.savefig(O/'comparison.png',dpi=150)
