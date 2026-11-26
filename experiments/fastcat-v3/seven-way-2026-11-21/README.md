# 测试交付目录

先阅读 REPORT.md 或打开 DATA.html。HTML包含完整表格及内嵌图表，可搜索、排序；CSV可用Excel/Numbers查看。

- requests.csv：逐请求，包含预热及原始/逻辑场景。
- latency-summary.csv/json：成功、失败、均值、P50/P90/P95/P99、最大、标准差、按轮bootstrap参考区间、分阶段观测、1/2/5秒内成功比例。
- throughput-summary.csv/json：三轮每轮值、均值、中位、范围、有效组数及Go资源快照。
- download-summary.csv/json：1MiB两轮完成状态与总耗时，完整样本端到端速率。
- idle-summary.csv/json：两个业务空闲窗口的实际时长、首次和后续结果。
- 各阶段jsonl：完整原始微秒记录；pilot不计正式样本。
- metadata/environment：版本、参数、哈希和只读环境快照。
- sources：当前基准程序、CatNode包装入口及整理后的复现脚本；不含临时账号或私钥。

复现需在FastCatAPP/core构建 tools/fastcat-v3-compare 安卓arm64程序；CatNode包装代码复制到CatNode模块中的独立临时目录，再用Go1.27.3编译。sources/run_seven_way.py是当前环境的测试脚本，要求准备指定二进制、安卓及SSH会话，不是生产部署脚本；使用前修改目标与设备并检查端口。分析脚本中的路径也需按环境调整。

图表环境：Python3.9、matplotlib3.9.4、numpy2.0.2；中文字体STHeiti Light。图表标签中的“轻量版”指IndependentPipelined/v3-light-fast。
