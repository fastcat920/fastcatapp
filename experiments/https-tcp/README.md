# HTTPS TCP 隔离实验

独立模块，仅标准库，不修改 core、默认线路或生产配置。运行 `go run . -h` 查看参数；认证从 FASTCAT_LAB_TOKEN 环境变量读取，至少 24 字节。客户端证书验证始终开启。服务端只能转发到启动时指定的固定 target；默认绑定回环。首版只支持 TCP。

## 运行与自检

在本目录执行 `go test ./...`（编译检查），再执行 `python3 smoke.py`（需 Go、Python 3.8+、openssl）。脚本生成临时 localhost 证书，启动本地 echo、服务端与客户端，校验 20 个顺序连接，每连接 65536 字节随机载荷。端口 18080、18443、19090 必须空闲。证书与程序在临时目录，退出清理进程。

2026-11-18：编译通过；本地 20 连接校验通过，每方向累计 1,310,720 字节。一次启动测试出现连接拒绝，重跑通过：当前脚本固定等待一秒存在启动竞态，不能据此宣称稳定性已验证。日志字节数是应用载荷，不是 TLS/IP 线上字节；尚无 pcap。短测无数据不一致，不代表长稳结果。

## 集成核对

core/go.mod 使用本地 core/Clash.Meta 替换 mihomo。core/main.go 是非 cgo 启动入口，core/lib_ios.go 通过 ClashCore_init 初始化 Apple 核心，NetworkExtension 持有 TUN。后续须检查 mihomo outbound 适配、配置解析与 Dart/Apple 桥接；本次未增加协议枚举或接入 TUN。

## 失败分层与后续实验

entry_tcp：入口 TCP 建连失败，只能说明当前路径无法建连，不能单凭这一项断言 IP 被封。tls：证书、握手或中间网络失败。https_response：HTTP 解析、认证 403、目标不可达 502；服务端同时记录 authentication 或 target_tcp。tunnel/upload/download：通道建立和载荷计数。日志不输出认证令牌和载荷。

待补：错误令牌、错误 CA、关闭入口、关闭目标的自动化负测；用相同入口对照普通 HTTPS 和本原型，记录握手耗时、成功率、并发、重连、半关闭、长连接与空闲行为。通过自有入口采集 pcap，统计实际线上字节、TLS 参数、包长和时序。当前 CONNECT、Go TLS 特征及流量形态仍可能被识别，不作不可识别承诺。原型尚无完整连接配额、优雅停机与服务端隧道超时，不应直接对公网开放。

iOS/tvOS 后续在真机 Release 构建测启动、空闲和传输峰值内存、CPU、电量、热状态、文件描述符、弱网切换与后台恢复；记录系统版本、设备、并发、载荷、NetworkExtension 退出原因。达标前不改默认线路、不部署生产。

## 第二批自检（2026-11-18）

执行 `python3 faults.py`，使用临时端口和独立进程，不占用网页演示端口。以下五项已通过：入口关闭→entry_tcp error；系统信任库拒绝自签证书→tls error；错误令牌→客户端 403 且服务端 authentication rejected；目标关闭→客户端 502 且服务端 target_tcp error；客户端发送 65536 字节后半关闭→目标等待 EOF 后完整回传，载荷一致。

修复：bufferedConn 透传 CloseWrite 到 TLS，relay 使用 CloseWrite 接口，从而传播客户端请求结束信号。入口和目标连接失败日志补充实际错误原因。go test ./... 编译检查及 go vet ./... 均通过。故障日志检查未包含测试令牌。

smoke.py 已将固定一秒等待改为最长 15 秒的端口就绪检查，并检查进程提前退出；改动后未在现有网页演示端口上重跑，避免中断演示。故障脚本使用相同就绪策略且已运行成功。动态端口分配存在释放后被其他程序抢占的小概率竞态。

边界：HTTP 服务 IdleTimeout 不约束劫持后的隧道，当前没有隧道空闲超时。入口失败只能确定当前 TCP 连接失败；无法据此区分运营商阻断、防火墙、服务未启动等根因。尚未执行并发、长稳、实际网络抓包或真机资源测试。

## 第三批：并发与持续传输（2026-11-18）

smoke.py 现使用动态端口，不影响网页演示；此节取代旧版固定端口说明。运行 256 次连接、16 路并发及单连接持续交换 15 秒，结果保存 last-run.json。

实测 256/256 完成，每方向 16,777,216 字节，批次 0.368 秒；连接建立至 64 KiB 回显结束的耗时中位数 17.758 ms、P95 52.340 ms。持续连接 15.048 秒，278 次交换，每方向 2,277,376 字节，无载荷不一致。包含本地排队和 TLS 耗时，不能作为公网性能预测；15 秒短测不代表长稳验证。

集成核对：core/Clash.Meta/adapter/parser.go 的 ParseProxy 是协议解析入口；候选 outbound 必须明确拒绝 UDP。ios/PacketTunnel/PacketTunnelProvider.swift、tvos/PacketTunnel/PacketTunnelProvider.swift 均调用 ClashCore_init，主应用探测走 ClashCore_init_probe，未来需要覆盖两条路径。

真机计划：iPhone 和 Apple TV Release 构建，空闲 10 分钟、单连接 30 分钟、16 连接、前后台及网络切换；对照既有线路记录峰值 RSS、CPU、热状态、FD、恢复耗时及扩展退出原因，按设备基线确定阈值。

尚无 pcap，流量数字均为应用载荷；没有降低指纹识别概率的实证。公网对照需自有入口与受信任证书，本次仅回环，未部署生产、未修改默认线路。

## 第四批：60 秒持续传输与服务重启

运行 `python3 smoke.py --duration 60 --output stability-run.json`：256 次连接、16 路并发全部完成，批次 0.345 秒；64 KiB 回显耗时中位数 19.235 ms、P95 33.356 ms。单连接持续 60.055 秒，1111 次交换，每方向 9,101,312 字节，无载荷不一致。

每秒通过 ps 采样 Mac 进程 RSS，共 60 个有效样本。服务端初值/峰值/末值 12992/22608/9888 KiB，客户端 16848/19632/9840 KiB。未见本次短测中的持续内存上涨，但不足以证明无泄漏；ps CPU 是进程生命周期平均值，不是瞬时 CPU。资源原始样本保存在 stability-run.json。

faults.py 重新全部通过，新增服务端停止并重启后，在同一客户端进程上建立新连接并校验 65536 字节半关闭回显。此项不表示已有连接能跨重启恢复，也没有自动重放请求。

本机尝试 tcpdump 回环抓包，但当前用户无 /dev/bpf0 权限，未获得抓包数据、未提升权限。尚不能报告实际线上字节、TLS 包长与时序对照。移动端资源与公网可达性仍需后续环境实测。60 秒结果仍属于短期稳定性，不能替代 30 分钟以上长稳。

## TCP v1 核心接入（取代最初“未增加协议枚举”的状态）

已增加 FastCatHTTPS 类型及 fastcat-https YAML 解析、独立 outbound，强制 TLS 证书验证，令牌在 TLS 内发送。支持每连接动态目标、响应预读保留、握手超时/取消及 TCP 写入结束；显式拒绝 UDP 和跳过证书校验。旧协议实现不改。

独立服务端新增 dynamic-targets、allow-private-targets（仅测试）、max-tunnels、session-timeout。默认保留固定目标模式；动态目标默认拒绝内网/回环/链路本地，校验 DNS 所有答案后直接连接已验证 IP。绝对连接期限默认 30 分钟，不是空闲超时。已认证隧道并发默认 128。

协议定义和使用见 PROTOCOL.md，节点片段见 node.example.yaml。核心客户端与独立服务端实际端到端通信已通过：动态目标、57344 字节回显；内核单测验证 200 响应与目标首包合并时不丢失 banner。解析测试验证独立类型及拒绝不安全证书配置；独立模块策略测试和 race 检查通过，故障集回归通过。新版本短回归 16 并发/256 连接通过，3 秒持续交换通过，见 v1-regression.json；此前 60 秒数据来自资源限制加入前，不作为新版本长稳证据。

当前未构建签名 iOS/tvOS 安装包、未配置真实入口；已安装的旧版 App 不能使用新类型。此实现是标准 HTTPS CONNECT 的 FastCat v1 配置规范，并非新加密算法，不能宣称不可识别或公网抗阻断。

最终补查：真实独立服务端设置 max-tunnels=1 时，第二个同时连接返回 503，第一个连接继续正确回显；核心相关测试带 race 检查通过。上层 core 的 go test ./... 通过。目标策略补充拒绝运营商共享地址、基准测试地址及常见 IPv6 地址转换前缀，并覆盖对应负测；独立模块 go test -race 与 go vet 通过。

## 第五批：Apple 构建及交付程序

已完成 iOS、tvOS 真机 arm64 核心库构建；两个库以及最终 iOS/tvOS 隧道扩展的二进制均检出 fastcat-https 标识，SHA256/大小见 apple-build-manifest.json。tvOS Debug 的实现位于 PacketTunnel.debug.dylib，不在启动壳中。

未签名应用构建通过：iOS 为 build/ios/iphoneos/Runner.app；tvOS 为 /tmp/fastcat-v1-tvos-build/Build/Products/Debug-appletvos/FastCat.app。tvOS 在核心库更新后再次构建，确保重新链接。iOS 使用 flutter build ios --debug --no-codesign；tvOS 使用 xcodebuild Debug/appletvos CODE_SIGNING_ALLOWED=NO。没有签名、安装、发布或切换默认线路；构建成功不代表真机隧道运行成功。仍使用仓库原有版本号，不作为 3.6.3 正式发布包。

新增 core/fastcat_https_test.go：同时验证正常隧道和 Apple 测速配置保留新协议，且手动组首选仍为 DIRECT。上层 core 全测通过。iOS IPC 测试通过；tvOS 运行协议、二维码登录及工具测试通过，新协议字段在运行配置注入后保留，节点列表能显示 FastCatHTTPS，既有选择保持 DIRECT。

补修双向半关闭：目标先发 FIN 后仍可接收客户端后续上传，避免提前关闭整条通道；新增回归、race、vet 和真实核心到服务端集成测试通过。

已生成 artifacts/fastcat-https-linux-amd64（交叉编译，未在 Linux 执行）、artifacts/fastcat-https-macos-arm64（实际端到端运行通过），校验见 server-build-manifest.json。artifacts 被忽略，不把程序文件混入源码。

未完成的外部验证：自有测试域名/入口和受信任证书、签名真机安装、30 分钟以上长稳及真机资源、具有抓包权限的流量对照。当前 App 构建只证明链接成功；原有订阅没有自动添加新节点，需要在独立测试配置加入 node.example.yaml 所示节点。

## 2026-11-19：iPhone 测试节点入口与覆盖安装

iOS 新增“我的 → 工具设置 → 新协议测试节点”。默认域名 zlhk.fastcat.ink、端口 8443；令牌由用户在手机输入，遮蔽显示、不写日志，节点正文复用 ProfileVault 加密存储。保存独立手动配置，不自动切换当前线路；可显式使用测试配置、恢复原配置，以及在非活动状态删除节点。活动配置禁止直接编辑/删除，避免 UI 和运行隧道状态不一致。保存不依赖离线时不可用的隧道 validateConfig 消息；固定生成结构经输入校验及模型测试覆盖，应用时由核心处理配置。

4 项模型/界面测试通过，新增文件及入口静态检查无问题。验证端口、域名、令牌注入、JSON/YAML 转义、默认预填及空令牌不会创建或切换配置。Profile 签名构建成功，检查 App.framework 确认新页面已编入，codesign 深度校验通过。覆盖安装到当前 USB iPhone X（iOS 16.7.16），安装工具返回 InstallComplete，未卸载或清空数据。

手机上尚未输入服务端令牌，未自动切换配置；手机真实 VPN 传输仍待用户输入令牌后验证。此前用户提供的 Mac curl 返回结果已确认 zlhk.fastcat.ink:8443 到 example.com 的公网认证和转发成功。

## 2026-11-19：手机“未连接测速超时”排查

只读检查手机偏好，确认当前为 fastcat-https-test-v1、rule 模式，测试组与 GLOBAL 保存选择均指向测试节点。日志确认 PacketTunnel active 启动成功，物理接口就绪；本次抓取窗口多次 AppleProbe category=success，另有 DIRECT 探测 category=dns（不能算作新协议失败）。一次节点探测 category=success 后，应用报“连接已切换，丢弃旧测速结果”，属于切换保护取消过期结果，不是服务端认证或握手失败。

用户反馈连接 VPN 后延迟正常；随后再次断开 VPN、单独测速也正常。原先首次离线测速超时未在抓取窗口稳定复现，因此尚不能确定其根因；冷启动、DNS 或过渡状态仅为待验证假设。本轮未修改协议或放宽证书/认证检查，未重新安装。敏感原始设备日志及偏好仅存本机临时目录，不加入仓库；采集已停止。

## 2026-11-19：修复应用重启后 VPN 启动失败

设备日志明确记录 ClashCore_init code=5，错误 Saved proxy selection is unavailable。设备偏好显示当前配置被启动订阅导入替换为 URL profile，但 selectedMap 仍为 FastCat 测试/FastCat HTTPS 测试。根因是订阅导入无条件继承当前 profile 的 selectedMap，并自动激活新订阅；新增手动测试配置未与此流程隔离。

修复包括：活动本地测试配置阻止订阅导入替换；在导入提交点再次检查，以覆盖下载期间用户切入测试的情况；仅从 URL profile 继承订阅选择；普通配置传给 Go 和 iOS 启动消息前去除本地测试专有选择，保留其余选择的原有严格验证。启动迁移在检测到完整测试选择误带入活动 URL profile、且原测试 profile 仍存在时，恢复本地测试并清除泄漏选择；正常订阅不被替换，迁移具有幂等性。

使用实际设备偏好副本验证恢复及重复启动无变更；5 项隔离/迁移测试、3 项节点模型、1 项界面、2 项保留策略、1 项订阅导入阻断测试全部通过，涉及文件静态检查无问题。未改变 TLS、令牌认证或原生无效选择检查。

修复版已完成签名构建和覆盖安装（InstallComplete）。设备日志显示启动后订阅导入被本地测试保护拦截，新的 PacketTunnel 初始化及 active 启动成功；用户确认首次连接及退出重开后再次连接成功。脱敏前后对照见 restart-fix-device-evidence.txt。停止日志采集，并删除本轮下载的偏好副本和原始设备日志。

## 2026-11-19：Android USB 安装准备

当前连接设备为 arm64 Android 手机（型号 24129PN74C）。按项目 setup.dart 流程重建 arm64 Go 核心并检出 fastcat-https 标识；Android 手机设置页开放相同测试节点入口。入口静态检查通过。现有 com.fastcat.app 安装版本 code=2008，拟构建 code=2009 以覆盖升级。

本机 Java 26 与现有 Gradle 不兼容，已在本次构建环境单独使用 Java 17。Flutter mobile release 编译完成到 packageMobileRelease 阶段，但当前 android/local.properties 中的签名密码无法打开 android/app/keystore.jks，签名失败。没有卸载、覆盖安装或清空手机数据；等待本机正确签名配置后再继续。现有设备安装签名可用于后续匹配校验。
