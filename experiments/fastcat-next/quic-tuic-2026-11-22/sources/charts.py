# -*- coding: utf-8 -*-
import json,pathlib,matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.font_manager import FontProperties
O=pathlib.Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/quic-tuic-2026-11-22');r=json.loads((O/'summary.json').read_text());font=FontProperties(fname='/System/Library/Fonts/STHeiti Light.ttc')
fig,axs=plt.subplots(1,3,figsize=(15,4.5));colors=['#3476b8','#e79b32','#29a184'];vs=['next-base','next-opt','tuic'];labels=['Next 原版','Next 候选','TUIC']
for ax,(phase,title) in zip(axs[:2],[('cold','外网冷启动首字节'),('batch','外网四路并发首字节')]):
 g=[next(a for a in r if a['test']=='final-internet' and a['version']==v and a['phase']==phase) for v in vs]
 for i,a in enumerate(g):
  ax.bar(i-.18,a['p50_ms'],width=.34,color=colors[i]);ax.bar(i+.18,a['p95_ms'],width=.34,color=colors[i],alpha=.45)
 ax.set_title(title,fontproperties=font);ax.set_xticks(range(3),labels,fontproperties=font);ax.set_ylabel('ms');ax.text(.02,.98,'左 P50 · 右 P95',transform=ax.transAxes,va='top',fontproperties=font);ax.set_ylim(0,3500);ax.grid(axis='y',alpha=.18)
a=json.loads((O/'all-final-rows.json').read_text());ax=axs[2]
for i,v in enumerate(vs):
 g=[x for x in a if x.get('version')==v and x.get('phase')=='download' and x.get('expected_bytes')==104857600]
 ax.scatter([i-.12,i+.12],[x['total_ms']/1000 for x in g],color=colors[i],s=65)
ax.set_title('100 MiB 下载（每组两轮）',fontproperties=font);ax.set_xticks(range(3),labels,fontproperties=font);ax.set_ylabel('seconds');ax.set_ylim(0,185);ax.grid(axis='y',alpha=.18)
fig.suptitle('安卓同网实测：候选配置没有全面优于原版',fontproperties=font,fontsize=17);fig.tight_layout(rect=(0,0,1,.92));fig.savefig(O/'comparison.png',dpi=160)
