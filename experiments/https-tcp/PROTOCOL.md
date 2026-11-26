# FastCat HTTPS v1

这是一套基于标准 HTTPS CONNECT 的 TCP 传输配置规范，不是新加密算法，也不宣称可规避流量识别。标识 `fastcat-https`，核心显示 `FastCatHTTPS`。v1 不支持 UDP、复用或请求重放。现有协议不变。

## 线路格式

1. 客户端连接入口 TCP；使用 TLS 1.2 或以上，校验证书链及入口域名；ALPN 为 http/1.1。
2. TLS 建立后发送 CONNECT authority，请求行与 Host 使用实际目标 host:port（IPv6 使用方括号）。Authorization 为 Bearer 加令牌，FastCat-Version 为 1。认证信息不会出现在明文 TLS 握手中。
3. 服务端校验令牌及版本，再执行目标策略、DNS 解析和目标 TCP 建连，成功返回 HTTP 200，此后双向传输原始 TCP 字节。解析响应时保留预读的目标数据。
4. TCP 写入结束映射到 TLS close_notify，服务端继续接收反向响应；连接错误不重放载荷。

失败分类：入口 TCP、TLS、CONNECT 请求/响应、认证 403、目标策略 403、目标 TCP 502、额度 503、隧道读写。403 的具体原因在服务端日志区分。未指定版本暂兼容最初实验客户端；未知版本返回 400。

## 服务端

构建：在本目录执行 `go build -o fastcat-https .`。使用自己的测试域名及证书，在环境变量 FASTCAT_LAB_TOKEN 设置至少 24 字节随机令牌，然后运行：

```
./fastcat-https -mode server -listen 127.0.0.1:18443 \
  -cert /absolute/path/fullchain.pem -key /absolute/path/key.pem \
  -dynamic-targets -max-tunnels 128 -session-timeout 30m
```

示例仍绑定回环。自有测试入口的监听地址由运维显式设置；本次不部署。动态模式默认拒绝回环、私有、链路本地和非全局单播目标；域名所有解析结果均须通过检查，之后直接拨号已检查的 IP，避免二次解析。`-allow-private-targets` 仅用于隔离测试。默认不开启动态目标，保留固定 target 实验模式。

多个设备共用入口时，在服务端启动参数中加入 `-tokens-file /etc/fastcat/v1-device-tokens`。服务进程需有读取权限，文件每行一个设备的独立随机令牌，每个令牌 24 至 512 个可见 ASCII 字符，行内不含空格。文件模式仅接受文件中的授权，原来的 `FASTCAT_LAB_TOKEN` 不会自动加入授权列表。迁移旧设备时，可将符合格式的旧令牌一并纳入首次加载的清单。

更新时先在同一目录写好仅有授权账号可读的新文件，再原子替换原路径，向运行中的 v1 服务进程发送 `SIGHUP`。新 CONNECT 立即按重载后的清单认证，已经建立的连接继续到关闭或超时。空文件会撤销所有新授权。文件缺失、包含空白行、不合规令牌或重复令牌时，启动阶段会报错退出，运行中重载仍保留上一次有效清单。

省略 `-tokens-file` 会沿用单令牌环境变量模式，修改环境变量需要重启服务。两种模式的默认总上限都是 128 个已认证活动隧道，绝对生命周期 30 分钟，客户端握手最长 8 秒。

## App 核心节点配置

以下内容作为单个节点加入测试配置，加入现有手动选择组；不要覆盖现有默认线路：

```yaml
proxies:
  - name: FastCat HTTPS 测试
    type: fastcat-https
    server: gateway.example.com
    port: 443
    sni: gateway.example.com
    token: REPLACE_WITH_RANDOM_TOKEN_AT_LEAST_24_BYTES
    # ca-file: /absolute/path/test-ca.pem
```

使用系统受信任证书时不设置 ca-file；自签证书测试必须配置可信 CA 文件，禁止跳过证书校验。显式 udp: true 或 skip-cert-verify: true 会使节点解析失败。节点令牌属于敏感配置，不要上传公开订阅或日志。

核心已经加入 outbound 和 ParseProxy 接入，Dart 的节点类型使用字符串，Apple 扩展沿用共享 Go 核心。要在安装包使用，必须重新构建核心和 App；当前运行的老安装包不会自动支持该类型。未运行 iOS/tvOS 真机或签名发布构建。

## 验证

本目录 `go test -race ./...`、`go vet ./...`；`python3 faults.py`；`python3 smoke.py --duration 60 --output stability-run.json`。

核心目录 `core/Clash.Meta` 中运行 `go test ./adapter/outbound ./adapter`。额外端到端测试：先构建本目录服务端，再以 FASTCAT_TEST_SERVER=/absolute/path/server 运行 `go test ./adapter/outbound -run TestFastCatHTTPS -v`，确认真实核心 adapter 与独立服务端传输，而不是只验证实验客户端。

未验证：公网入口、抓包指纹对照、移动端资源、跨网络恢复和长时间运行。标准 TLS 不保证入口 IP/端口可达，也不保证流量不可识别。

## 本机已生成程序

artifacts/fastcat-https-macos-arm64 与 artifacts/fastcat-https-linux-amd64 可直接作为服务端执行，参数见 `-h`。Linux 为交叉编译结果，尚未在服务器运行。Apple 两个平台的未签名 Debug 应用已构建，并确认隧道扩展链接新协议；安装真机仍需有效签名和独立测试节点配置。详见 README.md 最新构建记录。
