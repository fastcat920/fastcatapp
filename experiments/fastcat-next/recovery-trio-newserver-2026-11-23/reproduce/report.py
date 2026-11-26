# -*- coding: utf-8 -*-
from pathlib import Path
import json,math,statistics,html
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.font_manager import FontProperties
O=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/recovery-trio-newserver-2026-11-23');S=json.loads((O/'summary.json').read_text());G=json.loads((O/'download-groups.json').read_text());R=json.loads((O/'all-rows.json').read_text());P=json.loads((O/'port-summary.json').read_text());V=['next-opt','next-base','tuic'];N={'next-opt':'恢复状态选路','next-base':'Next 单连接','tuic':'TUIC v5'};C=['#8861b4','#3478b9','#26a185'];plt.rcParams.update({'font.family':FontProperties(fname='/System/Library/Fonts/STHeiti Light.ttc').get_name(),'axes.unicode_minus':False,'font.size':10})
def fmt(n):return '—' if n is None else f'{n:.2f}'
def table(h,rows):return '<div class="scroll"><table><tr>'+''.join('<th>'+html.escape(str(x))+'</th>' for x in h)+'</tr>'+''.join('<tr>'+''.join('<td>'+html.escape(str(x))+'</td>' for x in r)+'</tr>' for r in rows)+'</table></div>'
def setup(ax,title,y):ax.set_title(title);ax.set_xticks(range(3),[N[v] for v in V]);ax.set_ylabel(y);ax.set_ylim(bottom=0);ax.spines[['top','right']].set_visible(False);ax.grid(axis='y',alpha=.15)
def save(fig,name,title,foot):fig.suptitle(title,fontsize=16);fig.text(.5,.012,foot,ha='center',fontsize=9);fig.tight_layout(rect=(0,.055,1,.93));fig.savefig(O/name,dpi=160);plt.close(fig)
def latency(ax,key,title):
 heights=[]
 for i,v in enumerate(V):
  a=S[v][key];vals=[a['p50_ms'],a['p95_ms']]
  if vals[0] is None:continue
  for off,val,alpha in [(-.15,vals[0],1),(.15,vals[1],.4)]:
   ax.bar(i+off,val,.28,color=C[i],alpha=alpha);ax.annotate(f'{val:.0f}',(i+off,val),ha='center',xytext=(0,3),textcoords='offset points',fontsize=8)
  ax.annotate(f"{a['success']}/{a['total']}",(i,max(vals)),ha='center',xytext=(0,17),textcoords='offset points',fontsize=8);heights+=vals
 setup(ax,title,'ms，越低越好');ax.set_ylim(0,max(heights+[1])*1.3)
fig,axs=plt.subplots(2,2,figsize=(12.5,8))
for ax,key,title in zip(axs.flat,['latency/cold','latency/warm','latency/batch','batch8/batch'],['入口冷启动首字节','连续请求首字节','四路并发短请求','八路并发短请求']):latency(ax,key,title)
save(fig,'latency.png','首字节：左 P50，右 P95','上方分数为成功/总请求；失败单列，不混入延迟分位数。不是节点ping或App启动时间。')
fig,axs=plt.subplots(2,2,figsize=(12.5,8));M=['single16','parallel4','parallel8','rolling-small'];ML=['单文件16MiB','四路 × 4MiB','八路 × 2MiB','四路滚动十二个1MiB文件（低带宽阶段）']
for ax,m,label in zip(axs.flat,M,ML):
 allrates=[]
 for i,v in enumerate(V):
  a=S[v][m];g=[r for r in G if r['metric']==m and r['version']==v]
  if not g:continue
  rate=a['aggregate_mbps'];ax.bar(i,rate,.5,color=C[i],alpha=.6)
  for j,r in enumerate(g):ax.scatter(i+(j-2.5)*.045,r['mbps'],marker='o' if r['success']==r['jobs'] else 'x',color='#233444' if r['success']==r['jobs'] else '#d14747',s=25,zorder=3)
  ax.annotate(f'{rate:.2f}',(i,rate),ha='center',xytext=(0,5),textcoords='offset points');allrates += [r['mbps'] for r in g]+[rate]
 setup(ax,label,'有效 Mbps，越高越好');ax.set_ylim(0,max(allrates+[1])*1.2)
save(fig,'downloads.png','下载：柱为总体有效吞吐，点为各轮','总完整校验字节 / 总耗时，保留失败和超时等待；红叉代表未完整完成。')
fig,axs=plt.subplots(2,2,figsize=(12.5,8))
for ax,key,title in zip(axs.flat,['mixed/mixed','web-example/mixed','web-google/mixed','idle/idle-resume'],['固定目标：后台下载期间前台请求','Example：后台下载期间前台请求','Google：后台下载期间前台请求','闲置20秒后首请求（各6次）']):latency(ax,key,title)
save(fig,'loaded-idle.png','负载下前台与闲置恢复：左 P50，右 P95','带载须两条背景各收256KiB且请求开始时仍活跃；闲置仅首条恢复请求，6样本的P95等于最大值。')
fig,axs=plt.subplots(1,3,figsize=(14,4.8))
for i,v in enumerate(V):
 for j,w in enumerate([1,4]):
  a=S[v]['echo'+str(w)]
  for ax,key in zip(axs,['median_receive_mbps','median_alloc_per_verified_byte','median_heapalloc_mib']):
   if a[key] is not None:ax.bar(i+(j-.5)*.28,a[key],.27,color=C[i],alpha=1 if j==0 else .4)
for ax,title,y in zip(axs,['5秒双向回显：接收吞吐','Go分配字节 / 校验接收字节','阶段末 HeapAlloc 快照'],['Mbps','B/B','MiB']):setup(ax,title,y)
save(fig,'echo-resources.png','回显辅助观察：左单流，右四流','非纯上传/下载；数据阶段不含准备时间。HeapAlloc受GC影响，不是峰值RSS或耗电。')
fig,axs=plt.subplots(2,2,figsize=(12.5,8))
for ax,m,title,unit in zip(axs.flat,['latency','mixed','parallel4','rolling-small'],['连续请求 P95，按入口端口','带载前台 P95，按入口端口','四路下载，按入口端口','滚动下载，按入口端口'],['ms','ms','Mbps','Mbps']):
 heights=[]
 for i,v in enumerate(V):
  for j,port in enumerate(['19451','19458']):
   a=P[m][v][port];val=a.get('p95_ms') if m in ['latency','mixed'] else a.get('aggregate_mbps')
   if val is None:continue
   ax.bar(i+(j-.5)*.28,val,.27,color=C[i],alpha=1 if j==0 else .4);heights.append(val)
 setup(ax,title,unit);ax.set_ylim(0,max(heights+[1])*1.2)
save(fig,'ports.png','端口交叉检查：左19451，右19458','完整六轮指标每种配置在每端口各3轮；不是额外重复样本，不与主汇总再相加。')
lat=[]
for key,title in [('latency/cold','入口冷启动'),('latency/warm','连续请求'),('latency/batch','四路短请求'),('batch8/batch','八路短请求'),('mixed/mixed','本地目标带载'),('web-example/mixed','Example带载'),('web-google/mixed','Google带载'),('idle/idle-resume','闲置20秒后首条')]:
 for v in V:
  a=S[v][key];lat.append([title,N[v],f"{a['success']}/{a['total']}",fmt(a['p50_ms']),fmt(a['p95_ms']),fmt(a['max_ms'])])
download=[]
for m,label in zip(M,ML):
 for v in V:
  a=S[v][m];download.append([label,N[v],a['groups'],f"{a['success']}/{a['jobs']}",fmt(a['aggregate_mbps']),fmt(a['median_mbps']),fmt(a['min_mbps']),fmt(a['max_mbps'])])
bg=[]
for m in ['mixed/mixed','web-example/mixed','web-google/mixed']:
 for v in V:
  a=S[v][m];bg.append([m,N[v],f"{a['all_foreground_success']}/{a['all_foreground_total']}",a['total'],f"{a['background_success']}/{a['background_total']}"])
echo=[]
for v in V:
 for w in [1,4]:
  a=S[v]['echo'+str(w)];echo.append([N[v],w,a['groups'],f"{a['success']}/{a['workers']}",fmt(a['median_receive_mbps']),fmt(a['median_alloc_per_verified_byte']),fmt(a['median_heapalloc_mib'])])
intro='''<!doctype html><html lang="zh"><meta charset="utf-8"><title>恢复状态选路 / Next单连接 / TUIC 新对照</title><style>body{max-width:1180px;margin:36px auto;padding:0 22px;font:16px/1.75 system-ui;color:#223449}h1,h2{line-height:1.4}h2{margin-top:38px}.scroll{overflow:auto}table{border-collapse:collapse;width:100%;font-size:14px}th,td{border-bottom:1px solid #d9e1e8;text-align:left;padding:9px}th{background:#eff4f8}img{width:100%}.note{padding:18px;background:#eef4fa;border-left:5px solid #5476aa}a{color:#245b98}</style><h1>恢复状态选路 · Next 单连接 · TUIC v5</h1><p>2026-11-23 · VPS 154.37.155.240 · HONOR TFY-AN00 / Android12 · 同一Wi-Fi、同一公网VPS · 安卓原生核心独立程序。正式App VPN临时关闭，未替换正式App。</p><div class="note">本轮重新采样，不混用历史报告。注意：滚动中途出现共同带宽退化，直连HTTPS也降至约1.8Mbps；大任务未完成记录保留，随后改用独立的小任务阶段，不将两个阶段混合。完整主指标每配置6轮、六种先后顺序各一次；原48MiB滚动仅3轮，另列未完成记录；两组实验端口每轮交叉分配。关闭逐包、选路日志和请求快照，不在测试中调参或删除慢轮。结果只描述这一实现、配置和网络组合。</div><h2>配置与比较范围</h2>'''
config=table(['配置','客户端','服务端','保持/关闭'],[['恢复状态选路','Next自适应双通道 + RecoveryAware','冻结Next独立原型','BBR；预算/首段副本/确认合并关闭'],['Next单连接','单物理连接池，恢复选路关闭','与上一行相同服务端','BBR；相同QUIC基础配置'],['TUIC v5','Mihomo原生TUIC池，未额外双开','本轮从CatNode构建V2Core，含dispatcher/limiter','双方显式BBR；0RTT与FastOpen关闭；合成用户不限速/设备数']])
methods='''<p>三组使用同一证书与SNI，外层为QUIC/TLS1.3，密码实现与默认握手未另调。BBR名称相同不代表依赖实现和窗口参数完全一致。Next是独立实验服务器，TUIC是CatNode核心，差异包含实现和调度开销，不是单独线格式或加密算法的极限评比，也不是严格等连接数实验。</p><p>固定目标为VPS上的HTTPS服务；所有目标证书校验开启。首字节、单文件及成批下载来自前期约4.4Mbps阶段，滚动小任务、带载、回显、闲置与真实网站来自后期约1.8Mbps阶段。不同阶段不能用于单独归因协议调度效果。冷启动是每次新建客户端/入口连接，不是App启动，也没有声称清空系统DNS或所有TLS缓存。连续请求复用入口但每次新建目标TLS。文件组使用共享客户端，统计包含入口准备、目标TLS和完成校验耗时；回显吞吐则从准备完成后计时。首次并发可能包含副通道准备。</p><p>串行请求和单文件场景未必建立第二通道，因此即使恢复配置的数字不同，也不能全部归因于恢复选路。并发/带载更能体现其两条通道和新流选择。恢复信号直接来自本端已发包判丢与入口RTT，没有新增对端下行恢复反馈；既有业务不迁移、不重放。</p>'''
page=intro+config+methods+'<h2>首字节延迟</h2><img src="latency.png">'+table(['场景','配置','成功/总数','P50 ms','P95 ms','最大 ms'],lat)+'''<p>P50表示半数成功请求不超过该值；P95表示95%成功请求不超过该值，失败另列。首字节含入口/目标TLS/HTTP，不是ping。入口Dial返回可能早于成功状态被读取，不用旧entry/target_tls列直接判断根因，各阶段分位数不可相加。</p><h2>固定大小下载</h2><img src="downloads.png">'''+table(['场景','配置','轮数','文件完成','总体有效 Mbps','逐轮中位 Mbps','最慢轮 Mbps','最快轮 Mbps'],download)+'''<p>总体有效吞吐=完整校验字节总量/全部轮次总耗时。部分未完成文件不当成完整成果，失败/超时等待保留。TUIC原48MiB滚动第二、三轮触发180秒整组上限，未取得最终完成记录，整组待验证字节按零计；这不等于证明每个文件都未传输。编排停止并恢复VPN后，重新预检，从下一组续跑；没有重跑替换该超时组。不是峰值，也不是各轮速度的算术平均。不同指标或不同测试时段不合并成一个总分。</p><h2>带载前台与闲置后首请求</h2><img src="loaded-idle.png">'''+table(['场景','配置','全部前台成功','严格带载样本数','背景下载完成'],bg)+'''<p>低带宽阶段带载条件为2×4MiB背景下载与12次前台HEAD共享客户端；后台两条下载各收到256KiB后再发前台，最多等待5秒；只有请求开始时两条均已就绪且背景仍活跃的样本进入带载分位数。远端组后台使用证书匹配的fc-lab.test:19454，前台独立访问Example/Google。没有关闭证书校验。闲置组只看20秒后的第一条请求，6样本P95等于最大值；它不是切网或断线重连测试。</p><h2>回显与辅助资源</h2><img src="echo-resources.png">'''+table(['配置','并发流','轮数','成功流','接收Mbps中位','分配B/接收B中位','HeapAlloc MiB中位'],echo)+'''<p>每轮5秒同时发送并回显校验，准备时间另记。不是纯上传/下载；若有早退/错误，必须同时看成功数和原始errors。HeapAlloc是阶段末Go快照，受GC与吞吐影响，不是系统峰值内存或耗电，未做锁屏能耗判断。</p><h2>端口交叉复核</h2><img src="ports.png"><p>每轮重启测试服务；Next/TUIC在19451与19458间交换，Next两个配置共用该轮Next入口。完整六轮指标每种配置每端口3轮，原大滚动除外，并平衡先后位置。两个端口仍可能受源端口、路由和时段影响；公网与生产其他流量未完全隔离。分端口结果是主样本的切片，不重复累计；见 <a href="port-summary.json">分端口汇总</a>。</p><h2>数据与自检</h2><p><a href="plan.json">冻结计划与二进制SHA256</a> · <a href="summary.json">汇总JSON</a> · <a href="all-rows.csv">完整CSV</a> · <a href="download-groups.json">逐轮下载</a> · <a href="validation.txt">验证及清理</a> · <a href="reproduce/README.txt">复现说明</a></p><p>三组使用相同临时测试证书和自建信任根，域名校验开启；不是公开CA部署验收。服务端临时hosts映射fc-lab.test至本机公网IP，防止TUIC目标嗅探后无法解析。两种端口分配都先通过三组功能预检，预检不计入排名。首次功能预检中TUIC因临时域名缺少服务端映射失败，修正后重新预检通过才开始主测；失败预检单独保留，没有丢弃主测样本。测试因TUIC滚动整组超时中断一次，补充编排超时记录与续跑机制，保留原始日志和失败组。前半段本地目标仅加载临时根证书，首字节第六轮前补入系统公共根证书供后续真实网站校验；临时根保持不变，协议二进制未改。手机VPN和唤醒设置在结束后恢复，此服务器原有服务仅SSH，未覆盖生产服务。仅本安卓Wi-Fi原生核心实验，不代替正式App、多网络、隐蔽性或长期稳定性验收。</p></html>'''
(O/'REPORT.html').write_text(page);print(O/'REPORT.html')
