# Windows 通用安装器与 Linux 更新格式 · 2026-11-12

## 变更

- GitHub 的 Windows 开关同时启动 x64、ARM64 两个原生构建。仅汇总任务生成用户安装包 `FastCat-Windows-版本号-Setup.exe`，两个 payload 产物仅用于内部打包。
- 汇总前验证版本、build、提交号、所有文件 SHA-256 及 PE 架构，拒绝缺失、损坏、混合架构、不同提交或不同版本的产物。辅助服务与客户端、内核保持同一构建绑定。
- 通用 Inno 安装器按操作系统选择 x64 或 ARM64 程序及对应 VC 运行库；运行库从微软官方下载并由 CI 校验 Authenticode。沿用现有 AppId 和安装目录。内置更新时先给主程序退出时间，再停止辅助服务并进行替换，安装后以原用户身份重开。
- Windows OSS 仅保留 `artifacts.universal`。客户端两种架构使用同一个安装包。
- Linux OSS 仅保留 `artifacts.x64_deb` 与 `artifacts.x64_rpm`。优先查询当前可执行文件的包归属，无法查询时根据 `/etc/os-release` 及 `ID_LIKE` 选择；归属有冲突、发行版不明确或程序架构不是 x64 时不自动选择安装包。不投递 ARM64 或 AppImage 更新。
- Linux ARM64 的手动构建任务未移除；本次限制的是 OSS 自动更新信息。

## 自检

- Flutter 全量：667 项通过。
- 打包检查：22 项通过，覆盖合并模板、架构选择、提交/版本/文件一致性及错误拒绝。
- 修改范围静态分析：无问题。
- GitHub workflow YAML 可解析，Windows 汇总只依赖两个原生构建。
- 完整 OSS 模板为合法 JSON，Windows 只有 universal，Linux 只有 x64_deb/x64_rpm；其他平台配置保留。
- 差异空白检查通过。

## 仍需验证

当前环境为 macOS，没有实际执行 Windows Inno 编译或 Linux 系统安装，也没有推送、触发 GitHub 构建或发布 OSS。本地模板测试不能替代以下验收：

1. GitHub Windows 构建生成单一 Setup.exe 及 update-manifest.json。
2. Windows x64 和 ARM64 分别安装，确认应用/代理内核/辅助服务都是本机原生架构，VPN 实际流量正常。
3. 从既有安装覆盖升级，保留登录、订阅、设置；拒绝 UAC 后客户端不退出；允许后安装并重开。ARM64 上旧 x64 模拟运行版本迁移也需验证。
4. Debian/Ubuntu x64 选择 DEB，Fedora/RHEL/openSUSE x64 选择 RPM；取消与确认系统安装、升级后数据保留。未知发行版和 ARM64 不误装。

当前模板文件含示例版本、域名、哈希及 size 占位符，发布前必须替换为真实安装包信息并生成 fastcat-config-v2 签名封装。
