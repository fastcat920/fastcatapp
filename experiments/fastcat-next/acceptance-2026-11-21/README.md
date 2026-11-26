# FastCat Next 原型验收资料

先读 [REPORT.md](REPORT.md)，可筛选汇总见 [DATA.html](DATA.html)，线上格式见 [SPEC-0.1.md](SPEC-0.1.md)。

这是独立安卓核心和测试入口的原型验收；生产替换未通过。所有失败和超时保留。正式 App、面板、ECH、自动选路未发布。

- requests.csv 含主对照、预热以及额外 Reno/BBR 短请求；workload 字段区分来源，prime / idle-prime 不计正式请求。
- pilot-initial 为修复前预检，pilot-fixed 为修复后预检；均不计正式结果。
- 大文件 10/100 MiB 各路径各一次，与主对照属于不同时间段，不合并算平均。
- sources/core 为主测试的代码快照；sources/large-transfer-harness 只扩大文件上限、允许设定下载总预算，协议实现未变。
- sources 中的执行脚本是复现参考，需调整本机路径并预先编译其依赖的 v2/轻量版工具。不是公开一键部署安装器。sameport.py 参考脚本包含后续大文件段，实际执行时这两段以独立进程完成，结果分别保留。
- large-transfer-tcp-snapshot 是传输过程中的一次快照，采集时已进入 H3 阶段，不能用于解释此前 H2 超时。
- 凭证仅在运行时生成，已清理。源码中不包含公网测试账号密钥。
