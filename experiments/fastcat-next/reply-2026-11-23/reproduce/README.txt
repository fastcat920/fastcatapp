本目录为本轮公开参数的复现材料，不含临时账户配置、证书私钥、面板令牌或 SSH 密码。

数据分组：
wire-diagnostic：GSO/包长，16 case，带追踪。
mechanism：合并发送机制，6 case，带追踪。
performance：合并发送性能，42 case，逐包追踪关闭。
cross-network：Wi-Fi / 蜂窝小请求，7 case，带追踪，不做蜂窝大文件。
ecn-device：安卓/Mac × 服务端 ECN，16 case，带追踪。
ecn-fixed：安卓固定源端口，12 case，带追踪；仅用于排除公网映射差异。
ecn-performance/performance：独立 ECN 性能，42 case，逐包追踪关闭。

本轮安卓/Mac 客户端 Go1.26.2，Linux amd64 服务端 Go1.27.3；标准密码与依赖未改。
binaries-sha256.json 与每个 plan.json 用于核对实际测试二进制；不打包大型可执行文件。
source-final、comparator-final、server-main-final.go 对应最终诊断版本；source-before-reply 保留合并发送前的核心。
原有 mihomo、本地模块 replace 及 go.mod/go.sum 需要在原仓库使用。运行脚本内保留原实验路径，复现前应放到隔离输出目录，检查设备 ID 和测试端口，不要覆盖历史原始数据。
run.py 使用临时账号和权限600配置，只在隔离端口部署；完成后恢复 VPN 与设备唤醒设置，删除临时服务、可执行文件和凭证。

报告用最近秩 P95；有效吞吐按校验字节总量 / 各轮总耗时。不同追踪版本、时段、网络的样本不混合作性能排名。
