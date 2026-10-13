# 普通构建与签名发行

`pubspec.yaml` 是客户端版本与构建号的唯一来源。修改后执行
`ruby scripts/sync_tvos_version.rb`，提交生成的 `tvos/Version.xcconfig`；
CI 会校验 Flutter 和 tvOS app/extension 的版本一致。

- 手动 Actions 和标签 `v*` 都默认 `normal`（普通构建）。只有手动明确选择
  `signed`（签名发行）时才启用额外签名门禁；不再把未签名产物称为测试渠道。
- `FASTCAT_BUILD_COMMIT` 使用构建提交完整 SHA；`FASTCAT_BUILD_CHANNEL` 为
  `local` / `normal` / `signed`。Flutter 的运行日志、网络诊断包含非敏感构建来源，
  原生 tvOS 在应用 Info.plist 中保留相同来源。没有来源的本地包显示 local/unknown。
- `normal` 沿用现有编译和打包方式，不因没有发行证书而停止构建，也不改变
  Release 编译优化、包名、账号数据、服务器地址或功能。这个标识不证明产物已签名。
  未签名桌面产物可能触发系统安全提示；未签名 Apple 移动端产物仍需签名才能正常安装。
- Android 普通构建有完整签名配置时仍使用原签名；没有时保留调试签名回退并警告，
  此时可能无法覆盖原安装包。Android `signed` 必须同时配置完整的 `KEYSTORE_BASE64`、
  `KEYSTORE_PASSWORD`、`KEY_ALIAS`、`KEY_PASSWORD`；缺失即失败，禁止静默改用 debug key。
- 当前 Windows/macOS/iOS/tvOS 工作流没有经过验证的正式签名/导出链路，
  只有选择 `signed` 才会明确失败；`normal` 不受此限制。不是已有证书失效，而是这些发布步骤尚未接入。
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
构建标识不会创建证书或自动上传应用商店；`signed` 表示明确请求签名发行流程。

## CI 验证边界

共享检查覆盖 Flutter、SDK 会话隔离、Go core、独立 Mihomo resource/constant 模块、
网关 race 测试和 Helper 单元测试。网关数据库测试仅使用该 CI job 新建的 PostgreSQL
service 与 `fastcat_test_admission` 库，不读取部署 DSN。Windows Helper 额外检查 x64
和 ARM64 service 编译；tvOS 包含离线协议/扫码/配置/状态回归。
这些检查不替代各平台的安装升级、真实 VPN/系统代理、遥控器与真实网络切换测试。

客户端构建与公共检查平级并行，Linux 两种架构分别显示。Windows Helper 检查放在
各自 Windows 构建内部，不再使用跨任务前置依赖。公共检查失败不会阻止其他客户端
生成安装包，但整个工作流仍标记失败；生成安装包不代表所有公共检查已经通过。
