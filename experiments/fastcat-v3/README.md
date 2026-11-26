# FastCat v3 独立原型

本原型实现规范 0.2 的标准承载子集。代码在 `core/fastcatv3`，命令行入口在
`core/tools/fastcat-v3`。它使用原创会话及帧格式，通过 H2/H3 双向 POST 承载。
Noise IK 负责身份与握手，加密记录使用独立派生的 ChaCha20-Poly1305 密钥。

## 已实现

- Noise IK 的逐字节握手与规范测试向量一致，TLS exporter 绑定。
- 不透明固定账号凭证验证，握手防重放，服务端静态公钥固定验证。
- 双向加密记录、帧解析、严格序号、双向独立密钥代次。
- 单个会话复用 TCP 流，单流及会话流控，目标域名与 IP 校验。
- 半关闭、取消、错误流终止及取消后的流控额度回收。
- 固定目标 UDP 关联、最大 1024 字节数据报、序号去重与队列数量上限。
- H2/H3 标准承载，同一个监听端口同时提供 TCP 与 UDP 服务。
- 本地 HTTP CONNECT 代理，独立真实 HTTPS 请求与 UDP 回包探针。
- 会话 30 秒空闲超时、8 秒握手截止、64 个服务端承载上限和128条活动流上限。

## 本轮范围

这是可独立测试的原型，尚未接入快猫 UI、VPN 核心适配器、面板或自动订阅。
认证使用私有 JSON 文件内的单账号测试凭证。恢复票据为空，会话恢复关闭。
参数暂固定为规范默认值，客户端会拒绝其他参数。每个会话最多保留4096条流状态，
达到上限后应由调用方重建会话。

原生 UDP 的 ACK/拥塞/重传承载尚未实现。当前 DATAGRAM 帧通过可靠的 H2/H3
请求流传输，可以验证协议和目标 UDP 收发，但会受到承载流重传与队头阻塞影响。
多优先级调度、数据报队列100ms时限、GOAWAY优雅排空、账号撤销和面板计量尚待实现。
流级 deadline 用于等待数据与流控额度，底层阻塞写入仍由会话/承载超时约束。

H2/H3 是基础承载，原型握手属于 Noise IK 的应用。未声称原创密码算法、通过
外部安全审查，或具备已验证的抗识别效果。此版本没有接入 ECH，先验证 v3 自身。

## 构建与本地测试

在项目 `core` 目录执行，需要 Go 1.26 或更新版本。

```sh
go test -race ./fastcatv3
go build -trimpath -o fastcat-v3 ./tools/fastcat-v3
./fastcat-v3 init -dir /tmp/my-fastcat-v3
```

`init` 创建权限0700的新目录，生成权限0600的 `server.json` 和 `client.json`。
账号凭证和服务端私钥属于秘密。客户端配置不含服务端私钥。不要公开这些文件。

使用已有、受信的域名证书启动测试服务。

```sh
./fastcat-v3 serve \
  -config /tmp/my-fastcat-v3/server.json \
  -listen 0.0.0.0:19443 \
  -cert /path/to/fullchain.pem \
  -key /path/to/privkey.pem
```

在客户端运行探针，分别选择 `h2` 或 `h3`。

```sh
./fastcat-v3 probe \
  -config /private/client.json \
  -endpoint SERVER_IP:19443 \
  -server-name your-domain.example \
  -carrier h3 -samples 3
```

探针会在同一会话执行顺序网页请求、密钥更新后的请求及4个并发请求。
如果有独立 UDP echo 服务，增加 `-udp-target IP:PORT` 验证 UDP 回包。
`-debug` 输出阶段名，不输出凭证或密钥。

使用本地 HTTP CONNECT 入口访问网站。

```sh
./fastcat-v3 client \
  -config /private/client.json \
  -endpoint SERVER_IP:19443 \
  -server-name your-domain.example \
  -carrier h3 -proxy-listen 127.0.0.1:18083

curl --proxy http://127.0.0.1:18083 --noproxy '' -I https://example.com/
```

本地代理只接受loopback监听。此原型的会话失败后需要重新运行命令，尚无自动重连。

## 安卓独立程序

```sh
GOOS=linux GOARCH=arm64 CGO_ENABLED=0 \
  go build -trimpath -o fastcat-v3-android-arm64 ./tools/fastcat-v3
```

通过 ADB 将程序、私有客户端配置与可信 CA bundle 放进手机专用测试目录，目录
权限0700、凭证0600。运行程序时提供 `-ca /private/path/ca.pem`。静态独立程序
无法直接使用安卓系统的 Java DNS 与 CA 接口，因此本轮显式使用入口 IP 和
`-server-name`，并导入公共 CA bundle。集成 App 时应复用平台解析及证书能力。

## 测试覆盖

- Python规范向量与本原型Go握手、密钥、密文一致。
- 错误标签、方向、绑定、账号凭证、公钥及证书被拒绝。
- 重放CLIENT_INIT被拒绝，不同TLS exporter无法通过确认。
- 每种承载8条并发流，各600000字节，总4.8MB，验证流控与半关闭。
- 24条流各写256KiB后取消，随后仍能开新流收发，防止额度泄漏。
- UDP空报文、8字节、1024字节回包及超长拒绝。
- 私网目标策略通过普通OPEN入口验证。

公网使用隔离端口19443，UDP echo仅监听服务端loopback19444，测试期间显式
设置 `-allow-private-targets`。该开关只用于隔离测试，默认会阻止私网和元数据地址。
验收后关闭临时服务并删除凭证，现有 v2 节点保持原配置。

## 规范勘误

原向量生成器曾将 max_datagram 写为1200，超过规范1024上限。实现时已更正
客户端和服务端载荷并重新生成全部向量。它不修改线上v2，也不影响未部署的v3
互通版本。握手长度和派生结果以当前 `docs/protocols/fastcat-v3/vectors.json` 为准。

## 2026-11-21 性能优化

认证首包随 HTTP 请求 body 发送，避免等待响应头后才开始 Noise 握手。
确认消息仍绑定当前 TLS 会话，不使用 0-RTT 或自动业务重放。
流控批量补充曾进行公网试验，但 H2 结果不理想，最终未保留。

优化后公网对照见 [完整记录](V2-V3-OPTIMIZED-COMPARISON-2026-11-21.md)。当前结果不支持用v3替换v2。

## 控制记录合并优化

相邻的单流和会话 WINDOW_UPDATE 可以合并为一条加密记录。
额度通知立即唤醒后台发送器，不依赖定时器或累计阈值；业务读取不等待反向写入。
每个流仅保留最新绝对额度，发送批次最多64条，保持线格式兼容。取消连接归还的额度
也走该队列，RESET 保持原有发送路径。记录总长检查、密钥更新
独立记录和 nonce 连续性已有回归覆盖。`-debug` 可记录发送等待及目标解析/连接耗时，
不记录账号令牌、密钥或目标域名。默认关闭诊断日志。

控制记录与非阻塞读取的最新结果见 [对照报告](V2-V3-CREDIT-QUEUE-COMPARISON-2026-11-21.md)。公网结果仍不支持用v3替代v2。

发送阶段的分段日志和复核结果见 [诊断报告](V3-SPLIT-DIAGNOSIS-2026-11-21.md)。

## 独立业务流融合原型

新增 `fastcatv3.DialIndependent` / `NewIndependentServer` / `ServeIndependent`。
每条TCP业务使用独立H2/H3流；同一TLS连接先完成一次Noise认证，后续业务使用绑定该连接
的短证明。支持 `IndependentLight`（TLS保护加最小DATA/FIN封装）和
`IndependentSealed`（每流独立ChaCha20-Poly1305记录）。不是原v3单承载分流模式。

使用既有init生成的私有配置，在独立端口启动：

```sh
./fastcat-v3 serve -profile independent \
  -config /private/server.json -listen 0.0.0.0:19443 \
  -cert /path/to/fullchain.pem -key /path/to/privkey.pem
```

对照程序的私有JSON沿用 `V2Address`、`ServerName`、`V2Token`、`V3`、`CA`，
新增 `IndependentAddress` 指向新入口。`V3`仍是init生成的客户端Config，不含服务端私钥。
配置文件保持0600，不公开凭证。运行：

```sh
./fastcat-v3-compare -config /private/comparison.json \
  -versions v2,v3-light,v3-sealed -samples 20 -batches 5 -workers 4
```

当前原型仅TCP，未接入正式App、面板和UDP，未包含入口DoH/ECH及自动重连。
透明TCP/UDP四层前置可保留TLS绑定；TLS终止反代不在此profile支持范围。
读写截止时间目前共同取消整条业务，尚不是完整的独立读写截止时间实现。
线格式、HKDF参考向量、重放及生命周期约束见
[协议草案](../../docs/protocols/fastcat-v3/INDEPENDENT.md)。

两轮安卓三组对照见 [融合原型验收报告](INDEPENDENT-RESULTS-2026-11-21.md)。

## 轻量版写入与H2首响应优化

轻量DATA帧按流复用读写缓冲区和读取头部存储，达到当前帧大小后不再逐帧分配。
H2服务端不预先单独Flush空响应头，响应头与SERVER_ACCEPT或OPEN_RESULT一起发送；
客户端认证前缀仍预先随请求体发送。格式、证明、FIN、重放及跨TLS绑定规则不变。

新增回归测试核对不同大小帧与7字节分段读取，以及H2认证只显式刷新ACCEPT/READY两次。
基准 `BenchmarkIndependentLightWrite` 仅衡量本地封装，不代表网络吞吐或网页耗时。

对照程序新增 `client_ready_us`：冷启动构造客户端完成时间。对轻量版它包含外层建连及
Noise/READY；v2为惰性建连，该字段只含构造，不能直接当作v2认证时长。
原有entry_us仍累计到目标OPEN完成。

`-pools 3` 可为每个版本/承载建立三条独立连接，复用采样轮换连接；同一批四路并发仍
使用同一个连接。此选项用于检查单连接状态对结果的影响，不是App的自动连接池实现。

轻量版局部开销优化及两轮安卓复测见 [验收报告](LIGHT-OPTIMIZATION-RESULTS-2026-11-21.md)。

## 并行确认轻量模式（实验）

新增 `IndependentPipelined` / `X-Fastcat-Mode: light-fast`，对照标识`v3-light-fast`。
客户端从验证过的SERVER_ACCEPT取得会话ID并发送CLIENT_CONFIRM后即可发独立OPEN；
服务端发布有界临时会话并验证OPEN证明，只有确认门通过才拨目标，不再发送READY。
模式2使用FCI2加密目标地址，并认证OPEN_RESULT；客户端验证该回执后才返回业务连接。
原light及sealed保留，用于兼容和对照；格式与安全边界见
[扩展草案](../../docs/protocols/fastcat-v3/PIPELINED.md)。

```sh
./fastcat-v3-compare -config /private/comparison.json \
  -versions v2,v3-light,v3-light-fast -pools 3 -samples 20 -batches 5 -workers 4
```

新模式`client_ready_us`止于客户端确认提交，不含服务端确认回执；`entry_us`仍累计到
服务端确认、目标拨号和OPEN_RESULT完成，首字节也覆盖完整业务建立过程。

并行确认版的最终三组对照见 [验收报告](PIPELINED-RESULTS-2026-11-21.md)。

三协议安卓同网复测（含原始v3失败及空闲问题）见 [完整报告](THREE-PROTOCOL-COMPARISON-2026-11-21.md)。
