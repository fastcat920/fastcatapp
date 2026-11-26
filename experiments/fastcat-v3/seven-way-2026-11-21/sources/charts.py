# -*- coding: utf-8 -*-
from pathlib import Path
import json,numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib import font_manager
from matplotlib.lines import Line2D
from matplotlib.ticker import FixedLocator,FixedFormatter
D=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-v3/seven-way-2026-11-21')
font='/System/Library/Fonts/STHeiti Light.ttc';font_manager.fontManager.addfont(font);plt.rcParams['font.family']=font_manager.FontProperties(fname=font).get_name();plt.rcParams['axes.unicode_minus']=False
plt.rcParams.update({'font.size':11,'axes.spines.top':False,'axes.spines.right':False,'savefig.facecolor':'white'})
rows=json.loads((D/'latency-summary.json').read_text());look={(r['dataset'],r['phase'],r['path']):r for r in rows}
paths=['VLESS + TCP + TLS + Vision','Trojan + TCP + TLS','Hysteria 2','TUIC v5','AnyTLS','FastCat v2 · H2','FastCat v2 · H3','最新轻量版 · H2','最新轻量版 · H3']
short=['VLESS Vision','Trojan','Hysteria 2','TUIC v5','AnyTLS','v2 H2','v2 H3','轻量版 H2','轻量版 H3'];ys=np.arange(9)
fig,axes=plt.subplots(2,3,figsize=(17,9),sharex=True,sharey=True)
for ri,(dataset,target) in enumerate([('controlled','受控 HTTPS'),('internet','真实网站')]):
 for ci,(phase,label) in enumerate([('cold','冷连接'),('continuous_pool3','连续请求（三池轮换）'),('concurrent4','四路并发')]):
  ax=axes[ri,ci]
  for y,path in enumerate(paths):
   r=look[dataset,phase,path];med,p95=r['p50_ms'],r['p95_ms']
   if med is not None:
    ax.hlines(y,med,p95,color='#b9c8cd',lw=2);ax.scatter(med,y,color='#087f8c',s=44,zorder=3);ax.scatter(p95,y,color='#e68a2e',marker='^',s=42,zorder=3)
   else:ax.text(140,y,'无成功请求',va='center',color='#bd253c',fontsize=10)
   ax.text(1.02,y,f"{r['success']}/{r['attempts']}",transform=ax.get_yaxis_transform(),va='center',fontsize=10,color='#b32437' if r['failures'] else '#356345')
  ax.set_xscale('log');ax.set_xlim(100,15000);ax.set_yticks(ys,short);ax.set_ylim(8.6,-.6);ax.grid(axis='x',alpha=.18);ax.set_title(target+' · '+label,fontsize=12,pad=12)
  ax.xaxis.set_major_locator(FixedLocator([100,300,1000,3000,10000]));ax.xaxis.set_major_formatter(FixedFormatter(['100','300','1000','3000','10000']))
  if ri==1:ax.set_xlabel('首字节 ms（对数坐标）')
fig.suptitle('九条路径：首字节 P50/P95 与成功数',fontsize=20,y=.98)
fig.legend(handles=[Line2D([0],[0],marker='o',lw=0,color='#087f8c',label='P50'),Line2D([0],[0],marker='^',lw=0,color='#e68a2e',label='P95')],loc='upper center',bbox_to_anchor=(.5,.945),ncol=2,frameon=False)
fig.text(.5,.015,'右侧为成功数/尝试数；分位数只含成功请求。每组20次，P95/P99不能代表长期尾部。',ha='center',fontsize=10,color='#555')
fig.subplots_adjust(left=.12,right=.94,bottom=.09,top=.87,wspace=.27,hspace=.32)
for ext in ['png','svg']:fig.savefig(D/('latency.'+ext),dpi=180)
plt.close(fig)
columns=[('controlled','cold','受控\n冷连接'),('controlled','continuous_pool3','受控\n三池'),('controlled','concurrent4','受控\n四路'),('internet','cold','外网\n冷连接'),('internet','continuous_pool3','外网\n三池'),('internet','concurrent4','外网\n四路'),('singlepool','continuous_pool1','受控\n单池'),('concurrent8','concurrent8','受控\n八路'),('idle35','idle_first','闲置\n≥35秒'),('idle70','idle_first','闲置\n≥70秒')]
values=np.array([[look[d,p,path]['success_percent'] for d,p,_ in columns] for path in paths])
fig,ax=plt.subplots(figsize=(13,7));im=ax.imshow(values,vmin=0,vmax=100,cmap='RdYlGn',aspect='auto')
for y,path in enumerate(paths):
 for x,(d,p,_) in enumerate(columns):
  r=look[d,p,path];ax.text(x,y,f"{r['success']}/{r['attempts']}",ha='center',va='center',fontsize=10,color='white' if values[y,x]>=85 or values[y,x]<=20 else '#102419')
ax.set_yticks(ys,short);ax.set_xticks(np.arange(len(columns)),[c[2] for c in columns]);ax.tick_params(length=0,pad=9);ax.set_title('各场景请求成功数（绿=100%，红=0%）',fontsize=18,pad=18)
fig.colorbar(im,ax=ax,pad=.02,label='成功率 %');fig.text(.5,.015,'闲置列只展示空闲后的首次请求（每格1次）；实际空闲时长及后续两次请求详见报告。',ha='center',fontsize=10)
fig.subplots_adjust(left=.14,right=.96,bottom=.13,top=.88)
for ext in ['png','svg']:fig.savefig(D/('success.'+ext),dpi=180)
plt.close(fig)
t=json.loads((D/'throughput-summary.json').read_text());lk={(r['path'],r['workers']):r for r in t}
fig,axes=plt.subplots(1,2,figsize=(13,7),sharey=True)
for ax,w,label in zip(axes,[1,4],['单流','四路合计']):
 for y,path in enumerate(paths):
  r=lk[path,w];vals=r['raw_download_mbps'];med=r['p50_mbps']
  if vals:
   ax.hlines(y,min(vals),max(vals),lw=3,color='#b9c8cd');ax.scatter(vals,[y]*len(vals),s=35,color='#e68a2e',alpha=.8,zorder=3);ax.scatter(med,y,s=65,marker='D',color='#087f8c',zorder=4);ax.annotate(f'{med:.2f}',(med,y),xytext=(7,7),textcoords='offset points',fontsize=10)
 ax.set_xscale('log');ax.set_xlim(.01,30);ax.set_ylim(8.6,-.6);ax.set_yticks(ys,short);ax.grid(axis='x',alpha=.18);ax.set_title(label,fontsize=15);ax.set_xlabel('有效接收 Mbps（对数坐标）');ax.xaxis.set_major_locator(FixedLocator([.01,.1,1,10]));ax.xaxis.set_major_formatter(FixedFormatter(['0.01','0.1','1','10']))
fig.suptitle('TLS回显吞吐：三轮实测值与中位数',fontsize=20,y=.97)
fig.legend(handles=[Line2D([0],[0],marker='o',lw=0,color='#e68a2e',label='每轮值'),Line2D([0],[0],marker='D',lw=0,color='#087f8c',label='中位数'),Line2D([0],[0],lw=3,color='#b9c8cd',label='最小～最大')],loc='upper center',bbox_to_anchor=(.52,.92),ncol=3,frameon=False)
fig.text(.5,.025,'每轮8秒，准备入口及目标TLS后计时；四路为总和。仅代表本轮测量窗口，不是极限带宽。',ha='center',fontsize=10)
fig.subplots_adjust(left=.15,right=.97,bottom=.12,top=.83,wspace=.2)
for ext in ['png','svg']:fig.savefig(D/('throughput.'+ext),dpi=180)
plt.close(fig)
print('Saved three PNG/SVG charts')
