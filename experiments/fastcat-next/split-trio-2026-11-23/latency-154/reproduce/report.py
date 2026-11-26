from pathlib import Path
import json,html
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.font_manager import FontProperties
O=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/split-trio-2026-11-23/latency-154');S=json.loads((O/'summary.json').read_text());V=['next-opt','next-base','tuic'];N=['恢复状态选路','Next 单连接','TUIC v5'];C=['#8861b4','#3478b9','#26a185'];M=[('latency/cold','冷启动'),('latency/warm','连续请求'),('latency/batch','四路并发短请求'),('batch8/batch','八路并发短请求'),('mixed/mixed','严格带载：固定目标'),('idle/idle-resume','闲置20秒后首次'),('web-example/mixed','严格带载：Example'),('web-google/mixed','严格带载：Google')]
plt.rcParams.update({'font.family':FontProperties(fname='/System/Library/Fonts/STHeiti Light.ttc').get_name(),'axes.unicode_minus':False})
def tab(h,rows):return '<div class="scroll"><table><tr>'+''.join('<th>'+html.escape(str(x))+'</th>' for x in h)+'</tr>'+''.join('<tr>'+''.join('<td>'+html.escape(str(x))+'</td>' for x in r)+'</tr>' for r in rows)+'</table></div>'
rows=[]
for group in range(2):
 fig,axs=plt.subplots(2,2,figsize=(13,9))
 for ax,(key,label) in zip(axs.flat,M[group*4:group*4+4]):
  heights=[]
  for i,v in enumerate(V):
   a=S[v][key]
   for off,k,alpha in [(-.15,'p50_ms',1),(.15,'p95_ms',.4)]:
    val=a[k]
    if val is None:continue
    ax.bar(i+off,val,.28,color=C[i],alpha=alpha);ax.annotate(f'{val:.0f}',(i+off,val),xytext=(0,3),textcoords='offset points',ha='center',fontsize=9);heights.append(val)
   if a['p95_ms'] is not None:ax.annotate(f"{a['success']}/{a['total']}",(i,a['p95_ms']),xytext=(0,19),textcoords='offset points',ha='center',fontsize=9)
   rows.append([label,N[i],f"{a['success']}/{a['total']}",'—' if a['p50_ms'] is None else f"{a['p50_ms']:.2f}",'—' if a['p95_ms'] is None else f"{a['p95_ms']:.2f}",a['max_ms']])
  ax.set_title(label);ax.set_xticks(range(3),N);ax.set_ylabel('首字节 ms，越低越好');ax.set_ylim(0,max(heights+[1])*1.35);ax.spines[['top','right']].set_visible(False);ax.grid(axis='y',alpha=.15)
 fig.suptitle('154.37.155.240 延迟重测：左P50，右P95',fontsize=16);fig.text(.5,.015,'安卓原生核心 / Wi-Fi；上方为成功数/样本数；不是ping，闲置只有6样本。',ha='center');fig.tight_layout(rect=(0,.05,1,.94));fig.savefig(O/f'latency-{group+1}.png',dpi=160);plt.close(fig)
bg=[]
for key in ['mixed/mixed','web-example/mixed','web-google/mixed']:
 for v,n in zip(V,N):
  a=S[v][key];bg.append([key,n,f"{a['all_foreground_success']}/{a['all_foreground_total']}",a['total'],f"{a['background_success']}/{a['background_total']}"])
page='''<!doctype html><html lang="zh"><meta charset="utf-8"><title>154延迟重测 · 三配置对照</title><style>body{max-width:1150px;margin:36px auto;padding:0 22px;font:16px/1.75 system-ui;color:#223449}img{width:100%}table{border-collapse:collapse;width:100%;font-size:14px}th,td{padding:9px;border-bottom:1px solid #d9e1e8;text-align:left}th{background:#edf3f8}.scroll{overflow:auto}h2{margin-top:36px}.note{padding:16px;background:#eef4fa}</style><h1>154.37.155.240：恢复状态选路 / Next单连接 / TUIC</h1><p>2026-11-23 · HONOR TFY-AN00 / Android12 · 同一Wi-Fi · 本次全新采样</p><div class="note">按用户要求，本服务器只用于延迟对比。速度服务器原104.64.221.179不可达，用户随后修正为172.104.55.44并独立测速；本报告仅包含154延迟，不使用154吞吐代替。延迟和速度不跨服务器合并成总分。</div><h2>配置与测量方法</h2><p>恢复选路=Next双通道、自适应与RecoveryAware启用；单连接=Next单通道；TUIC v5=Mihomo客户端＋CatNode V2Core服务器、原生连接池未人为双开。三组显式BBR，但实现/窗口默认值不同；不是严格等连接数实验。预算、首段副本、确认合并、0RTT/FastOpen关闭。沿用冻结二进制，测试中不调参。Next信号来自本端发包判丢和RTT，没有新增服务端下行恢复反馈；既有业务不自动重放。</p><p>每项主指标6轮、六种先后顺序各一次；两组实验端口19451/19458交叉分配，每配置各端口3轮。真实网站2轮，每配置每端口1轮。每组重启服务并冷却5秒，性能测试不采逐包或选路日志。端口交叉不能消除全部公网路由、时段或源端口影响。</p><p>固定目标是本VPS的TLS HTTPS服务。冷启动每请求新建客户端/入口；连续请求复用入口，每次仍新建目标TLS。首字节包括入口、目标TLS和HTTP，不能当ping或App启动时间。串行场景未必建立第二通道，因此不同数字不能直接归因恢复算法。</p><p>带载背景2×4MiB，前台12次HEAD；等待两条背景各收到256KiB或最多5秒。仅请求开始时两条已就绪且至少一条仍活跃的样本进入严格带载分位数；全部前台与背景完成数同时列出，文件结束完整SHA256校验。真实网站只替换前台目标，背景仍在本VPS。所有证书校验开启，临时实验根证书只供本轮程序使用，没有安装到系统；服务端临时hosts映射供TUIC目标嗅探后的解析。</p><h2>轻载与并发</h2><img src="latency-1.png"><h2>带载与闲置恢复</h2><img src="latency-2.png">'''
page+=tab(['场景','配置','成功/样本','P50 ms','P95 ms','最大 ms'],rows)+tab(['带载场景','配置','全部前台成功','严格样本数','背景完成'],bg)
page+='''<p>P50/P95按成功样本最近秩计算，失败另列。闲置只有六次首次请求，P95等于最慢值；不是切网验收。带载是否达到阈值与严格样本数必须一并看，不能只取成功分位数作为可靠性评分。</p><h2>数据与复现</h2><p><a href="plan.json">冻结计划及SHA256</a> · <a href="timeline.json">完整顺序与时间线</a> · <a href="summary.json">汇总</a> · <a href="all-rows.csv">全部CSV</a> · <a href="port-summary.json">分端口切片</a> · <a href="paired-uncertainty.json">探索性按轮重采样</a> · <a href="validation.txt">校验与清理</a> · <a href="reproduce/README.txt">复现说明</a></p><p>安卓原生核心独立程序、Wi-Fi测试，不替代正式App/TUN、蜂窝、锁屏耗电、隐蔽性或长期可用性验收。仅六个配对轮次，重采样区间不作正式显著性结论。手机VPN和唤醒设置在结束后恢复；临时入口和私钥清理。</p></html>'''
(O/'REPORT.html').write_text(page)
