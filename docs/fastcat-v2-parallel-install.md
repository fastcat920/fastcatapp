# 在现有节点加装 FastCat v2

以下命令适用于有 systemd 247 或更新版本的 x86_64 Linux 节点，以 `zlhk.fastcat.ink` 为例。新服务使用 IPv4 的 TCP 18445 和 UDP 18445，复用该域名已经签发的证书。原有 8443 和 18444 服务可继续运行。普通用户选地区即可，网页和 UDP 数据由手机直连节点，订阅和设备授权由面板与设备网关负责。

## 1. 在 Mac 上传

在 Mac 终端执行。如果平时用 IP 或 SSH 别名登录服务器，将下方的 SSH 目的地换成平时使用的地址。后面安装时填写的证书域名仍用 `zlhk.fastcat.ink`。

```sh
cd /Users/pizihu/Projects/FastCatAPP
scp scripts/deploy_fastcat_v2_node.sh \
    dist/fastcat-v2/FastCat-v2-Linux-amd64.tar.gz \
    dist/fastcat-v2/FastCat-v2-Linux-amd64.tar.gz.sha256 \
    root@zlhk.fastcat.ink:/root/
ssh root@zlhk.fastcat.ink
```

## 2. 在节点服务器安装

以 root 在服务器运行。命令把包解到新建的目录。脚本会校验包内文件、系统架构、证书和端口，创建两个独立的服务，并检查实际监听端口的进程。

```sh
cd /root &&
sha256sum -c FastCat-v2-Linux-amd64.tar.gz.sha256 &&
release_dir=$(mktemp -d /root/fastcat-v2-release.XXXXXXXX) &&
tar -xzf FastCat-v2-Linux-amd64.tar.gz -C "$release_dir" &&
cd "$release_dir/FastCat-v2-Linux-amd64" &&
bash /root/deploy_fastcat_v2_node.sh zlhk.fastcat.ink 18445
```

首次安装默认使用空授权名单，此时任何设备的 CONNECT 都会被拒绝。如果手里已有面板**为这个节点**导出的两份名单，可在首次安装命令末尾加上名单目录的绝对路径，一次装好。重复运行安装脚本会提示已存在。

在云服务商的入站规则及主机防火墙中放行 **TCP 18445 和 UDP 18445**，并确认域名的 A 记录直达节点。服务器启用了 UFW 时可以执行 `ufw allow 18445/tcp` 和 `ufw allow 18445/udp`。其他防火墙按其原有规则管理。

```sh
systemctl is-active fastcat-v2-h2 fastcat-v2-h3
ss -lntp 'sport = :18445'
ss -lunp 'sport = :18445'
```

两个服务应分别返回 `active`，TCP 和 UDP 各显示一个监听。若启动失败，在节点运行 `journalctl -u fastcat-v2-h2 -u fastcat-v2-h3 -n 40 --no-pager`。

## 3. 为安卓手机发放授权

1. 在**面板和设备网关各自的主机**完成 v2 升级。面板应用与自身代码基线相符的补丁，在两个服务的私有配置中设置相同的 `FASTCAT_DEVICE_GRANT_KEY`。面板另设置 `FASTCAT_AUTO_GRANTS_DIR=/srv/catboard-private/fastcat`，并确保该目录由面板服务账户读写。网关保留已有账户、数据库和 `DG_*` 配置。具体命令见 [面板与设备网关升级](fastcat-v2-linux.md#2-面板与设备网关)。
2. 在面板选择一个计划用于 v2 的节点，确认测试账号有权看到它。首次试用可选独立的测试节点，避免改动在用节点的订阅地址。记录该节点的真实类型和数字 ID、账号的数字 ID，以及设备网关中该账号安卓手机的 `id`（`dev_` 加 24 个小写十六进制字符）。在设备网关的用户设备列表中可根据机型和最近登录时间核对设备。
3. 在面板项目目录，以面板服务账户执行下面的命令。三个变量必须换成真实值。示例使用新节点；写入配置的命令遇到已有 `endpoints.json` 会停止，已有节点应先核对并备份其既有配置。

```sh
(
  set -eu
  umask 077
  NODE='vless:42'
  ACCOUNT='71'
  DEVICE='dev_0123456789abcdef01234567'
  GRANTS=/srv/catboard-private/fastcat
  install -d -m 0700 "$GRANTS/$NODE"
  (set -C; printf '%s\n' '{"server":"zlhk.fastcat.ink","port":18445,"h3-port":18445,"tls-key-exchange":"default"}' > "$GRANTS/$NODE/endpoints.json")
  php artisan fastcat:auto grant "$NODE" "$ACCOUNT" --device="$DEVICE"
  SNAPSHOT="$GRANTS/export-$(date -u +%Y%m%dT%H%M%SZ)-$$"
  php artisan fastcat:auto export "$NODE" --out="$SNAPSHOT"
  printf '授权目录 %s\n' "$SNAPSHOT"
)
```

通过已有的 SSH 运维通道将该目录中的 `h2.tokens` 和 `h3.tokens` 安全复制到**节点服务器**，例如放在 root 专用的 `/root/fastcat-v2-authorized/`。两个文件只在服务端使用，不需要向用户发送。若面板和节点同机，可直接将下一段的 `SNAPSHOT` 改为上一步输出的路径。

下面的操作将两份完整的节点授权名单应用到两条入口。今后发放、撤销设备授权时，重新导出该节点的完整快照，重复此操作。

```sh
(
  set -eu
  export LC_ALL=C
  umask 077
  SNAPSHOT=/root/fastcat-v2-authorized
  ENTRY=/etc/fastcat-v2
  stage=$(mktemp -d "$ENTRY/.grants.XXXXXXXX")
  trap 'rm -f -- "$stage/h2.tokens" "$stage/h3.tokens"; rmdir -- "$stage"' EXIT
  for p in h2 h3; do
    install -m 0600 -o fastcat-v2 -g fastcat-v2 "$SNAPSHOT/$p.tokens" "$stage/$p.tokens"
    awk 'length<24 || length>512 || /[^!-~]/ || seen[$0]++ { exit 1 }' "$stage/$p.tokens"
  done
  for p in h2 h3; do mv -f -- "$stage/$p.tokens" "$ENTRY/$p.tokens"; done
  systemctl reload fastcat-v2-h2 fastcat-v2-h3
)
journalctl -u fastcat-v2-h2 -u fastcat-v2-h3 -n 12 --no-pager
```

日志中两项服务均应出现 `device tokens reloaded`。空文件表示该入口撤销全部授权。每次导出都需要同步到数据节点。旧节点的 `/etc/fastcat/server.env` 对应原有服务。

## 4. 从公网和手机验证

在 Mac 运行。入口处理隧道请求，普通 GET 会返回 `405`。第一条预期打印 `HTTP/2 405`。若已安装的 curl 支持 HTTP/3，第二条预期打印 `HTTP/3 405`。第二条只通过 QUIC 测试，能发现 UDP 入站未放行的问题。[curl 官方参数说明](https://curl.se/docs/manpage.html#--http3-only)

```sh
curl --noproxy '*' --http2 --max-time 8 -sS -o /dev/null -w 'HTTP/%{http_version} %{http_code}\n' https://zlhk.fastcat.ink:18445/
curl --noproxy '*' --http3-only --max-time 8 -sS -o /dev/null -w 'HTTP/%{http_version} %{http_code}\n' https://zlhk.fastcat.ink:18445/
```

在已授权的安卓手机上打开快猫 3.7.0，刷新该账号的订阅，选择对应地区，连接后先打开网页，再使用一项确定会发 UDP 数据的应用。到「我的 → 工具设置 → FastCat v2 连接状态」刷新。网页访问成功、实际 UDP 业务收到回应，且状态页显示「UDP · 已接通」，即完成端到端验证。若订阅仍只有旧节点，检查设备网关和面板共享密钥、设备授权和账号节点可见范围。若网页可用但 UDP 不通，先核对 UDP 18445 的公网入站规则及 H3 授权名单。

## 证书续期与回退

两个新服务启动时读取 `/etc/letsencrypt/live/zlhk.fastcat.ink/` 的证书。在节点上执行一次以下命令，让 Certbot 在该证书续期成功时重启正在运行的 v2 服务。已存在同名脚本时命令会停止，应先核对其内容。[Certbot 续期说明](https://eff-certbot.readthedocs.io/en/stable/using.html#renewing-certificates)

```sh
(
  set -euC
  hook=/etc/letsencrypt/renewal-hooks/deploy/70-fastcat-v2
  mkdir -p /etc/letsencrypt/renewal-hooks/deploy
  cat > "$hook" <<'HOOK'
#!/bin/sh
if [ "${RENEWED_LINEAGE:-}" = /etc/letsencrypt/live/zlhk.fastcat.ink ]; then
  systemctl try-restart fastcat-v2-h2 fastcat-v2-h3
fi
HOOK
  chmod 0755 "$hook"
)
```

需要下线试用时，将该试用账号切回原地区节点并刷新订阅，然后在节点服务器运行 `systemctl disable --now fastcat-v2-h2 fastcat-v2-h3`，移除新增的 18445 入站规则。完整的面板、设备网关回退步骤见 [部署与回滚手册](fastcat-v2-linux.md#6-回滚)。

本安装脚本已在隔离的 Ubuntu 22.04、systemd 249 中运行发布包的 x86_64 程序。两项服务均已开机启用并分别监听 TCP、UDP 18445。空名单时 H2 连接返回 407，导入名单并重载后通过认证。已验证端口冲突、重复安装和启动失败清理。公网防火墙和手机订阅仍需在实际部署时按第四节验证。
