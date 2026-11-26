from pathlib import Path
import shutil,hashlib,json,zipfile
root=Path('/Users/pizihu/Projects/FastCatAPP')
tmp=Path('/tmp/fc-next-primary')
out=root/'experiments/fastcat-next/primary-2026-11-22'
m=json.loads((out/'metadata.json').read_text())
for name,expected in m['sha256'].items():
 assert hashlib.sha256((tmp/name).read_bytes()).hexdigest()==expected,name
for folder,src in [('fastcatnext',root/'core/fastcatnext'),('fastcat-v3-compare',root/'core/tools/fastcat-v3-compare')]:
 for p in src.glob('*.go'):
  shutil.copy2(p,out/'sources'/folder/p.name)
for name in ['run.py','control.py','queue_control.py','device_profile.py','lab.py','backend.py','analyze.py','report.py','charts.py','finish.py']:
 shutil.copy2(tmp/name,out/'sources'/name)
for name in ['go.mod','go.sum']:
 shutil.copy2(root/'core'/name,out/'sources'/name)
shutil.copy2(tmp/'local-profile.txt',out/'local-profile.txt')
shutil.copy2(tmp/'validation-race.txt',out/'validation-race.txt')
cleanup='Final cleanup verified: Android VPN CONNECTED; stay_on_while_plugged_in=0. Temporary fc-opt services, binaries and runtime directories removed. Temporary private configs removed. Production TCP/UDP 443 and 18447 remain listening. No production app build deployed.\n'
(out/'cleanup.txt').write_text(cleanup)
section='''<section id="acceptance"><h2>最终结论：未通过默认升级验收</h2><p><strong>主连接优先机制已经实现，但本轮没有证明能同时继承单连接吞吐和原调度的其他优势，因此保持默认关闭。</strong>共享服务十二轮四路下载中位数：单连接 19.52、原调度 9.22、主连接优先 9.45、TUIC 18.68 Mbps。发现明显波动后，追加均衡顺序、每组重启两端测试服务的八轮对照；两种条件分别统计。</p><p>追加对照四路下载中位数：单连接 <strong>17.38 Mbps（32/32 完成）</strong>、原调度 10.17（32/32）、主连接优先 <strong>9.59（28/32）</strong>、TUIC 10.05（24/32）。90 秒组预算耗尽的失败保留在统计中，不挑选快轮。</p><p>所有冷批主连接优先分配均为 [4,0]，确认没有强制拆成两条连接。两轮滚动下载均为 [11,1]，仅有试探分配；本轮没有观察到经容量证明后的正式分流。共享服务首字节冷启动 P50/P95 为 710/1677 ms，单连接为 1083/2308 ms，但该改善不足以抵消吞吐和完成率问题。滚动下载仅两轮，不据此宣布稳定胜出。</p><p>正反顺序轮次差异明显，本地回环未观察到同量级的软件损耗。公网慢轮的根因仍未确定，不能直接归因于调度开销，也不能把偶发高吞吐视为优化成立。</p><img src="comparison.png" alt="分条件展示下载和首字节的对照图" style="width:100%;height:auto"><p>已通过 race 与 vet。手机 VPN 已恢复，临时服务与私有测试配置已清理；生产入口保持运行。未替换正式 App 或默认策略。压缩包包含原始失败、追加对照和源码快照。control-first-attempt.log 是首次控制脚本在测量前因临时服务已自动回收而退出的记录，修正后重新完成全部八轮，不算协议失败样本。</p></section>'''
p=out/'REPORT.html';s=p.read_text();needle='<h2>实现与采用边界</h2>';assert needle in s
if 'id="acceptance"' not in s:s=s.replace(needle,section+needle,1)
p.write_text(s)
m['acceptance']='failed combined-advantages gate; optional policy remains default off'
m['controlled_rounds_per_mode']=8
m['main_cold_download_rounds_per_mode']=12
m['cleanup']='verified; see cleanup.txt'
(out/'metadata.json').write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n')
z=out.with_suffix('.zip')
with zipfile.ZipFile(z,'w',zipfile.ZIP_DEFLATED) as archive:
 for f in sorted(out.rglob('*')):
  if f.is_file():archive.write(f,f.relative_to(out.parent))
with zipfile.ZipFile(z) as archive:assert archive.testzip() is None
print('Report and ZIP verified:',z, z.stat().st_size)
