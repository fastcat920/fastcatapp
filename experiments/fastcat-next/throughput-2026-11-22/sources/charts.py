# -*- coding: utf-8 -*-
import json,pathlib,statistics,matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.font_manager import FontProperties
O=pathlib.Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/throughput-2026-11-22');raw=json.loads((O/'all-final-rows.json').read_text());control=json.loads((O/'all-control-rows.json').read_text());font=FontProperties(fname='/System/Library/Fonts/STHeiti Light.ttc')
fig,axs=plt.subplots(2,2,figsize=(13,8.5));colors={'next-base':'#3478b9','next-opt':'#e59b32','tuic':'#28a184','tuic-dual':'#8861b4'};vs=['next-base','next-opt','tuic'];labels=['Next 单通道','Next 双通道','TUIC 默认']
def draw(ax,data,phase,field,title,versions=vs,xticks=labels):
 for i,v in enumerate(versions):
  g=[r[field] for r in data if r.get('version')==v and r.get('phase')==phase and (phase!='timed_bulk' or r.get('workers')==4)]
  if not g:continue
  if field=='total_ms':g=[x/1000 for x in g]
  ax.bar(i,statistics.median(g),color=colors[v],alpha=.7,width=.5)
  ax.scatter([i+(j-(len(g)-1)/2)*.12 for j in range(len(g))],g,c='#1e2c3a',s=30,zorder=3)
 ax.set_title(title,fontproperties=font);ax.set_xticks(range(len(versions)),xticks,fontproperties=font);ax.set_ylim(bottom=0);ax.grid(axis='y',alpha=.2)
draw(axs[0,0],raw,'timed_bulk','download_mbps','主对照：四路回显（Mbps，3 轮）')
draw(axs[0,1],raw,'parallel_download','verified_mbps','主对照：四路单向下载（Mbps，3 轮）')
draw(axs[1,0],control,'parallel_download','verified_mbps','补充对照：加入 TUIC 双连接（Mbps，3 轮）',versions=['next-opt','tuic','tuic-dual'],xticks=['Next 双通道','TUIC 默认','TUIC 双连接'])
draw(axs[1,1],[r for r in raw if r.get('expected_bytes')==100<<20],'download','total_ms','单路 100 MiB（秒，只有 1 轮）')
fig.suptitle('并发分流改善吞吐；单流没有获得相同收益',fontproperties=font,fontsize=18)
fig.text(.5,.012,'柱为中位数，点为逐轮值；不同面板采用不同工作负载，不能直接比较数值。',ha='center',fontproperties=font,fontsize=11)
fig.tight_layout(rect=(0,.04,1,.95));fig.savefig(O/'comparison.png',dpi=150)
