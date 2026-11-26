# -*- coding: utf-8 -*-
from pathlib import Path
import json,html
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.font_manager import FontProperties
O=Path('/Users/pizihu/Projects/FastCatAPP/experiments/fastcat-next/queue-2026-11-23');web=json.loads((O/'remote-web/summary.json').read_text());cold=json.loads((O/'cold-confirm/summary.json').read_text());s3=json.loads((O/'stage3/performance/summary.json').read_text())['summary']
plt.rcParams.update({'font.family':FontProperties(fname='/System/Library/Fonts/STHeiti Light.ttc').get_name(),'axes.unicode_minus':False})
fig,axs=plt.subplots(1,2,figsize=(11.5,4.5),layout='constrained')
for ax,labels,b,c in [(axs[0],['Example 带载','Google 带载'],[web['summary'][t]['baseline']['loaded_p95_ms'] for t in web['summary']],[web['summary'][t]['selected']['loaded_p95_ms'] for t in web['summary']]),(axs[1],['随机本地端口\n主测试，各36次','固定本地端口\n追加复核，各48次'],[s3['baseline']['cold']['p95'],cold['summary']['baseline']['cold']['p95_ms']],[s3['recovery']['cold']['p95'],cold['summary']['recovery']['cold']['p95_ms']])]:
 for off,values,col,name in [(-.18,b,'#5476aa','同期原方案'),(.18,c,'#55a185','恢复状态选路')]:
  bars=ax.bar([i+off for i in range(len(labels))],values,.34,color=col,label=name);ax.bar_label(bars,fmt='%.1f',padding=3,fontsize=9)
 ax.set_xticks(range(len(labels)),labels);ax.set_ylim(0,max(b+c)*1.23);ax.set_ylabel('首字节 P95，ms');ax.spines[['top','right']].set_visible(False)
axs[0].set_title('有效远端带载补充验证');axs[1].set_title('冷启动：两组独立样本，不混合统计');axs[0].legend(fontsize=9);fig.savefig(O/'supplement.png',dpi=170);plt.close(fig)
def table(head,rows):return '<table><tr>'+''.join('<th>'+html.escape(str(v))+'</th>' for v in head)+'</tr>'+''.join('<tr>'+''.join('<td>'+html.escape(str(v))+'</td>' for v in row)+'</tr>' for row in rows)+'</table>'
wr=[]
for t,a in web['summary'].items():
 b,c=a['baseline'],a['selected'];wr.append([t,f"{b['loaded_p50_ms']:.1f} / {b['loaded_p95_ms']:.1f} ms",f"{c['loaded_p50_ms']:.1f} / {c['loaded_p95_ms']:.1f} ms",f"{b['foreground_success']}/{b['foreground_total']}；{c['foreground_success']}/{c['foreground_total']}",f"{b['background_success']}/{b['background_total']}；{c['background_success']}/{c['background_total']}"])
section='<h2>追加验证与最终选择</h2><p><b>保留恢复状态选路作为本轮通过门槛的实验候选；写入预算和首段冗余保持关闭。</b>这不是正式App发布或所有网络的长期结论。</p><img src="supplement.png">'+table(['远端目标','原方案带载 P50 / P95','恢复选路带载 P50 / P95','前台成功：原；新','背景完成：原；新'],wr)+'<p>每目标每条件24次前台HEAD，2组各2×16MiB后台下载，全部前台处于后台仍活跃的阶段；关闭逐包诊断，使用同一共享客户端。补充门槛是各目标P95恶化不超过10%、至少12个带载样本且完成率不降低，结果通过。Example约+1.1%，Google约−7.6%，没有宣称远端同样达到20%改善。</p><p>最初远端补充组后台IP地址与证书SAN不匹配，背景下载失败，因此不作为有效带载数据。原记录保存在 <a href="remote-web-invalid-tls-name/INVALID.txt">无效组说明</a>；改用证书对应域名后完整重跑，证书校验始终开启。</p><p>主测试的冷启动P95由1666.4升至2207.0ms，保留不删。追加各48次固定本地UDP端口复核：原方案529.2ms、候选543.1ms（约+2.6%），两边48/48成功，通过追加10%门槛；未复现原大幅差异。固定本地端口不能证明公网映射和中间路由完全相同，冷启动无可用备选时恢复选路通常不触发，因此仍不能断言原差异由策略引起或已排除所有冷启动问题。</p><p>最终候选仅在已有自适应双通道上启用RecoveryAware，传输、加密和拥塞控制保持原样；默认配置仍不自动改变。<a href="candidate-profile.json">实验配置及验收状态</a> · <a href="remote-web/summary.json">有效远端汇总</a> · <a href="cold-confirm/summary.json">冷启动复核</a>。</p>'
wire=json.loads((O/'stage4/performance/wire-cost.json').read_text());ww=[]
for k in ['mixed_summary','parallel_download','rolling_download']:
 a,b=wire['baseline'][k],wire['prefix'][k];ww.append([k,f"{a['wire_per_business_byte']:.4f}",f"{b['wire_per_business_byte']:.4f}"])
section+='<h2>冗余成本与使用证据</h2><p>机制轮36个前台请求中32个从副本提前交付部分字节，服务端42个流的副本载荷最大8193字节、尝试最大11次，未超出上限。这里的提前是相对可靠Read消费进度，不等于都避免了一次物理丢包。有限冗余能工作，但本轮没有转化为足够的带载P95改善。</p>'+table(['负载','第3项：接收QUIC字节/验证业务字节','第3项+副本：同口径'],ww)+'<p>比率含QUIC头、控制帧、重传和副本，不含UDP/IP；是Close前仍登记会话的快照，各组均2条会话，不跨移除/Reset累积。大文件组约增加0.2个百分点，不能据此推断小请求的相对成本或锁屏耗电。资源、能耗与其他网络尚未完成长期验收。</p>'
p=O/'REPORT.html';a=p.read_text().replace('<h2>测量与验收口径</h2>',section+'<h2>测量与验收口径</h2>');p.write_text(a)
profile=dict(status='Android Wi-Fi lab candidate; main gate, remote non-regression and fixed-local-port cold confirmation passed; original cold regression retained',formal_app_installed=False,production_defaults_changed=False,core_client=dict(QUICLanes=2,AdaptiveLanes=True,RecoveryAware=True,LatencyAware=False,PrimaryPreferred=False,PrefixRedundancy=False),standalone_server=dict(DownstreamBudget=False,PrefixRedundancy=False,ReplyCoalesceMillis=0,DisableECN=False,DisableGSO=False,FixedPacketSize=0),limitations=['no direct server downlink recovery feedback','not all networks / devices / lockscreen / energy tested','original random-port cold P95 worsened; fixed-local-port confirmation did not reproduce large difference'])
(O/'candidate-profile.json').write_text(json.dumps(profile,indent=2))
