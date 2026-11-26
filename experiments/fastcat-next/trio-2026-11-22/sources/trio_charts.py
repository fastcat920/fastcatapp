# -*- coding: utf-8 -*-
from pathlib import Path
import json,math,statistics,matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.font_manager import FontProperties
O=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/trio-2026-11-22');R=json.loads((O/'all-rows.json').read_text());G=json.loads((O/'download-groups.json').read_text())
V=['next-base','next-opt','tuic'];L=['Next 单连接','Next 当前新调度','TUIC'];C=['#3478b9','#8861b4','#26a185'];F=FontProperties(fname='/System/Library/Fonts/STHeiti Light.ttc')
def p(a,q):return sorted(a)[max(0,math.ceil(len(a)*q)-1)] if a else 0
def setup(ax,title,y):
 ax.set_title(title,fontproperties=F,fontsize=13);ax.set_xticks(range(3),L,fontproperties=F,fontsize=10);ax.set_ylabel(y);ax.set_ylim(bottom=0);ax.grid(axis='y',alpha=.17)
def save(fig,name,title,foot):
 fig.suptitle(title,fontproperties=F,fontsize=17);fig.text(.5,.012,foot,fontproperties=F,fontsize=10,ha='center');fig.tight_layout(rect=(0,.05,1,.90));fig.savefig(O/name,dpi=150);plt.close(fig)
def latency(ax,metric,phase,title,filterfn=lambda r:True):
 for i,v in enumerate(V):
  a=[r for r in R if r.get('metric')==metric and r.get('phase')==phase and r.get('version')==v and filterfn(r)];b=[r['first_byte_us']/1000 for r in a if not r.get('error') and r.get('first_byte_us',0)>0]
  if not a:continue
  ax.bar(i-.15,p(b,.5),width=.28,color=C[i]);ax.bar(i+.15,p(b,.95),width=.28,color=C[i],alpha=.4)
  ax.annotate(str(len(b))+'/'+str(len(a)),(i,max(p(b,.5),p(b,.95))),ha='center',xytext=(0,5),textcoords='offset points',fontsize=9)
 setup(ax,title,'ms');ax.set_ylim(0,max([b.get_height() for b in ax.patches]+[1])*1.2)
fig,axs=plt.subplots(2,2,figsize=(13,8))
for ax,metric,phase,title in zip(axs.flat,['latency']*3+['batch8'],['cold','warm','batch','batch'],['冷启动首字节','连续请求首字节','四路并发短请求','八路并发短请求']):latency(ax,metric,phase,title)
save(fig,'latency.png','首字节延迟：左柱 P50，右柱 P95','数字为成功/总请求；失败不计入延迟分位数，另计成功率。越低越好。')
fig,axs=plt.subplots(2,2,figsize=(13,8))
for ax,metric,title in zip(axs.flat,['single16','parallel4','parallel8','rolling'],['单文件16MiB','四路 × 4MiB','八路 × 2MiB','四路滚动十二个4MiB文件']):
 for i,v in enumerate(V):
  a=[r for r in G if r['version']==v and r['metric']==metric];b=[r['verified_mbps'] for r in a]
  if not a:continue
  med=statistics.median(b);ax.bar(i,med,width=.5,color=C[i],alpha=.65)
  for j,r in enumerate(a):ax.scatter(i+(j-(len(a)-1)/2)*.055,r['verified_mbps'],marker='o' if r['success']==r['jobs'] else 'x',color='#263747' if r['success']==r['jobs'] else '#d34848',s=30,zorder=3)
  ax.annotate(f'{med:.2f}',(i,med),ha='center',xytext=(0,5),textcoords='offset points',fontsize=9)
 setup(ax,title,'Mbps');ax.set_ylim(0,max([b.get_height() for b in ax.patches]+[r['verified_mbps'] for r in G if r['metric']==metric]+[1])*1.2)
save(fig,'downloads.png','逐组下载吞吐与波动','柱为中位数，点为各组，红叉为未完整完成；失败保留，越高越好。')
fig,axs=plt.subplots(1,2,figsize=(13,5))
metrics=['single16','parallel4','parallel8','rolling'];labels=['单文件','四路','八路','滚动']
for i,v in enumerate(V):
 rates=[];success=[]
 for metric in metrics:
  a=[r for r in G if r['version']==v and r['metric']==metric];
  rates.append(sum(r['verified_mbps']*r['elapsed_ms'] for r in a)/max(sum(r['elapsed_ms'] for r in a),1));success.append(sum(r['success'] for r in a)/max(sum(r['jobs'] for r in a),1)*100)
 for ax,values in zip(axs,[rates,success]):
  bars=ax.bar([j+(i-1)*.24 for j in range(4)],values,width=.23,color=C[i],label=L[i]);ax.bar_label(bars,fmt='%.1f',fontsize=8,padding=3)
for ax,title,y in zip(axs,['总体有效吞吐（包含超时等待）','完整文件成功率'],['Mbps','%']):
 ax.set_xticks(range(4),labels,fontproperties=F);ax.set_title(title,fontproperties=F);ax.set_ylabel(y);ax.set_ylim(bottom=0);ax.grid(axis='y',alpha=.17);ax.set_ylim(0,max([b.get_height() for b in ax.patches]+[1])*1.3)
fig.legend(*axs[0].get_legend_handles_labels(),loc='upper center',bbox_to_anchor=(.5,.94),ncol=3,prop=F)
save(fig,'stability.png','速度与完成率一起看','总体吞吐=总完整校验字节/总耗时，部分字节不当作完成文件；非峰值速度。')
fig,axs=plt.subplots(1,2,figsize=(13,5));latency(axs[0],'mixed','mixed','两条后台下载期间前台请求',lambda r:r.get('background_active',0)>0);latency(axs[1],'idle','idle-resume','闲置20秒后第一条请求',lambda r:r.get('round')==1)
save(fig,'loaded-idle.png','负载下响应与闲置恢复','左 P50 / 右 P95；仅计请求开始时后台仍活跃的样本；闲置只统计第一条恢复请求。')
fig,axs=plt.subplots(1,3,figsize=(15,5))
for i,v in enumerate(V):
 for j,w in enumerate([1,4]):
  a=[r for r in R if r.get('version')==v and r.get('phase')=='timed_bulk' and r.get('workers')==w]
  vals=[[r.get('download_mbps',0) or 0 for r in a],[r['alloc_bytes']/max(r.get('received_bytes',0),1) for r in a if r.get('received_bytes',0)>0],[r['heap_live_bytes']/1048576 for r in a if 'heap_live_bytes' in r]]
  for ax,b in zip(axs,vals):
   if b:ax.bar(i+(j-.5)*.28,p(b,.5),width=.27,color=C[i],alpha=1 if j==0 else .4)
for ax,title,y in zip(axs,['10秒双向回显接收吞吐','Go分配字节/校验接收字节','阶段末Go堆快照'],['Mbps','B/B','MiB']):setup(ax,title,y)
save(fig,'echo-resources.png','回显吞吐与辅助资源观察：左单流 / 右四流','资源不是系统峰值或耗电；受吞吐和GC影响，不能按堆快照单独判性能优劣。')
fig,axs=plt.subplots(1,3,figsize=(14,5))
for ax,key,title in zip(axs,['entry_us','target_tls_us','response_us'],['入口建立阶段','目标HTTPS握手阶段','等待目标响应阶段']):
 for i,v in enumerate(V):
  a=[r[key]/1000 for r in R if r.get('version')==v and r.get('phase')=='cold' and r.get('metric')=='latency' and not r.get('error') and key in r]
  if a:ax.bar(i,p(a,.5),color=C[i],alpha=.8)
 setup(ax,title,'ms')
save(fig,'stages.png','冷启动分阶段 P50','入口包含协议与目标建立，不是纯QUIC握手；各阶段中位数不能直接相加。')
print('Generated 6 charts')
