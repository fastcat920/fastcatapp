# -*- coding: utf-8 -*-
from pathlib import Path
import json,shutil,hashlib,zipfile,collections
ROOT=Path('/Users/pizihu/Projects/FastCatAPP');O=ROOT/'experiments/fastcat-next/trio-2026-11-22';D=Path('/tmp/fc-next-primary')
R=json.loads((O/'all-rows.json').read_text());T=json.loads((O/'timeline.json').read_text());P=json.loads((O/'plan.json').read_text())
assert len(T)==117 and len(R)==1251
for n,digest in P['sha256'].items():assert hashlib.sha256((D/n).read_bytes()).hexdigest()==digest
for v in P['versions']:
 a=[r for r in R if r.get('version')==v]
 for phase,n in [('cold',36),('warm',36),('batch',108),('download',6),('parallel_download',12),('rolling_download',6),('mixed',36),('mixed_background',6),('timed_bulk',6),('idle-resume',9)]:assert sum(r.get('phase')==phase for r in a)==n,(v,phase)
 assert all(not r.get('error') for r in a if r.get('phase') in ['cold','warm','batch','mixed','idle-resume'])
P.update(completed_cases=len(T),raw_rows=len(R),native_server_sha256=hashlib.sha256(Path('/tmp/fc-seven-way/xray-lab').read_bytes()).hexdigest(),app_updated=False,default_changed=False,conclusion='tradeoffs remain; retain existing scheduler, no universal winner',validation='counts and frozen binary hashes verified; ZIP CRC verified')
(O/'plan.json').write_text(json.dumps(P,ensure_ascii=False,indent=2)+'\n')
conclusion='''<section id="conclusion"><h2>本轮结论</h2><p><strong>三项各有优势，保留当前新调度，不根据某一项吞吐宣布全面胜出。</strong>本次117组、1251条原始记录完整，540条标准短请求全部成功。下载每个场景每种六轮，包含六种先后排列；短请求/混合/回显/闲置各三组。</p><ul><li><strong>当前新调度：</strong>冷启动P50/P95为701/2114ms，连续请求393/755ms，本轮三项中较低。四路下载总体有效吞吐7.17Mbps、24/24完成；滚动下载21.18Mbps、72/72完成，表现最好。代价是负载下前台请求P95约1795ms，高于单连接546ms和TUIC854ms；这次没有全面继承单连接的前台响应优势。</li><li><strong>Next单连接：</strong>八路下载10.95Mbps、48/48完成，领先新调度8.57和TUIC6.24Mbps；负载下前台响应也更好。但单文件有1/6未完成，四路文件20/24完成，停滞拉低整体吞吐，不适合只按正常组速度判定。</li><li><strong>TUIC：</strong>单文件6/6完成，总体有效吞吐5.81Mbps，高于两种Next；四路、八路、滚动也全部完成。但混合负载后台文件只有4/6完成，且滚动吞吐10.12Mbps低于新调度，不能认定整体稳定性全面领先。</li></ul><p>闲置20秒后首请求三项均3/3成功，仅三次，P95就是最大样本。固定10秒双向回显六组/方案全部流都有校验数据，但数据波动大，不把它当作纯下载或纯上传结论。Go堆与分配只作辅助观察。</p><p>这些是同一安卓、同一Wi-Fi和VPS在本轮时段的描述性结果。跨场景按阶段串行执行，不能据四路和八路间的差异单独推断并发的因果作用。未进行识别率、蜂窝、切网、锁屏耗电或长期可用性验收；本轮没有修改协议或正式App。</p></section>'''
p=O/'REPORT.html';s=p.read_text();marker='<h2>测试边界</h2>';assert marker in s and 'id="conclusion"' not in s;s=s.replace(marker,conclusion+marker,1)
s=s.replace('</html>','<h2>清理与复现资料</h2><p>手机VPN已恢复，保持亮屏设置恢复为0。临时服务、服务器私有配置和手机测试文件已删除，生产TCP/UDP443、18447仍监听。随包保留测试脚本、功能源码快照、原始日志、CSV及编译哈希；源码快照仍依赖FastCatAPP core工作区的本地依赖，不是独立完整仓库。没有包含部署凭证。</p></html>');p.write_text(s)
(O/'cleanup.txt').write_text('Verified: Android VPN CONNECTED; stay_on_while_plugged_in=0. Lab ports19451/19454/19458 no longer listening. No fc-opt runtime dirs or binaries remain. Production TCP/UDP443 and18447 listening. Temporary phone test files and private configs removed by Lab context cleanup. No production app update, no default change.\n')
S=O/'sources';S.mkdir(exist_ok=True)
for n in ['trio_run.py','trio_report.py','trio_charts.py','trio_finish.py','lab.py','backend.py']:shutil.copy2(D/n,S/n)
for folder,src in [('fastcatnext',ROOT/'core/fastcatnext'),('fastcat-v3-compare',ROOT/'core/tools/fastcat-v3-compare'),('fastcat-next',ROOT/'core/tools/fastcat-next')]:
 (S/folder).mkdir(exist_ok=True)
 for f in src.glob('*.go'):shutil.copy2(f,S/folder/f.name)
for n in ['go.mod','go.sum']:shutil.copy2(ROOT/'core'/n,S/n)
shutil.copy2(ROOT/'experiments/fastcat-next/optimization-2026-11-21/sources/catnode-native-lab.go.txt',S/'catnode-native-lab.go.txt')
shutil.copy2(D/'trio.log',O/'run.log')
z=O.with_suffix('.zip')
with zipfile.ZipFile(z,'w',zipfile.ZIP_DEFLATED) as a:
 for f in sorted(O.rglob('*')):
  if f.is_file():a.write(f,f.relative_to(O.parent))
with zipfile.ZipFile(z) as a:assert a.testzip() is None
print('Verified report and archive:',z,z.stat().st_size)
