from pathlib import Path
import json,shutil,zipfile,collections
O=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/rolling-retest-2026-11-22');D=Path('/tmp/fc-next-primary')
rows=json.loads((O/'summary-rows.json').read_text());assert len(rows)==32
assert all(sum(r['version']==v for r in rows)==8 for v in ['next-base','next-opt','next-primary','tuic'])
assert sum(r['jobs'] for r in rows)==384
p=O/'REPORT.html';s=p.read_text();marker='<h2>本轮结论</h2>'
conclusion='''<h2>本轮结论</h2><p><strong>滚动下载优先保留原调度。主连接优先版没有证明能同时继承单连接速度和原调度稳定性，继续保持默认关闭。</strong>原调度 96/96 完成，总体有效吞吐 12.49 Mbps；主连接优先 94/96、8.80 Mbps；单连接 72/96、5.45 Mbps；TUIC 84/96、6.02 Mbps。原调度本轮总体有效吞吐比主连接优先高约 42%，这是描述性比较，不代表所有网络或统计显著结论。</p><p>主连接优先组吞吐中位数 16.69 Mbps，略高于原调度 15.81 Mbps；但它有一组 150 秒只完成 10/12，导致总体有效吞吐反而较差。单连接组中位数最高，但有两组零完整文件且另有明显慢组，不能按中位数单独判胜。</p><p>这次主连接优先在两组中实际发生经证据门限后的分流，分流次数分别为四次和一次；其他组只试探或全走主连接。容量证明机制已在公网触发，但没有形成稳定吞吐收益。原调度八组都使用了两条通道。该结果支持继续研究备用连接启用时机，但不能据此确认停滞的底层根因。</p><p>失败任务共 38 个：单连接 24、主连接优先 2、TUIC 12。错误原文包括本地关闭连接、入口连接已关闭以及目标 TLS/context 超时。它们是在组预算耗尽时观察到的终止错误，不能直接当作停滞最初原因。未经额外追踪，不归因于认证、GFW 或某个拥塞算法。</p><p>与上一轮只有两组的滚动结果相比，本次样本更多、顺序均衡，但每组重启测试服务的条件也不同；没有把两轮数据混合统计。原调度依然值得保留，但上一轮两组的 27.10 Mbps 不能当作稳定预期。</p>'''
s=s.replace('<h2>逐组记录</h2>',conclusion+'<h2>逐组记录</h2>',1)
s=s.replace('</html>','<h2>收尾检查</h2><p>32 组、384 个任务记录完整；临时测试服务、凭证及手机测试文件已清理，正式 TCP/UDP 443、18447 仍在监听。手机 VPN 已恢复，保持亮屏设置恢复为 0。未发布新正式 App，未更改默认策略。</p></html>')
p.write_text(s)
(O/'cleanup.txt').write_text('32 groups, 384 tasks verified. Android VPN CONNECTED; stay_on_while_plugged_in=0. Temporary lab services, credentials, runtime directories, phone test files removed. Production TCP/UDP 443 and 18447 listening. No app update or default change.\n')
S=O/'scripts';S.mkdir(exist_ok=True)
for name in ['rolling_retest.py','rolling_report.py','rolling_finish.py','lab.py','backend.py']:shutil.copy2(D/name,S/name)
shutil.copy2(D/'rolling-retest.log',O/'run.log')
z=O.with_suffix('.zip')
with zipfile.ZipFile(z,'w',zipfile.ZIP_DEFLATED) as f:
 for p in sorted(O.rglob('*')):
  if p.is_file():f.write(p,p.relative_to(O.parent))
with zipfile.ZipFile(z) as f:assert f.testzip() is None
print('Verified 32 groups, 384 tasks, report and ZIP:',z)
