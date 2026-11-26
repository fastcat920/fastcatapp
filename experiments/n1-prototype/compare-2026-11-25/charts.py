from pathlib import Path
import json
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.font_manager import FontProperties
from matplotlib.patches import Patch
root=Path(__file__).resolve().parent;d=json.loads((root/'summary.json').read_text());font=FontProperties(fname='/System/Library/Fonts/Supplemental/Arial Unicode.ttf');plt.rcParams['font.family']=font.get_name();plt.rcParams['axes.unicode_minus']=False
protos=['n1','hysteria2','tuic'];labels=['N1 当前版','Hysteria 2','TUIC v5'];colors=['#4c68c8','#189980','#df8532'];fig,axes=plt.subplots(2,3,figsize=(15,8.7));fig.patch.set_facecolor('#f5f7fb')
for ax in axes.flat:ax.set_facecolor('white');ax.spines[['top','right']].set_visible(False);ax.grid(axis='y',alpha=.18);ax.set_axisbelow(True);ax.set_xticks(range(3),labels,fontsize=10)
for ax,key,title in zip(axes[0],['cold','warm','concurrent'],['冷启动首字节 · 18次/协议','连续请求首字节 · 排除每批首个','4路并发首字节 · 24次/协议']):
 for i,p in enumerate(protos):
  s=d[p][key]['first_byte_ms'];v=[s['p50'],s['p95']];bars=ax.bar([i-.17,i+.17],v,width=.30,color=[colors[i],colors[i]+'66'],zorder=3)
  ax.bar_label(bars,fmt='%.0f',padding=3,fontsize=9)
 ax.set_title(title,fontsize=12,pad=14);ax.set_ylabel('毫秒 · 越低越好');ax.legend(handles=[Patch(color='#64748b',label='P50'),Patch(color='#64748b66',label='P95')],fontsize=9,frameon=False)
for ax,key,field,title in zip(axes[1],['download_single','download_4','upload'],['e2e_mbps','payload_aggregate_mbps','e2e_mbps'],['4 MiB 单路下载 · 6轮','4 × 1 MiB 并发下载 · 6轮','1 MiB 上传 · 6轮']):
 for i,p in enumerate(protos):
  value=d[p][key][field]['p50'];bar=ax.bar(i,value,color=colors[i],width=.6,zorder=3);ax.bar_label(bar,fmt='%.2f',padding=4,fontsize=10)
  if field=='payload_aggregate_mbps':points=[x['payload_aggregate_mbps'] for x in d[p][key]['per_block']]
  else:points=[x['e2e_mbps'] for x in json.loads((root/'samples.json').read_text()) if x['protocol']==p and x['success'] and x['phase_index']==({'download_single':3,'upload':5}[key])]
  ax.scatter([i]*len(points),points,color='#172033',s=16,zorder=4,alpha=.65)
 if key=='download_single':ax.annotate('1次失败',xy=(0,0),xytext=(0,1.0),ha='center',fontsize=9,color='#b42318')
 ax.set_title(title,fontsize=12,pad=14);ax.set_ylabel('Mbps · 越高越好');ax.set_ylim(bottom=0)
fig.suptitle('N1 / Hysteria 2 / TUIC 实机对照',fontsize=21,fontweight='bold',x=.05,ha='left',y=.98)
fig.text(.05,.923,'同一荣耀安卓、Wi-Fi、香港服务器及校验源；N1 101/102，Hysteria 2 与 TUIC 各102/102成功。',fontsize=11,color='#44516a')
fig.text(.05,.02,'速率为成功样本中位数，含入口与正文/确认；并发按正文完成窗口合计。黑点为各轮。N1单路下载5/6成功；不代表通用排名。',fontsize=10,color='#44516a')
fig.subplots_adjust(left=.06,right=.98,top=.86,bottom=.10,hspace=.47,wspace=.28)
fig.savefig(root/'comparison.png',dpi=170,facecolor=fig.get_facecolor());fig.savefig(root/'comparison.svg',facecolor=fig.get_facecolor());print('saved comparison.png / .svg')
