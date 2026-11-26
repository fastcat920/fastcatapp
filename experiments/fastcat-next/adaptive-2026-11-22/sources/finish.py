# -*- coding: utf-8 -*-
from pathlib import Path
import json,shutil,hashlib,zipfile,subprocess
O=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/adaptive-2026-11-22');p=O/'REPORT.html';s=p.read_text()
lead='''<h2>结果与采用决定</h2><p><strong>本轮完成就绪优先、后台预建、近期表现有界调度和诊断；新调度保持可选，未自动替换默认。</strong>最明确的本轮改善在短请求：四路首字节 P50 从上轮双连接策略 570.78 降至 296.45 ms，P95 从 1647.36 降至 812.62 ms；TUIC 默认为 387.66 / 817.91 ms。混合负载 P95 从 799.94 到 761.88 ms，变化不大；TUIC 默认为 698.37 ms、双连接为 686.59 ms。样本较少，不作显著性承诺。</p><p>四路回显中位数：Next 单连接 5.40、上轮双连接 7.72、新调度 7.77、TUIC 默认 7.22、TUIC 双连接 5.91 Mbps。新调度三轮 7.77 / 8.47 / 6.46 Mbps，范围比上轮 8.85 / 3.60 / 7.72 更集中，但不能用三轮推断长期稳定。</p><p>四路单向下载完整任务数：前三种 Next 和 TUIC 默认均 12/12，TUIC 双连接 10/12。按各轮已校验字节计算的有效吞吐中位数依次为 32.38 / 15.34 / 10.03 / 6.40 / 6.62 Mbps；TUIC 双连接仅完整组中位数为 8.84 Mbps。<strong>新调度未优于上轮的并发下载，也未优于本轮 Next 单连接结果，不能认定总体吞吐升级成功。</strong></p><p>单路 100 MiB 仅各一轮：Next 单连接 23.077、新调度 26.456、TUIC 默认 66.770 秒，均通过校验。32 MiB 新调度两轮 9.005 / 11.237 秒，TUIC 双连接有一轮超时。单流没有被拆到两条连接，本轮样本不能证明慢连接已根治。</p><p>正式常规短请求 215/215、混合前台请求 120/120 成功，混合后台下载 20/20 完整；三项超时均出现在 TUIC 双连接（两条并发任务和一次单路 32 MiB），原始记录完整保留。生产入口与正式 App 未更新。手机 VPN、保持唤醒设置已恢复，临时服务及凭证已清理。</p><img src="comparison.png" alt="短请求改善与吞吐限制" style="width:100%;height:auto">'''
s=s.replace('<h2>这次改了什么</h2>',lead+'<h2>这次改了什么</h2>',1)
s=s.replace('<h2>验证与限制</h2>','<img src="diagnostic-cwnd.png" alt="独立诊断组拥塞窗口" style="width:100%;max-width:1000px;height:auto"><h2>验证与限制</h2>',1)
p.write_text(s)
for n in ['lab.py','backend.py','run.py','final.py','analyze.py','report.py','charts.py','finish.py']:shutil.copy2('/tmp/fc-next-adaptive/'+n,O/'sources'/n)
for n in ['go.mod','go.sum']:shutil.copy2('/Users/pizihu/Projects/FastCatAPP/core/'+n,O/'sources'/('core-'+n))
m=json.loads((O/'metadata.json').read_text());m['quic_module']=json.loads(subprocess.check_output(['go','list','-m','-json','github.com/metacubex/quic-go'],cwd='/Users/pizihu/Projects/FastCatAPP/core',text=True));m['cleanup_verified']=True;m['source_scope']='Feature source snapshots, lab scripts, core module manifests. Building requires the FastCatAPP core workspace and its local replacements.'
for n in ['compare-final','next-final']:assert hashlib.sha256(Path('/tmp/fc-next-adaptive',n).read_bytes()).hexdigest()==m['sha256'][n]
(O/'metadata.json').write_text(json.dumps(m,indent=2));(O/'cleanup.txt').write_text('Final contexts completed. Android VPN CONNECTED; stay_on_while_plugged_in=0. No running fc-opt-* services, /run/fc-opt-* directories, /usr/local/bin/fc-opt-* files, or timestamped local private JSON files. No temporary lab listeners 19445/46/48/50/51/52/54/56/57/58/59. Production TCP+UDP 443/18447 listening.\n')
with zipfile.ZipFile(O.with_suffix('.zip'),'w',zipfile.ZIP_DEFLATED) as z:
 for f in O.rglob('*'):
  if f.is_file():z.write(f,str(f.relative_to(O.parent)))
with zipfile.ZipFile(O.with_suffix('.zip')) as z:assert z.testzip() is None
print('Finalized report and archive')
