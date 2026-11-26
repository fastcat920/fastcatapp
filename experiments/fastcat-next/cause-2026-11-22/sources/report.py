# -*- coding: utf-8 -*-
from pathlib import Path
import json,html
O=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/cause-2026-11-22')
M=json.loads((O/'measurements.json').read_text());S=json.loads((O/'summary.json').read_text());P=json.loads((O/'prefix/proofs.json').read_text());K=json.loads((O/'kernel-check/proofs.json').read_text());Q=json.loads((O/'prefix/selected-proof.json').read_text());D=json.loads((O/'request-details.json').read_text())
def table(head,rows):return '<div class="scroll"><table><tr>'+''.join('<th>'+html.escape(str(x))+'</th>' for x in head)+'</tr>'+''.join('<tr>'+''.join('<td>'+html.escape(str(x))+'</td>' for x in r)+'</tr>' for r in rows)+'</table></div>'
b='''<h1>Next 尾延迟排查：修正计时边界与流头部恢复证据</h1><p>2026-11-22 · 同一Android TFY-AN00 / Wi-Fi / 香港VPS · 原调度 next-opt，两个候选调度关闭。未改加密、BBR或业务线格式。</p><h2>已定位的具体机制</h2><p><strong>一部分等待来自OPEN确认及后续同流数据的恢复，而非单纯“选择了繁忙连接”。</strong>初轮追踪108个请求中，82个有前8KiB下行重叠区间恢复证据，26个能看到覆盖流offset 0的重发被接收后，客户端结束状态等待；其中带载10、连续10、冷启动6。追加36请求又出现12个状态恢复解除阻塞样本。这些恢复事件不能直接当作请求失败计数；即使前台请求最终成功，也会产生等待。后台文件完成情况另列，未把超时文件当作成功。</p><p>这些是本轮具体样本的证据，不代表全部尾延迟都只有这一种原因。发送端判丢/PTO、首发包在接收端状态解除前未被观察、覆盖同流偏移的新包被观察，是确认恢复路径的依据；不能据此区分底层真实丢包、过度延迟或接收端处理问题。</p><h2>必须更正的旧测量结论</h2><p>旧entry_us只量到Dial返回。Next QUIC的Dial提交OPEN后就返回，状态字节的读取在quicConn.Read内；目标tls.HandshakeContext会触发该Read，因此旧target_tls_us包含OPEN状态等待。之前“入口小于1ms，所以慢不在入口”的推断不成立。端到端首字节、下载、完成率及原候选未通过性能门槛的数值结论不变。旧报告和数据包已补更正说明。</p><p><a href="MEASUREMENT-ERRATA.txt">完整测量口径更正</a>。新status_wait_us仅为实际读取状态时的阻塞，不是OPEN总往返；扣除它只是客户端时间分摊，不能当成独立TLS握手时长，因为两者会流水线重叠。</p>'''
q=Q['proof'];r=Q['request'];b+='<h2>一个可逐包核对的样本</h2>'+table(['项目','实测'],[['来源',q['source']],['业务流',q['stream']],['首字节',f"{q['first_ms']:.3f} ms"],['服务端目标拨号',f"{q['server_dial_ms']:.3f} ms"],['读取OPEN确认阻塞',f"{q['status_wait_ms']:.3f} ms"],['承载确认流头部的发送包号',' → '.join(str(e.get('packet',0)) for e in Q['server_status_sent'])],['TLS后续片段提前到达',f"{Q['status_after_earlier_payload_ms']:.3f} ms"],['状态读取结束后读到TLS片段',f"{Q['first_data_after_status_ms']:.3f} ms"]])
b+='''<p>原始包928及后续1301覆盖offset 0、长度1，均被发送端判丢；1740覆盖同一偏移并被客户端观察。客户端此前已观察到offset 1及更高偏移的TLS片段，但可靠有序流不能跳过缺失的第0字节。确认恢复后约14微秒即可从缓冲区读到先到的TLS数据。这是本样本中等待的直接证据。不能据1字节STREAM帧推断整个UDP包只有1字节，包还可能包含其他帧。</p><p><a href="prefix/selected-proof.json">该样本完整证据</a> · <a href="prefix/proofs.csv">108请求恢复证据CSV</a>。包号按方向、包号空间和同一QUIC会话配对；会话用随机OPEN nonce的一向哈希关联，两端不输出真实nonce、连接ID、目标、凭证或载荷。</p>'''
for name in ['proof-timeline.png','request-budget.png','conditions.png']:
 if (O/name).exists():b+=f'<img src="{name}" alt="{name}">'
b+='<h2>两端追踪与关闭追踪对照</h2>'
rows=[]
for k,a in S['conditions'].items():
 bg=[r for r in M if r.get('condition')==k and r.get('phase')=='mixed_summary'];bg_count=str(sum(r['success'] for r in bg))+'/'+str(sum(r['workers'] for r in bg)) if bg else '—';rows.append([k,a['samples'],a['success'],a['p50_ms'],a['p95_ms'],a['max_ms'],a['status_p95_ms'],a['server_dial_max_ms'],bg_count])
b+=table(['场景','样本','成功','首字节P50ms','P95ms','最大ms','状态读取P95ms','服务端拨号最大ms','后台完整文件'],rows)
b+='''<p>on/off为双端传输追踪开启/关闭，轻量通道记录均开启。首轮带载追踪开/关的后台文件分别10/12与8/12完整完成，未完成文件保留在原始JSONL中；本表前台成功不能代替后台完成率。PTO及恢复记录可能有开销，因此不将追踪结果并入性能升级验收。带载有两条16MiB后台下载、每组12个前台请求；无载使用默认串行warm请求，另有cold请求用于追踪。它们<strong>不是纯粹只改变负载的因果对照</strong>：混合测试显式Warm两个通道，默认串行warm通常只建立一条；因此不能用此表声称“加后台下载就更快”。on/off也不是同一时刻，不凭微小差异宣称追踪提速或精确测量开销。</p>'''
b+='<h2>恢复证据分组</h2>'
rows=[]
for cohort,R in [('包号追踪108请求',P),('内核计数补测36请求',K)]:
 for phase in ['mixed','warm','cold']:
  a=[r for r in R if r['phase']==phase];rows.append([cohort,phase,len(a),sum(bool(r['downstream_recovery']) for r in a),sum(bool(r['upstream_recovery']) for r in a),sum(bool(r['status_recovery_at_unblock']) for r in a)])
b+=table(['轮次','场景','请求数','下行区间恢复证据','上行区间恢复证据','确认恢复后解除状态阻塞'],rows)
b+='''<p>元数据只观察每流前8KiB的帧偏移/长度、包号及判丢/PTO事件，单连接输出最多8192条、跟踪包号最多4096个；本轮meta_dropped为0。没有记录数据载荷、TLS密钥或QUIC连接ID。重叠区间恢复的判断要求首发包在截至请求完成+100ms的接收记录中未观察到、新包覆盖重叠偏移并被接收、原包被判丢或两次发送之间有PTO。状态解除证据还要求重发覆盖offset0、是客户端第一次观察到该流offset0、抵达时客户端正在等待状态、实际阻塞至少1ms，且接收与状态读取结束相隔0—20ms。</p><p>计数是“有这些证据”的请求数，不能把没有证据解释为没有恢复，也不能把它直接叫物理丢包率。无需依靠两端时钟同步来做包号/偏移配对；250ms统计窗口关联另有时钟不确定性约250ms，仅供辅助，不能替代逐包证明。</p>'''
b+='<h2>流控、拥塞窗口和本机计数</h2>'
onserver=[]
for f in O.glob('*-server.log'):
 for l in f.read_text().splitlines():
  try:e=json.loads(l)
  except:continue
  if e.get('stage')=='server_quic_progress':onserver.append(e)
b+=f'<p>首轮服务端进度记录中，发送DATA_BLOCKED/STREAM_DATA_BLOCKED计数最大值为{max([e.get("blocked_sent",0) for e in onserver]+[0])}。这未提供流控阻塞帧证据，但不能排除所有应用Write排队。拥塞窗口与在途量保留在原始事件，尚不能据低频快照确定所有慢请求是否受到拥塞窗口限制。</p>'
rows=[]
for a in json.loads((O/'kernel-check/udp-deltas.json').read_text()):rows.append([a['source'],a['delta']['InErrors'],a['delta']['RcvbufErrors'],a['delta']['SndbufErrors']])
b+=table(['补测','UDP InErrors增量','RcvbufErrors增量','SndbufErrors增量'],rows)
b+='''<p>VPS的历史UDP缓冲错误计数非零；没有更早的前置基线，不能归因于首轮实验。追加两例使用同一追踪二进制，前后全局计数如上；该结果不追溯排除此前本机错误，也不能排除安卓、虚拟化或中间链路问题。全局计数不是单进程计数。</p><h2>为什么先前评分优化没有命中问题</h2><p>新评分主要试图避开繁忙通道，但已发流中的缺口不能靠后续选择另一通道修复。首读等待又混合了OPEN确认、传输恢复和目标响应，拿它当连接质量信号可能误判。过度惩罚高吞吐通道或保留轻载通道，还会损失吞吐。本轮未启用两个候选，没有用额外重放或跳过确认来制造改善。</p><h2>后续优化应验证什么</h2><p>先试验OPEN确认与首段返回数据的合并/调度，测能否减少额外头部依赖和恢复等待，同时保留认证失败、目标失败和服务端先发场景。它不能消除可靠流内部的重传等待，也不能保证一定提速。当前只完成诊断，没有上线该优化，没有修改默认调度，更没有据此断言GFW识别或干扰。</p><h2>原始资料与边界</h2><p><a href="summary.json">首轮汇总</a> · <a href="request-details.csv">逐请求阶段与计数CSV</a> · <a href="prefix/proofs.json">包号证据</a> · <a href="kernel-check/proofs.json">补测证据</a> · <a href="kernel-check/udp-deltas.json">UDP计数差分</a>。首轮24例、包号追踪6例、内核补测2例，共32例；每轮分别保留计划、时间线、哈希与原始日志。各轮二进制和条件不同，不合并性能排名。没有进行多网络、长期阻断或正式App性能验收。</p>'''
(O/'REPORT.html').write_text('<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Next 尾延迟原因排查</title><style>body{font:16px/1.7 -apple-system,sans-serif;max-width:1350px;margin:30px auto;padding:0 22px;color:#20344b;background:#f7f9fc}table{border-collapse:collapse;width:100%;background:white;margin:16px 0}td,th{border:1px solid #d1dbe7;padding:8px;text-align:right;white-space:nowrap}td:first-child,th:first-child{text-align:left}.scroll{overflow:auto}th{background:#e8eff8}img{width:100%;height:auto}</style>'+b+'</html>')
print('Built cause report')
