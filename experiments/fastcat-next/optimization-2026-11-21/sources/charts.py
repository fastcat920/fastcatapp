from pathlib import Path
import json,statistics
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.font_manager import FontProperties
D=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/optimization-2026-11-21')
f=FontProperties(fname='/System/Library/Fonts/STHeiti Light.ttc');plt.rcParams['font.family']=f.get_name();plt.rcParams['axes.unicode_minus']=False
P=[('vless-vision','tcp-tls','VLESS Vision'),('trojan','tcp-tls','Trojan'),('hysteria2','quic','Hysteria 2'),('tuic','quic','TUIC v5'),('anytls','tcp-tls','AnyTLS'),('v2','h2','v2 H2'),('v2','h3','v2 H3 Reno'),('v2-bbr','h3','v2 H3 BBR'),('v3-light-fast','h2','轻量版 H2'),('v3-light-fast','h3','轻量版 H3'),('next','h2','Next 优化 H2'),('next','quic','Next 优化 QUIC')]
C=['#718ba1','#718ba1','#4188b1','#4188b1','#718ba1','#a49876','#bc8a8c','#3f7796','#ab9bb9','#ab9bb9','#73b4a6','#128778']
S=json.loads((D/'latency-summary.json').read_text())
fig,axs=plt.subplots(1,3,figsize=(18,9),layout='constrained')
for ax,phase,title in zip(axs,['cold','warm','batch'],['冷启动','三池连续','4 并发']):
 for i,(v,p,label) in enumerate(P):
  r=next((r for r in S if (r['workload'],r['version'],r['protocol'],r['phase'])==('internet',v,p,phase)),None)
  if r is None:continue
  if r['p50_ms'] is not None:
   ax.barh(i,r['p50_ms'],height=.55,color=C[i]);ax.scatter([r['p95_ms']],[i],marker='|',s=110,c='#142c3b',zorder=3)
   ax.text(r['p50_ms']+20,i+.35,f"{r['p50_ms']:.0f}   {r['success']}/{r['total']}",va='center',fontsize=8)
  else:ax.text(20,i,f"失败 {r['failures']}/{r['total']}",color='#a32d39',va='center',fontsize=9)
 ax.set_yticks(range(len(P)),[p[2] for p in P]);ax.invert_yaxis();ax.set_title(title);ax.set_xlabel('首字节 ms：柱=P50，竖线=P95');ax.grid(axis='x',alpha=.15);ax.set_axisbelow(True);ax.spines[['top','right']].set_visible(False)
fig.suptitle('优化后八协议 · 同一安卓 / Wi-Fi / VPS\n互联网目标；仅成功请求统计延迟，标签含成功/总数',fontsize=17);fig.savefig(D/'latency.png',dpi=160);plt.close(fig)
T=[json.loads(x) for x in (D/'throughput.jsonl').read_text().splitlines() if x.startswith('{')]
fig,ax=plt.subplots(figsize=(12,9),layout='constrained')
for i,(v,p,label) in enumerate(P):
 for j,w in enumerate([1,4]):
  rr=[r for r in T if (r['version'],r['protocol'],r['workers'])==(v,p,w) and not r.get('errors') and r.get('success')==w and r.get('download_mbps') is not None];a=[r['download_mbps'] for r in rr];y=i+(j-.5)*.3
  if a:ax.barh(y,statistics.median(a),height=.25,color=C[i],alpha=1 if j==0 else .45);ax.scatter(a,[y]*len(a),s=13,c='#142c3b',zorder=3);ax.text(.99,y,f'{statistics.median(a):.2f} ({len(a)}/3)',transform=ax.get_yaxis_transform(),ha='right',va='center',fontsize=8)
  else:ax.text(.99,y,'无有效组',transform=ax.get_yaxis_transform(),ha='right',va='center',fontsize=8)
maxval=max([r.get('download_mbps') or 0 for r in T] or [1]);ax.set_xlim(0,maxval*1.15);ax.set_yticks(range(len(P)),[p[2] for p in P]);ax.invert_yaxis();ax.set_title('8 秒双向 TLS 回环有效吞吐\n深色单流 / 浅色四流聚合，柱=中位数，右列含有效组数，点=各轮有效组');ax.set_xlabel('收到且校验通过的业务 Mbps');ax.grid(axis='x',alpha=.15);ax.set_axisbelow(True);ax.spines[['top','right']].set_visible(False);fig.savefig(D/'throughput.png',dpi=160);plt.close(fig)
