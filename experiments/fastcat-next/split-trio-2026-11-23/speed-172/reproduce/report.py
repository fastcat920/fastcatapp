# -*- coding: utf-8 -*-
from pathlib import Path
import json,html,statistics,math,re
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.font_manager import FontProperties
O=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/split-trio-2026-11-23/speed-172');S=json.loads((O/'summary.json').read_text());G=json.loads((O/'download-groups.json').read_text());R=json.loads((O/'all-rows.json').read_text());V=['next-opt','next-base','tuic'];N=['恢复状态选路','Next 单连接','TUIC v5'];C=['#8861b4','#3478b9','#26a185'];M=['single64','parallel4','parallel8','rolling'];ML=['单文件64MiB','四路×16MiB','八路×8MiB','四路滚动十二个8MiB文件']
plt.rcParams.update({'font.family':FontProperties(fname='/System/Library/Fonts/STHeiti Light.ttc').get_name(),'axes.unicode_minus':False})
def tab(h,rows):return '<div class="scroll"><table><tr>'+''.join('<th>'+html.escape(str(x))+'</th>' for x in h)+'</tr>'+''.join('<tr>'+''.join('<td>'+html.escape(str(x))+'</td>' for x in r)+'</tr>' for r in rows)+'</table></div>'
def fmt(x):return '—' if x is None else f'{x:.2f}'
def pct(a,q):return sorted(a)[math.ceil(len(a)*q)-1] if a else None
fig,axs=plt.subplots(2,2,figsize=(13,9));rows=[]
for ax,m,title in zip(axs.flat,M,ML):
 heights=[]
 for i,v in enumerate(V):
  a=S[v][m];g=[r for r in G if r['metric']==m and r['version']==v]
  rate=a['aggregate_mbps'];ax.bar(i,rate,.5,color=C[i],alpha=.6);heights.append(rate)
  for j,r in enumerate(g):ax.scatter(i+(j-2.5)*.045,r['mbps'],s=24,color='#233444' if r['success']==r['jobs'] else '#c34343',marker='o' if r['success']==r['jobs'] else 'x',zorder=3);heights.append(r['mbps'])
  ax.annotate(fmt(rate),(i,max([rate]+[r['mbps'] for r in g])),xytext=(0,6),textcoords='offset points',ha='center');rows.append([title,N[i],a['groups'],f"{a['success']}/{a['jobs']}",fmt(rate),fmt(a['median_mbps']),fmt(a['min_mbps']),fmt(a['max_mbps'])])
 ax.set_title(title);ax.set_xticks(range(3),N);ax.set_ylabel('总体有效 Mbps，越高越好');ax.set_ylim(0,max(heights+[1])*1.25);ax.spines[['top','right']].set_visible(False);ax.grid(axis='y',alpha=.15)
fig.suptitle('172.104.55.44 速度重测：柱为总体有效吞吐，点为逐轮',fontsize=16);fig.text(.5,.015,'完整校验字节总量 / 总耗时；包含入口准备、目标TLS和校验；保留所有失败与超时。',ha='center');fig.tight_layout(rect=(0,.05,1,.94));fig.savefig(O/'downloads.png',dpi=160);plt.close(fig)
# Per-file completion samples preserve all failures and rolling slot scheduling definition.
completion=[]
for m,title in zip(M,ML):
 for v,n in zip(V,N):
  phases={'single64':'download','parallel4':'parallel_download_stream','parallel8':'parallel_download_stream','rolling':'rolling_download_stream'};a=[r for r in R if r.get('metric')==m and r.get('version')==v and r.get('phase')==phases[m]];good=[r for r in a if r.get('complete') and not r.get('error')];times=[r['total_ms'] for r in good];first=[r['first_byte_ms'] for r in good if r.get('first_byte_ms') is not None];completion.append([title,n,f'{len(good)}/{len(a)}',fmt(pct(times,.5)),fmt(pct(times,.95)),fmt(pct(first,.5)),fmt(pct(first,.95))])
echo=[];resource=[]
for v,n in zip(V,N):
 for w in [1,4]:
  a=S[v]['echo'+str(w)];echo.append([n,w,a['groups'],f"{a['success']}/{a['workers']}",fmt(a['median_receive_mbps']),fmt(a['median_alloc_per_verified_byte']),fmt(a['median_heapalloc_mib'])])
 for m,title in zip(M,ML):
  rr=[]
  for g in G:
   if g['metric']==m and g['version']==v:
    p=O/(g['source']+'-server-resource.txt')
    if p.exists():rr.append(dict(l.split('=',1) for l in p.read_text().splitlines() if '=' in l))
  mem=[int(x['MemoryPeak'])/1048576 for x in rr if x.get('MemoryPeak','').isdigit()];cpu=[int(x['CPUUsageNSec'])/1e9 for x in rr if x.get('CPUUsageNSec','').isdigit()];resource.append([title,n,len(rr),fmt(statistics.median(mem) if mem else None),fmt(statistics.median(cpu) if cpu else None)])
page='''<!doctype html><html lang="zh"><meta charset="utf-8"><title>172速度重测 · 三配置对照</title><style>body{max-width:1150px;margin:36px auto;padding:0 22px;font:16px/1.75 system-ui;color:#223449}img{width:100%}table{border-collapse:collapse;width:100%;font-size:14px}th,td{padding:9px;border-bottom:1px solid #d9e1e8;text-align:left}th{background:#edf3f8}.scroll{overflow:auto}h2{margin-top:36px}.note{padding:16px;background:#eef4fa}</style><h1>172.104.55.44：三配置网络速度对比</h1><p>2026-11-23 · HONOR TFY-AN00 / Android12 · 同一Wi-Fi · 原生核心独立程序</p><div class="note">用户将测速服务器修正为本地址；此前104.64.221.179没有测量数据。延迟结果另在154.37.155.240采集，两台服务器的数据不合成总分，不直接作跨服务器因果解释。</div><h2>配置和公平性边界</h2><p>冻结相同Next、CatNode TUIC服务器及安卓比较程序。恢复选路=Next双通道、自适应与RecoveryAware；单连接=Next单通道；TUIC v5=CatNode V2Core＋Mihomo原生池，未额外双开。显式BBR名称相同不代表实现、窗口及默认值一致。预算/首段副本/确认合并/0RTT/FastOpen关闭，没有调参。不是严格等连接数或单独线格式极限实验。</p><p>每项六轮、六种测试顺序各一次；19451/19458端口交叉，每配置每端口三轮。每组重启服务并冷却5秒，关闭逐包/选路日志和请求快照。串行或单文件场景恢复配置未必用到第二通道，所以差异不能直接归因恢复算法。既有业务不迁移或重放。真实恢复信号来自本端已发包判丢/RTT，没有新增服务器下行恢复反馈。</p><p>固定目标位于同VPS，HTTPS/TLS1.3且证书校验开启；相同临时证书与实验根，不装到系统。服务端临时hosts映射只供目标嗅探后的域名解析。原有服务不停止或覆盖，因此仍有共享CPU、其他业务和公网时段影响。服务器环境、原监听及每组资源快照均保留。</p><h2>完整文件有效吞吐</h2><img src="downloads.png">'''
page+=tab(['任务','配置','轮数','完整校验文件','总体Mbps','逐轮中位Mbps','最慢轮Mbps','最快轮Mbps'],rows)
page+='''<p>总体有效吞吐=所有完成校验的字节总量/全部轮次耗时，包含入口准备、目标TLS、接收与校验。不是峰值或各轮速度的算术平均；未完成文件不当成完整成果，等待和失败保留。红叉代表不完整组。每组新客户端，单文件与并发均保持相同目标任务总量64MiB；滚动96MiB独立列出。</p><h2>每文件完成时间</h2>'''+tab(['任务','配置','完成/记录数','完成P50 ms','完成P95 ms','首字节P50 ms','首字节P95 ms'],completion)
page+='''<p>仅成功文件进入延迟分位数，失败数同时列出。滚动单文件计时从拿到工作槽位开始，不包含此前排队；整组耗时包含全部队列完成。此处首字节是大下载任务里的辅助观察，不替代154的延迟专测。</p><h2>八秒双向回显（非纯上传）</h2>'''+tab(['配置','流数','轮数','成功流','接收Mbps中位','分配B/校验接收B','HeapAlloc MiB中位'],echo)
page+='''<p>同时发送并接收回显，数据阶段在准备完成后计时；它不是纯上传，也不与端到端下载吞吐直接合成。HeapAlloc是Go阶段末快照，受GC和吞吐影响，不是峰值RSS或耗电。</p><h2>服务端辅助资源快照</h2>'''+tab(['任务','配置','快照数','MemoryPeak中位MiB','CPUUsage中位秒'],resource)
page+='''<p>数据来自阶段结束后的systemd服务统计，包含服务启动和准备开销；只覆盖该入口服务，不含本地HTTPS目标、系统或客户端，不能等同净协议CPU成本。原始每组文件可核对。</p><h2>直连HTTPS对照</h2>'''
p=O/'direct-control.jsonl'
if p.exists():
 dr=[json.loads(l) for l in p.read_text().splitlines() if l.strip()];page+=tab(['轮次','接收字节','耗时秒','已收字节/耗时（非完整吞吐）Mbps','错误'],[[r['round'],r['bytes'],fmt(r['seconds']),fmt(r['mbps']),r['error']] for r in dr]);page+='<p>64MiB×3，TLS验证开启；只有完整64MiB且哈希匹配才算完成。目前必须同时查看接收字节和错误，部分文件的字节/耗时不能当作完整下载吞吐或网络上限。主测试结束后单独进行，没有与代理流量同时争用。此三次对照均未完成，不能用部分字节速率判定带宽上限。服务器TCP快照显示CUBIC、cwnd6、重传/重排序；三种代理则是QUIC/BBR，时间、拥塞控制、封装和连接结构不同，不能单凭该快照认定全部根因。</p>'
else:page+='<p>直连对照待主测试结束后采集，不用历史数字代替。</p>'
page+='''<h2>原始数据与校验</h2><p><a href="plan.json">冻结计划和SHA256</a> · <a href="timeline.json">时间线</a> · <a href="summary.json">汇总</a> · <a href="all-rows.csv">全部CSV</a> · <a href="download-groups.json">逐轮下载</a> · <a href="port-summary.json">分端口切片</a> · <a href="paired-uncertainty.json">配对整轮探索性重采样</a> · <a href="validation.txt">自检与清理</a> · <a href="reproduce/README.txt">复现说明</a></p><p>六对样本的区间仅探索，不作正式显著性结论。所有原始失败、慢轮保留。此处仅安卓Wi-Fi原生核心，非正式App/TUN、蜂窝、锁屏能耗或隐蔽性验收。结束恢复手机VPN，清理临时服务与私钥。</p></html>'''
(O/'REPORT.html').write_text(page)
