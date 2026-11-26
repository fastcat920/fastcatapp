# -*- coding: utf-8 -*-
from pathlib import Path
import json,csv,math,statistics,html
O=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/primary-2026-11-22')
N={'next-base':'Next 单连接','next-opt':'Next 当前新调度','next-primary':'Next 主连接优先','tuic':'TUIC 默认','tuic-dual':'TUIC 双连接'}
def rows(f):
 a=[]
 for l in f.read_text().splitlines():
  try:r=json.loads(l)
  except:continue
  if isinstance(r,dict):a.append(dict(r,test=f.stem))
 return a
def q(a,p):
 a=sorted(a);return round(a[max(0,math.ceil(len(a)*p)-1)],2) if a else None
def med(a):return round(statistics.median(a),2) if a else None
def table(h,a):return '<div class="scroll"><table><thead><tr>'+''.join('<th>'+html.escape(str(x))+'</th>' for x in h)+'</tr></thead><tbody>'+''.join('<tr>'+''.join('<td>'+html.escape(str(x))+'</td>' for x in r)+'</tr>' for r in a)+'</tbody></table></div>'
R=[];C=[]
for f in sorted(O.glob('final-*.jsonl')):R+=rows(f)
for f in sorted(O.glob('controlled-c*.jsonl')):C+=rows(f)
(O/'all-main-rows.json').write_text(json.dumps(R,indent=2));(O/'all-controlled-rows.json').write_text(json.dumps(C,indent=2))
def group_summary(data,phase):
 a=[]
 for v in N:
  g=[r for r in data if r.get('version')==v and r.get('phase')==phase]
  if not g:continue
  rate=[r['verified_mbps'] for r in g];tasks=sum(r.get('jobs',r['workers']) for r in g);done=sum(r['success'] for r in g);duration=sum(r['elapsed_ms'] for r in g)/1000
  a.append([N[v],len(g),str(done)+'/'+str(tasks),med(rate),round(sum(r['verified_bytes'] for r in g)*8/duration/1e6,2),', '.join(str(round(r['verified_mbps'],2))+' ('+str(r['success'])+'/'+str(r.get('jobs',r['workers']))+')' for r in g)])
 return a
head=['实现','组数','完整任务/总数','有效吞吐中位 Mbps','总已完成字节/总耗时 Mbps','逐组 Mbps (完成/总数)']
lat=[];mixed=[];echo=[];routes=[];down=[]
for v in N:
 for ph in ['cold','warm','batch']:
  g=[r for r in R if r.get('version')==v and r.get('phase')==ph];a=[r['first_byte_us']/1000 for r in g if not r.get('error')]
  if g:lat.append([N[v],ph,str(len(a))+'/'+str(len(g)),q(a,.5),q(a,.95)])
 g=[r for r in R if r.get('version')==v and r.get('phase')=='mixed'];loaded=[r for r in g if r.get('background_active',0)>0];a=[r['first_byte_us']/1000 for r in loaded if not r.get('error')];bg=[r for r in R if r.get('version')==v and r.get('phase')=='mixed_background']
 if g:mixed.append([N[v],str(len(a))+'/'+str(len(loaded)),len(g),q(a,.5),q(a,.95),str(sum(r.get('complete')==True for r in bg))+'/'+str(len(bg))])
 for w in [1,4]:
  g=[r for r in R if r.get('version')==v and r.get('phase')=='timed_bulk' and r.get('workers')==w];a=[r['download_mbps'] for r in g if r.get('success')==w]
  if g:echo.append([N[v],w,str(len(a))+'/'+str(len(g)),med(a),', '.join(str(round(x,2)) for x in a)])
for r in R+C:
 u=r.get('lane_usage')
 if u and r.get('phase') in ['parallel_download','rolling_download','mixed_summary','timed_bulk']:routes.append([r['test'],N[r['version']],r.get('round'),u['tcp_assignments'],u['trial_assignments'],u['proven_spill_assignments']])
for r in R:
 if r.get('phase')=='download':down.append([N[r['version']],r['expected_bytes']//(1<<20),r['round'],r.get('complete'),r['total_ms']/1000,round(r.get('received_bytes',0)/(1<<20),2),r.get('error','')])
body='''<h1>Next 主连接优先：优化与扩样对照</h1><p>2026-11-22 · Android TFY-AN00 / Android12 · 同 Wi-Fi、香港 VPS · 原型核心实验</p>
<h2>实现与采用边界</h2><p>新增显式可选 <code>QUICLanes=2, AdaptiveLanes=true, PrimaryPreferred=true</code>。首批业务优先复用主连接，Warm 只准备主连接，不因并发数量增加就强制分到两个通道。已有业务不迁移、不重放，不拆分一条 TCP 流。本轮未修改 BBR、加密或 FCN/1 线格式，也未发布正式 App。</p><p>当新请求到来时，只有主连接至少两条既有活跃流且观察到持续读取，才后台准备备用连接。负载观察窗口至少 2 秒、至少 32 KiB 实际读取，避免完全排除较慢的主连接；备用握手成功并不算容量证明。备用容量要求两个至少 0.5 秒、各至少 256 KiB 的正向读样本，证据 15 秒过期。备用速率至少高出主连接近期估计 25%，RTT 不明显更差，才允许有限的新业务分流。</p><p>探索期最多一个未结束试探流、每 5 秒最多四次新试探；已收到 64 KiB 后停止该窗口内进一步试探。该字节门限只限制后续分配，不能截断已开始的大流。已有备用业务仍继续完成。新分流的活跃流门限约束不能理解为任意时刻的字节份额上限。备用空闲 15 秒回收，过期回调有代际与序号保护。默认配置仍关闭此策略。</p>
<h2>测试设计与重复规则</h2><p>四个主组：Next 单连接、上一轮新调度、主连接优先、TUIC 默认。三种 Next 共用 19458，TUIC 为实际 CatNode/Xray TUIC v5、19451，BBR、FastOpen=false、ReduceRtt=false。证书验证开启，入口固定 IP 隔离 DNS。每阶段开始验证当前物理默认网络为 Wi-Fi，正式性能记录关闭详细追踪。</p><p>共享服务初测四路下载每任务 4 MiB、四任务共享一个协议客户端，每组预算 90 秒。先六轮，任何组不完整，或任一模式极差比超过 2.5 / CV 超过 .45，则所有主组一起反向追加六轮，最多十二轮，不按新策略是否获胜决定补测。固定时长回显先三轮，如出现不完整、极差比大于 3 / CV 大于 .60，全组再反向追加两轮。触发原因保留在 repeat-decisions.json；失败组零有效吞吐用于触发，不把分母截断后的巨大极差比当作物理结论。</p><p>循环和反向初测出现顺序/时段依赖迹象，因此另外做独立控制对照：两套 Williams 均衡序列，每个模式八个新客户端组。各模式在每个位置出现相同次数，前后继配对均衡；每组重启两种临时传输服务、等待五秒后采样其中一个实现，避免残留连接和旧运行时干扰。该控制组改变了服务器初始条件，不能代表持续负载中的共享服务，不能与初测直接合并。受控计划和逐组时间线全部保留。</p><p>滚动下载：四个工作槽持续执行十二个 4 MiB 任务，共享一个客户端，每组预算 150 秒，两个轮次；用于观察首批结束后是否实际试探/分流。混合负载：两条 16 MiB 下载与十二条前台请求共享客户端，两轮；另含 TUIC 双连接作资源对照。回显固定十秒，握手准备另计。短请求每组冷启动/连续各 24、四路 24、预热 3。32 MiB 每组三轮，100 MiB 仅各一轮，不计算稳定性保证。</p><p>MiB=1,048,576 字节。有效吞吐仅计完整且内容校验正确的任务字节，除以整组时间；未完成任务的部分字节不算完成数据。表中同时给各组中位数和总完成字节/总耗时，失败不隐藏。首字节 P50/P95 为成功样本 nearest-rank，失败另列。本轮独立节点、单 Wi-Fi，没有蜂窝、锁屏能耗或识别概率验收。</p>
<h2>受控对照：每组重新启动传输服务</h2>'''+table(head,group_summary(C,'parallel_download'))+'''<h2>共享服务初测与反向扩样（独立列示）</h2>'''+table(head,group_summary(R,'parallel_download'))+'''<h2>滚动下载</h2>'''+table(head,group_summary(R,'rolling_download'))+'''<h2>短请求</h2>'''+table(['实现','阶段','成功/总数','首字节 P50 ms','首字节 P95 ms'],lat)+'''<h2>混合负载</h2>'''+table(['实现','有后台时成功/样本','前台总样本','P50 ms','P95 ms','后台完整/总数'],mixed)+'''<h2>固定时长回显</h2>'''+table(['实现','并发','有效组/总数','中位 Mbps','逐组 Mbps'],echo)+'''<h2>单流文件逐次记录</h2>'''+table(['实现','MiB','轮次','完整','耗时秒','收到 MiB','错误'],down)+'''<h2>实际分配计数</h2><p>分配计数为 TCP Dial 决策，不是字节比例。冷批次的 [4,0] 表明没有强制分到备用通道；完成率和速度仍须独立验收。试探次数不等于已经证明分流有收益，proven_spill 为零时不能宣称晋升路径已获公网性能证明。</p>'''+table(['测试','实现','轮次','主/备分配','试探','有证据新分流'],routes)+'''<h2>本地开销消融</h2><p>独立本地四路回环使用同一代码和本地测试证书，不连接公网节点。Mac 单连接中位约 778 Mbps、主连接优先约 790 Mbps；Android 单连接约 234 Mbps、主连接优先约 235 Mbps，均只有三轮。该诊断未观察到与公网差异同量级的软件开销，不能据此排除所有设备、拥塞恢复或路径交互。Android 诊断在一个完整公网阶段结束后执行，期间主调度器等待，诊断结束后恢复后续阶段，未与公网传输抢同一设备资源。</p><p>原始回环输出在 local-profile.txt / android-local-profile.txt。出现组预算耗尽时，父上下文会关闭连接，所以流错误原文可能是 Application error 0x0 (local)，而不是字符串 deadline exceeded；应结合整组总耗时和预算判断，不将此误报为认证错误。</p>
<h2>验证与资料</h2><p>本地 race/vet 通过，覆盖冷批单连接、资格证据、试探门限、过期证据、活跃比例门限、空闲回调代际与低速持续读样本。原始 JSONL、CSV、服务时间线、重复决策、编译哈希、功能源码均保留。构建仍需 FastCatAPP 的 core 工作区及其本地依赖；压缩包不是独立完整仓库。不含部署凭证。</p>'''
css='body{font:16px/1.65 -apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif;max-width:1280px;margin:35px auto;padding:0 24px;background:#f7f9fc;color:#193047}h1,h2{color:#173d61}.scroll{overflow:auto}table{border-collapse:collapse;background:white;margin:18px 0;width:100%;font-size:14px}td,th{border:1px solid #d9e2ed;padding:9px 12px;text-align:right;white-space:nowrap}td:first-child,th:first-child{text-align:left}th{background:#e5edf6}p{max-width:1100px}code{background:#e5ecf5;padding:2px 5px}'
(O/'REPORT.html').write_text('<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Next 主连接优先与 TUIC 扩样对照</title><style>'+css+'</style>'+body+'</html>')
for data,name in [(R,'main'),(C,'controlled')]:
 for phases,label in [({'cold','warm','batch','prime'},'latency'),({'parallel_download','rolling_download'},'downloads'),({'mixed'},'mixed'),({'timed_bulk'},'echo'),({'download'},'single-files')]:
  a=[r for r in data if r.get('phase') in phases]
  if a:
   with (O/(name+'-'+label+'.csv')).open('w') as f:
    w=csv.DictWriter(f,fieldnames=sorted({k for r in a for k in r}));w.writeheader();w.writerows(a)
print('Report updated:',len(R),'shared rows,',len(C),'controlled rows')
