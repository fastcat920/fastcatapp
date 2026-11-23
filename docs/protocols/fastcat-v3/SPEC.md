# FastCat v3 二进制与状态机规范 0.2

状态为实验性协议规范。文中“必须”“禁止”是实现互通要求。该版本可用于
编写两个独立实现，尚未通过外部密码审查或跨实现互通验收。版本 0.1 的
模糊处以本文件为准。本次交付规范与向量，未改变线上 v2 配置。

设计目标包括身份认证、流复用、移动网络恢复和可测的网络行为。识别率、
可达性及性能必须另行实验。本协议使用 Noise 和标准密码原语，原创部分为
应用握手载荷、会话状态、消息编码和承载映射。

## 1. 编码与常量

除明确指明 Noise 内部编码外，整数为无符号大端定长整数。u8/u16/u32/u64
分别占 1/2/4/8 字节。bytes[N] 是精确 N 字节，vec16 是 u16 长度后紧接数据。
所有长度指字节数。字段按表中顺序串联，无对齐和隐式填充。

字符串是 ASCII，目标域名采用小写 IDNA A-label，不包含结尾点，长度 1..253，
标签 1..63 字节，不允许空标签、控制字符或路径。目标 IP 使用网络字节序原始
4/16 字节。禁止 IPv6 zone。文本转换发生在编码之前。

初始协议 wire_version=1。cipher_suite=1 唯一对应
Noise_IK_25519_ChaChaPoly_SHA256（Noise revision 34）。能力位和保留位均为 0。
载荷缺字节、多字节、计数溢出、重复互斥字段必须拒绝。禁止猜测其他编码。

固定限制如下。

| 名称 | 值 |
|---|---:|
| 握手 Noise 消息 | 4096 字节 |
| 可靠承载记录密文（含标签） | 16384 字节 |
| 单会话活动流 | 最多 128 |
| 单流初始接收额度 | 262144 字节 |
| 会话初始接收额度 | 4194304 字节 |
| 双向无活动超时 | 30000 ms |
| 首版原生 UDP 最大 UDP payload | 1200 字节 |
| 首版应用数据报 | 1024 字节 |
| 协议握手总超时 | 8 秒 |
| 单一密钥代次记录数上限 | 2^24 |
| 单一密钥代次明文上限 | 2^30 字节 |

接收额度是累计绝对上限，不是可以重复增加的计数。支持更低额度的部署
必须在握手内协商，不能默默截断应用数据。

## 2. 承载与信任

carrier=1 为 HTTPS H2 双向请求字节流；carrier=2 为 HTTPS H3 双向请求字节流；
carrier=3 为实验性原生 UDP。每个承载连接完成独立握手，禁止挪用其他连接的
记录密钥、计数器或握手消息。H2/H3 首版每个会话使用一个请求流，内部复用
业务流，因此丢失的承载流字节仍可能阻塞多个业务流。

标准承载发起 POST /fc-session，Content-Type 为 application/octet-stream，
不使用 Content-Encoding、HTTP 重定向或缓存。服务器支持完整双向流式 body。
HTTP 200 仅表示承载就绪，Noise 握手成功并确认后才有代理权限。
客户端可在收到 HTTP 响应头之前，将 prologue 与 CLIENT_INIT 随请求 body 发送。
CLIENT_CONFIRM 仍必须绑定当前 TLS exporter；服务端在确认通过前不得建立目标连接。
服务端必须通过受信 TLS 证书校验，禁用 skip-verify，TLS 最低版本 1.3。
H2 与 H3 的 TLS exporter label 为 ASCII EXPORTER-FastCat-v3，context 为空，
输出 32 字节。客户端和服务端都必须能从该承载的 TLS 会话取得相同 exporter。
跨 TLS 终结代理部署若无法提供该绑定，不得实现本版本标准承载。

客户端从可信订阅获得 service_id（随机 16 字节）和服务端 X25519 静态公钥。
每次完整握手生成新的客户端 X25519 静态密钥及临时密钥。这里的客户端静态
密钥仅存在于一次握手中，账号身份由凭证决定。所有密钥来自系统 CSPRNG。
X25519 共享结果为全零必须失败。禁止凭外层域名替换订阅信任锚。

标准承载可用 ECH；严格 ECH 的失败必须终止该连接。HTTP 0-RTT 和 QUIC
0-RTT 应用数据在本版本禁用。

## 3. Noise 握手和载荷

prologue 精确为以下 38 字节。

| 字段 | 编码 |
|---|---|
| context | ASCII FCV3，4 字节 |
| wire_version | u8=1 |
| carrier | u8=1、2、3 |
| service_id | bytes[16] |
| attempt_id | bytes[16]，每次握手随机生成 |

标准承载先发送 prologue，然后每条 Noise 消息编码为 u16 noise_length 与
noise_message。服务端逐项验证 prologue，初始化 Noise IK，再处理消息。
客户端初始化 IK 时预先 MixHash 服务端静态公钥，严格遵循 Noise revision 34。

Noise 模式如下。

```
预共享身份信息       <- s
CLIENT_INIT          -> e, es, s, ss, payload_client
SERVER_ACCEPT        <- e, ee, se, payload_server
```

CLIENT_INIT 中的 e 为 32 字节，随后是加密客户端静态公钥（48 字节），随后
是加密 payload_client（明文长度+16 字节）。SERVER_ACCEPT 是 32 字节 e，
随后是加密 payload_server（明文长度+16 字节）。禁止提前发送代理目标或载荷。
Noise nonce 为 4 字节零加 u64 小端计数，与后续记录的编码独立。

payload_client 如下。

| 字段 | 编码 |
|---|---|
| auth_kind | u8=0，新会话；1，会话恢复 |
| attempt_id | bytes[16]，必须匹配 prologue |
| credential | vec16，32..1024 字节，不透明账号凭证 |
| stream_credit | u32，16384..262144 |
| connection_credit | u32，262144..4194304 |
| idle_timeout_ms | u32，10000..60000 |
| max_streams | u16，1..128 |
| max_datagram | u16，0..1024；0 表示禁用应用 UDP |
| capabilities | u16=0 |
| resume_ticket | vec16；auth_kind=0 时必须为空 |

账号凭证由面板或服务端签发，只能在此加密载荷内发送。服务端必须验证过期、
受众、撤销和权限。恢复也必须重新验证账号凭证。

payload_server 如下。

| 字段 | 编码 |
|---|---|
| result | u8；0 成功，1 认证失败，2 容量不足，3 恢复不可用，4 参数错误 |
| session_id | bytes[16]，成功新会话由服务端随机生成 |
| stream_credit | u32，服务端接收额度 |
| connection_credit | u32，服务端接收额度 |
| idle_timeout_ms | u32，双方 idle_timeout_ms 的较小值 |
| max_streams | u16，不大于客户端提供值 |
| max_datagram | u16，不大于客户端提供值 |
| capabilities | u16=0 |
| resume_ticket | vec16，0 或固定 32 字节 |
| generation | u32，新会话=0，恢复时严格增加 |

成功响应必须满足以上限制。失败响应除 result 外均为零，ticket 为空，然后关闭。
server_credit 与 client_credit 分别约束对端发送的数据，不要求两者相同。

服务端对已解密 CLIENT_INIT 的 (service_id,attempt_id,客户端静态公钥)
保留 10 分钟防重放状态，状态容量不足时拒绝新握手。重复请求不得建立第二个
会话或目标。原生 UDP 的同一 attempt 可重发精确相同消息，并重发缓存响应。
必须在 SERVER_ACCEPT 和 CLIENT_CONFIRM 之后才允许 OPEN。

## 4. 流量密钥、记录和更新

IK 完成后调用 Noise Split，得到 k1、k2，分别固定对应客户端发送、服务端发送。
这里将它们视为流量派生的种子，不用于后续 Noise EncryptWithAd。

```
h = Noise 最终 handshake hash
binding = TLS exporter 32 字节（carrier 1/2）；32 字节零（carrier 3）
ctx = SHA256(prologue || h || binding)
send_secret[0] = HKDF-Extract(salt=ctx, IKM=k1 或 k2)
key[e] = HKDF-Expand(send_secret[e], ASCII "FCV3 key", 32)
iv[e]  = HKDF-Expand(send_secret[e], ASCII "FCV3 iv", 12)
send_secret[e+1] = HKDF-Expand(send_secret[e], ASCII "FCV3 update", 32)
nonce = iv[e] XOR (00000000 || uint64_be(record_number))
```

HKDF 严格使用 RFC 5869 HMAC-SHA256，包括 Extract 与 Expand 的区分。
方向字节 direction 为 c2s=0、s2c=1。AEAD 为 RFC 8439 ChaCha20-Poly1305。

可靠承载记录为 u16 ciphertext_length || ciphertext（标签已包含）。
最小 ciphertext_length=30，最大=16384。记录号每方向每代从 0 开始，可靠
承载上隐式递增。AAD 为 ctx || direction:u8 || epoch:u32 || record_number:u64
|| ciphertext_length:u16。先检查长度再分配内存，验证标签后才处理内容。
认证失败关闭整个承载，禁止尝试另一 nonce 或自动跳过记录。

明文为一个或多个完整帧；任何帧都不能跨记录。可靠承载长度是可见字段，
标准承载外层 TLS 另外加密它。内层加密与外层 TLS 的 CPU/字节成本必须计入评测。

CLIENT_CONFIRM 为首个 c2s 加密帧，正文是 h，stream_id=0。服务端验证后
进入 ACTIVE。可在同记录后附 OPEN。服务端只能在确认后发送业务帧。

KEY_UPDATE 正文为 u32 next_epoch，stream_id=0，只能占一个单独记录。
它使用旧代密钥加密，next_epoch 必须为当前+1。发送完立即切到新代并置记录号0。
接收端验证该记录后立即切换，不要求反方向也更新。达到计数或字节限额前必须
完成更新。新代更新完成即擦除旧 secret。epoch 不能回绕。

## 5. 帧格式与逐字节定义

所有帧共有 type:u8 || flags:u8 || stream_id:u64 || body_length:u32，头共14字节。
flags 必须为0。body_length 必须精确匹配帧体。未知 type 关闭会话并报 PROTOCOL。
控制帧 stream_id=0，业务流 stream_id 必须为正奇数，客户端从1开始每次加2，
会话内不复用。服务器不能主动 OPEN。0.2 无可忽略扩展帧。

| type | 名称 | body |
|---:|---|---|
| 1 | CLIENT_CONFIRM | bytes[32] 握手 h |
| 2 | OPEN | kind:u8, addr_type:u8, addr_len:u16, address:bytes[addr_len], port:u16, priority:u8 |
| 3 | OPEN_RESULT | status:u16 |
| 4 | DATA | offset:u64, bytes[剩余长度]，至少1字节 |
| 5 | DATAGRAM | sequence:u64, bytes[剩余长度] |
| 6 | WINDOW_UPDATE | absolute_limit:u64 |
| 7 | FIN | final_offset:u64 |
| 8 | PING | opaque:bytes[8] |
| 9 | PONG | opaque:bytes[8]，原样回复 |
| 10 | RESET | code:u16, final_offset:u64 |
| 11 | KEY_UPDATE | next_epoch:u32 |
| 12 | GOAWAY | last_accepted_stream:u64, code:u16 |
| 13 | PADDING | 任意字节，最长256 |
| 14 | RESUME_STATE | generation:u32 |
| 15 | CLOSE | code:u16 |
| 16 | ACK | 仅原生UDP，见第8节 |

OPEN.kind 为0 TCP、1 UDP固定目标关联；addr_type 为1域名、2 IPv4、3 IPv6。
addr_len 对 IP 必须为4/16。port=1..65535。priority 为0交互、1普通、2批量。
同一 UDP 关联只允许一个固定目标，业务切换目标必须另开关联。

OPEN_RESULT.status 为0成功、1目标不可达、2策略拒绝、3容量、4不支持。
RESET/CLOSE/GOAWAY code 为0正常、1协议错误、2流控、3目标失败、4容量、
5授权失效、6资源超时、7最终偏移错误。客户端日志只记录类别。

每条流最多接受一次OPEN及一次OPEN_RESULT。相同OPEN的UDP重发必须与首次
正文逐字节一致，服务端返回原结果，禁止重复拨号。冲突OPEN关闭会话。
服务端在拨号结果确定前最多缓存64 KiB流数据；客户端首版必须等成功结果再发DATA。

DATA.offset 是流内本方向绝对字节偏移。可靠承载必须连续，UDP可乱序；重叠数据
若与已缓存字节冲突则关闭会话，已经消费的重复区间丢弃。FIN.final_offset 必须
等于已发送DATA总长度，接收方收到连续数据到该偏移后半关闭目标。RESET 的
final_offset 至少为已观察最大偏移，且计入流控。最终偏移一旦声明不能改变。
UDP关联不允许DATA/FIN，TCP流不允许DATAGRAM。

WINDOW_UPDATE 的 stream_id=0 更新会话额度，否则更新该流额度。额度单调增加，
旧值忽略。值不得大于2^60。发送方每方向按每条流最高偏移增量累计会话消费；
重传不额外消费。流关闭后仍保留其会话消费，禁止复用已消费额度。
DATAGRAM 使用协商大小限制和拥塞预算，不消费字节流接收额度；接收队列独立限制。

UDP业务 sequence 每关联从0增长，接收方使用1024位窗口丢弃重复，窗口外丢弃。
空数据报允许，超过协商值必须拒绝发送；收到超长报文RESET该关联。不分片、不重传。

调度采用带权 deficit round robin，三类量子分别16/8/4 KiB。同一类按流轮转，
每轮每流最多一个量子，额度不足跳过。控制帧每轮最多8 KiB并计入承载拥塞预算。
UDP队列最长100 ms、每会话256个报文，先丢弃过期报文，满时丢最旧报文。

## 6. 流和会话状态机

会话状态固定为 NEW → HANDSHAKING → WAIT_CONFIRM → ACTIVE → DRAINING → CLOSED。
客户端发送确认后可进入ACTIVE；服务端须收确认后进入ACTIVE。8秒内未完成握手
关闭。失败状态不得回到ACTIVE。ACTIVE可接GOAWAY进入DRAINING，之后禁止新OPEN，
已有流最多再运行30秒。CLOSE立即终止全部流。对无效密文不发送详细错误。

流状态为 OPENING、OPEN、LOCAL_FIN、REMOTE_FIN、BOTH_FIN、RESET、CLOSED。
只有成功OPEN_RESULT才能从OPENING进入OPEN。双向FIN且数据交付完成后CLOSED。
RESET立即停止该流，不影响其他流。目标连接失败返回OPEN_RESULT，随后关闭该流。

活动包括通过认证的收发帧。PADDING不刷新idle计时，ACK不刷新应用活动计时。
首版默认无周期保活；业务仍活跃且连续10秒无有效包时可发PING，最多每10秒一次。
切网强制新建承载与完整Noise握手，第一版保留H2/H3池与会话状态的生命周期一致。

## 7. 恢复规范

0.2 只恢复账号会话，新业务流可以重建。活动TCP流无缝续传不在0.2能力范围内。
旧连接所有未结束流必须RESET并向应用报告中断。禁止自动重放应用请求。
RESUME_STATE只允许在确认后、首个OPEN前发送，正文为本次generation。

服务端ticket为CSPRNG生成的32字节随机引用，仅在内存存储其SHA256，绑定session_id、
账号、service_id、有效期（60秒）和generation。普通新会话可返回空ticket禁用恢复。
恢复请求在credential之后的resume_ticket提交ticket；它位于Noise加密载荷内。

恢复批准时，在session锁内执行以下原子步骤：验证ticket未过期且未消费、验证账号、
标记ticket已消费、generation加1、废止旧承载的目标写权限、取消旧流、生成新ticket。
两个并发恢复仅一个成功。SERVER_ACCEPT丢失后客户端使用旧ticket重试必须失败；
随后使用auth_kind=0创建新会话。服务端重启丢状态同样返回恢复不可用。

握手恢复仍使用新的四个Noise密钥输入和新attempt_id；禁止0-RTT目标请求。
服务端账号撤销后，下一次授权检查立即关闭会话，检查间隔不超过30秒。

## 8. 原生 UDP 报文与可靠恢复

此承载是实验 wire profile，其公开头本身可能形成指纹。未做隐蔽性承诺。
一个UDP报文只能承载一个完整协议包，不支持拼包或IP分片。报文最大1200字节。

握手报文头如下，后面是payload_length字节正文。

```
kind:u8, flags:u8=0, connection_id:bytes[16], message_id:u8,
payload_length:u16, payload
```

kind=0x10 CLIENT_INIT，message_id=0，payload=prologue||Noise消息1。
kind=0x11 SERVER_ACCEPT，message_id=1，payload=Noise消息2。
kind=0x12 RETRY，message_id=0，payload=cookie_len:u16||cookie。
完整握手报文必须<=1200，禁止握手分片。UDP profile的credential限制为512字节，
恢复ticket最多32字节。客户端初始connection_id随机生成，服务端回复原样。
原生UDP的prologue.carrier必须为3。

服务端未知地址先返回RETRY。cookie格式为issued_at:u64||mac:bytes[32]，mac是
HMAC-SHA256(cookie_key,源IP字节||源端口:u16||connection_id||issued_at||SHA256(消息1))。
cookie有效10秒，服务端密钥每5分钟更新并保留上一份10秒。客户端第二次INIT的
flags=1，payload变为cookie_len:u16||cookie||prologue||Noise消息1，消息1必须不变。
这是唯一允许flags非0的包。RETRY失败最多2次，之后关闭。RETRY本身不认证服务端。

地址验证前所有响应累计字节不得超过已收字节的3倍。已验证cookie仍需Noise认证。
任何重传都受到拥塞和速率预算约束。无认证前每IP每秒最多20次握手尝试，最多
100个待认证状态，超额丢弃，生产部署可进一步降低。

应用包如下。

```
kind:u8=0x20, flags:u8=0, connection_id:bytes[16], epoch:u32,
packet_number:u64, ciphertext_length:u16, ciphertext
```

明文是第5节帧序列。AAD=ctx||direction:u8||完整32字节应用包头。
nonce使用第4节iv和packet_number。单包ciphertext_length最大1168字节，标签占16，
所以最多1152字节明文，body长度受帧头14字节限制。禁止公开发送目标和账号标识。
packet_number每方向每代从0开始。丢包重发帧内容时使用新包号、重新加密，禁止复用
旧nonce。相同UDP包重复到达只ACK一次状态，不再次交付。

每方向保留4096包重放位图，只有AEAD成功才更新最高包号与窗口。窗口外旧包静默丢弃。
epoch增加最多1；收到下一代时派生候选密钥，只有认证成功才提交代次。保留旧代
接收密钥3个PTO，之后删除。发送下一代必须先发KEY_UPDATE，允许接收端因乱序
先收到下一代包。更新后必须收到新代ACK才允许再次更新。ACK不能确认不同epoch的包。

### 8.1 ACK

ACK帧stream_id=0，正文为epoch:u32, ack_delay_us:u32, range_count:u8，随后每段
start:u64,end:u64，均闭区间。range_count=1..32。区间按end严格降序排列，不重叠
且不相邻。ack_delay_us最大25000，指该ACK最大包号收到至ACK发送的时间。
ACK不得确认尚未发送的包号，违者关闭。帧类型16仅UDP允许。

除ACK和PADDING外的帧都ack-eliciting。收到2个ack-eliciting包或收到首个后25ms，
以先到为准发ACK；有乱序或缺口立即ACK。ACK只确认已认证且已接纳的包。
ACK仅包不引发ACK、不进入bytes_in_flight，但受发送速率上限约束。

接收端重组预算会话4MiB、单流256KiB。无法接纳可靠帧时不得ACK该包，超过预算
发送FLOW_CONTROL关闭。DATAGRAM接收队列满可丢数据并ACK包。ACK并不意味着目标
应用已经消费字节，首版禁止基于ACK实现跨承载业务恢复。

### 8.2 丢包、PTO、拥塞

采用RFC9002第5、6、7节的RTT估计、丢包检测、PTO和NewReno算法，映射为本协议
每epoch的packet_number空间。握手使用独立的消息重传计时器；建立后最多保留相邻
两代包号空间。恢复算法在一条路径上共享RTT、cwnd和bytes_in_flight。

初始化initial_rtt=333ms，smoothed_rtt=333ms，rttvar=166.5ms，计时粒度1ms。
RTT样本取本次新确认最大包的发送时间；ACK延迟上限25ms，不从样本扣除到min_rtt以下。
packet_threshold=3，time_threshold=9/8 * max(latest_rtt,smoothed_rtt)。
PTO=smoothed_rtt+max(4*rttvar,1ms)+25ms，每次触发指数退避。握手重发为1、2、4秒，
8秒总截止。ACK确认新ack-eliciting包才重置退避。PTO最多发送2个探测包，每包包含
最早未确认可靠数据，若无可靠数据则PING。禁止重传ACK、DATAGRAM和PADDING。

初始cwnd=min(10*1200,max(2*1200,14720))=12000字节，最小cwnd=2400字节。
丢包事件按RFC9002进入恢复，窗口减半；同一恢复期内不反复减半。慢启动与拥塞避免
按RFC9002附录B实现，计入全部ack-eliciting协议包头及标签字节。
持续拥塞按3个PTO窗口处理。发送pacing，速率<=cwnd/smoothed_rtt，允许突发最多
2个包。除受限PTO探测外不得超出cwnd。拥塞限制同样作用于不可靠DATAGRAM。

丢包重发DATA区间、OPEN、OPEN_RESULT、FIN、RESET、WINDOW_UPDATE、确认、GOAWAY。
新数据与重传用同一字节额度，ACK后释放重传副本。以消息身份或DATA偏移去重。
KEY_UPDATE首次必须在旧代包中发送。若该帧丢失，发送方用新代新包号重发同一
next_epoch，接收端允许其等于已提交当前epoch并将它视为重复更新，禁止再次更新。
如果帧来自旧代，它也必须等于当前epoch。其余跳代值必须关闭。发送新代包前的
旧代包号历史必须保留用于ACK处理，新的ACK帧用正文epoch指定确认空间。
新代ACK证明对端已切换后可释放更新帧。

### 8.3 路径变化

0.2 禁止对未验证新地址沿用旧UDP会话。源地址变化时服务端丢包；客户端完整重握手，
需要恢复时走第7节。客户端收到其他地址的报文丢弃。原生UDP连接不迁移connection_id。

## 9. 示例与测试向量

vectors.json 给出固定测试密钥、Noise消息1/2、双方payload、handshake hash、Split
种子、流量secret/key/iv/下一代secret、PING记录密文以及UDP包向量。
所有私钥均为公开测试常量，严禁用于部署。

标准记录向量的TLS exporter输入固定为00..1f，便于重现。原生UDP layer向量单独
把ctx=20..3f作为输入，只验证派生与包层，不能冒充原生承载完整握手向量。
流量派生及可靠/UDP密文另由独立Go计算复核通过。Noise握手尚未通过独立库互通。
Noise消息及流量向量由vectors.py生成，脚本同时模拟双方处理，检查payload、最终
hash和Split结果相同，并验证AEAD解密。它是参考生成器，仍须独立实现复核。

运行方式如下。

```
python3 vectors.py --check
```

额外解析向量如下（空格仅方便阅读）。

```
PING type=8 flags=0 stream=0 body_length=8 body=0102030405060708
08 00 0000000000000000 00000008 0102030405060708

OPEN TCP example.com:443 priority=1 stream=1
02 00 0000000000000001 00000012
00 01 000b 6578616d706c652e636f6d 01bb 01

UDP ACK epoch=0 delay=1000 ranges=[10..12,5..7]
10 00 0000000000000000 00000029
00000000 000003e8 02 000000000000000a 000000000000000c
0000000000000005 0000000000000007
```

实现必须覆盖以下负向测试（本次规范交付未实现下列完整测试集）：长度截断与溢出、错误标签、错误方向与绑定、重放包、
Nonce/包号重复、未知帧、OPEN冲突、FIN最终偏移冲突、额度超限、重复恢复票据、
旧epoch过期、ACK确认未发送包、乱序KEY_UPDATE、模拟丢包与重传后字节交付一次。
必须增加两个独立实现的向量复核，不能以同一脚本自产自验代替互通验收。

## 10. 计费、版本与发布门槛

账号业务流量以服务端与目标之间实际读写的应用字节计量。隧道头、认证、填充、重传
不重复扣用户套餐。每个上报批次带随机16字节batch_id，面板以node_id+batch_id去重。
服务端崩溃前需持久化尚未确认批次，面板确认后才能删除。多进程节点须共享去重规则。

订阅type=fastcat-v3，必须附最低客户端版本、service_id、server_identity、账号
credential、承载列表和入口地址。旧版不得降级解释为v2。选择其他承载仅在网络错误
时允许，身份失败、账号失败或严格ECH失败必须向用户报告。

发布前须通过密码审查、独立实现向量一致、混沌网络测试、安卓/iOS真机验证、资源
限制与模糊测试，以及授权/计量/灰度回滚测试。原生UDP profile独立验收。
填充模式仅有第5节编码，首版发送端默认禁用，接收端按规则忽略其正文。

## 11. 参考与设计归属

本协议复用Noise IK握手结构和成熟加密原语。其应用层语义、编码、承载绑定和恢复
规则由本草案定义。原生UDP的恢复与拥塞采用RFC9002算法，避免另造未经分析的
拥塞算法。它的公开wire image与QUIC不同，协议新颖性不等于抗识别能力。

- [Noise Framework revision 34](https://noiseprotocol.org/noise.html)
- [HKDF RFC 5869](https://www.rfc-editor.org/rfc/rfc5869.html)
- [ChaCha20-Poly1305 RFC 8439](https://www.rfc-editor.org/rfc/rfc8439.html)
- [丢包恢复与拥塞控制 RFC 9002](https://www.rfc-editor.org/rfc/rfc9002.html)
