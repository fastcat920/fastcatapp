# -*- coding: utf-8 -*-
import json,math,statistics
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.font_manager import FontProperties
O=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/latency-2026-11-22');F=FontProperties(fname='/System/Library/Fonts/STHeiti Light.ttc');colors=['#3478b9','#a08ac4','#29a183'];N={'next-opt':'原调度','next-latency':'1、2项评分版','next-reserve':'1—4项完整策略'}
def save(fig,stage,name,title,foot):
 fig.suptitle(title,fontproperties=F,fontsize=17);fig.text(.5,.015,foot,fontproperties=F,fontsize=10,ha='center');fig.tight_layout(rect=(0,.06,1,.92));fig.savefig(O/(stage+'-'+name+'.png'),dpi=150);plt.close(fig)
def style(ax,title,V,y):
 ax.set_title(title,fontproperties=F,fontsize=12);ax.set_xticks(range(len(V)),[N[v] for v in V],fontproperties=F,fontsize=10);ax.set_ylabel(y);ax.grid(axis='y',alpha=.17)
def pct(a,q):return sorted(a)[max(0,math.ceil(len(a)*q)-1)] if a else 0
for stage in ['stage12','stage34']:
 d=O/stage
 if not (d/'summary.json').exists():continue
 S=json.loads((d/'summary.json').read_text())['summary'];R=json.loads((d/'all-rows.json').read_text());V=list(S)
 fig,axs=plt.subplots(1,3,figsize=(15,5))
 for ax,key,title in zip(axs,['loaded','cold','warm'],['负载下前台首字节','冷启动首字节','连续请求首字节']):
  for i,v in enumerate(V):
   a=S[v];p50=a['loaded_p50'] if key=='loaded' else a[key]['p50'];p95=a['loaded_p95'] if key=='loaded' else a[key]['p95']
   if p50 is None or p95 is None:continue
   ax.bar(i-.15,p50,width=.28,color=colors[i]);ax.bar(i+.15,p95,width=.28,color=colors[i],alpha=.4);ax.annotate(f'{p95:.0f}',(i+.15,p95),ha='center',xytext=(0,4),textcoords='offset points',fontsize=9)
  if key=='loaded' and S['next-opt']['loaded_p95']:
   ax.axhline(S['next-opt']['loaded_p95']*.8,color='#b64a4a',linestyle='--',linewidth=1)
  style(ax,title,V,'ms');ax.set_ylim(0,max([p.get_height() for p in ax.patches]+[1])*1.25)
 save(fig,stage,'latency',stage+'：首字节延迟（左P50 / 右P95）','红虚线为同轮原调度P95的80%验收线；延迟只计成功请求，样本数和完成率见表。')
 fig,axs=plt.subplots(1,2,figsize=(12,5))
 for ax,key,title in zip(axs,['parallel','rolling'],['四路4×4MiB下载','四路滚动12×4MiB下载']):
  for i,v in enumerate(V):
   a=S[v][key];rate=a['aggregate_mbps'];ax.bar(i,rate,width=.5,color=colors[i],alpha=.85);ax.annotate(f'{rate:.2f}\n{a["success"]}/{a["jobs"]}',(i,rate),ha='center',xytext=(0,5),textcoords='offset points',fontsize=9)
  ax.axhline(S['next-opt'][key]['aggregate_mbps']*.9,color='#b64a4a',linestyle='--',linewidth=1);style(ax,title,V,'Mbps');ax.set_ylim(0,max([p.get_height() for p in ax.patches]+[1])*1.35)
 save(fig,stage,'throughput',stage+'：总体有效吞吐与完整文件','红线为原调度90%；总完整校验字节/总耗时，保留失败与等待成本，不计部分字节为成功。')
 fig,axs=plt.subplots(1,2,figsize=(12,5))
 for ax,key,phase,title in zip(axs,['parallel','rolling'],['parallel_download','rolling_download'],['四路逐组有效吞吐','滚动逐组有效吞吐']):
  allrates=[]
  for i,v in enumerate(V):
   a=[r for r in R if r.get('version')==v and r.get('phase')==phase];b=[r['verified_mbps'] for r in a];allrates+=b
   if not b:continue
   ax.bar(i,statistics.median(b),color=colors[i],alpha=.55,width=.5)
   for j,r in enumerate(a):
    good=r['success']==r.get('jobs',r['workers']);ax.scatter(i+(j-(len(a)-1)/2)*.055,r['verified_mbps'],color='#27394b' if good else '#cc4646',marker='o' if good else 'x',s=30,zorder=3,clip_on=False)
  style(ax,title,V,'Mbps');ax.set_ylim(0,max(allrates+[1])*1.2)
 save(fig,stage,'distribution',stage+'：波动与失败全部保留','柱为逐组中位数，点为每组，红叉为任务未完整完成；不与其他阶段混合排名。')
 fig,axs=plt.subplots(1,3,figsize=(15,5))
 for ax,key,title in zip(axs,['entry_us','target_tls_us','response_us'],['入口阶段P95','目标TLS阶段P95','等待目标响应P95']):
  for i,v in enumerate(V):
   a=[r.get(key,0)/1000 for r in R if r.get('version')==v and r.get('phase')=='mixed' and r.get('background_active',0)>0 and not r.get('error')];rate=pct(a,.95);ax.bar(i,rate,color=colors[i],alpha=.8);ax.annotate(f'{rate:.0f}',(i,rate),ha='center',xytext=(0,5),textcoords='offset points',fontsize=9)
  style(ax,title,V,'ms');ax.set_ylim(0,max([p.get_height() for p in ax.patches]+[1])*1.3)
 save(fig,stage,'stages',stage+'：负载下慢请求的等待阶段','各阶段P95不可相加；入口包含协议/目标建立，不等于纯QUIC握手，不能凭阶段耗时证明底层根因。')
print('Generated phase comparison charts')
