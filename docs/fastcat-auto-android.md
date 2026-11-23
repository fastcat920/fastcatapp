# 快猫 Android 自动连接交付

用户刷新获授权的订阅后，在首页选地区、点「连接」。同一地区只显示一个节点。HTTP/2 与 HTTPS v1 在核心中共用这个名字，两个入口有各自的授权令牌。自动节点承载 TCP；需要 UDP 的业务仍需配置支持 UDP 的线路。

## 构建与分发

| 文件 | 用途 |
| --- | --- |
| `FastCat-Android-arm64-device-test.apk` | 已签名的荣耀真机验收包，包名 `com.fastcat.app.debug` |
| `FastCat-Android-3.6.3-arm64-v8a-unsigned.apk` | 64 位正式构建，包名 `com.fastcat.app`，版本码 2009，须用原正式证书签名 |
| `FastCat-Android-3.6.3-armeabi-v7a-unsigned.apk` | 32 位正式构建，同一包名，版本码 1009，须用原正式证书签名 |
| `FastCat-Auto-Linux-amd64.tar.gz` | Linux 双入口、systemd 服务、面板补丁、授权与回滚说明 |

本地交付文件在 `dist/fastcat-auto/`。正式包按 ABI 分发。已有用户更新时，APK 签名应与原发布版一致，版本码也应高于手机已装的同架构版本。当前工作区的正式签名库未能通过已有密码校验。

如在签名机使用 Android SDK 的 `apksigner`，可从项目根目录执行以下命令，在提示时本机输入原发布密钥的密码。如果签名库内含多个条目，向 sign 命令添加 `--ks-key-alias` 及原发布别名。

```sh
set -e
for abi in arm64-v8a armeabi-v7a; do
  base="dist/fastcat-auto/FastCat-Android-3.6.3-${abi}"
  apksigner sign --ks android/app/keystore.jks --out "${base}.apk" "${base}-unsigned.apk"
  apksigner verify --verbose --print-certs "${base}.apk"
done
```

将输出的证书 SHA-256 指纹与已发布 APK 的签名证书核对。启用面板和两个入口的步骤见 [Linux 部署说明](fastcat-auto-linux.md)。进入计费环境前，需要把入口的授权同步接到账户生命周期，并落实按账户流量回账。

## 连接和故障行为

1. 首次使用优先走 HTTP/2。入口 TCP 或 TLS 建连过程发生可重试的网络错误时，核心会在请求的时限内重试。连续两次失败后，同一个新连接尝试备用入口。
2. 备用成功后优先使用它五分钟。如果备用也不可达，新连接仍可试主入口。连接已经建立后，核心不会重新发送应用数据。证书验证、身份验证和目标策略失败会返回给调用方。
3. 两个入口都不可达时，通过该节点的请求失败。切网后，新连接使用当前可用的物理网络，并保留这个节点最近成功的协议偏好。

## 2026-11-19 荣耀 Android 12 真机验收

在已有账号订阅的手机上冷启动打开订阅链接，点「添加并使用」。测试服务器收到加密订阅下载请求，快猫首页选中一个自动节点。点首页「连接」后，Android 系统建立 VPN。使用手机自带浏览器向受控 HTTP 目标发送不同的请求标记，由目标记录实际到达路径。

| 测试入口状态 | 浏览器结果 |
| --- | --- |
| HTTP/2 和 v1 均可达 | 通过 HTTP/2 收到目标响应 |
| 停止 HTTP/2，保留 v1 | 同一节点自动回退，浏览器请求通过 v1 到达 |
| 两端均停 | 目标未收到请求标记 |
| 仅恢复 HTTP/2 | 浏览器新请求通过恢复的主入口到达 |

同一台设备也验证了 Wi-Fi 关闭后重连，系统恢复 Wi-Fi 和 VPN，浏览器的新请求再次经网关到达。设备无 SIM 卡。验收使用 USB 转发接入隔离测试网关，结果验证了真机操作、VPN 流量与入口回退。公网性能和 Wi-Fi 至蜂窝切换需另行实测。
