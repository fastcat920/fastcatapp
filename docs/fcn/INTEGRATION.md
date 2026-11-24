# FCN 接入验收（2026-11-23）

- Next 单连接正式名称：FCN v1；恢复状态选路：FCN v2。
- 共用 QUIC + TLS 1.3 + BBR、FCN/1 认证和数据格式；区别是客户端单连接池与双连接池恢复选路。
- 与旧 FastCat HTTPS v1/v2 独立。没有自动继承旧协议的 ECH 或 H2 备用。
- Android/iOS 原生核心接入 `type: fcn`、`version: 1|2`，具备受保护的入口 UDP 拨号、网络代际更新和 TCP/多目标 UDP 适配。
- 新核心导出 `fastCatSupportsFCN`；App 自动声明 `fc_fcn=1`，面板下发只按正常账号权限组，不按客户端版本或能力标记隐藏。仍是普通账号拉取，不要求设备证明。
- 面板直接选择 FCN v1/FCN v2，复用 V2node 权限组、账号、倍率、配置/用户/流量接口；生成 CatNode native 部署命令。
- CatNode 按 UID 统计 TCP/UDP 业务载荷，并复用 dispatcher 的路由、限速与在线 IP；撤销用户会关闭已有 TCP 流和 UDP 关联。

## 已验证

1. 共享 FCN 模块完整测试及 race 检查通过。
2. 客户端解析两种版本、拒绝未知版本和关闭后的拨号通过。
3. Mihomo FCN v1/v2 真实 QUIC TCP/UDP 回传及错误证书域名拒绝通过。
4. CatNode 两种版本的 8 路并发 + TCP/UDP 载荷校验、精确 UID 计数、计数提取后不重复、账号撤销通过多轮 race 检查。
5. 上报 HTTP 503 后原批次保留，下一轮按相同 UID/字节数重试，通过。
6. Flutter 订阅能力标记与防止链接伪造能力标记的 4 项测试通过。
7. 面板无依赖订阅契约测试通过：版本参数、UUID、SNI 回退；当前已移除客户端能力筛选。PHP 语法检查、前端类型检查和生产构建通过。
8. CatNode 全仓 Go 测试通过，Linux amd64 二进制与安装包已生成。
9. Android arm64 原生核心和完整调试 APK 编译通过；已安装当前 HONOR 安卓，版本码 14。iOS arm64 原生核心编译通过，没有安装 iOS App。

## 尚未验收 / 发布边界

- 线上面板没有在本轮部署，新 FCN 节点没有通过真实线上账号订阅在完整 App 中连通；本次不声称公网 App 与线上套餐扣量验收完成。
- 面板当前工作区无 Composer vendor，尚未运行 Laravel 完整 HTTP/数据库测试；已运行订阅契约测试，不能等同于数据库端到端验收。
- 代码已上传 App `3.6.3`、面板 `custom`、CatNode `main`。CatNode v0.5.0 以预发布版提供 Linux amd64/arm64 安装包；以 GitHub Release 页面上的资产为准。线上面板与节点仍需更新。
- UDP 载荷上限 1100 字节，尚不支持分片。计量失败批次保存在内存中，尚无持久化幂等账本。

详细部署规范见 `/Users/pizihu/Projects/CatNode/deploy/fcn.md`。

## GitHub 与小米安装（2026-11-23）

FCN 接入代码已上传三个仓库，安卓调试包已安装到 Xiaomi 24129PN74C（版本码 14），并确认应用位于前台、进程正常。此项是安装/启动验收，不代表线上 FCN 隧道验收。

## Android 混合栈打包修复（2026-11-24）

小米出现节点测速正常、VPN 启动后清理接口的问题。定位为上一版手工构建漏了 `with_gvisor`，原生库只有 `cmfa`，而设备选择 `mixed`，因此 `Core.startTun` 失败。标准 `setup.dart` 本来就带两个标记；补充了编译期校验，Android cgo 构建缺少任一标记立即报错，避免再次生成无法运行默认混合栈的 App。

修复后的 APK 已确认包含 `-tags=cmfa,with_gvisor` 并安装到小米（版本码 15）。FCN v2 从 09:53:26 保持至 09:55:47 后主动断开；FCN v1 于 09:56:05 冷启动，09:57:20 返回 App 复核仍保持连接。期间切换浏览器与 App，浏览器显示 Example Domain。缺少 `with_gvisor` 的反向构建检查已确认在编译阶段被阻止。

## FCN 固定公钥（2026-11-24）

新增 `tls-trust: spki` + `server-public-key-pins`，与默认 CA 模式分离。面板自动生成 SAN 自签证书、公钥指纹并通过普通账号订阅下发；私钥不进入用户订阅。续证保留密钥及 pin，明确换钥后旧订阅需刷新。节点是否下发仅沿用权限组规则，能力标记不再用于隐藏 FCN 节点。

小米原生客户端测试已通过：FCN v1/v2 的 CA 与 SPKI 模式 TCP/UDP；PHP 签发 `www.bing.com` 自签证书的实际 QUIC 回传；首次连接、同密钥续证、错误公钥拒绝、显式双 pin 过渡、错误名称、过期、未来生效、用途不符与中间证书冒充拒绝。共享模块 race 测试、Flutter 订阅参数测试、PHP 身份管理/订阅契约测试及面板类型检查和构建通过。

Android 调试包版本码 16，原生核心仍包含 `cmfa,with_gvisor`；iOS 核心已编译。线上面板未在本轮更新，93/94 的证书身份没有被自动更改；完整 App 公网固定公钥节点及 Laravel 数据库验收尚未进行。新配置需要更新面板后选择“自签证书 + 固定公钥”，旧客户端也会收到节点，连接仍需支持该模式。
