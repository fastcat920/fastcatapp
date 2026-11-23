# FastCat v2 安卓直连验收

这条路径用于在面板适配前验证手机核心。调试版只向节点出示该测试设备的 H2、H3 凭证。节点直接验证凭证、建立 TCP 或 UDP 通道。此流程无需创建面板节点、登录快猫或刷新订阅。

## 当前手机与节点

荣耀手机使用 Android 调试版 3.7.1，包名 `com.fastcat.app.debug`。在登录页点「FastCat v2 直连」，已登录时从「我的 → 工具设置 → FastCat v2 直连」进入。手机已连接其他 VPN 时先断开。确认域名和端口后点「连接」，首次使用可按 Android 提示授予 VPN 权限。「查看连接状态」可查看最近一次 TCP 使用的协议和 UDP 入口状态。「断开并恢复原配置」可恢复之前的选择。

本轮 VPS 使用 `zlhk.fastcat.ink:18446`，TCP 和 UDP 使用相同的端口号。原有 18445 入口继续独立运行。Linux 服务名是 `fastcat-v2-direct-h2`、`fastcat-v2-direct-h3`。证书使用该域名现有的 Let’s Encrypt 证书，节点名单位于 `/etc/fastcat-v2-direct/`。普通用户发行版继续通过原有登录和订阅入口配置节点。

## 再次将节点传给手机

手机通过 USB 连接 Mac，并在当前 Android 用户中安装此调试版。于项目根目录执行以下命令。它通过 SSH 和 USB 将配置写入快猫私有缓存，终端不会显示令牌。下次进入「FastCat v2 直连」时自动载入。请点一次「连接」完成保存；如果只打开页面就退出，可以重新传入。

```sh
cd /Users/pizihu/Projects/FastCatAPP
bash scripts/import_fastcat_v2_direct_android.sh root@zlhk.fastcat.ink
```

每个独立测试入口为一台受信设备签发一对凭证，将同一份文件再次导入另一台手机会共享这对凭证。

## 荣耀真机到公网节点的实测

在荣耀 Android 12 的独立测试用户中，快猫从未登录页导入 VPS 生成的配置。外部测试应用通过系统 VPN 请求网页，并逐个比对 UDP 数据报的内容和长度。VPS 上的临时回显目标只向本机源地址发回正确标记，手机断开 VPN 时无法取得这些标记。

| 18446 入口状态 | 安卓业务结果 |
| --- | --- |
| 两条入口均运行 | 4 次受控网页请求的正文均匹配，4 次外部 HTTPS 请求均返回 200。UDP 收到 11/12 个匹配回显，1 个 141 字节数据报超时。 |
| 只运行 H3 | 两轮受控网页和 HTTPS 均成功，包含断开后重新连接的一轮。23、141、262 字节的 UDP 数据报共 6/6 个匹配。状态页确认 TCP 走 HTTP/3。 |
| 在 VPN 连着时停 H3、提供 H2 | 新网页获得正确正文，外部 HTTPS 返回 200，UDP 0/3。状态页显示 TCP 使用 HTTP/2，UDP 入口不可达。 |
| 恢复 H3，保持同一 VPN | 两次受控网页和 HTTPS 均成功。首轮 UDP 3/3，回显耗时为 209、104、106 ms；下一轮 UDP 2/3，有 1 个 23 字节数据报超时。 |

回显程序记录到上述两次手机端超时对应的数据报均抵达 VPS，且回写调用成功；手机在 5.5 秒内没有收到匹配的回应。现有记录无法进一步定位回程中的具体环节。临时回显服务在测试后关闭，两项直连入口继续运行。面板上的节点 62 不参与此次验收。这是指定手机、网络和节点的一轮公网结果。

## 服务端复测与撤销

以下命令在此次 VPS 上以 root 执行。

```sh
systemctl is-active fastcat-v2-direct-h2 fastcat-v2-direct-h3
ss -lnt 'sport = :18446'
ss -lun 'sport = :18446'
```

在快猫内点「断开」会停止手机的连接。若要同时关闭服务器独立入口、撤销此测试凭证，则执行以下命令。

```sh
bash /root/fastcat-v2-direct-test/deploy_fastcat_v2_node.sh --revoke-direct
```

撤销后重新执行 `bash /root/fastcat-v2-direct-test/deploy_fastcat_v2_node.sh --direct zlhk.fastcat.ink` 会在原测试端口签发新凭证。再次用 USB 导入即可。保持长期运行时，域名证书成功续期后需要重启这两个独立测试服务以读取新证书。

## 在另一台服务器从头安装

准备 x86_64 Linux、systemd 247 以上和目标域名已签发的证书。将 `scripts/deploy_fastcat_v2_node.sh`、`dist/fastcat-v2/FastCat-v2-Linux-amd64.tar.gz` 及同名 `.sha256` 校验文件一起复制到服务器的一个 root 私有目录。在该目录执行 `bash deploy_fastcat_v2_node.sh --direct 证书域名`。脚本默认先检查 TCP、UDP 18445，已占用时尝试 18446；也可把指定端口作为最后一个参数。按实际输出端口放行云安全组与防火墙的 TCP 和 UDP。生成的 `/etc/fastcat-v2-direct/android.json` 权限为 0600。手机使用系统证书校验域名，运行上面的 USB 导入命令时将 SSH 地址改成对应服务器即可。
