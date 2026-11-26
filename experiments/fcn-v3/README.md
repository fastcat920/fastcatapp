# FCN v3 独立原型

客户端和服务端位于 `core/fcnv3`。这个版本使用真实 HTTP/3，普通 GET 和经过授权的 TCP CONNECT 共用入口。每个目标占一条 QUIC 流。已完成且验证证书的 TLS 连接允许发送 CONNECT 头及最多 8 KiB 首段。服务端验证授权并拨通目标后才转发这些数据。连接失败直接上报，不重放业务。

线上凭证格式为 `Proxy-Authorization: FCN3 <account>.<proof>`。proof 是无填充 base64url 编码的 HMAC-SHA256。MAC 输入依序为 UTF-8 `FCN3\x00CONNECT\x00`，32 字节 TLS exporter，8 字节大端 QUIC stream ID，1 字节账号长度及账号字节，1 字节目标长度及规范化目标字节。TLS exporter 标签为 `EXPORTER-FCN-v3-CONNECT`，context 为空。账号允许 1–48 个 ASCII 字母、数字、短横线和下划线。secret 为 32 字节随机值的十六进制编码。认证不依赖系统时钟，持有证明无法将其用于其它连接、目标或流。

在 `core` 模块目录使用已更新安全补丁的 Go 工具链：

```sh
go test -race ./fcnv3 ./tools/fcn-v3-compare ./tools/fcn-v3-server
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -o ../experiments/fcn-v3/artifacts/fcn-v3-server-linux-amd64 ./tools/fcn-v3-server
```

运行服务端时提供 `-listen`、`-cert`、`-key`、`-credentials-file` 及一个或多个 `-target IP:端口`。凭证文件是进程用户所有的普通 0600 文件。JSON 使用 `revision` 正整数和 `credentials` 数组，元素包含 `id` 和 `secret`。发布更高版本时原子替换文件并发送 SIGHUP。删除或更改条目会关闭该凭证的活动隧道。空数组撤销全部凭证。无效更新保留内存中的有效版本，版本检查适用于本次进程生命周期。

当前最多 64 条已接入 QUIC 连接、128 个全局授权隧道、32 个显式目标，隧道最多 5 分钟。该入口用来验证原型，面向公网生产前还需要完善规模化容量限制与审计。

`core/tools/fcn-v3-compare` 提供统一的 FCN v3/TUIC 测试程序。通过 `-help` 查看冷启动、连续请求、并发、下载和上传的选项。分析脚本读取测试计划和每批 JSONL。本轮版本、口径与结果见 [第一阶段验收](REPORT.md)。

第二阶段使用 `Client.Warm(ctx)` 按需准备一条 QUIC 连接。测量工具的 `-preconnect` 单独输出 `preconnect_ms`。按需建立仍是默认。

配置 `fcnv3.entry_doh` 可启用严格 ECH。设置 `url` 为专用 HTTPS DoH URL，`bootstrap_ip` 为已知的数值 IP。服务器应提供入口名的 HTTPS 记录和 A 或 AAAA 记录。配置中的 `server_name` 是内层名称，`endpoint` 提供 QUIC 端口，实际 IP 来自 DoH。客户端只在 ECH 接受后发出 CONNECT。拒绝时最多刷新一次，复用原连接的业务继续使用其已建立的 TLS 状态。

服务器以 `-ech-keys-file` 读入私有 `ECH KEYS` PEM。证书应同时覆盖实际服务名和 ECH 公共名，或者通过 `-ech-public-cert` 与 `-ech-public-key` 配置单独的外层证书。轮换时先让服务端同时接受新旧密钥，再让 DoH 返回新配置。等待旧记录的 TTL 到期后退役旧密钥。文件以原子替换加 SIGHUP 更新。详见 [优化复测与 ECH 验收](PHASE2-REPORT.md)。

第三阶段在服务端提供独立的 `-adaptive-writes` 和 `-limited-padding` 开关，默认关闭。普通写入使用 64 KiB 转发缓冲。有限填充作用于 TCP 的首个小下行 DATA 帧，每个 QUIC 连接最多增加 512 B HTTP/3 保留帧。详见 [写入与填充报告](PHASE3-REPORT.md)。

第四阶段可用 `-udp-target 数字IP:端口` 单独授权 UDP，客户端设置 `Config.EnableUDP` 后通过 `DialUDP` 创建关联。数据报最大 1150 B，服务端空闲超时默认 30 秒，可显式设置 `-udp-idle-timeout`。调用方先通过 `Client.UpdateNetwork(id)` 注册默认网络，再通知变更，新的业务会使用新连接。详见 [UDP 与切网报告](PHASE4-REPORT.md)。
