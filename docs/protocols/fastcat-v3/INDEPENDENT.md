# FastCat v3 independent-stream profile 0.1

状态：实验草案及独立原型。与原v3单承载多路复用profile不互通；不替换生产入口。
本profile仅定义TCP业务，支持H2、H3。UDP、正式App/面板、入口DoH/ECH、自动重连和会话续期不在当前实现内。
透明四层转发可保留原TLS连接；TLS终止反代未实现。

## 1. 目标与承载

复用v2的每业务独立HTTP流结构，使用v3的Noise IK身份验证及TLS exporter绑定。
H3业务处于不同QUIC流；H2业务处于不同HTTP流，但共享TCP的丢包等待仍然存在。
并发业务不共享内层记录锁或内层WINDOW_UPDATE。底层HTTP/QUIC负责流控。

所有入口校验证书、域名和TLS1.3，不接受HTTP/QUIC 0-RTT。不得自动重放业务数据。
路径：POST /fc-independent/1/auth、POST /fc-independent/1/flow。
Content-Type=application/octet-stream，无Content-Encoding、重定向或缓存。
X-Fastcat-Mode取light或sealed。两模式必须显式选择，失败不得自动降为light。
HTTP 200只表示双向承载已准备，不代表认证或目标OPEN成功。

外层TLS/QUIC和常规HTTPS仍可能具有可观察指纹。新profile不声称已经证明更难识别。

## 2. 一次认证

客户端为一个物理TLS连接打开auth流，使用原v3的prologue、Noise IK、CLIENT_CONFIRM和
record格式。carrier仍取1=H2、2=H3。除ServiceID域分离外，握手消息格式不变。

mode byte：0=light，1=sealed。新增2=light-fast实验扩展见 [PIPELINED.md](PIPELINED.md)，以下READY流程仍描述原模式0/1。
握手中实际ServiceID为：

    SHA256(ASCII("FastCat independent/v1/") || mode:u8 || configured_service_id:16)[0:16]

这将新profile与原v3、light与sealed的Noise握手域分离。
TLS binding为当前物理连接的ExportKeyingMaterial("EXPORTER-FastCat-v3", nil, 32)。
客户端必须确认服务端静态公钥；服务端必须验证账号凭证、握手重放与CLIENT_CONFIRM。
不得在确认前拨目标。复用认证不意味着省略服务端身份校验。

设Noise split得到客户端方向seed A、服务端方向seed B，ctx为原v3记录上下文：

    C = HKDF-Extract(ctx, A)
    S = HKDF-Extract(ctx, B)
    session_root = HKDF-Expand(
        HKDF-Extract(ctx, C || S), "FastCat independent/v1/session", 32)

HKDF使用HMAC-SHA256，与原v3 helper及公开参考向量一致，不附加隐含NUL。
服务端产生随机16字节session_id，写入一条加密READY记录：

    frame kind=15, stream_id=0
    body = session_id:16 || ttl_seconds:u32 || mode:u8

当前ttl固定600秒。客户端只接受1..600秒。auth流保持打开，后续不发送业务数据。
auth流关闭、收到额外数据、TTL到期或认证连接丢失时，会话失效，活动业务必须终止。
该TTL不是跨连接恢复票据；替换TLS连接必须重新执行认证。

客户端可保留少量已认证入口；当前原型不实现自动重连。QUIC空闲超时也可能先于TTL。

## 3. 每业务独立流

客户端在同一HTTP transport/物理TLS连接打开flow流，先发送：

| 字段 | 类型 |
|---|---|
| magic | ASCII FCI1，4字节 |
| session_id | 16字节 |
| counter | u64，1..4096 |
| mode | u8 |
| target_length | u16，1..512 |
| target | UTF-8/ASCII host:decimal_port，target_length字节 |
| proof | 32字节 |

整数均为网络字节序。端口必须为1..65535；IPv6使用方括号。当前目标DNS使用系统解析器，
校验全部解析地址后按固定地址拨号，默认拒绝私网、回环和其他受限目标。
证明算法：

    proof = HMAC-SHA256(session_root,
        ASCII("FastCat independent/v1/flow") || preceding_prefix || tls_binding)

preceding_prefix为magic至target全部字节，不含proof。
服务端先验证会话存在、有效期、模式、当前TLS exporter一致、证明和counter未使用，
然后保留counter，最后拨目标。一次拨号失败也不能重用counter。

不同业务流允许乱序到达，不能仅要求counter大于上一次值。服务端保存已用counter集合，
上限4096；每会话最多128活动业务；每实例最多64认证会话、256并发HTTP请求。
超过限制必须报错或显式重新认证，不得放宽重放检查。认证流本身也占HTTP并发。

H2客户端限制每入口最多一条物理连接，auth流保持活跃；H3使用相同transport连接池。
两种承载都再次比较响应TLS exporter。新TLS连接不能携带旧证明继续用；客户端必须
使旧会话失效并重新认证。当前原型报告需重新认证，不自动重放请求。

## 4. light模式

服务端拨号结果为2字节：00 00成功、00 01失败。在成功结果之前不能发送业务数据。
业务仍使用最小DATA/FIN封装，完整性和保密性依靠外层TLS，避免把HTTP流异常截断当作正常FIN。

    kind:u8 || payload_length:u16 || offset:u64 || payload

DATA kind=4，payload_length=1..16346，offset必须等于该方向已收到业务字节数。
FIN kind=7，length=0，offset为该方向最终业务字节数。FIN后该方向不得再发送DATA。
每方向offset从0开始。发送端可先FIN，另一方向仍可继续传输。无FIN遇到EOF必须报截断错误。
没有额外内层AEAD、流控额度或全会话记录计数器。

## 5. sealed模式

为每条业务独立派生上下文和两个方向的种子：

    stream_ctx = SHA256(ASCII("FastCat independent/v1/stream") || preceding_prefix || tls_binding)
    traffic_seeds = HKDF-Expand(
        HKDF-Extract(stream_ctx, session_root), "FastCat independent/v1/traffic", 64)

前32字节为客户端发送种子，后32字节为服务端发送种子，分别送入原v3 newRecord。
原记录层仍先以stream_ctx对种子执行HKDF-Extract，再派生ChaCha20-Poly1305密钥和IV。
记录AAD、nonce、epoch与KEY_UPDATE规则沿用原v3；方向0=客户端、1=服务端。
所有计数器、密钥更新和写锁仅属于这一条业务流。

服务端首先发送加密OPEN_RESULT(kind=3，stream_id=counter，body为2字节状态)。
成功后的DATA(kind=4)及FIN(kind=7)均使用原v3记录格式，stream_id=counter。
DATA body=offset:u64 || 1..16346字节数据；FIN body=最终offset:u64。
没有WINDOW_UPDATE；底层HTTP/QUIC流控是唯一传输额度。KEY_UPDATE(kind=11)单独成记录。
EOF前必须收到有效FIN，标签错误、offset不连续或错误stream_id均终止该业务。

独立counter、session_id、target、TLS binding和模式共同隔离派生上下文。
当前mode也通过握手的域分离ServiceID进入session_root，不能静默降级。

## 6. 资源、失败与实现限制

认证及前缀阶段8秒超时，目标拨号5秒。取消一条业务仅取消该HTTP流，不能关闭同一入口的其他流。
auth流丢失则取消整个会话。失败后的业务数据不重放。

light与sealed均为独立测试入口，尚无账号动态更新、客户端版本灰度或正式订阅支持。
net.Conn截止时间当前实现为取消整条业务流；读写截止时间尚未分离，不可将其当完整生产net.Conn语义。
完整TTL、跨网、耗电及长期故障恢复尚需验收。未实施专用抗识别填充。

参考：independent_vectors.py生成公开测试材料；independent_vectors.json及Go测试核对
会话根、flow证明与两方向流密钥。测试材料不能用作部署凭证。
