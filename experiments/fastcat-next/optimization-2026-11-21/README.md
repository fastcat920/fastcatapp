# 优化后的八协议对照资料

先读 [REPORT.md](REPORT.md)，可筛选汇总见 [DATA.html](DATA.html)，修复说明见 [OPTIMIZATION-0.2.md](OPTIMIZATION-0.2.md)。

- 8 类协议、12 条配置路径；v2 包括 H2、原 H3 Reno 与双端 BBR H3。VLESS 是 TCP+TLS+Vision，没有 REALITY。
- 主实验关闭追踪、沿用系统默认 TCP MSS；诊断与小报文实验独立保存，不能合并为主排名。
- requests.csv 保留全部原值；prime / idle-prime 为预热，不计正式样本。失败不被记成零延迟。
- downloads.csv 保留完整下载与部分接收；throughput.csv 为定时双向回环，不能当成完整文件或单向链路带宽。
- sources/ 为源码快照和复现参考，运行脚本需要调整本机路径及预先构建的辅助程序，不是公开安装器。
- metadata.json、binary-build-info.txt 与 SHA256SUMS 用于核对构建及资料完整性。
- 此次没有发布正式 App 或修改生产入口。所有测试账号均为临时静态账号，不含真实用户套餐计费操作。
