# 构建渠道与正式发布

`pubspec.yaml` 是客户端版本与构建号的唯一来源。修改后执行
`ruby scripts/sync_tvos_version.rb`，提交生成的 `tvos/Version.xcconfig`；
CI 会校验 Flutter 和 tvOS app/extension 的版本一致。

- 手动 Actions 默认 `test`；标签 `v*` 自动使用 `release`。
- `FASTCAT_BUILD_COMMIT` 使用构建提交完整 SHA；`FASTCAT_BUILD_CHANNEL` 为
  `local` / `test` / `release`。Flutter 的运行日志、网络诊断包含非敏感构建来源，
  原生 tvOS 在应用 Info.plist 中保留相同来源。没有来源的本地包显示 local/unknown。
- `test` 允许现有未签名或临时签名产物，不能作为可升级的正式签名发行物。
  测试渠道本身不改变包名或账号数据；安装前确认不会覆盖用户的正式客户端。
- Android `release` 必须同时配置完整的 `KEYSTORE_BASE64`、
  `KEYSTORE_PASSWORD`、`KEY_ALIAS`、`KEY_PASSWORD`；缺失即失败，禁止静默改用 debug key。
- 当前 Windows/macOS/iOS/tvOS 工作流没有经过验证的正式签名/导出链路，
  `release` 会明确失败。不是已有证书失效，而是这些发布步骤尚未接入。
  Linux 保持当前分架构发行方式；如后续通过软件仓库分发，需另行管理仓库签名。

## 接入正式签名前的条件

1. Windows：提供 Authenticode 证书或可信签名服务，先签名最终 runner，
   再计算已签名 runner 的 SHA256 并重新编译 Helper，最后签名 Helper/安装程序。
   对安装产物验证证书与文件架构。不能先绑定 Helper，再修改 runner 签名。
2. macOS：Developer ID Application 签名、运行时授权、公证及 stapling，
   验证安装后的代理/Helper 功能。当前 ad-hoc 签名不等于正式签名。
3. iOS/tvOS：正确的开发团队、App Group、Network Extension 权限、
   app/extension provisioning profiles 与正式 archive/export，配合实机验证。
   当前 unsigned IPA/app 不能替代 App Store/TestFlight 的签名发行流程。

提供这些外部条件并完成专用平台验证后，才可用真正的签名校验替换对应门禁。
本次没有创建证书、上传商店、推送代码或触发远程构建。

## CI 验证边界

共享检查覆盖 Flutter、SDK 会话隔离、Go core、独立 Mihomo resource/constant 模块、
网关 race 测试和 Helper 单元测试。网关数据库测试仅使用该 CI job 新建的 PostgreSQL
service 与 `fastcat_test_admission` 库，不读取部署 DSN。Windows Helper 额外检查 x64
和 ARM64 service 编译；tvOS 包含离线协议/扫码/配置/状态回归。
这些检查不替代各平台的安装升级、真实 VPN/系统代理、遥控器与真实网络切换测试。
