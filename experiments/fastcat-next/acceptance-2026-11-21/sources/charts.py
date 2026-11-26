from pathlib import Path
import json,statistics,math
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.font_manager import FontProperties
D=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/acceptance-2026-11-21')
font=FontProperties(fname='/System/Library/Fonts/STHeiti Light.ttc');plt.rcParams['font.family']=font.get_name();plt.rcParams['axes.unicode_minus']=False
S=json.loads((D/'latency-summary.json').read_text())
paths=[('v2-reno','h3','v2 H3 Reno'),('v2-bbr','h3','v2 H3 BBR'),('next','quic','Next QUIC BBR'),('next','h2','Next H2'),('v3-light-fast','h2','轻量版 H2'),('v3-light-fast','h3','轻量版 H3')]
colors=['#a0aab5','#4387ba','#168a78','#75b4a8','#a786b1','#b4a7bf']
fig,axs=plt.subplots(1,3,figsize=(15,5.1),layout='constrained')
for ax,phase,title in zip(axs,['cold','warm','batch'],['冷启动','连续请求 · 三个池','4 并发']):
 for i,(v,p,label) in enumerate(paths):
  row=next((r for r in S if r['workload']=='internet' and r['version']==v and r['protocol']==p and r['phase']==phase),None)
  if not row:continue
  ax.barh(i,row['p50_ms'] or 0,color=colors[i],height=.58);ax.scatter([row['p95_ms'] or 0],[i],marker='|',s=150,color='#152b3c',zorder=4)
  if row['p50_ms'] is not None:ax.text(row['p50_ms']+25,i+.35,f"{row['p50_ms']:.0f}   {row['success']}/{row['total']}",va='center',fontsize=8)
 ax.set_yticks(range(len(paths)),[x[2] for x in paths]);ax.invert_yaxis();ax.set_title(title);ax.set_xlabel('首字节 ms：柱=P50，竖线=P95');ax.grid(axis='x',alpha=.15);ax.set_axisbelow(True);ax.spines[['top','right']].set_visible(False)
fig.suptitle('同一安卓 / Wi-Fi / VPS：互联网目标首字节\n成功请求的延迟；标签为 P50 与成功/总数，失败不记零',fontsize=15)
fig.savefig(D/'latency.png',dpi=160);plt.close(fig)
R=[json.loads(x) for x in (D/'throughput.jsonl').read_text().splitlines() if x.startswith('{')]
fig,ax=plt.subplots(figsize=(10,5.2),layout='constrained')
for i,(v,p,label) in enumerate(paths):
 for j,workers in enumerate([1,4]):
  r=[r for r in R if r['version']==v and r['protocol']==p and r['workers']==workers and not r.get('errors') and r.get('success')==workers and r.get('download_mbps') is not None]
  values=[x['download_mbps'] for x in r];y=i+(j-.5)*.31
  if values:
   med=statistics.median(values);ax.barh(y,med,height=.26,color=colors[i],alpha=1 if j==0 else .48);ax.scatter(values,[y]*len(values),s=13,c='#152b3c',zorder=3);ax.text(.99,y,f'{med:.2f}',transform=ax.get_yaxis_transform(),ha='right',fontsize=8,va='center')
ax.set_xlim(0,max(r.get('download_mbps') or 0 for r in R)*1.15);ax.set_yticks(range(len(paths)),[x[2] for x in paths]);ax.invert_yaxis();ax.set_xlabel('收到且校验通过的业务 Mbps（4 流为聚合值）');ax.set_title('8 秒 TLS 回环有效吞吐：深色单流 / 浅色四流\n柱/右列=3 轮中位数，圆点=各轮有效组');ax.grid(axis='x',alpha=.15);ax.set_axisbelow(True);ax.spines[['top','right']].set_visible(False);fig.savefig(D/'throughput.png',dpi=160);plt.close(fig)
