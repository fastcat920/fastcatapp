# 独立流轻量版：并行确认扩展 0.1

状态：实验扩展，mode=2，HTTP头X-Fastcat-Mode=light-fast。
原light(mode=0)和sealed(mode=1)继续保留，不自动降级或隐式切换。
端点沿用INDEPENDENT.md；mode=2改用FCI2前缀，原mode=0/1仍用FCI1。
mode字节进入握手域分离和流上下文，不兼容未补强的早期试跑格式。

## 目的

原light路径：SERVER_ACCEPT → CLIENT_CONFIRM → READY → 独立流OPEN。
新路径：SERVER_ACCEPT → CLIENT_CONFIRM与独立流OPEN并行 → 服务端确认后OPEN_RESULT。
客户端不等待额外READY，争取省去一个网络往返；它不是TLS/QUIC 0-RTT。
业务数据仍必须等OPEN_RESULT成功后才发送，不自动重放。

## 会话标识与派生

使用原SERVER_ACCEPT加密payload内的16字节session_id，不再另生成一个READY会话ID。
客户端先验证服务端静态公钥、SERVER_ACCEPT状态与参数，再取得该ID并写CLIENT_CONFIRM。
会话根派生、TLS exporter绑定及轻量DATA/FIN格式沿用独立流profile。
OPEN的目标改为会话密钥加密，成功回执也必须经会话密钥认证，详见下节。
mode=2参与effective_service_id的SHA256输入，从而与mode=0/1的Noise及会话根域分离。
TTL固定600秒、counter范围1..4096、其他资源上限保持不变。该模式不发送READY记录。

## OPEN保密与回执认证

先收到SERVER_ACCEPT不等于已经确认TLS通道绑定。因此mode=2不能在此时发送明文目标，
也不能仅凭外层TLS中的裸00 00回执就向业务暴露可写连接。

mode=2请求为：

    magic="FCI2":4 || session_id:16 || counter:u64 || mode=2:u8 || target_length:u16 || ciphertext

前31字节为header，target_length是目标明文长度1..512。ciphertext为目标地址及16字节标签。

    open_key = HKDF-Expand(session_root, "FastCat independent/v1/fast-open", 32)
    nonce = 00000000 || counter:u64_be
    AAD = header || tls_binding
    ciphertext = ChaCha20-Poly1305.Seal(open_key, nonce, target, AAD)

counter只能在同一会话内使用一次。服务端验证TLS绑定并成功解密、检查目标格式后，才保留counter。
密文标签同时证明发送者知道会话根，不再附原FCI1的32字节HMAC。
公开的session_id、counter及长度仍在外层TLS内；这不是长度隐藏或填充方案。

OPEN_RESULT（目标成功或失败）为2字节status加32字节HMAC：

    ack_key = HKDF-Expand(session_root, "FastCat independent/v1/fast-ack", 32)
    tag = HMAC-SHA256(ack_key,
        ASCII("FastCat independent/v1/OPEN_RESULT") || complete_open_prefix || tls_binding || status)

客户端必须验证完整34字节回执的标签及成功状态后才返回业务net.Conn。
MAC绑定完整请求密文、counter、会话及TLS，不能跨请求重放，也不能降为裸2字节回执。
这在去掉READY等待的同时保留了发送业务明文之前的服务端密钥/通道绑定确认。
后续业务仍是轻量DATA/FIN，由已确认的TLS通道保护，不是全程内层AEAD模式。

公开参考向量由pipelined_vectors.py使用Python cryptography生成，Go测试核对密文、
回执及域分离；包含目标篡改、绑定替换及伪造回执拒绝测试。测试材料不是部署密钥。

## 服务端临时状态

在账号凭证与握手重放检查通过、已生成SERVER_ACCEPT及派生记录密钥后，服务端：

1. 在发送SERVER_ACCEPT之前注册provisional会话，包含root、session_id、当前TLS binding、
   mode、有效期、已用counter集合及一个尚未打开的确认门。
2. 有效OPEN可查到该状态，但必须先校验当前TLS binding、模式、目标密文的AEAD标签、有效期和唯一counter。
3. 验证通过后立即保留counter，计入活动请求上限；等待确认门。重复counter立即拒绝。
4. 只有原握手的CLIENT_CONFIRM通过记录AEAD、frame种类、stream_id和handshake hash检查后，
   才打开确认门。确认门缺失必须拒绝，不能按“已确认”处理。
5. 确认门打开后再次检查取消/有效期，随后才执行目标DNS、拨号和OPEN_RESULT。

这是独立流mode=2对“允许接收OPEN”的明确扩展；原v3及其他模式的时序规则不变。
收到一个有效OPEN密文证明本身不等于允许拨目标，不得用它替代CLIENT_CONFIRM检查。

## 失败、时限和资源

无效确认、认证流取消、断连、过期或握手错误：移除临时状态、取消该会话及所有排队OPEN。
确认/前缀阶段有8秒超时，等待门也有8秒上限。不存在未知session_id的无限等待队列。
会话总数最多64（包括provisional），每会话最多128活动/排队业务，实例最多256并发HTTP请求。
counter一旦保留，失败或取消也不重复使用。失败不发送业务数据，也不自动重放。

客户端构造成功现在表示“服务端身份和账号接受消息已验证、确认已交给发送器”，不是
“已收到服务端确认回执”。真正可用的业务连接必须等待OPEN_RESULT成功。
应用不能仅凭构造函数返回就断言端到端可用。首次OPEN会覆盖服务端确认等待。

TTL在服务端发布临时状态时开始，客户端600秒计时仅为本地上限提示；以服务端撤销为准。
控制流始终保持打开。纯四层转发可保留TLS绑定，TLS终止反代未实现。

## 验证与限制

新增端到端测试故意先送OPEN、后送确认，检查确认前没有目标连接，正确确认后只拨一次。
完整无效AEAD标签必须使排队请求失败且不拨目标；等待期间重复counter也必须拒绝。
覆盖确认门缺失、撤销与确认竞争，以及H2/H3的大数据、半关闭、慢流隔离、取消和私网限制。

该扩展仍为独立TCP原型，不含正式App/面板、UDP、自动重连、DoH/ECH或抗识别结论。
