# -*- coding: utf-8 -*-
from pathlib import Path
import json,shutil,csv,zipfile,html
O=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/quic-tuic-2026-11-22')
p=O/'REPORT.html';s=p.read_text();lead='''<h2>验收结论</h2><p><strong>本轮候选配置没有通过默认升级标准，保留原 BBR 与即时 OPEN。</strong>完成了实现、筛选和真机对照；新增参数保持可选，不能声称已修好偶发失速。每组 199 次短请求均成功，100 MiB 各 2/2 完成；但原版 Next 的 32 MiB 第二轮仍超时，说明长传输问题尚未根治。</p><p>候选版外网四路首字节 P95 从原版 1281.8 ms 降到 760.3 ms（TUIC 1427.6 ms），但受控复用请求和四路有效吞吐退步。四路吞吐中位数：原版 4.19、候选 1.18、TUIC 2.60 Mbps；单路：原版 5.65、候选 6.34、TUIC 9.06 Mbps。100 MiB 原版 24.648 / 25.334 秒、候选 42.854 / 65.071 秒、TUIC 22.320 / 160.374 秒。没有一种在所有项目领先。</p><p>仅首包合并的同端口试验中，冷启动 P95 从 1589.4 ms 到 5563.6 ms，保持关闭。同端口 BBR 复测的 32 MiB：候选 15.795 / 13.815 秒，原版 10.791 / 13.307 秒，未确认换 BBR 的收益。采样规模小，不作显著性保证。</p><img src="comparison.png" alt="三组冷启动、并发与下载比较" style="width:100%;height:auto"><p>手机原 VPN 已恢复、保持唤醒设置恢复为 0；临时服务、监听端口与凭证已清理。生产 443 和 18447 的 TCP/UDP 仍监听。未改装正式 App。</p>'''
s=s.replace('<h2>配置与验收原则</h2>',lead+'<h2>配置与验收原则</h2>',1)
s=s.replace('<h2>解释与限制</h2>','''<h2>BBR 机制诊断（同端口 ABBA）</h2><p>四次 32 MiB 都完成校验，追踪关闭的正式对照见前表，以下是追踪开启的诊断计数：</p><table><tr><th>顺序 / 配置</th><th>发送包</th><th>丢失判定</th><th>结束 CWND 字节</th><th>发送窗口阻塞帧</th></tr><tr><td>1 候选 BBR</td><td>151954</td><td>126752</td><td>14380000</td><td>54</td></tr><tr><td>2 原版 BBR</td><td>30727</td><td>5858</td><td>1533078</td><td>1</td></tr><tr><td>3 原版 BBR</td><td>30015</td><td>5167</td><td>1580310</td><td>4</td></tr><tr><td>4 候选 BBR</td><td>117776</td><td>92749</td><td>14350000</td><td>59</td></tr></table><p>候选的结束拥塞窗口约为原版的 9 倍，发送包约 4–5 倍，却没有更快完成。这支持拒绝当前候选实现：它的发送与恢复行为代价更高。这里比较包数而非准确线缆流量字节，也不能据此确定全部丢失判定都是真丢包。</p><p>早期诊断的 CWND/RTT 汇总曾被部分更新事件的零值覆盖，已修正；早期日志的零值不用于机制结论。新诊断的部分更新仍不作为精确同一时刻的完整网络状态。</p><h2>解释与限制</h2>''',1)
s=s.replace('100 MiB 仅两轮，P95 不能用于稳定性承诺。','100 MiB 仅两轮，P95 不能用于稳定性承诺。空闲恢复每组仅一次真实 70 秒等待，随后两条是连续请求，不是三次独立空闲样本。')
p.write_text(s)
raw=json.loads((O/'all-final-rows.json').read_text())
for phase,name in [('download','downloads.csv'),('timed_bulk','throughput.csv')]:
 rr=[r for r in raw if r.get('phase')==phase];keys=sorted({k for r in rr for k in r})
 with (O/name).open('w') as f:
  w=csv.DictWriter(f,fieldnames=keys);w.writeheader();w.writerows(rr)
for name in ['isolate.py','report.py','charts.py','finish.py']:shutil.copy2('/tmp/fc-next-tuic/'+name,O/'sources'/name)
(O/'cleanup.txt').write_text('Final and isolate contexts completed. Android VPN CONNECTED restored; stay_on_while_plugged_in=0. VPS no running fc-opt-* service or /run/fc-opt-* directory. No test listeners 19445/19451/19454/19458/19459. Production TCP+UDP 443/18447 listening. Private client/server credential files removed by context cleanup.\n')
with zipfile.ZipFile(O.with_suffix('.zip'),'w',zipfile.ZIP_DEFLATED) as z:
 for f in O.rglob('*'):
  if f.is_file():z.write(f,str(f.relative_to(O.parent)))
print('Saved',p,'and',O.with_suffix('.zip'))
