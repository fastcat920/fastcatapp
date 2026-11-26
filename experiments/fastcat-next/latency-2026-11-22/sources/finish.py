# -*- coding: utf-8 -*-
from pathlib import Path
import json,shutil,hashlib,zipfile,difflib
from html.parser import HTMLParser
ROOT=Path('/Users/pizihu/Projects/FastCatAPP');O=ROOT/'experiments/fastcat-next/latency-2026-11-22';D=Path('/tmp/fc-next-latency')
checks={};total_cases=total_rows=0
for stage,expected in [('stage12',42),('stage34',63)]:
 d=O/stage;T=json.loads((d/'timeline.json').read_text());P=json.loads((d/'plan.json').read_text());R=json.loads((d/'all-rows.json').read_text());assert len(T)==expected
 assert not any(g['passed'] for g in json.loads((d/'summary.json').read_text())['gate'].values())
 count=0
 for f in list(d.glob('*.jsonl'))+list(d.glob('latency-*.log')):
  for line in f.read_text().splitlines():
   if line.strip():json.loads(line);count+=1
 for v in P['versions']:
  a=[r for r in R if r.get('version')==v]
  for phase,n in [('mixed',72),('mixed_background',12),('mixed_summary',6),('parallel_download',6),('rolling_download',6),('cold',36),('warm',36),('batch',36)]:assert sum(r.get('phase')==phase for r in a)==n,(stage,v,phase)
  assert not any(r.get('error') for r in a)
 for n,expected_hash in P['sha256'].items():
  f=D/('compare12' if stage=='stage12' and n=='compare' else 'compare34' if n=='compare' else n)
  assert hashlib.sha256(f.read_bytes()).hexdigest()==expected_hash,(stage,n)
 checks[stage]=dict(cases=len(T),merged_rows=len(R),valid_raw_json_lines=count,gate='failed',measurement_errors=0,binary_hashes='verified')
 total_cases+=len(T);total_rows+=len(R)
for n in ['race-stage12.txt','race-stage34.txt']:
 text=(D/n).read_text();assert 'FAIL' not in text and 'ok  ' in text
V=O/'validation';V.mkdir(exist_ok=True)
for n in ['race-stage12.txt','race-stage34.txt','vet-stage34.txt']:shutil.copy2(D/n,V/n)
S=O/'sources';S.mkdir(exist_ok=True)
for n in ['bench.py','analyze.py','charts.py','report.py','finish.py','queue34.py','edit.py','compare_edit.py','edit34.py','backend.py']:shutil.copy2(D/n,S/n)
shutil.copy2(Path('/tmp/fc-next-primary/lab.py'),S/'lab.py')
shutil.copytree(D/'stage12-sources',S/'stage12',dirs_exist_ok=True)
final=S/'stage34';final.mkdir(exist_ok=True)
for name,p in [('fastcatnext',ROOT/'core/fastcatnext'),('fastcat-v3-compare',ROOT/'core/tools/fastcat-v3-compare')]:
 dest=final/name;dest.mkdir(exist_ok=True)
 for f in p.glob('*.go'):shutil.copy2(f,dest/f.name)
for n in ['go.mod','go.sum']:shutil.copy2(ROOT/'core'/n,S/n)
diff=[]
for name,before,after in [('fastcatnext',D/'before',final/'fastcatnext'),('fastcat-v3-compare',ROOT/'experiments/fastcat-next/trio-2026-11-22/sources/fastcat-v3-compare',final/'fastcat-v3-compare')]:
 for filename in sorted({f.name for f in before.glob('*.go')}|{f.name for f in after.glob('*.go')}):
  a=before/filename;b=after/filename
  aa=a.read_text().splitlines(True) if a.exists() else [];bb=b.read_text().splitlines(True) if b.exists() else []
  diff.extend(difflib.unified_diff(aa,bb,fromfile='before/'+name+'/'+filename,tofile='after/'+name+'/'+filename))
(O/'implementation.diff').write_text(''.join(diff))
for n in ['stage12','stage34']:shutil.copy2(D/(n+'.log'),O/n/'run.log')
cleanup='Verified Android VPN CONNECTED, stay_on_while_plugged_in=0. No temporary fc-opt phone files, remote runtime directories or binaries. Lab ports19454/19458 closed. Production TCP/UDP443 and18447 still listening. Private test configs deleted. No app update, default change, production deployment, Git commit or push.\n'
(O/'cleanup.txt').write_text(cleanup)
checks.update(total_cases=total_cases,total_merged_rows=total_rows,default='unchanged; experimental flags off',cleanup='verified',scope='Android prototype core on one Wi-Fi/VPS; no performance claim beyond this cohort')
(O/'validation.json').write_text(json.dumps(checks,ensure_ascii=False,indent=2)+'\n')
p=O/'REPORT.html';text=p.read_text()
conclusion='''<section id="final-result"><h2>最终结论：已完成第1—4项实现与测试，未通过默认升级验收</h2><p><strong>轻量记录可用于后续排查；两种新调度保持默认关闭，继续使用原调度。</strong>第一阶段第1、2项带载P95为767ms，对照764ms，四路有效吞吐7.48Mbps，对照8.82Mbps；未达标后继续实现第3、4项，并开启第二阶段三组同期对照。没有用第一阶段数值作第二阶段的基线。</p><p>第二阶段每种策略6组混合、6组四路、6组滚动和3组短请求。带载P95：原调度641ms、评分版1133ms、完整策略814ms；完整策略的带载P50虽从403降到367ms，尾延迟没有改善。四路有效吞吐12.47/13.16/12.19Mbps，滚动20.56/24.07/16.91Mbps。完整策略滚动只保留82.3%的原调度吞吐，低于90%门槛。各组前台请求和后台/下载文件全部完成，没有用失败或慢组筛选出优势。</p><p>本轮共105例、4245条主合并记录，原始辅助日志另存。race与vet通过，原始JSON行完整且编译哈希一致。冷启动、连续与并发的完整数据也保留；例如候选冷启动有改善，但连续请求尾部回退，不能以单项提升宣布验收成功。</p><h3>这次实际定位到什么</h3><p>第一阶段一个原调度慢请求入口仅0.72ms，目标TLS约1259.77ms，响应约363.82ms。选择时另一通道RTT约125ms，选中通道约260ms；这说明该次等待主要不在入口建立，且原评分会接纳到RTT更高的通道，但并不能独自证明因果。新策略已经在真机将两条后台流聚到一个通道，并让多数后续请求使用另一条；后续目标TLS/响应仍有慢样本，说明纯粹分开连接不足以达到本轮目标。</p><p>first_read_wait是第一次应用Write到第一次成功Read的等待，不等于完整目标TLS握手；pending_write_bytes是正在执行的应用Write长度，不是QUIC内部队列长度。目标握手、共享链路竞争和传输恢复的相互影响仍未确定，不能把所有尾延迟归为调度排队。下一步若再研究，应先针对这些阶段收集证据，而非直接发布当前候选。</p></section>'''
assert 'id="final-result"' not in text;text=text.replace('<h2>预定验收条件</h2>',conclusion+'<h2>预定验收条件</h2>',1)
text=text.replace('</html>','<h2>收尾</h2><p>手机VPN已恢复，保持亮屏设置回到0；临时服务和私有测试配置清理完成，生产入口保持运行。未安装新正式App，未修改默认策略。<a href="validation.json">验证记录</a> · <a href="implementation.diff">本轮源码差异</a>。源码快照依赖FastCatAPP core工作区，不是独立完整仓库；包内不含部署凭证。</p></html>');p.write_text(text)
class Assets(HTMLParser):
 def handle_starttag(self,tag,attrs):
  for k,v in attrs:
   if k in ['src','href'] and not v.startswith(('http','#')):assert (O/v).exists(),v
Assets().feed(text)
z=O.with_suffix('.zip')
with zipfile.ZipFile(z,'w',zipfile.ZIP_DEFLATED) as a:
 for f in sorted(O.rglob('*')):
  if f.is_file():a.write(f,f.relative_to(O.parent))
with zipfile.ZipFile(z) as a:assert a.testzip() is None
print(json.dumps(checks,ensure_ascii=False));print('ZIP CRC verified',z,z.stat().st_size)
