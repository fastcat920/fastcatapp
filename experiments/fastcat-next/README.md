# FastCat Next 实验原型

FCN/1 不是 FastCat v2 的配置别名。它定义了 TLS exporter 绑定的 OPEN 消息、原生 QUIC 独立流/数据报和连接生命周期；H2 是备用 TCP 载体。标准密码算法与 QUIC 实现复用成熟依赖。

- [分阶段排队、恢复选路与首段冗余验收](queue-2026-11-23/REPORT.html)
- [尾延迟针对性优化与复测（合并发送未通过验收）](reply-2026-11-23/REPORT.html)
- [尾延迟原因排查与测量口径更正](cause-2026-11-22/REPORT.html)
- [首包等待调度优化与分阶段验收（未通过升级验收）](latency-2026-11-22/REPORT.html)
- [主连接优先实验与扩样对照（未通过升级验收）](primary-2026-11-22/REPORT.html)
- [Next QUIC 新调度与 TUIC 对照](adaptive-2026-11-22/REPORT.html)
- [Next QUIC 吞吐与双连接对照](throughput-2026-11-22/REPORT.html)
- [Next QUIC / TUIC 优化复测](quic-tuic-2026-11-22/REPORT.html)
- [实现优化 0.2](OPTIMIZATION-0.2.md)
- [优化后的八协议对照](optimization-2026-11-21/REPORT.md)
- [规范 0.1](SPEC-0.1.md)
- [本轮验收报告](acceptance-2026-11-21/REPORT.md)
- [可筛选数据表](acceptance-2026-11-21/DATA.html)
- 核心：`core/fastcatnext`
- 独立服务器：`core/tools/fastcat-next`
- 安卓功能检查：`core/tools/fastcat-next-check`
- 对照程序：`core/tools/fastcat-v3-compare`

服务器编译（在 FastCatAPP/core 中）：

```sh
GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o fastcat-next ./tools/fastcat-next
```

服务器用权限 600 的私有 JSON 配置启动：

```sh
./fastcat-next -config /path/to/private-config.json
```

配置结构如下，Secret 必须用密码学随机数生成 32 字节后编码成 64 位十六进制；账号不能使用真实登录密码代替随机密钥。证书应覆盖真实 ServerName。该进程同时占用 Listen 的 TCP 与 UDP。

```json
{
  "Listen": "0.0.0.0:19458",
  "Cert": "/path/to/fullchain.pem",
  "Key": "/path/to/privkey.pem",
  "Account": "isolated-test-account",
  "Secret": "REPLACE_WITH_64_HEX_RANDOM_CHARACTERS",
  "Congestion": "bbr",
  "IdleSeconds": 60
}
```

客户端需链接 `fastcatnext.NewClient`。载体参数为 `quic` 或 `h2`，TCP 使用 Dial，QUIC UDP 使用 DialPacket。必须传 RootCAs/有效证书域名、同账号与随机密钥。标准库根证书池在某些安卓独立程序环境不可用，所以测试程序显式载入 CA bundle。

这是可独立复现和测试的原型。当前没有正式 App 节点类型、面板配置、公开一键安装器、ECH 或自动选路发布。不能把原型实验 ALPN 当作普通 HTTP/3，不能把一次网络结果推广为抗识别结论。

## QUIC 受控优化试验

`Config.QUICProfile` 与 `ServerConfig.QUICProfile` 支持以下可选配置，空值仍保持原版行为：

| 值 | 改动 |
| --- | --- |
| `baseline` | 原 BBR、原接收窗口 |
| `wide` | 流最大 16 MiB、连接初始 6 MiB / 最大 64 MiB |
| `conservative` | BBR 初始拥塞窗口 16 包，保守启动配置 |
| `balanced` | 同时应用扩窗与保守启动 |
| `bbr-legacy` | 使用依赖库 `bbr_meta_v1` 实现，原接收窗口；不是自研 BBR |

`Config.CoalesceOpen=true` 可合并 OPEN 与最多 16 KiB 的第一段业务。Read / CloseWrite 会先发出 OPEN，支持服务端先发数据；不会重放已发送业务。默认关闭，不能把候选配置当作已通过所有网络验收的默认优化。

独立服务端可设置 `Trace=true`，客户端可提供 `Trace` 回调，记录连接级传输统计。详细追踪会产生开销，正式性能对照关闭。统计只包含计数和时间，不记录密码、业务载荷或 TLS 密钥。`declared_lost` 是 QUIC 丢失判定计数，不能直接当物理丢包率。

对照程序新增 `next-base` / `next-opt` 标签，后者使用私有配置的 `NextOptimizedAddress`、`NextOptimizedProfile`、`NextOptimizedCoalesce`。标签用于隔离试验，不代表新增公开协议版本。

## 可选双通道吞吐模式

`Config.QUICLanes=2` 仅用于 QUIC，按活跃 TCP 流数量把新流分配给两个独立连接池。串行请求优先走主通道；`Warm` 只准备主通道，第二个通道在并发时按需连接。已有流不迁移、不重放，UDP 关联仍交给主通道。

默认 0/1 保持单通道。双通道通常至多两条物理连接；每个池在 4096 次请求上限后的轮换保留既有业务时仍有最多两条物理连接，所以轮换期间总上限为四条。`Reset`、`Close` 和父上下文取消作用于两个池。增加连接意味着额外握手与资源，当前不默认开启，也未作锁屏或耗电验收。

对照程序的 `NextOptimizedConnections=2` 映射到该设置。`-download-workers 4` 运行四个共享客户端的单向下载任务，并保留逐流校验和整组有效吞吐。`tuic-dual` 仅为测试连接数相同的诊断标签，内部使用两个原样 TUIC 客户端，不是新增 TUIC 协议版本。

## 可选就绪优先与自适应调度

设置 `QUICLanes=2, AdaptiveLanes=true` 可启用新调度。普通 `Dial` 优先已有可用连接，不等待另一通道的握手；有并发时后台准备缺失通道，单次最多 1 秒、每通道每秒最多发起一次。显式 `Warm` 会先准备主通道，再等待有界的可选副通道准备，副通道失败不使已经成功的主通道失败。主次通道都支持对称恢复。

两个通道都就绪时，按活跃流数量、近期有效读写速率、正在进行的应用 Write 字节量和入口 RTT 作有界权重调整。速率样本空闲超过 3 秒失效，不把目标业务暂时无返回视作入口失效。Reset 会清空速率与新代计数、取消后台握手，旧流的关闭不会扣减新代计数。既有业务不迁移、不重放。

`AdaptiveLanes` 默认关闭；上轮 `QUICLanes=2` 的固定按活跃流分配行为仍可用。对照工具 `next-fixed` 是该旧模式，`next-opt` 使用 `NextOptimizedAdaptive=true` 的新模式，`next-base` 保持单通道。`-mixed-download-bytes` 可让两条后台下载与前台 HEAD 请求共享一个客户端；原始数据保留每条前台请求开始时的后台活跃数量。

可选传输追踪增加客户端进度采样（诊断版为每 250ms）、QUIC 包字节计数及服务端 QUIC 转发读写等待。包字节不含 UDP/IP 外层，丢失判定不等于物理丢包率。正式性能对照关闭追踪；开启追踪的诊断结果不能直接并入关闭追踪的性能样本。当前仍未声明单流偶发慢连接已经修复。

## 主连接优先实验（默认关闭）

`QUICLanes=2, AdaptiveLanes=true, PrimaryPreferred=true` 优先复用主连接，首批并发不强制分流，显式 Warm 只准备主连接。有后续新请求、主连接至少两条既有活跃流且存在持续读取时，才后台准备备用连接并允许有界试探。握手就绪本身不算容量证据。试探门限和实测资格在 `primary.go`，`LaneUsage()` 仅返回分配计数，不记录地址或载荷。

备用空闲回收、试探门限、证据过期和代际保护已通过本地检查。公网冷批分配确认保持 `[4,0]`，但十二轮共享服务及八轮受控测试未证明吞吐同时继承单连接优势，且出现慢轮次/预算耗尽。因此该实现只保留为研究选项，默认不启用，不能当作推荐升级配置。详细数据见上述实验报告。客户端和服务端认证、加密、FCN/1 线格式未修改。

对照工具增加 `next-primary`；`-download-jobs 12 -download-workers 4` 可运行共享客户端的滚动任务。`FASTCAT_LOCAL_PROFILE=1 go test ./fastcatnext -run TestLocalPrimarySamplerCost -v` 只做本地回环开销诊断，不能替代公网验收。

## 首包等待评分与通道准入实验（默认关闭）

本轮实现及分阶段数据见 [调度优化验收报告](latency-2026-11-22/REPORT.html)。先测试记录与评分，再因未达到预定门槛继续测试准入偏好和滞后；两阶段分别保留同期原调度，不合并时段不同的吞吐数据。

- `QUICLanes=2, AdaptiveLanes=true, LatencyAware=true`：新流按 RTT、近期建立/首次读取等待、活跃/等待首包/已读取超过 256 KiB 的流数及待写量评分。等待证据有上界并在 10 秒后失效，不再把大流速率高作为新业务的容量优惠。与 `PrimaryPreferred` 互斥。
- 额外设置 `ReserveInteractive=true, ScheduleHysteresis=true`：至多将最初两条并发、未首读且路径相近的未知业务在 250ms 窗口内放到同一通道，给后来工作留下另一条通道；已有大流时优先选择健康的轻载通道。轻微评分变化使用最多 200ms 滞后，连续分配达到三次且另一通道足够接近时允许其承接。该策略不是按业务内容识别，也不保证专属带宽。两个新增开关均要求 `LatencyAware=true`。
- `LaneTrace`：独立的轻量回调，不开启逐包 QUIC 追踪。包含客户端内请求编号、代际、选择时两通道状态及建立/关闭事件；不含目标、凭证、载荷或 QUIC 连接标识。回调可能并发调用，接入方应安全处理并避免阻塞。`LaneObservation()` 用于在请求记录中关联选中通道、首读等待与字节计数。第二阶段另有最近完成观察窗口的收发字节及窗口时长。`lane_select` 是选择前置事件，不能把其默认 `ok=false` 当成拨号失败；拨号结果看 `lane_entry`。`lane_close.duration_us` 表示首次读取等待，并非流寿命。

对照标签 `next-latency` 和 `next-reserve` 分别映射上述两种策略，`next-opt` 保持原调度。`-lane-diagnostics` 开启轻量记录；与开销更高的 `-trace-next` 分开。即使诊断关闭，显式启用新策略仍会收集其评分所需的有界计数。

本轮两种候选均未同时达到「带载前台 P95 至少降低 20%、四路和滚动总体有效吞吐至少保留 90%、完成率不降低」的门槛，**不替换原调度、不默认启用**。慢请求已能拆分到目标 TLS/响应等待，但不能据此独自确定底层拥塞或丢包原因。既有业务不迁移、不自动重放，认证、加密和 FCN/1 线格式不变。


## OPEN确认与传输恢复诊断

旧对照的 `entry_us` 仅测到 Dial 返回；QUIC 的 OPEN 状态读取发生在首次 Read，旧 `target_tls_us` 会包含这段等待。因此不能据旧阶段列直接排除入口等待。端到端首字节及吞吐数据不因此失效。详细更正和包号证据见上述尾延迟排查报告。

开启 `Trace` 后，`TransportObservation()` 记录状态读取起止、首个有效载荷读取、传输计数和客户端内会话编号；`LaneObservation` 不代替这份状态。独立服务器和客户端的 `PrefixTrace` / 对照工具 `-trace-prefix` 可进一步记录每流前8KiB的帧偏移、长度和包号，并标记相关发送判丢与PTO。只记录元数据：不含载荷、密钥、实际OPEN随机nonce、目标或QUIC连接ID。两端通过随机nonce的一向哈希关联请求。

元数据每连接最多8192条，发送包号表最多4096项；达到上界增加 `meta_dropped`，不应把截断后的缺失记录解释为没有收到数据。记录有额外开销，只用于诊断，不并入关闭追踪的性能验收。服务端目标拨号与ACK入发送队列分别记录，ACK排队完成不代表客户端已经收到。

本轮已观察到确认字节所在流头部恢复前，后续TLS片段已到达却无法按序读出的样本。该证据定位了具体恢复等待机制，但没有确定底层未及时到达的链路位置，也不代表所有尾延迟都来自同一种原因。未发布确认合并或重传策略优化；原调度和业务线格式保持不变。


## 成功标记合并与网络诊断实验（2026-11-23）

`ServerConfig.ReplyCoalesceDelay` / 独立服务端 JSON `ReplyCoalesceMillis` 默认为 0，立即发送成功标记。非零值上限 10ms，实验值 5ms：在首段目标数据到达时合并状态与数据，否则定时器刷新状态；EOF 也刷新，兼容先等状态再发数据的旧客户端。业务计数排除状态字节，认证与目标失败路径保持原行为。当前机制测试减少了独立首帧，但关闭追踪的性能轮未通过尾延迟与完成率门槛，**不应默认启用**。完整数值和失败轮见报告。

独立服务端的 `DisableGSO`、`DisableECN` 只作用于该进程；`FixedPacketSize=0` 保留 PMTU 默认值，诊断非零允许 1200–1452，仅固定服务端 QUIC 包长。它们都不是已验收的通用加速选项。

`LocalUDPPort` / 对照工具 `-next-local-port` 仅用于短时诊断，默认 0；双通道依次占用指定端口和下一端口。固定端口会限制旧连接尚未关闭时的轮换，不能作为生产配置。`warm-only` 工作负载跳过冷启动，仍有 prime 与 batch 记录，统计时分别过滤。

服务端 `TracePeerSalt` 可传入仅本轮使用的 32 字节随机盐（JSON 为十六进制），用于输出对端地址的 HMAC 摘要，核对 NAT 映射是否一致；不记录原始地址，盐留在私有配置并随实验删除。无盐不输出此字段。ECN 状态、标记和 packet-dropped 原因仅在诊断中使用；旧 Initial/Handshake 密钥不可用不能直接解释为业务包解密失败。


## 2026-11-23 分阶段排队 / 恢复选路 / 首段冗余实验

完整计划、每阶段同期对照、失败结果与补充测试见上述分阶段报告。以下均为原型库 / 独立对照工具选项，尚未接入正式 App 或订阅；默认关闭。

- 服务端 `DownstreamBudget=true`：新流与已发送至少256KiB的大流共存时，共享16KiB/2ms的组包预算；新流预留最多500ms，独占下载不节流。写入同时按16KiB切分。调用依赖已有的 QUIC `WriteWithLimit`，回调不阻塞、不调用QUIC方法；重传不重复扣减。第2项实验改善带载延迟，但滚动吞吐只保留约83%，未启用。
- 客户端 `RecoveryAware=true`：要求 `QUICLanes=2, AdaptiveLanes=true`，与 `PrimaryPreferred` / `LatencyAware` 互斥。按本端新增发包判丢和入口RTT膨胀，短时避开恢复中的通道；信号300–1000ms过期，恢复触发的额外切换至少间隔500ms。两边都不佳时保留原选择。Reset 清空恢复代际，既有流不迁移、不自动重放。没有直接引入对端下行恢复反馈，不代表完整双向健康控制。独立工具私有配置 `NextRecoveryAware` 映射该选项。
- 双端 `PrefixRedundancy=true`：仅支持QUIC，显式Kind2请求，已有exporter HMAC覆盖kind。可靠流不变，额外用加密DATAGRAM发送至多1字节状态+8KiB业务首段，最多12次尝试。客户端有序去重并验证重叠一致性，可靠流追上后回到普通Read。不支持时报错、不降级重发。与服务端确认合并 / 写入预算互斥。独立工具 `NextPrefixRedundancy` 映射客户端选项。第4项为第3项之上的增量对照，未达到带载尾延迟门槛，保留默认关闭。扩展格式和内存/计量边界见 `queue-2026-11-23/PREFIX-EXTENSION.txt`。

诊断记录新增目标首读就绪、首写接受及有界慢读写事件。首读等待可能包含客户端数据仍在途中，不能全部算目标处理；`PacketSent`不是网卡实发证明。`-transport-snapshots` 只读请求边界计数，不开启逐包追踪；前者可与正式对照两边一致启用。`LaneUsage` 的 live wire 字节是当前仍登记物理会话的快照，包含QUIC开销和重传，不含UDP/IP；跨移除/Reset不是累计总量，测试在Close前读取。

`-mixed-foreground-target host:port` 允许前台外部HEAD与固定本地后台下载共享客户端；两类目标应各自使用匹配证书的主机名。远端补充组首次IP/SAN配置失配的数据单独保留并排除，随后以证书对应域名重跑。

第3项通过本轮既定主门槛和有效远端不回退检查；主轮冷启动P95退化数据保留，追加固定本地端口各48次复核未复现大幅差异。只保留为安卓Wi‑Fi实验候选，不自动更改正式App/服务器默认配置，其他网络、iOS、锁屏及耗电尚未作为本轮验收范围。
