# -*- coding: utf-8 -*-
from pathlib import Path
import json,matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.font_manager import FontProperties
O=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/cause-2026-11-22');F=FontProperties(fname='/System/Library/Fonts/STHeiti Light.ttc');Q=json.loads((O/'prefix/selected-proof.json').read_text());S=json.loads((O/'summary.json').read_text())['conditions'];r=Q['request'];p=Q['proof'];t=r['transport_tls']
fig,axs=plt.subplots(1,2,figsize=(14,5))
a=Q['server_status_sent'];base=a[0]['at_unix_us']
for i,e in enumerate(a):
 x=(e['at_unix_us']-base)/1000;y=2-i;axs[0].scatter(x,y,color='#c24747' if i<2 else '#229977',s=60);axs[0].annotate(f"PN {e.get('packet',0)}  +{x:.3f} ms",(x,y),xytext=(7,7),textcoords='offset points',fontsize=10)
axs[0].set_yticks([2,1,0],['确认首次发送','确认第一次重发','确认第二次重发'],fontproperties=F);axs[0].set_xlim(-20,400);axs[0].set_ylim(-.5,2.6);axs[0].set_xlabel('ms');axs[0].set_title('服务端：offset 0、长度1 的流帧',fontproperties=F)
b=min(e['at_unix_us'] for e in Q['client_earlier_payload']);statusrx=min(e['receiver_at_us'] for e in p['status_recovery_at_unblock']);times=[b,statusrx,t['status_end_us'],t['first_data_us']]
for i,e in enumerate(times):
 x=(e-b)/1000;y=3-i;axs[1].scatter(x,y,color='#3478b9' if i==0 else '#229977',s=60);axs[1].annotate(f'+{x:.3f} ms',(x,y),xytext=(7,7),textcoords='offset points',fontsize=10)
axs[1].set_yticks([3,2,1,0],['后续TLS片段已到达','PN1740确认字节到达','状态读取结束','读出缓冲的TLS片段'],fontproperties=F);axs[1].set_xlim(-10,170);axs[1].set_ylim(-.5,3.6);axs[1].set_xlabel('ms');axs[1].set_title('客户端：缺少流头部，后续字节只能等',fontproperties=F)
for ax in axs:ax.grid(axis='x',alpha=.2)
fig.suptitle('逐包证据：TLS片段先到108ms，确认恢复后14μs即读出',fontproperties=F,fontsize=17);fig.text(.5,.015,'左右使用各自端点的相对时间，不跨端相减；通过同一会话、方向、包号和流偏移对应。',fontproperties=F,ha='center',fontsize=10);fig.tight_layout(rect=(0,.06,1,.91));fig.savefig(O/'proof-timeline.png',dpi=150);plt.close(fig)
fig,ax=plt.subplots(figsize=(12,3.8));parts=[r['entry_us']/1000,t['status_wait_us']/1000,(r['target_tls_us']-t['status_wait_us'])/1000,r['response_us']/1000];labels=['本地Dial返回','读取OPEN确认阻塞','TLS计时其余部分','等待HTTP响应'];colors=['#8fabc7','#d26450','#a18bc4','#279c88'];left=0
for value,label,color in zip(parts,labels,colors):
 ax.barh(0,value,left=left,color=color,label=label,height=.45)
 if value>20:ax.text(left+value/2,0,f'{value:.2f} ms',ha='center',va='center',fontsize=11,color='white')
 left+=value
ax.set_yticks([]);ax.set_xlabel('ms');ax.set_xlim(0,600);fig.legend(*ax.get_legend_handles_labels(),prop=F,loc='upper center',bbox_to_anchor=(.5,.84),ncol=4);ax.grid(axis='x',alpha=.17);fig.suptitle('该请求首字节约534ms：状态读取占378ms',fontproperties=F,fontsize=17);fig.text(.5,.025,'这是客户端计时分摊；TLS其余部分不是独立握手时长，OPEN与TLS会流水线重叠。',fontproperties=F,ha='center',fontsize=10);fig.tight_layout(rect=(0,.12,1,.70));fig.savefig(O/'request-budget.png',dpi=150);plt.close(fig)
fig,ax=plt.subplots(figsize=(11,5));conditions=list(S);labels=['带载/追踪开','串行/追踪开','带载/追踪关','串行/追踪关']
for i,k in enumerate(conditions):
 d=S[k];ax.bar(i-.15,d['p50_ms'],width=.28,color='#3478b9');ax.bar(i+.15,d['p95_ms'],width=.28,color='#3478b9',alpha=.4);ax.annotate(f"{d['p95_ms']:.0f}",(i+.15,d['p95_ms']),ha='center',xytext=(0,5),textcoords='offset points')
ax.set_xticks(range(4),labels,fontproperties=F);ax.set_ylim(0,max(d['p95_ms'] for d in S.values())*1.25);ax.set_ylabel('ms');ax.grid(axis='y',alpha=.17);fig.suptitle('诊断对照：左P50 / 右P95，每组72个请求',fontproperties=F,fontsize=16);fig.text(.5,.015,'带载显式预热两通道，默认串行通常只建立一条；不能单独解释为“加负载更快”。',fontproperties=F,ha='center',fontsize=10);fig.tight_layout(rect=(0,.06,1,.92));fig.savefig(O/'conditions.png',dpi=150);plt.close(fig)
print('Generated 3 diagnostic charts')
