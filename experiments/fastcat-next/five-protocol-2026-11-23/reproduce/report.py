# -*- coding: utf-8 -*-
from pathlib import Path
import sys,json,html,statistics,math
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.font_manager import FontProperties
MODE=sys.argv[1];O=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/five-protocol-2026-11-23')/MODE;S=json.loads((O/'summary.json').read_text());R=json.loads((O/'all-rows.json').read_text());G=json.loads((O/'download-groups.json').read_text());V=['next-opt','next-base','tuic','hysteria2','vless-vision'];N=['恢复选路','Next单连接','TUIC v5','Hysteria 2','VLESS Vision'];C=['#8861b4','#3478b9','#26a185','#e09c32','#cb647b'];plt.rcParams.update({'font.family':FontProperties(fname='/System/Library/Fonts/STHeiti Light.ttc').get_name(),'axes.unicode_minus':False})
# Combine disjoint latency metrics only; never pool superseded measurements.
if MODE=='latency':
 loaded=O.parent/'latency-loaded/summary.json'
 if loaded.exists():
  LS=json.loads(loaded.read_text())
  for v in V:
   for key in ['mixed/mixed','web-example/mixed','web-google/mixed']:S[v][key]=LS[v][key]
  (O/'combined-summary.json').write_text(json.dumps(S,indent=2))
def fmt(x):return '—' if x is None else f'{x:.2f}'
def tab(h,rows):return '<div class="scroll"><table><tr>'+''.join('<th>'+html.escape(str(x))+'</th>' for x in h)+'</tr>'+''.join('<tr>'+''.join('<td>'+html.escape(str(x))+'</td>' for x in r)+'</tr>' for r in rows)+'</table></div>'
def pct(a,q):return sorted(a)[math.ceil(len(a)*q)-1] if a else None
config=tab(['配置','实际组合','服务端/补充参数'],[['恢复选路','Next双QUIC通道＋TLS、自适应RecoveryAware','冻结Next原型，BBR；预算/副本/合并关闭'],['Next单连接','Next单QUIC通道＋TLS','同Next服务器，BBR'],['TUIC v5','QUIC＋TLS','CatNode V2Core/Mihomo；BBR，0RTT/FastOpen关闭'],['Hysteria 2','QUIC＋TLS','CatNode V2Core/Mihomo；未填Brutal速率，默认BBR路径，无obfs'],['VLESS Vision','TCP＋TLS＋XTLS Vision，VLESS无额外加密','CatNode V2Core/Mihomo；系统TCP拥塞控制见环境记录；不是REALITY']])
page='''<!doctype html><html lang="zh"><meta charset="utf-8"><title>五配置新对照</title><style>body{max-width:1250px;margin:36px auto;padding:0 22px;font:16px/1.75 system-ui;color:#223449}img{width:100%}h2{margin-top:36px}table{border-collapse:collapse;width:100%;font-size:14px}th,td{padding:9px;text-align:left;border-bottom:1px solid #dbe2e9}th{background:#edf3f8}.scroll{overflow:auto}.note{padding:18px;background:#edf3f8}a{color:#245b98}</style><h1>五配置新对照 · '''+('172.104.55.44 网络速度' if MODE=='speed' else '154.37.155.240 首字节延迟')+'''</h1><p>2026-11-23 · HONOR TFY-AN00 / Android12 · 同一Wi-Fi原生核心</p><div class="note">本次五组全部重新采样，不拼接旧三组成绩。主项十轮Williams平衡顺序，各配置在每位置两次；每轮五组共用同一数字入口端口，轮间19458/19451交替，每配置每端口五轮。真实网站仅两轮、前后顺序反转，单独列出。</div><h2>配置与解释边界</h2>'''+config+'''<p>每组新客户端并重启对应测试服务，冷却5秒；只有当前测试入口启动。证书校验开启，临时根证书仅用于测试程序，不装到系统。固定目标为同VPS上的HTTPS服务，相同证书及域名；临时hosts映射保证CatNode目标嗅探后可解析。两台服务器分别用于速度/延迟，不跨服务器合成总分。业务是TCP/HTTPS和TCP回显，未测试UDP业务中继、人工丢包、切网或耗电；QUIC入口不等于已验收UDP业务。端口和顺序平衡仍不能消除全部源端口、路径和时段影响；服务器原有业务未停用，公网和CPU不是完全隔离的实验室环境。</p><p>Next原型与CatNode完整核心的调度/dispatcher/limiter开销不同；QUIC的BBR也不是同一实现与窗口。VLESS基于TCP，无法据本结果分离传输、拥塞算法与实现效果。串行场景恢复配置未必建立第二通道，差异不能全部归因恢复选路。恢复只为新流避让本端发包判丢/RTT恶化的入口，既有业务不迁移/重放，没有新增服务器下行恢复反馈。</p><p>测试不调参，不采逐包或选路日志，不删除或替换慢轮。仅测量工具增加收到前缀的SHA256校验及严格带载等待上限15秒，协议核心未改；竞态和静态检查已通过。相同测量工具覆盖全部五组。</p>'''
if MODE=='speed':
 M=['single32','parallel4','parallel8','rolling'];ML=['单文件32MiB / 上限30秒','四路×8MiB / 上限30秒','八路×4MiB / 上限30秒','四路滚动12×4MiB / 上限45秒'];rows=[];fig,axs=plt.subplots(2,2,figsize=(15,10))
 for ax,m,title in zip(axs.flat,M,ML):
  heights=[]
  for i,v in enumerate(V):
   a=S[v][m];g=[r for r in G if r['metric']==m and r['version']==v];rate=a['aggregate_prefix_mbps'];ax.bar(i,rate,.5,color=C[i],alpha=.65);heights.append(rate)
   for j,r in enumerate(g):ax.scatter(i+(j-4.5)*.025,r['prefix_mbps'],s=20,color='#233444' if r['success']==r['jobs'] else '#b33c3c',marker='o' if r['success']==r['jobs'] else 'x',zorder=3);heights.append(r['prefix_mbps'])
   ax.annotate(fmt(rate),(i,max([rate]+[r['prefix_mbps'] for r in g])),xytext=(0,5),textcoords='offset points',ha='center',fontsize=9)
   rows.append([title,N[i],a['groups'],fmt(rate),fmt(a['aggregate_complete_mbps']),f"{a['success']}/{a['jobs']}",fmt(a['median_prefix_mbps']),fmt(a['min_prefix_mbps']),fmt(a['max_prefix_mbps']),a['prefix_validation_failures']])
  ax.set_title(title);ax.set_xticks(range(5),N,rotation=12);ax.set_ylabel('已校验接收吞吐 Mbps，越高越好');ax.set_ylim(0,max(heights+[1])*1.22);ax.spines[['top','right']].set_visible(False);ax.grid(axis='y',alpha=.15)
 fig.suptitle('五配置速度：柱为总体，点为各轮；红叉为未完整完成文件',fontsize=16);fig.text(.5,.013,'接收前缀独立SHA256校验；未完整文件保留其状态与耗时。不能把前缀吞吐当成完整文件成功率。',ha='center',fontsize=10);fig.tight_layout(rect=(0,.05,1,.94));fig.savefig(O/'speed.png',dpi=160);plt.close(fig)
 page+='<h2>下载吞吐与完整文件成果</h2><img src="speed.png">'+tab(['任务','配置','轮数','校验接收Mbps','完整文件成果Mbps','完整文件/计划','逐轮中位','最慢轮','最快轮','前缀校验失败'],rows)
 page+='''<p><b>两种吞吐必须区别：</b>校验接收吞吐=完整文件及未完成文件中已收到、且前缀SHA256与固定目标数据匹配的字节总量/总耗时；完整文件成果吞吐只计完整并校验通过的文件字节，分母仍含失败等待。未完成文件不能说成成功；仅连接失败和确实未收字节的组才是零接收成果。超时错误及字节数原样保留。所有配置相同目标、大小、时限和校验。</p><p>主测文件总任务量：单流/四路/八路各32MiB，滚动48MiB；上限30/45秒是端到端组时限，不是固定稳态数据窗口。入口准备、目标TLS和校验含在时间中。能提前完成的组提前结束，慢组按时限返回；这是有界文件任务表现，非单独拥塞算法极限速率。部分接收可测速度，但文件完成数和错误必须一起评估。</p>'''
 echo=[]
 for v,n in zip(V,N):
  for w in [1,4]:
   a=S[v]['echo'+str(w)];echo.append([n,w,a['groups'],f"{a['success']}/{a['workers']}",fmt(a['median_receive_mbps']),len(a['errors'])])
 page+='<h2>五秒双向回显辅助观察</h2>'+tab(['配置','流数','轮数','成功流','接收Mbps中位','错误条数'],echo)+'<p>同时发送与接收回显，开始计时前已有准备阶段；不是纯上传，也不与端到端下载速率直接合成。没有进行纯上传、锁屏或耗电结论。</p>'
else:
 page+='''<p><b>带载覆盖修正：</b>初版测量工具的带载分支只选QUIC，跳过VLESS TCP。旧带载记录已归档且不参与五组排名；带载/真实网站全部五组用修正后的同一工具重新采集于独立latency-loaded阶段。冷/热、并发和闲置覆盖正确，继续保留。两种工具只在带载测量选择和帮助文本不同，协议核心和服务器未改；不将两个阶段混算同一指标。</p><p><a href="../latency-loaded/plan.json">修正后带载冻结计划</a> · <a href="../latency-loaded/all-rows.csv">带载与网站全部CSV</a> · <a href="../latency-loaded/summary.json">带载汇总</a> · <a href="combined-summary.json">按场景合并展示的汇总</a></p>'''
 M=[('latency/cold','冷启动'),('latency/warm','连续请求'),('latency/batch','四路短请求'),('batch8/batch','八路短请求'),('mixed/mixed','固定目标严格带载'),('idle/idle-resume','闲置20秒后的首次（10次）'),('web-example/mixed','Example严格带载（两轮）'),('web-google/mixed','Google严格带载（两轮）')];rows=[]
 for group in range(2):
  fig,axs=plt.subplots(2,2,figsize=(15,10))
  for ax,(key,title) in zip(axs.flat,M[group*4:group*4+4]):
   heights=[]
   for i,v in enumerate(V):
    a=S[v][key]
    for off,k,alpha in [(-.14,'p50_ms',1),(.14,'p95_ms',.4)]:
     val=a[k]
     if val is None:continue
     ax.bar(i+off,val,.25,color=C[i],alpha=alpha);heights.append(val);ax.annotate(f'{val:.0f}',(i+off,val),xytext=(0,3),textcoords='offset points',ha='center',fontsize=8)
    if a['p95_ms'] is not None:ax.annotate(f"{a['success']}/{a['total']}",(i,a['p95_ms']),xytext=(0,18),textcoords='offset points',ha='center',fontsize=8)
    rows.append([title,N[i],f"{a['success']}/{a['total']}",fmt(a['p50_ms']),fmt(a['p95_ms']),fmt(a['max_ms']),a['missing_rows']])
   ax.set_title(title);ax.set_xticks(range(5),N,rotation=12);ax.set_ylabel('首字节 ms，越低越好');ax.set_ylim(0,max(heights+[1])*1.35);ax.spines[['top','right']].set_visible(False);ax.grid(axis='y',alpha=.15)
  fig.suptitle('五配置延迟：左P50，右P95；上方为成功/样本',fontsize=16);fig.text(.5,.013,'端到端首字节包含入口、目标TLS和HTTP；不是ping或App启动时间。',ha='center');fig.tight_layout(rect=(0,.05,1,.94));fig.savefig(O/f'latency-{group+1}.png',dpi=160);plt.close(fig)
 page+='<h2>首字节延迟</h2><img src="latency-1.png"><img src="latency-2.png">'+tab(['场景','配置','成功/样本','P50 ms','P95 ms','最大 ms','缺失记录'],rows)
 bg=[]
 for key in ['mixed/mixed','web-example/mixed','web-google/mixed']:
  for v,n in zip(V,N):
   a=S[v][key];bg.append([key,n,f"{a['all_foreground_success']}/{a['all_foreground_total']}",a['total'],f"{a['background_success']}/{a['background_total']}"])
 page+='<h2>带载资格和文件完成数</h2>'+tab(['场景','配置','全部前台成功','严格样本数','背景完整文件'],bg)
 page+='''<p>冷启动每请求新建客户端/入口，连续请求复用入口但新建目标TLS。主项冷/热各60次、四路短请求80次、八路160次；固定带载前台60次，闲置只取每轮20秒后的首次10次。真实网站每组24次。失败单列，不挤入成功延迟分位数；主项期望数按尝试的计划计算，缺失单列。</p><p>带载背景2×2MiB，等待两条各收256KiB或最多15秒，再发前台；只有请求开始时两条都就绪且至少一条仍活跃才进入严格样本。全部前台结果、背景完整校验数一并列出。背景可能较早完成或未达到就绪阈值，所以严格样本数可不同。未满足资格不是丢弃失败，原记录仍保留。真实网站前台替换域名，背景不变。闲置10样本P95等于最大值，不能判断长期概率；不是切网测试。</p>'''
page+='''<h2>复现与自检</h2><p><a href="plan.json">冻结计划与二进制SHA256</a> · <a href="timeline.json">完整顺序和时间线</a> · <a href="summary.json">汇总JSON</a> · <a href="all-rows.csv">全部CSV</a> · <a href="paired-uncertainty.json">按整轮配对探索性重采样</a> · <a href="validation.txt">验证与清理</a> · <a href="../reproduce/README.txt">复现说明</a></p><p>仅一台安卓、一个Wi-Fi、指定两个VPS，正式App/TUN、其他网络、长期可用性、耗电和隐蔽性尚未由本实验验证。十轮仍有限，探索性区间不作正式显著性声明，未做多重比较校正。正式数据不混入早期部署预检失败或历史成绩；所有已测慢轮和错误保留。</p></html>'''
(O/'REPORT.html').write_text(page)
