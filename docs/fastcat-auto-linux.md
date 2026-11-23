# 快猫 Android 自动节点的 Linux 部署

适用于 x86_64 Linux、systemd 247 及以上。HTTP/2 监听 TCP 18444，HTTPS v1 监听 TCP 8443，两者均对外提供 TCP CONNECT。访问 HTTPS 目标网站时，入口和目标网站各自使用独立的 TLS 会话。安卓用户在原来的节点列表中选择地区。客户端、面板订阅和两个 Linux 入口都需要支持自动节点。

离线包包含两个静态 Linux 程序、systemd 模板、面板补丁和文件校验清单。以下操作由管理员在相应机器执行。解压不会安装或替换服务。

## 一、确认目标及保留回滚材料

```sh
tar -xzf FastCat-Auto-Linux-amd64.tar.gz
cd FastCat-Auto-Linux-amd64
sha256sum -c SHA256SUMS
uname -m
systemctl --version | head -1
ss -lntp | grep -E ':(8443|18444)[[:space:]]'
systemctl show fastcat-https fastcat-h2 -p FragmentPath -p DropInPaths -p UnitFileState
```

先记录占用端口的实际服务名称、原始启动方式、是否开机自启、旧程序的绝对路径，备份旧二进制、unit 及所有 drop-in 和原有私有环境文件到 root 专用的 0700 目录。后续将替换同名实例并中断现有连接。若名称不同或旧服务由其他工具托管，先在该工具中备份并协调停止旧实例，避免两个进程抢同一端口。保留原有证书续期机制。

## 二、安装面板补丁并生成首批授权

在 catboard 项目根目录操作。包内补丁基于 `191a9f320a743e9bafd558f7dd8c360f233c1bce`，应用前检查自身分支和待提交更改。备份面板代码和原配置，按项目现有流程发布。以下命令中的 `/path/to/package` 是解压目录：

```sh
git apply --check /path/to/package/catboard-auto.patch
git apply /path/to/package/catboard-auto.patch
```

在 Web 根目录外创建私有授权目录，属主设为面板服务账户。以面板服务账户运行下面示例，`vless:42` 为已经存在的面板节点类型和 ID，`71` 为有该节点权限的真实账户 ID。请把 `hk.example.net` 改为入口证书覆盖的实际域名。不同主机或域名时，在 JSON 设置 `fallback-server` 和按需设置 `sni`、`fallback-sni`。

```sh
umask 077
install -d -m 700 /srv/catboard-private/fastcat/vless:42
cat > /srv/catboard-private/fastcat/vless:42/endpoints.json <<'JSON'
{"server":"hk.example.net","port":18444,"fallback-port":8443}
JSON
```

把 `FASTCAT_AUTO_GRANTS_DIR=/srv/catboard-private/fastcat` 加入面板环境，按已有方式刷新配置缓存并重载常驻面板进程。面板应已启用 FastCat 加密订阅。初次部署先让两端服务可接受名单，再通知试用用户刷新订阅。

```sh
php artisan fastcat:auto grant vless:42 71
php artisan fastcat:auto export vless:42 --out=/srv/catboard-private/snapshot-001
```

每一对账户与节点生成两份独立随机令牌。重复 grant 保持原令牌。导出重新检查账户、套餐、剩余额度和节点状态。通过现有的受保护部署通道将 `h2.tokens` 和 `v1.tokens` 分别传给对应 Linux 服务的管理员，临时目录仅允许管理员访问。快照可能包含该节点多个用户的有效令牌。

## 三、替换入口实例

以下示例在两个入口同机时以 root 执行。分散部署时，每台主机仅安装对应服务与其名单。若只开放域名的 IPv6 记录，请按网络部署调整监听地址；模板使用 IPv4 的所有接口。放行用户需要访问的 TCP 18444、8443。

```sh
getent group fastcat-auto >/dev/null || groupadd --system fastcat-auto
id fastcat-auto >/dev/null 2>&1 || useradd --system --gid fastcat-auto --no-create-home --shell /usr/sbin/nologin fastcat-auto
install -d -o root -g fastcat-auto -m 0750 /etc/fastcat-auto
install -o fastcat-auto -g fastcat-auto -m 0600 /root/private-snapshot/h2.tokens /etc/fastcat-auto/h2.tokens.new
install -o fastcat-auto -g fastcat-auto -m 0600 /root/private-snapshot/v1.tokens /etc/fastcat-auto/v1.tokens.new
mv -f /etc/fastcat-auto/h2.tokens.new /etc/fastcat-auto/h2.tokens
mv -f /etc/fastcat-auto/v1.tokens.new /etc/fastcat-auto/v1.tokens
install -m 0755 bin/fastcat-h2 /usr/local/bin/fastcat-h2.new
install -m 0755 bin/fastcat-https /usr/local/bin/fastcat-https.new
mv -f /usr/local/bin/fastcat-h2.new /usr/local/bin/fastcat-h2
mv -f /usr/local/bin/fastcat-https.new /usr/local/bin/fastcat-https
install -m 0644 systemd/fastcat-h2.service /etc/systemd/system/fastcat-h2.service
install -m 0644 systemd/fastcat-https.service /etc/systemd/system/fastcat-https.service
```

模板默认由 systemd 读取 `/etc/fastcat/fullchain.pem` 和 `/etc/fastcat/privkey.pem`。如果证书在其他位置，调整两个模板中的 `LoadCredential=` 来源路径。域名证书和私钥应匹配。程序以专用服务账户运行。确认原服务的 drop-in 与新参数兼容，尤其检查是否覆盖 `ExecStart`。令牌采取文件模式，启动时清除旧的单令牌环境变量。

```sh
systemd-analyze verify /etc/systemd/system/fastcat-h2.service /etc/systemd/system/fastcat-https.service
systemctl daemon-reload
systemctl restart fastcat-h2.service fastcat-https.service
systemctl enable fastcat-h2.service fastcat-https.service
systemctl is-active fastcat-h2.service fastcat-https.service
ss -lntp | grep -E ':(8443|18444)[[:space:]]'
```

证书续期后重启两个服务以加载新证书。单令牌模式旧客户端的凭据只有在新名单中有相应授权时才会通过认证。切换前先评估原有用户影响，并选择维护时间。

## 四、验证认证、订阅与回退

从能访问入口的设备分别核对证书和 TLS 协商。替换两处示例域名：

```sh
NODE_HOST=hk.example.net
openssl s_client -connect "$NODE_HOST:18444" -servername "$NODE_HOST" -verify_hostname "$NODE_HOST" -verify_return_error -alpn h2 </dev/null
openssl s_client -connect "$NODE_HOST:8443" -servername "$NODE_HOST" -verify_hostname "$NODE_HOST" -verify_return_error -alpn http/1.1 </dev/null
```

HTTP/2 应协商 `h2`，v1 应协商 `http/1.1`，证书校验均应成功。再用一名已授权的账号在新版安卓客户端刷新订阅，选原来的地区、连接并访问 HTTPS 网页。TLS 协商成功只能验证入口，实际网页请求才能同时验证账户授权与转发。要验证回退，可在独立测试节点暂时停其 H2 服务，保持 v1 可用，用测试客户端创建一个新的 TCP 请求。恢复 H2 服务后让客户端在后续新请求中重新使用主入口。此步骤应避免影响线上其他用户。

## 五、更新、撤销与回滚

1. 在面板执行 `php artisan fastcat:auto revoke vless:42 71`。重新导出到新目录，通过受保护通道同步两份名单，在服务机用第三节的同目录临时文件加 `mv` 原子替换。
2. 执行 `systemctl reload fastcat-h2.service fastcat-https.service`。核对 `journalctl -u fastcat-h2 -u fastcat-https --since '5 minutes ago' --no-pager` 的加载错误，再用已撤销账户验证两个入口均拒绝新请求。任一文件格式错误时进程继续使用上一份有效名单，修复并重新载入。最后一名账号撤销后应同步两份空文件。成功送达 SIGHUP 与权限实际生效是两项独立检查。
3. 账户过期、停用或套餐额度变化时需重新导出和同步。已建立的连接会持续到断开或服务端会话到期。面板默认按账户发放；如需立即阻断现存连接，重启服务会同时影响其他用户。此包不含流量按用户回账、限速或自动跨主机分发服务。
4. 回滚时先在面板关闭 `FASTCAT_AUTO_GRANTS_DIR`，刷新面板缓存/常驻进程，让试用用户刷新订阅、选回原线路。停止新入口服务，恢复第一节备份的旧二进制、unit、drop-in 与环境文件；没有旧实例的服务先停用并移除新 unit。执行 `systemctl daemon-reload` 并按原来的方式启动和恢复开机自启状态，再验证旧线路。若面板代码也需还原，在未叠加相关新改动时用 `git apply -R --check /path/to/package/catboard-auto.patch` 核对，随后按面板发布流程回滚。

## 离线核验记录

包内两个 amd64 ELF 已在本机隔离的 Linux 虚拟机中通过 QEMU x86_64 用户态执行。每个协议均使用临时测试证书和账户完成 TLS 建连及双向 TCP 回显，重载空名单后拒绝该账户的新请求，恢复名单并重载后再次传输成功。两份原样 unit 模板已通过 Linux 的 `systemd-analyze verify`。面板补丁已从上述干净提交做 `git apply --check` 并核对生成内容。实际生产域名、证书更新流程、账号计量和公网防火墙需要在部署环境核验。
