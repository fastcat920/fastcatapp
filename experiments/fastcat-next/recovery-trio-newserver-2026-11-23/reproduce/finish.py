from pathlib import Path
import json,html,statistics
O=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/recovery-trio-newserver-2026-11-23');S=json.loads((O/'summary.json').read_text());V=['next-opt','next-base','tuic'];N=['恢复状态选路','Next 单连接','TUIC v5']
def table(h,rows):return '<div class="scroll"><table><tr>'+''.join('<th>'+html.escape(str(x))+'</th>' for x in h)+'</tr>'+''.join('<tr>'+''.join('<td>'+html.escape(str(x))+'</td>' for x in row)+'</tr>' for row in rows)+'</table></div>'
direct=[json.loads(l) for l in (O/'direct-control.jsonl').read_text().splitlines()]
old=[]
for v,n in zip(V,N):
 a=S[v]['rolling'];old.append([n,a['groups'],f"{a['success']}/{a['jobs']}",f"{a['aggregate_mbps']:.3f}",f"{a['elapsed_ms']/1000:.1f}"])
section='<h2>中途网络退化与原大滚动任务</h2><p>早期多种下载均约4.4Mbps，原滚动第二轮起陆续超时或部分完成。暂停后独立直连HTTPS三次4MiB文件全部校验成功，速度分别为'+', '.join(format(r['mbps'],'.3f') for r in direct)+' Mbps。观察到共同路径容量下降，不能仅凭此定位到运营商限速、服务器或Wi-Fi中的某一处。</p>'
section+=table(['原48MiB任务（只执行3轮）','轮数','取得完整校验记录/计划文件','总体有效Mbps','含失败耗时秒'],old)
section+='<p>TUIC第二、三轮均触发180秒整组时限，未取得最终完成记录，按0可验证成果保留；不表示已证明每个文件都没有传输。Next保留实际完成文件数和150秒等待。原任务后3轮未执行，不计成功也不计失败。以1.8Mbps估算，48MiB需约224秒，超过既定150秒，因此这些不完整结果无法用来认定某协议固有可靠性。</p><p>随后冻结独立低带宽计划：滚动12×1MiB/4路、带载背景2×4MiB，其余协议设置与二进制不变。每种配置各6轮并继续交换端口，不重跑替换原失败组，不与原大滚动混算。带载、回显、闲置和网站与前期首字节/大文件属于不同时段网络状态。</p><p><a href="direct-control.jsonl">直连对照原始数据</a> · <a href="lowbandwidth-plan.json">低带宽独立计划</a> · <a href="timeline.json">含中断、预检与续跑时间线</a></p>'
findings='<h2>本轮结论</h2><p><b>未复现恢复状态选路在所有场景上的明显优势。</b>早期冷启动P95以恢复选路较低，连续和八路短请求P95以TUIC较低；单文件及成批下载多数接近共同带宽上限。低带宽滚动三组也接近，严格带载P95差距较小。</p><p>原大滚动存在超时与不完整文件，且已经被直连对照证实同期普通HTTPS也较慢；不能将这些失败直接解读为协议固有缺陷。当前证据不足以仅凭这台服务器选择最终默认调度。实验是安卓原生核心，不是正式App/TUN、耗电或隐蔽性验收。</p>'
U=json.loads((O/'paired-uncertainty.json').read_text());section+='<details><summary>探索性不确定性</summary><p>完整六轮指标按整轮配对重采样10000次，六对样本量仍少，不作正式显著性判断。区间跨1表示方向尚不确定。原未完成大滚动不参与六轮分析。</p><p><a href="paired-uncertainty.json">查看配对比值和区间</a></p></details>'
page=(O/'REPORT.html').read_text().replace('<h2>配置与比较范围</h2>',findings+'<h2>配置与比较范围</h2>').replace('<h2>数据与自检</h2>',section+'<h2>数据与自检</h2>');(O/'REPORT.html').write_text(page)
