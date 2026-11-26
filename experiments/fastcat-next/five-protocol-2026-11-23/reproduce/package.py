# -*- coding: utf-8 -*-
from pathlib import Path
import json,hashlib,shutil,re,zipfile,subprocess,collections,csv,html
O=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/five-protocol-2026-11-23');B=Path('/tmp/fc-five');R=O/'reproduce';V=['next-opt','next-base','tuic','hysteria2','vless-vision'];N=['恢复选路','Next 单连接','TUIC v5','Hysteria 2','VLESS Vision'];S=json.loads((O/'speed/summary.json').read_text());A=json.loads((O/'latency/combined-summary.json').read_text());M=json.loads((O/'latency-loaded/summary.json').read_text());base=json.loads((O/'latency/summary.json').read_text())
plans={m:json.loads((O/m/'plan.json').read_text()) for m in ['speed','latency','latency-loaded']}
for m,expected_cases,expected_pilots in [('speed',250,10),('latency',150,20),('latency-loaded',70,15)]:
 t=json.loads((O/m/'timeline.json').read_text());assert sum(r['metric']!='pilot' for r in t)==expected_cases,(m,len(t));assert sum(r['metric']=='pilot' for r in t)==expected_pilots;(O/m/'timeline.json').read_text();assert len(t)==len({r['name'] for r in t});assert all(r.get('status','returned')=='returned' for r in t)
 for metric in {r['metric'] for r in t if r['metric']!='pilot'}:
  for v in V:
   rr=[r for r in t if r['metric']==metric and r.get('version')==v];want=2 if metric.startswith('web-') else 10;assert len(rr)==want,(m,metric,v);ports=collections.Counter(r['dest_port'] for r in rr);assert ports==({19458:1,19451:1} if want==2 else {19458:5,19451:5}),ports
 for n,h in plans[m]['sha256'].items():assert hashlib.sha256((B/m/n).read_bytes()).hexdigest()==h,(m,n)
 assert plans[m]['sha256']['next-diagnostic']==plans['speed']['sha256']['next-diagnostic'];assert plans[m]['sha256']['catnode-server']==plans['speed']['sha256']['catnode-server']
 rr=json.loads((O/m/'all-rows.json').read_text());assert not any(r.get('received_sha256') and not r.get('offline_prefix_verified') for r in rr)
 for r in rr:
  if r.get('metric') not in ['single32','parallel4','parallel8','rolling'] and r.get('complete'):assert r.get('checksum_ok') and r.get('offline_prefix_verified')
 errors=[{k:r.get(k) for k in ['source','metric','version','phase','error']} for r in rr if r.get('error')];(O/m/'errors.json').write_text(json.dumps(errors,indent=2))
for v in V:
 for k,n in [('single32',10),('parallel4',40),('parallel8',80),('rolling',120)]:
  a=S[v][k];assert a['groups']==10 and a['jobs']==n and a['prefix_validation_failures']==0 and a['harness_timeouts']==0
  assert a['success']==(0 if v=='vless-vision' else n),(v,k,a['success'])
 assert S[v]['echo1']['success']==10 and S[v]['echo4']['success']==40
 for k,n in [('latency/cold',60),('latency/warm',60),('latency/batch',80),('batch8/batch',160),('idle/idle-resume',10)]:
  a=base[v][k];assert a['total']==a['observed_rows']==n and a['missing_rows']==0;assert a['success']==(57 if v=='vless-vision' and k=='latency/warm' else n),(v,k,a)
 for k,n,bg in [('mixed/mixed',60,20),('web-example/mixed',24,4),('web-google/mixed',24,4)]:
  a=M[v][k];assert a['all_foreground_total']==a['all_foreground_observed']==n and a['missing_rows']==0;assert 0<=a['all_foreground_success']<=n,(v,k,a);assert a['background_total']==bg and 0<=a['background_success']<=bg
# Coverage pilots prove the fixed VLESS workload emitted actual foreground andbackground records.
t=json.loads((O/'latency-loaded/timeline.json').read_text())
for v in V:
 c=next(r for r in t if r['name'].startswith('loaded-pilot-') and r['version']==v);rows=[]
 for l in (O/'latency-loaded'/(c['name']+'.jsonl')).read_text().splitlines():
  try:rows.append(json.loads(l))
  except:pass
 assert sum(r.get('phase')=='mixed' for r in rows)==1 and sum(r.get('phase')=='mixed_background' for r in rows)==2
# Protocol source unchanged. The two comparator revisions differ only in measurement coverage/help text.
for p in (R/'fastcatnext').rglob('*.go'):assert p.read_bytes()==(Path('/Users/pizihu/Projects/FastCatAPP/core/fastcatnext')/p.relative_to(R/'fastcatnext')).read_bytes()
phone=subprocess.check_output(['adb','-s','A3GMVB2110006859','shell','dumpsys','connectivity'],text=True);assert 'ni{VPN CONNECTED' in phone
assert subprocess.check_output(['adb','-s','A3GMVB2110006859','shell','settings','get','global','stay_on_while_plugged_in'],text=True).strip()=='0'
r=subprocess.run(['adb','-s','A3GMVB2110006859','shell','ls -d /data/local/tmp/fc-opt-* 2>/dev/null'],capture_output=True,text=True);assert not r.stdout.strip()
for m in ['speed','latency-loaded']:
 c=(B/m/'cleanup-server.txt').read_text();assert 'fc-opt' not in c and not re.search(r':194(?:45|51|54|58)\s',c)
 if m=='speed':assert ':20501 ' in c
# Per-case network audit: native comparison must not silently run inside theAppVPN.
net=[]
for m in ['speed','latency','latency-loaded']:
 for c in json.loads((O/m/'timeline.json').read_text()):
  if c['metric']=='pilot':continue
  for suffix in ['before','after']:
   p=O/m/(c['name']+'-network-'+suffix+'.txt');txt=p.read_text();assert 'ni{VPN CONNECTED' not in txt,str(p);match=re.search(r'Active default network: (\d+)',txt);assert match
   lines=[l for l in txt.splitlines() if 'network{'+match.group(1)+'}' in l and 'Transports: WIFI' in l];assert lines
   line=lines[0];freq=re.search(r'Frequency: (\d+)',line);ssid=re.search(r'SSID: "([^"]+)"',line);net.append(dict(mode=m,case=c['name'],boundary=suffix,frequency_mhz=int(freq.group(1)) if freq else None,ssid_sha256=hashlib.sha256(ssid.group(1).encode()).hexdigest() if ssid else None))
(O/'network-audit.json').write_text(json.dumps(dict(boundaries=len(net),vpn_connected_boundaries=0,frequencies=sorted({r['frequency_mhz'] for r in net if r['frequency_mhz']}),ssid_hashes=sorted({r['ssid_sha256'] for r in net if r['ssid_sha256']}),rows=net),indent=2));assert len(net)==940;assert {r['frequency_mhz'] for r in net}=={2412};assert len({r['ssid_sha256'] for r in net})==1
# Archive executed scripts and logs, not private configs/keys/binaries.
for n in ['run.py','run-base-resume.py','run-loaded.py','queue-loaded.py','analyze.py','report.py','uncertainty.py','race.txt','vet.txt','race-mixed-fix.txt','vet-mixed-fix.txt','catnode-wrapper.go']:shutil.copy2(B/n,R/n)
for m,names in [('speed',['run.log','cleanup-server.txt']),('latency',['run-initial.log','run-base-resume.log']),('latency-loaded',['run.log','cleanup-server.txt'])]:
 d=R/m;d.mkdir(exist_ok=True)
 for n in names:shutil.copy2(B/m/n,d/n)
# Raw server resource snapshots as a convenience index, not net protocolCPU/RSS claims.
resource=[]
for m in ['speed','latency','latency-loaded']:
 for c in json.loads((O/m/'timeline.json').read_text()):
  if c['metric']=='pilot':continue
  p=O/m/(c['name']+'-server-resource.txt');d=dict(l.split('=',1) for l in p.read_text().splitlines() if '=' in l);resource.append(dict(mode=m,case=c['name'],metric=c['metric'],version=c['version'],**d))
(O/'resource-snapshots.json').write_text(json.dumps(resource,indent=2))
for m in ['speed','latency','latency-loaded']:
 (O/m/'validation.txt').write_text('PASS: all planned cases and expected request/stream rows present; port/order schedule checked. Payloadprefix independentlySHA256verified, no checksum failure.\nSpeed: VLESS fullfiles intentionally NOT called successful; partial transfers/timeouts retained. Valid latency: VLESS warm57/60, request failures are retained and counted, includingGoogleVLESS23/24; no outcome-based reruns.\nMeasurement coverage defect archived in latency/superseded-mixed; invalid oldmixed NOT ranked as failures. Entire5-way loaded/web rerun with regression pilots. Two comparatorrevisions, protocol/servers unchanged. Race/vet passed.\nCleanup: own listeners/units/files/keys/hosts gone, originalserver20501 retained; phoneVPN restored and keepawake0. Networkaudit confirmsWiFi andVPNoff at940 valid case boundaries.\nLimits: nativeAndroidWiFi, noApp/TUN/UDPbusiness/energy/privacytest; ten rounds and shared resources are not universal protocol proof.\n')
(O/'STATUS.json').write_text(json.dumps(dict(status='complete',speed={'server':'172.104.55.44','valid_cases':250,'preflight_cases':10},latency={'server':'154.37.155.240','valid_base_cases':150,'valid_loaded_cases':70,'preflight_cases':35,'warm_vless_success':'57/60'},valid_total_cases=470,measurement_fix='superseded4-waymixed excluded;all5loaded andweb rerun',cleanup='complete',network_boundaries_verified=940),indent=2))
def tab(h,rows):return '<div class="scroll"><table><tr>'+''.join('<th>'+html.escape(str(x))+'</th>' for x in h)+'</tr>'+''.join('<tr>'+''.join('<td>'+html.escape(str(x))+'</td>' for x in r)+'</tr>' for r in rows)+'</table></div>'
rows=[];complete=[]
for k,title in [('single32','单文件32MiB'),('parallel4','四路×8MiB'),('parallel8','八路×4MiB'),('rolling','四路滚动12×4MiB')]:
 rows.append([title]+[f"{S[v][k]['aggregate_prefix_mbps']:.2f}"+(' *' if v=='vless-vision' else '') for v in V]);complete.append([title]+[f"{S[v][k]['success']}/{S[v][k]['jobs']}" for v in V])
lat=[]
for k,title in [('latency/cold','冷启动'),('latency/warm','连续请求'),('latency/batch','四路短请求'),('batch8/batch','八路短请求'),('mixed/mixed','固定目标严格带载'),('idle/idle-resume','闲置20秒后首次（10次）'),('web-example/mixed','Example严格带载（24次）'),('web-google/mixed','Google严格带载（24次）')]:
 lat.append([title]+[('—' if A[v][k]['p95_ms'] is None else f"{A[v][k]['p95_ms']:.0f}")+f" ({A[v][k]['success']}/{A[v][k]['total']})" for v in V])
page='''<!doctype html><html lang="zh"><meta charset="utf-8"><title>五配置：双服务器速度与延迟重测</title><style>body{max-width:1350px;margin:36px auto;padding:0 22px;font:17px/1.8 system-ui;color:#223449}img{width:100%}h2{margin-top:36px}table{border-collapse:collapse;width:100%;font-size:15px}th,td{padding:10px;text-align:left;border-bottom:1px solid #dbe2e9}th{background:#edf3f8}.scroll{overflow:auto}.note{padding:18px;background:#edf3f8}a{color:#245b98}</style><h1>恢复选路 / Next单连接 / TUIC / Hysteria 2 / VLESS Vision</h1><p>2026-11-23 · HONOR TFY-AN00 / Android12 · 本轮五组全部重测</p><div class="note"><b>速度172.104.55.44：250组；延迟154.37.155.240：220组。</b>主项十轮平衡测试位置、端口和先后方向；真实网站两轮另列。不拼旧三组数据，不把两个服务器混成总分。实际有效采样470组，45组预检不排名；测量工具覆盖修正及归档记录保留。</div><h2>本轮观察与边界</h2><p>没有配置在全部场景领先。下载点估计：Hysteria 2在单文件和滚动较高，TUIC在四路较高，恢复选路在八路较高。冷启动和连续请求P95以TUIC较低；固定目标带载以Next单连接较低。部分差距较小、逐轮波动较大，不能将点估计当作所有网络的稳定排名，详见整轮探索性区间。</p><p>VLESS采用TCP＋TLS＋XTLS Vision、系统TCP拥塞控制，<b>不是REALITY</b>；Hysteria 2使用未设置Brutal速率的默认BBR路径。其他QUIC也显式BBR，但实现和窗口不同；Next恢复选路是双通道，其他配置的池结构不同，不是严格等连接数/等拥塞实现实验。只代表当前实现、组合和网络。</p><p>172上VLESS大文件均未在时限内完成，但已收到数据的SHA256正确，因此下面列其接收吞吐，同时明确完整文件完成数为零。154上小请求大多成功，连续请求有3次EOF，Google带载有1次失败；不能把这两条不同路径合成“VLESS本身不通”。全程保持证书校验，未关闭安全验证。</p><h2>速度：校验接收吞吐（Mbps，越高越好）</h2>'''
page+=tab(['场景']+N,rows)+'''<p>* VLESS为部分已收数据，不代表完整文件成功。所有配置目标大小和时限相同：单/四/八路30秒，滚动45秒。校验接收吞吐包括已校验完整文件和未完整文件前缀字节；时间含入口准备、目标TLS、校验和等待。不是纯稳态固定窗口或峰值。</p>'''+tab(['完整文件 / 计划文件']+N,complete)+'<img src="speed/speed.png"><p><a href="speed/REPORT.html">速度完整报告、回显与逐轮散点</a> · <a href="speed/summary.json">汇总JSON</a> · <a href="speed/download-groups.json">逐轮数据</a></p><h2>首字节P95：ms（成功/样本），越低越好；不是ping</h2>'+tab(['场景']+N,lat)+'<img src="latency/latency-1.png"><img src="latency/latency-2.png"><p><a href="latency/REPORT.html">完整P50/P95、成功率及带载资格</a> · <a href="latency/combined-summary.json">按场景展示的汇总</a> · <a href="latency/all-rows.csv">冷/热/并发/闲置CSV</a> · <a href="latency-loaded/all-rows.csv">带载/网站CSV</a></p>'
page+='''<h2>测量修正与复现</h2><p>首次带载工具只选QUIC，错误地跳过VLESS TCP。及时发现后停止，旧带载全部归档且不参加五组排名，空记录没有当作网络失败。修正测量选择、添加回归测试和每组真实执行预检后，将<b>全部五组带载和真实网站一起重新采集</b>；冷/热、并发、闲置覆盖正确，继续保留。两个测量版本只用于不同场景，协议核心、两种服务器二进制不变，未将同一指标跨版本拼样本。</p><p>测试时记录为Wi-Fi2412MHz（2.4GHz），940个有效测量边界均确认VPN关闭；仍有无线、公网时段和服务器原有业务的影响。它是安卓原生核心程序，未替换正式App；不是完整App/TUN、UDP业务、蜂窝、耗电或隐蔽性验收。</p><p>手机原VPN和唤醒设置已恢复，临时服务、私钥和hosts映射已清理，原有服务保留。<a href="STATUS.json">最终状态</a> · <a href="network-audit.json">网络核对</a> · <a href="resource-snapshots.json">资源原始快照</a> · <a href="speed/validation.txt">速度自检</a> · <a href="latency/validation.txt">延迟自检</a> · <a href="reproduce/README.txt">复现说明及覆盖修正</a> · <a href="SHA256SUMS.json">文件SHA256</a></p></html>'''
(O/'REPORT.html').write_text(page)
(O/'SHA256SUMS.json').touch(exist_ok=True)
for p in [O/'REPORT.html',O/'speed/REPORT.html',O/'latency/REPORT.html']:
 for x in re.findall(r'(?:href|src)="([^"]+)"',p.read_text()):
  if not x.startswith(('http','#')):assert (p.parent/x).exists(),(p,x)
manifest={str(p.relative_to(O)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(O.rglob('*')) if p.is_file() and p.name!='SHA256SUMS.json'};(O/'SHA256SUMS.json').write_text(json.dumps(manifest,indent=2)+'\n');z=O.with_suffix('.zip')
with zipfile.ZipFile(z,'w',zipfile.ZIP_DEFLATED) as f:
 for p in sorted(O.rglob('*')):
  if p.is_file():f.write(p,str(Path(O.name)/p.relative_to(O)))
with zipfile.ZipFile(z) as f:assert f.testzip() is None
print('PASS',len(manifest),'files',z.stat().st_size,'bytes;470validcases')
