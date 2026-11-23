# 快猫 v2 的 Linux 部署与回滚

此包供 x86_64 Linux 服务器使用。TCP 请求可使用 HTTP/3 或 HTTP/2，客户端按当前网络的连接情况选择入口；用户只需选择原来的地区节点。UDP 业务经过 HTTP/3 的 CONNECT-UDP，需要 UDP 入口可达。保留 HTTPS v1 可继续服务原有的账户级授权。

| 主机角色 | 程序／模板 | 默认监听或依赖 |
| --- | --- | --- |
| 数据入口 | `fastcat-h2 h3-server`，`fastcat-h3.service` | UDP 18444，读取 `h3.tokens` |
| 数据入口 | `fastcat-h2 server`，`fastcat-h2.service` | TCP 18444，读取 `h2.tokens` |
| 可选旧入口 | `fastcat-https -mode server -dynamic-targets`，`fastcat-https.service` | TCP 8443，读取 `v1.tokens` |
| 设备网关 | `device_gateway`，`device-gateway.service` | 保留现有网关域名、数据目录、数据库、环境及反向代理 |
| 订阅面板 | `catboard-v2.patch` | 原有 FastCat 加密订阅、面板用户／节点及设备网关 |

## 1. 校验并备份

在解压目录的上一层运行：

```sh
sha256sum -c FastCat-v2-Linux-amd64.tar.gz.sha256
tar -xzf FastCat-v2-Linux-amd64.tar.gz
cd FastCat-v2-Linux-amd64
sha256sum -c SHA256SUMS
uname -m
systemctl --version | head -1
```

模板使用 systemd 247 或更新版本的 `LoadCredential`。记录原来占用 TCP 18444、TCP 8443、UDP 18444 的实际进程，记录四个服务的当前路径、启用状态和 drop-in。在各主机先以 0700 私有目录备份原二进制、unit、环境配置、授权文件及网关数据库／状态文件，再按维护窗口依次替换。代码包不会自行安装。Redis、PostgreSQL、动态配置服务与面板密钥使用运营方现有部署。

## 2. 面板与设备网关

在 catboard 目录中核对代码基线。完整补丁基于提交 `191a9f320a743e9bafd558f7dd8c360f233c1bce`，包括旧版账户级与新版设备级配置。新部署可运行：

```sh
git apply --check /path/to/FastCat-v2-Linux-amd64/catboard-v2.patch
git apply /path/to/FastCat-v2-Linux-amd64/catboard-v2.patch
```

如已原样应用上轮 FastCat-Auto 面板补丁，改用包内增量 `catboard-auto-to-v2.patch` 并先执行同样的 `--check`。只应用与当前面板匹配的一份。自定义过相同代码的分支需要按本地发布流程合并。

在设备网关与面板的私有环境配置中设置相同的 `FASTCAT_DEVICE_GRANT_KEY`。可用 `umask 077; openssl rand -hex 32 > /root/fastcat-device-grant.key` 在受保护的机器生成一次，再通过现有秘密管理系统将文件中那一行的值分别注入两个服务。此变量与 `DG_TOKEN_SECRET`、加密订阅密钥以及数据入口令牌分别配置。网关与面板需要准确时钟；设备证明有效窗口是 60 秒。保留 HTTPS，设备通过原网关订阅地址刷新，由网关先验证会话，再将真实设备记录 ID 与上游订阅 token 绑定并签名。

升级既有设备网关时，核对 `systemctl show device-gateway -p FragmentPath -p ExecStart`，用 `bin/device_gateway` 替换原可执行文件。包内设备网关 unit 为原项目的部署模板，默认工作目录和环境文件位于 `/www/wwwroot/get.fastcat.com`。按实际位置调整并保留现有 `DG_*` 配置与持久化数据。示例在设备网关主机的解压目录执行：

```sh
install -m 0755 bin/device_gateway /www/wwwroot/get.fastcat.com/device_gateway.new
mv -f /www/wwwroot/get.fastcat.com/device_gateway.new /www/wwwroot/get.fastcat.com/device_gateway
systemctl restart device-gateway
systemctl is-active device-gateway
curl -fsS http://127.0.0.1:8787/healthz
```

面板增加 `FASTCAT_AUTO_GRANTS_DIR=/srv/catboard-private/fastcat`，目录置于 Web 根目录外并由面板服务账户读取。按现有流程刷新 Laravel 配置缓存和重启常驻面板进程。网关主机若不同于面板主机，应分别替换对应组件。

## 3. 登记节点、发放设备授权

下例中的 `vless:42` 是已存在的面板节点类型和 ID，`71` 为有权限且未过期的测试账户。把示例域名改为证书覆盖的入口域名。以面板服务账户执行：

```sh
umask 077
install -d -m 0700 /srv/catboard-private/fastcat/vless:42
cat > /srv/catboard-private/fastcat/vless:42/endpoints.json <<'JSON'
{"server":"hk.example.net","port":18444,"h3-port":18444,"fallback-port":8443,"tls-key-exchange":"default"}
JSON
DEVICE_ID=dev_0123456789abcdef01234567
php artisan fastcat:auto grant vless:42 71 --device="$DEVICE_ID"
php artisan fastcat:auto export vless:42 --out=/srv/catboard-private/snapshot-001
```

将 `DEVICE_ID` 替换成设备网关中该账号设备记录的内部 `id`，格式为 `dev_` 加 24 位小写十六进制。授权粒度是节点＋账号＋设备，重复 grant 保留该设备的既有令牌。可用 `h3-server`、`h3-sni`、`sni`、`fallback-server`、`fallback-sni` 指定独立地址和证书名。TLS 密钥交换可选 `default`、`x25519`、`x25519mlkem768`；若要求固定模式，应在面板、H3、H2 两个服务配置一致，并验证服务器和客户端均支持。

导出目录包含 `h2.tokens`、`h3.tokens`、`v1.tokens`，权限为 0600。H2 汇集该节点有效的设备级与旧账号级授权，H3 只收设备级授权，v1 只收兼容旧账号授权。导出重查账户资格、到期、剩余额度、禁用和节点状态。通过受保护通道将各自文件同步给相应入口。前一次导出的文件不会随面板变化而自动更新。

## 4. 安装或更新数据入口

以下示例在三入口同机且旧账户仍需 v1 时以 root 执行。若分机部署，各机只安装本机角色并复制其令牌文件。域名证书默认由 systemd 从 `/etc/fastcat/fullchain.pem` 和 `/etc/fastcat/privkey.pem` 读取。如路径不同，修改 unit 中的 `LoadCredential=`。证书实际续期后重启各服务。入口模板按 IPv4 的所有接口监听。安全组、边界防火墙与地址解析应允许目标客户端连接相应 TCP 和 UDP 端口。

```sh
getent group fastcat-auto >/dev/null || groupadd --system fastcat-auto
id fastcat-auto >/dev/null 2>&1 || useradd --system --gid fastcat-auto --no-create-home --shell /usr/sbin/nologin fastcat-auto
install -d -o root -g fastcat-auto -m 0750 /etc/fastcat-auto
for name in h3 h2 v1; do
  install -o fastcat-auto -g fastcat-auto -m 0600 "/root/private-snapshot/$name.tokens" "/etc/fastcat-auto/$name.tokens.new" || exit 1
  mv -f "/etc/fastcat-auto/$name.tokens.new" "/etc/fastcat-auto/$name.tokens" || exit 1
done
for name in fastcat-h2 fastcat-https; do
  install -m 0755 "bin/$name" "/usr/local/bin/$name.new" || exit 1
  mv -f "/usr/local/bin/$name.new" "/usr/local/bin/$name" || exit 1
done
for name in fastcat-h3 fastcat-h2 fastcat-https; do
  install -m 0644 "systemd/$name.service" "/etc/systemd/system/$name.service" || exit 1
done
systemd-analyze verify /etc/systemd/system/fastcat-h3.service /etc/systemd/system/fastcat-h2.service /etc/systemd/system/fastcat-https.service
systemctl daemon-reload
systemctl restart fastcat-h3 fastcat-h2 fastcat-https
systemctl enable fastcat-h3 fastcat-h2 fastcat-https
ss -lunp | grep ':18444'
ss -lntp | grep -E ':(18444|8443)[[:space:]]'
```

对已投产的 v1 账号，保留该节点现有有效名单和端口映射。在维护窗口替换旧 unit 后，原连接会中断并重新连接。

## 5. 用户侧验证与撤销

1. 使用已登记设备和对应的账号登录新版 Android 客户端，经设备网关刷新订阅。选原有地区连接，访问 HTTPS 网页，再测试实际 UDP 业务。在独立验收环境短时阻断该测试机到 18444/UDP 的路径，使用新建的 TCP 请求验证 H2 回退，恢复 UDP 后再验证 UDP 通信。生产用户无需选择 TCP、QUIC 或网络类型。
2. 老版客户端只声明 `fc_auto` 时仍按原有账户级授权处理。v2 声明 `fc_auto=1&fc_v2=1`。面板已配置共享 key 时，缺少有效设备证明、无该设备授权的请求继续得到原有订阅节点。面板未设置共享 key 时保留旧账户级行为。若要求严格按设备隔离，迁移后需撤销同账号同节点原有的账户级授权并同步名单。
3. 撤销一台设备时，在设备网关禁用/撤销该设备或其会话，以阻止刷新，同时在面板执行 `php artisan fastcat:auto revoke vless:42 71 --device="$DEVICE_ID"`。需要撤销旧账户授权时单独执行无 `--device` 的 revoke。重新导出到新的快照路径，按第四节原子替换所有启用入口的名单，执行 `systemctl reload fastcat-h3 fastcat-h2 fastcat-https`。核对日志加载结果，再用已撤销和保留的两台测试设备分别验证新请求。已打开的流可持续到断开或到期；令牌文件格式错误时仍使用上一份有效名单。
4. 到期、禁用、额度变化、管理端设备删除都需将相应撤销／再导出、传输和重载接入运营方流程。此包不含各主机之间自动同步、按用户流量回账或计费系统。

## 6. 回滚

先在面板关闭 `FASTCAT_AUTO_GRANTS_DIR`、刷新配置和常驻进程，引导试用设备刷新旧订阅并恢复原线路。若恢复旧账户自动节点，应恢复对应的旧面板设置与旧授权名单。在维护窗口停止新增 H3 服务，按实际部署恢复原数据入口和设备网关的可执行文件、unit、drop-in、环境变量与名单，再按备份记录执行 `systemctl daemon-reload` 和服务启动。避免覆盖服务运行期间新写入的设备状态。面板代码回滚先在对应分支执行 `git apply -R --check` 加实际使用的补丁路径，再按既有发布流程回滚。最后用旧客户端验证登录、订阅刷新和网页请求。

## 此交付的离线验收

实际出货的 3 个 x86_64 ELF 均已在隔离 Linux 虚拟机运行（使用 QEMU x86_64 用户态执行，网络命名空间仅有回环）。H3 以 X25519MLKEM768 测试 TCP 回显和 UDP 数据报，H2、v1 测试各自的 TCP 回显。独立单令牌测试时 H3 读取 `FASTCAT_H3_TOKEN`，H2 读取 `FASTCAT_H2_TOKEN`。三个入口均验证了文件授权、重载空名单后新请求被拒绝、恢复名单后重新通信。设备网关程序完成本地模拟登录、订阅 URL 重写和 HMAC 校验，旧能力请求没有设备签名。四份 systemd 模板均经 systemd-analyze verify 检查。PHP/Laravel 测试覆盖设备授权、撤销与加密订阅；完整补丁与从上轮包升级的增量补丁均已从各自基线实际应用并核对文件。实际公网链路、生产数据库与运维跨机同步未参与这些离线测试。
