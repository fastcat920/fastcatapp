# OSS 配置简化验收 · 2026-11-11

## 完成内容

- Flutter 菜单不再读取远程或打包 YAML 的 `features`。加入群组和工单入口固定隐藏，其他现有服务菜单显示；原有面板能力限制保留。
- 删除工单图片选择、上传按钮、ImgBB 服务和配置字段。客服会话自身附件功能不受影响。
- 删除 Flutter/tvOS 延迟折扣配置、读取器和换算逻辑，直接显示原始测速结果。
- 客服仅保留 FastCat Support，删除 Crisp/Salesmartly 页面、探测、预热、备用路由和配置读取；客服专用直连规则只包含当前 Support 服务地址。
- 仅消费 `update.platforms`，删除旧 `latest`、全局最低版本和全局更新说明回退。六组独立版本、构建号、最低版本与中英文说明：`android`、`ios`、`tvos`、`windows`、`macos`、`linux`。安卓手机和安卓 TV 共用 `android`。
- 提供完整新格式模板，不保留旧兼容字段；上传仍须由后端生成 `fastcat-config-v2` 签名封装。

## 检查结果

- Flutter 全量测试：661 项通过。
- 打包相关检查：13 项通过。
- 修改范围静态分析：无问题。
- Android ARM64 mobile Debug、iOS Release 无签名、macOS Debug、tvOS 设备架构 Debug 无签名构建通过。
- tvOS 已有运行协议、二维码和工具校验通过。
- 运行代码与打包 YAML 中不再存在 Crisp/Salesmartly/ImgBB/延迟折扣引用。
- 差异空白检查通过。

Android Debug 沿用项目的 Debug 专用选项跳过不匹配的 Firebase 配置，不代表推送功能已真机验证。Windows/Linux 没有本机对应构建环境；本次没有安装到设备、推送 GitHub或发布线上 OSS。

## 使用模板

[完整明文 JSON](remote-config-plaintext.example.json) 中的域名、版本、构建号、App Store ID、SHA-256、size 均为示例或占位内容，不能直接发布。`size: 0` 必须替换为真实字节数，SHA-256 使用对应安装包的64位十六进制值。`config_version` 必须大于现行配置修订号。

安卓手机和安卓 TV 统一使用 `android.artifacts.arm64`，版本、构建号、更新开关及更新说明全部一致；不再单独填写 `android_tv`。无需填写旧版 `latest`、平台顶层浏览器下载链接、全局更新说明或全局最低版本。
