# N1 独立实验原型

规范：[SPEC-0.1.md](SPEC-0.1.md)。这是标准 TCP/TLS/HTTP 外层上的原创应用记录与认证原型，不是“从物理层到密码算法全部原创”的协议，也不是已证明抗识别的产品。

## 构建与自检

本轮使用 Go 1.26.11（修补已知标准库漏洞）；请使用仍受维护且完成安全更新的版本，无第三方 Go 依赖。

```sh
go test -race -count=1 ./...
go vet ./...
go build -trimpath -o artifacts/n1-macos-arm64 .
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -o artifacts/n1-linux-amd64 .
```

Android arm64 必须接入系统 DNS，不使用纯 Go 的本机 DNS 回退：

```sh
CGO_ENABLED=1 GOOS=android GOARCH=arm64 \
CC="$ANDROID_NDK/toolchains/llvm/prebuilt/darwin-x86_64/bin/aarch64-linux-android24-clang" \
go build -trimpath -o artifacts/n1-android-systemdns-arm64 .
```

## 本轮隔离部署

- 入口：zlhk.fastcat.ink:18461/TCP，TLS 名称 zlhk.fastcat.ink。
- 服务端目录：/opt/fastcat-n1-lab（700）；config.json（600）。
- systemd 临时服务：fastcat-n1-experiment、fastcat-n1-origin；不启用开机自启。
- 测试源仅监听 127.0.0.1:18462，只提供可逐字节验证的合成数据，不提供私有文件。
- 入口仅允许连接该测试源，不是开放代理。停止命令：`systemctl stop fastcat-n1-experiment fastcat-n1-origin`。
- 测试凭证保存在私有临时目录和设备 600 文件中，不进入仓库或报告。
- 正式快猫、面板、原有 443/18447/30005 等服务均不替换。

Android 设备 A3GMVB2110006859，荣耀 TFY-AN00。原型位于 /data/local/tmp/fastcat-n1-lab，不覆盖正式 App。

## 公网验收

`python3 run_acceptance.py` 用已部署的私有配置在安卓上测试：

- 20 次 32 KiB 完整请求，每次新 TCP/TLS 会话；这是串行重复，不是暖连接复用。
- 5 次 8 MiB 完整下载，逐字节校验。
- 4 个并发客户端，每个 5 次 32 KiB 请求。

first_response_headers_ms 包含 DNS/TCP/TLS、认证、目标连接与 HTTP 响应头时间，不等于节点 RTT。end_to_end_mbps 包含建立连接和内容校验，不等于纯传输阶段吞吐。P95 使用 nearest rank；5 个大文件样本的 P95 等于最大值，结论有限。

结果写入 results/2026-11-24；第一轮失败数据保留在 round-1，不能删除失败只报告复测成功。

## 下一阶段

先完善未认证行为的时序与资源验证，再做同设备浏览器握手、包长和时序对照、不同网络与主动探测测试。UDP、多路复用、App/VPN 接入、动态账号、面板计量、凭证轮换均未实现；不要将此次原生测试解释成生产可用或抗 GFW 验收。

第二阶段工具：`inspect`执行随机顺序的HTTP拒绝探测；`baseline`与`baseline-stream`下载相同32KiB普通资源，分别使用固定长度和分块流式响应；`hold -count 12`仅在隔离入口测试半握手连接限额，结束自动释放，最多16条。`analyze_hello.py`从私有抓包提取IPv4 TCP的ClientHello与TLS记录元数据，不是识别率评估器。`analyze_probes.py`分析请求头至响应头时序；`probe_tls.py`用本机OpenSSL补充少量TLS行为探测。

第二阶段数据位于 `results/phase2-2026-11-24`。包捕获只针对18461，不抓取正式节点。原始pcap留在私有临时目录，报告剔除来源IP和凭证。连接同源上限对NAT/前置有影响，勿直接将实验默认值用于生产。

第三阶段对照工具为 `run_phase3_ab.py`，在安卓上对18461旧布局与18463合并布局做10轮随机先后顺序的新连接请求。分析器支持 `--port` 分开提取同一pcap的两组；必须检查握手数量、TCP重组连续性与未解析TLS字节，不能将缺包算作记录减少。初轮失败及后续测量口径变更的结果均分别保留。

新增测试覆盖外层HTTP结束标记延迟、双向半关闭、空响应、小包即时返回、取消释放、重复EOF/FIN与HTTP分块有效性；fixture会把被HTTP服务恢复的panic判为测试失败，不能仅凭测试进程打印PASS忽略后台异常。

第三阶段验收后，18461实验服务已明确选择coalesced，18463临时服务已停止。A/B脚本会核对实际服务配置并拒绝不符的环境；直接重跑不会再得到可比的两组。完整结果见PHASE3-REPORT-2026-11-24.md。阶段3的完整事务时间包含FIN/HTTP EOF/TLS终止读，口径比早期HTTP载荷检查更严格。

第四阶段见 PHASE4-PLAN.md：`run_phase4.py` 采集 72 条同入口、相同 TLS 栈的 N1/GET/流式 RPC 样本，采用预先确定的训练尺寸与未见尺寸验证。`analyze_phase4.py` 只用训练数据选取简单判别规则，并报告普通对照的误报。该实验不能评估真实 GFW 识别概率。诊断 RPC 和可变公共样本必须显式启用 `-workload-controls`，采集结束移除临时 systemd 配置，恢复默认关闭。

第四阶段完整结果见 PHASE4-REPORT-2026-11-24.md。72 条复采通过，但客户端记录数仍可区分本批 N1 与合成 GET/RPC；未改 N1 发送策略，不能宣称隐蔽性提高。第一轮握手失败与对照关闭差异均保留。

第五阶段将客户端 FIN 和外层 HTTP 终止块合并发送，保持相同 N1 记录与完整结束校验。私有客户端配置设置 `"client_emission":"coalesced"` 启用；省略仍为 legacy，服务端不需要升级。`run_phase5.py` 用新的载荷尺寸比较 legacy/coalesced/RPC；`analyze_phase5.py` 分别评估记录计数特征和加入字节数后的特征，规则仅在训练数据上选择。预定方案见 PHASE5-PLAN.md，验收结果见 PHASE5-REPORT-2026-11-24.md。

第六阶段：`run_phase6.py` 对每对 N1/普通流式任务匹配上行三次写入长度与因果阶段；使用新的训练和留出尺寸，不更改 N1 发送策略。`analyze_phase6.py` 验证上行相等并评估预定特征，`analyze_phase6_trace.py` 将受限服务端阶段日志与完整 TLS 记录核对。见 PHASE6-PLAN.md 与 PHASE6-REPORT-2026-11-24.md；测试控制和日志默认关闭。

第七阶段新服务端实验参数 `-data-write-limit 16384` 将下行完整业务 Write 限于 16 KiB；需 `-emission coalesced`，默认不开启，原稳定实验服务已恢复。`run_phase7.py` 进行随机顺序的双入口 A/B；`run_phase7_bulk.py` 是首轮吞吐异常后补充的四对 1 MiB 请求，保留最后一条基线超时，不混入首轮成功率。帧归因工具只对完整捕获做对齐，失败请求独立保留。实现、结果和边界见 PHASE7-PLAN.md、PHASE7-REPORT-2026-11-24.md。


## 有序验证结果（2026-11-25）

按稳定性→性能/资源→真实浏览器/双网络→安全生命周期推进。详见PHASE8、PHASE9、PHASE10、PHASE11报告。新增配置默认保持实验隔离，正式App、面板、原18461均未替换。写入限额适合作为下一版实验候选，没有统计上确认的吞吐提升；真实浏览器功能通过不代表已证明抗GFW识别。
