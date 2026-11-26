# -*- coding: utf-8 -*-
from pathlib import Path
import json,shutil,csv,zipfile,hashlib
O=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/throughput-2026-11-22');p=O/'REPORT.html';s=p.read_text()
lead='''<h2>结论与是否采用</h2><p><strong>实现了可选双通道并发吞吐模式，本轮并发结果改善；默认仍保留单通道。</strong>主对照三轮的四路单向下载中位数从原版 11.16 提高到 25.98 Mbps，约 2.33 倍；TUIC 默认为 32.88 Mbps。四路回显从 3.71 到 11.04 Mbps，TUIC 默认为 5.53 Mbps。这两个测试的工作负载不同，不可混同。</p><p>后续连接数相同的对照中，四路下载中位数为 Next 双通道 28.03、TUIC 默认 7.45、TUIC 双连接 31.42 Mbps。两轮四路回显的均值/中位数分别为 Next 双通道 5.46、TUIC 默认 2.94、TUIC 双连接 6.94 Mbps。TUIC 默认在两场下载对照中的波动很大，所以不能把不同时间的中位数拼接成一个协议固定排名。证据支持保留独立连接分流作为吞吐选项，未证明 Next 在相同连接资源下领先 TUIC。</p><p>单条流不会被拆分，因此没有结构上的单流提速。本轮单路 100 MiB 只测一次：原版 23.347 秒、吞吐版 77.427 秒、TUIC 24.701 秒；虽都校验通过，吞吐版仍出现慢连接。短请求也没有全面改善。<strong>不能以并发成绩宣布单连接失速已修复，不能默认替换原配置。</strong></p><p>主对照每组 43/43 短请求成功；主对照 36 条并发下载、12 次单路下载全部通过校验；补充对照另 36 条并发下载全部通过校验。本地 race/vet 通过。手机 VPN 与保持唤醒设置已恢复，临时服务、端口、凭证已清理，生产 443/18447 的 TCP/UDP 保持监听。</p><img src="comparison.png" alt="吞吐提升与单流限制" style="width:100%;height:auto">'''
s=s.replace('<h2>实现与配置</h2>',lead+'<h2>实现与配置</h2>',1);p.write_text(s)
for folder in ['core/fastcatnext','core/tools/fastcat-v3-compare']:
 shutil.copytree('/Users/pizihu/Projects/FastCatAPP/'+folder,O/'sources'/Path(folder).name,dirs_exist_ok=True)
for n in ['lab.py','gso.py','final.py','control.py','analyze.py','report.py','charts.py','finish.py','backend.py']:
 shutil.copy2('/tmp/fc-next-throughput/'+n,O/'sources'/n)
m=json.loads((O/'metadata.json').read_text());m['control_client_sha256']=hashlib.sha256(Path('/tmp/fc-next-throughput/compare-control').read_bytes()).hexdigest();m['cleanup_verified']=True;(O/'metadata.json').write_text(json.dumps(m,indent=2))
(O/'cleanup.txt').write_text('Verified after all contexts: Android VPN CONNECTED; stay_on_while_plugged_in=0. No running fc-opt-* service, /run/fc-opt-* directory, /usr/local/bin/fc-opt-* file or lab test listener 19445/46/48/50/51/52/54/56/57/58/59. Production TCP+UDP 443/18447 listening. No timestamped private JSON files remain in local lab directory.\n')
with (O/'validation.txt').open('a') as f:f.write('Final comparator with tuic-dual: go test -race PASS (2.744s), go vet PASS; Android pilot 12/12 success.\n')
raw=json.loads((O/'all-final-rows.json').read_text());lat=[]
for r in raw:
 if r.get('phase') in ['cold','warm','batch','prime']:lat.append(r)
keys=sorted({k for r in lat for k in r})
with (O/'latency.csv').open('w') as f:
 w=csv.DictWriter(f,fieldnames=keys);w.writeheader();w.writerows(lat)
with zipfile.ZipFile(O.with_suffix('.zip'),'w',zipfile.ZIP_DEFLATED) as z:
 for f in O.rglob('*'):
  if f.is_file():z.write(f,str(f.relative_to(O.parent)))
print('Report and ZIP finalized')
