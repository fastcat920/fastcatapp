# -*- coding: utf-8 -*-
from pathlib import Path
import json,html
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.font_manager import FontProperties
O=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/recovery-trio-2026-11-23');V=['next-opt','next-base','tuic'];N={'next-opt':'恢复状态选路','next-base':'Next 单连接','tuic':'TUIC v5'};C=['#8861b4','#3478b9','#26a185'];S=json.loads((O/'summary.json').read_text());T=json.loads((O/'steady-load/summary.json').read_text());U=json.loads((O/'paired-uncertainty.json').read_text())
plt.rcParams.update({'font.family':FontProperties(fname='/System/Library/Fonts/STHeiti Light.ttc').get_name(),'axes.unicode_minus':False})
def fmt(n):return '—' if n is None else f'{n:.2f}'
def table(h,rows):return '<div class="scroll"><table><tr>'+''.join('<th>'+html.escape(str(x))+'</th>' for x in h)+'</tr>'+''.join('<tr>'+''.join('<td>'+html.escape(str(x))+'</td>' for x in r)+'</tr>' for r in rows)+'</table></div>'
fig,axs=plt.subplots(1,2,figsize=(12,4.6),layout='constrained')
for i,v in enumerate(V):
 a=T[v]
 for off,key,alpha in [(-.15,'p50_ms',1),(.15,'p95_ms',.4)]:
  if a[key] is not None:
   ax=axs[0];bar=ax.bar(i+off,a[key],.28,color=C[i],alpha=alpha);ax.bar_label(bar,fmt='%.0f',padding=3,fontsize=9)
 if a['median_setup_plus_ready_ms'] is not None:
  bar=axs[1].bar(i,a['median_setup_plus_ready_ms'],.5,color=C[i],alpha=.7);axs[1].bar_label(bar,fmt='%.0f',padding=3)
for ax,title,y in zip(axs,['背景已各收256KiB：左P50，右P95','入口准备＋等待背景就绪，中位数'],['前台首字节 ms','ms']):
 ax.set_xticks(range(3),[N[v] for v in V]);ax.set_ylabel(y);ax.set_title(title);ax.spines[['top','right']].set_visible(False);ax.set_ylim(0,max([p.get_height() for p in ax.patches]+[1])*1.25)
fig.savefig(O/'steady-load.png',dpi=160);plt.close(fig)
rows=[]
for v in V:
 a=T[v];rows.append([N[v],a['groups'],f"{a['strict_loaded_success']}/{a['strict_loaded_total']}",fmt(a['p50_ms']),fmt(a['p95_ms']),f"{a['foreground_success']}/{a['foreground_total']}",f"{a['background_success']}/{a['background_total']}",fmt(a['median_setup_plus_ready_ms'])])
section='<h2>追加：背景已实际传输后的严格带载对照</h2><img src="steady-load.png">'+table(['配置','轮数','严格带载成功/总数','P50 ms','P95 ms','全部前台成功','背景完成','准备至就绪中位 ms'],rows)+'''<p>原带载程序只在后台任务启动150ms后开始前台，Next可用Warm预备入口，TUIC没有同接口。为减少准备时机差异，追加独立组六轮三配置对照：等两条背景各收到256KiB后再开始前台，最多等5秒；文件结束仍完整SHA256校验。只将请求开始时两条均已达到阈值且至少一条背景仍活跃的样本计入严格带载。等待次数、准备耗时与未满足条件的样本全部保留。</p><p>此补充组只增加测量就绪回调，协议核心和两个服务端二进制不变；组内三配置使用相同新测量程序，关闭诊断并继续交换端口。就绪计数在请求开始前读取，自检覆盖数据不丢失、收到两个信号才放行、等待取消和上限。原组与补充组在不同时间运行，且起始负载状态不同，不能把两组之间变化全部归因为预连接，更不能混合取最优结果。</p><p><a href="steady-load/plan.json">补充冻结计划</a> · <a href="steady-load/summary.json">严格带载汇总</a> · <a href="steady-load/all-rows.json">全部记录</a>。</p>'''
ci=[]
for r in U['results']:
 a,b=r['ratio'].split('/');ci.append([r['metric'],N[a]+' / '+N[b],fmt(r['estimate']),f"{fmt(r['exploratory_ci95'][0])} – {fmt(r['exploratory_ci95'][1])}",'高于1较好' if r['higher_is_better'] else '低于1较好',r.get('wins','—')])
section+='<h2>逐轮波动与解释边界</h2><p>六轮下载的散点已经保留在图中。部分场景最快与最慢轮差异很大；总体有效吞吐会被慢轮拉低，这正是它与逐轮中位数不同的原因。不要只挑最高点，也不要把串行或单文件场景的差异全部解释为恢复算法；该场景可能只有一个物理入口连接。</p><details><summary>查看按整轮配对重采样的不确定性（不是请求P95）</summary><p>六对样本按整轮配对进行10000次重采样；比值=左配置/右配置。区间跨1表示现有样本不足以稳判方向。仅为探索性95%区间，样本少、没有多重比较校正，不是正式显著性声明。吞吐的胜轮数也列出，不能仅由它推断长期胜率。</p>'+table(['指标','比值 左/右','点估计','探索性95%区间','方向','吞吐胜轮/6'],ci)+'</details>'
# Avoid importing current report generator (it regenerates all images). Append the final evidence to its fresh output.
p=O/'REPORT.html';page=p.read_text().replace('<h2>数据与自检</h2>',section+'<h2>数据与自检</h2>')
# Findings are explicit observations, not a cross-metric score or universal recommendation.
findings='''<h2>这轮数据说明什么</h2><p><b>没有一项配置在全部指标上领先。</b>恢复选路在本轮连续请求P95和滚动有效吞吐较好；Next单连接在四路、八路成批下载较好；TUIC单文件总体吞吐较高，两个真实网站带载P95也较低。启动期带载与背景就绪后的带载分别列出，不能只选对某配置有利的一组。</p><p>四路下载中恢复选路的总体吞吐约比单连接低26%；滚动下载则约高29%，但六轮中只在三轮吞吐高于单连接，结果受慢轮和波动影响。单文件两种Next配置未必启用第二条通道，该组的差异不能直接视为恢复算法收益。端口交叉虽减少固定端口偏差，不能消除所有源端口、路由与时段差异；本轮尚不足以判定所有网络下的稳定优劣。</p>'''
page=page.replace('<h2>配置与比较范围</h2>',findings+'<h2>配置与比较范围</h2>');p.write_text(page)
