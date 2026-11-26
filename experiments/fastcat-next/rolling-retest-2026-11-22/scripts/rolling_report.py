from pathlib import Path
import json,statistics,csv,html,shutil,zipfile
O=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/rolling-retest-2026-11-22')
V={'next-base':'Next 单连接','next-opt':'Next 原调度','next-primary':'Next 主连接优先','tuic':'TUIC 默认'}
rows=[];streams=[]
for p in sorted(O.glob('rolling-*.jsonl')):
 for line in p.read_text().splitlines():
  try:r=json.loads(line)
  except:continue
  r['source']=p.name
  if r.get('phase')=='rolling_download':rows.append(r)
  elif r.get('phase')=='rolling_download_stream':streams.append(r)
(O/'summary-rows.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2))
fields=['source','version','success','jobs','elapsed_ms','verified_bytes','received_bytes','verified_mbps','lane_usage']
with (O/'groups.csv').open('w') as f:
 w=csv.DictWriter(f,fields,extrasaction='ignore');w.writeheader();w.writerows(rows)
def table(head,rr):return '<table><tr>'+''.join('<th>'+html.escape(str(x))+'</th>' for x in head)+'</tr>'+''.join('<tr>'+''.join('<td>'+html.escape(str(x))+'</td>' for x in row)+'</tr>' for row in rr)+'</table>'
summ=[]
for v,label in V.items():
 a=[r for r in rows if r['version']==v]
 if not a:continue
 rate=[r['verified_mbps'] for r in a];done=sum(r['success'] for r in a);jobs=sum(r['jobs'] for r in a)
 summ.append([label,len(a),f'{done}/{jobs}',sum(r['success']==r['jobs'] for r in a),f'{statistics.median(rate):.2f}',f'{sum(r["verified_bytes"] for r in a)*8/sum(r["elapsed_ms"] for r in a)/1000:.2f}',f'{min(rate):.2f}–{max(rate):.2f}'])
print(json.dumps(summ,ensure_ascii=False),flush=True)
s='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>滚动下载重新对照</title><style>body{font:16px/1.7 -apple-system,sans-serif;max-width:1200px;margin:32px auto;padding:0 20px;color:#20344b}table{border-collapse:collapse;margin:20px 0;width:100%}td,th{border:1px solid #ccd6df;padding:8px;text-align:right}td:first-child,th:first-child{text-align:left}th{background:#edf3fa}</style><h1>安卓滚动下载重新对照</h1><p>2026-11-22 · TFY-AN00 / Android 12 · 同一 Wi-Fi、香港 VPS · 原型核心 CLI，正式 App 未更新。</p><p>沿用上一轮相同客户端与服务端二进制。每组四个固定工作线程滚动下载十二个 4 MiB 文件，共 48 MiB；整组预算 150 秒，新客户端连接共享于十二个任务。两轮 Williams 均衡设计，每种方案八组，均衡位置和相邻方案。每组重启 Next 与 TUIC 测试服务、等待五秒，目标服务持续运行。每组开始前确认默认网络为 Wi-Fi。</p><p>所有超时均保留。有效吞吐只计完整校验成功的文件，分母包含整组等待时间；部分下载字节单独保留，不计成功。总体有效吞吐为总校验字节除以总耗时，中位数是逐组有效吞吐的中位数。每组重启条件与上一轮共享服务的两组滚动测试不同，不直接合并。</p>'''
s+=table(['方案','组数','完成任务','完整组数','吞吐中位 Mbps','总体有效 Mbps','组吞吐范围 Mbps'],summ)
s+='<h2>逐组记录</h2>'+table(['文件','方案','完成','耗时秒','有效 Mbps','通道分配'],[[r['source'],V[r['version']],str(r['success'])+'/'+str(r['jobs']),f'{r["elapsed_ms"]/1000:.2f}',f'{r["verified_mbps"]:.2f}',r.get('lane_usage')] for r in rows])
s+='<p>原始 JSONL、网络状态、时间线、计划及二进制哈希随报告保留。未完成任务错误在原始记录中。此测试仅代表本次设备、网络和服务条件，不能外推所有线路。</p></html>'
(O/'REPORT.html').write_text(s)
