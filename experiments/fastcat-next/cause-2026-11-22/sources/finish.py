# -*- coding: utf-8 -*-
from pathlib import Path
import json,hashlib,shutil,zipfile,difflib,os
from html.parser import HTMLParser
ROOT=Path('/Users/pizihu/Projects/FastCatAPP');O=ROOT/'experiments/fastcat-next/cause-2026-11-22';D=Path('/tmp/fc-next-cause');validation={}
for folder,count,binroot in [('',24,D/'v1'),('prefix',6,D),('kernel-check',2,D)]:
 d=O/folder;p=json.loads((d/'plan.json').read_text());t=json.loads((d/'timeline.json').read_text());assert len(t)==count
 for n,h in p['sha256'].items():assert hashlib.sha256((binroot/n).read_bytes()).hexdigest()==h,(folder,n)
 lines=0
 for f in d.glob('*-b*-p*.jsonl'):
  for line in f.read_text().splitlines():
   if line.strip():json.loads(line);lines+=1
 validation[folder or 'initial']=dict(cases=len(t),raw_jsonl_lines=lines,binary_hashes='verified')
for name in ['race.txt','race-prefix.txt']:
 s=(D/name).read_text();assert 'FAIL' not in s and 'ok  ' in s
proof=json.loads((O/'prefix/proofs.json').read_text());supp=json.loads((O/'kernel-check/proofs.json').read_text());assert len(proof)==108 and len(supp)==36
assert sum(bool(r['status_recovery_at_unblock']) for r in proof)==26
assert all(r['client_meta_dropped']==r['server_meta_dropped']==0 for r in proof+supp)
S=O/'sources';S.mkdir(exist_ok=True)
for n in ['run.py','prefix.py','kernel_check.py','queue.py','analyze.py','prefix_analyze.py','report.py','charts.py','finish.py','edit.py','prefix_edit.py','backend.py']:shutil.copy2(D/n,S/n)
shutil.copy2(Path('/tmp/fc-next-primary/lab.py'),S/'lab.py')
shutil.copytree(D/'v1/fastcatnext',S/'initial-fastcatnext',dirs_exist_ok=True)
for name,p in [('fastcatnext',ROOT/'core/fastcatnext'),('fastcat-v3-compare',ROOT/'core/tools/fastcat-v3-compare'),('fastcat-next',ROOT/'core/tools/fastcat-next')]:
 dest=S/name;dest.mkdir(exist_ok=True)
 for f in p.glob('*.go'):shutil.copy2(f,dest/f.name)
for n in ['go.mod','go.sum']:shutil.copy2(ROOT/'core'/n,S/n)
V=O/'validation';V.mkdir(exist_ok=True)
for n in ['race.txt','race-prefix.txt','vet.txt','vet-prefix.txt','cleanup-server.txt','server-final.txt']:shutil.copy2(D/n,V/n)
for source,dest in [('run.log','run.log'),('prefix.log','prefix/run.log'),('kernel-check.log','kernel-check/run.log')]:shutil.copy2(D/source,O/dest)
diff=[]
for f in sorted((ROOT/'core/fastcatnext').glob('*.go')):
 a=D/'before'/f.name;old=a.read_text().splitlines(True) if a.exists() else []
 diff.extend(difflib.unified_diff(old,f.read_text().splitlines(True),fromfile='before/fastcatnext/'+f.name,tofile='after/fastcatnext/'+f.name))
(O/'implementation.diff').write_text(''.join(diff))
cleanup=(D/'cleanup-server.txt').read_text();assert ':19458 ' not in cleanup and ':19454 ' not in cleanup and 'fc-opt-' not in cleanup
assert ':443 ' in cleanup and ':18447 ' in cleanup
(O/'cleanup.txt').write_text('Android VPN restored and stay_on_while_plugged_in=0 verified. No temporary fc-opt phone files, remote services/runtime dirs/binaries remain. Private test configs removed. Production TCP/UDP443 and18447 still listening. No formal App installation, scheduler default change, protocol wire change or Git push. SSH control session left available under existing authorization.\n')
assert 'Suppressed' not in (D/'journal-suppression.txt').read_text()
shutil.copy2(D/'journal-suppression.txt',V/'journal-suppression.txt')
validation.update(auxiliary_json_lines_verified=18544,journal_suppression='none observed',total_cases=32,prefix_requests=108,prefix_status_recovery_unblock=26,supplement_requests=36,supplement_status_recovery_unblock=sum(bool(r['status_recovery_at_unblock']) for r in supp),packet_metadata_dropped=0,cleanup='verified',races='passed',vet='passed',source_scope='Initial core source and final diagnostic sources supplied; binaries have frozen hashes. Archive is not a standalone full repository.',conclusion='Concrete stream-head recovery waits confirmed; underlying delivery failure location remains unproven.')
(O/'validation.json').write_text(json.dumps(validation,indent=2)+'\n')
p=O/'REPORT.html';s=p.read_text();s=s.replace('</html>','<h2>验证与收尾</h2><p>32例均按计划结束，原始主JSONL行可解析、二进制哈希一致；两轮race/vet通过。<a href="validation.json">验证记录</a> · <a href="implementation.diff">本轮核心代码差异</a>。手机VPN已恢复、亮屏设置恢复为0；临时服务、私有配置与手机测试文件已清理，生产入口保持运行。未安装正式App或修改默认调度。源码仍需FastCatAPP core工作区的本地依赖，包内不含部署凭证。</p></html>');p.write_text(s)
class Assets(HTMLParser):
 def handle_starttag(self,tag,attrs):
  for k,v in attrs:
   if k in ['src','href'] and not v.startswith(('http','#')):assert (O/v).exists(),v
Assets().feed(s)
def pack(folder):
 z=folder.with_suffix('.zip');tmp=z.with_suffix('.zip.tmp')
 with zipfile.ZipFile(tmp,'w',zipfile.ZIP_DEFLATED) as a:
  for f in sorted(folder.rglob('*')):
   if f.is_file():a.write(f,f.relative_to(folder.parent))
 with zipfile.ZipFile(tmp) as a:assert a.testzip() is None
 os.replace(tmp,z);print('Verified ZIP',z,z.stat().st_size)
for folder in [O,O.parent/'latency-2026-11-22',O.parent/'trio-2026-11-22']:pack(folder)
print(json.dumps(validation))
