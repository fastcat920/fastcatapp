# 客户端更新发布与验证

## 行为

- 普通更新：取消／更新。取消下载保留已下载的部分，下次重试支持续传；同一版本和构建号只自动提示一次，设置红点保留。
- 强制更新：只有更新按钮，屏蔽返回和点击遮罩关闭。只对本次确认过的远程配置生效；缺失可用安装信息时不启用强制锁定，避免锁死客户端。
- Android／Android TV：弹窗内下载及显示进度，SHA-256 校验，原生二次核对包名、版本号及签名，然后打开系统安装器。第一次可能需允许安装此来源，返回点击继续安装。普通第三方应用不能保证静默安装或安装后自动打开；使用系统的安装／打开按钮。
- Windows：只发布一个同时包含 x64/ARM64 的 EXE。安装器按操作系统选择原生程序、代理内核、辅助服务及 VC 运行库；两种客户端更新均下载同一个通用安装包。系统权限确认通过后，等待客户端退出，再安装并重新打开。
- macOS：下载、校验 DMG，自动打开镜像；按提示拖到应用程序替换，重新打开。这一版采用系统安装引导，未集成 Sparkle，不承诺自动替换。
- Linux：自动更新只提供 x64 DEB/RPM。优先查询当前程序属于哪个包管理器，其次按发行版选择：Debian/Ubuntu 系使用 DEB，Fedora/RHEL/openSUSE 系使用 RPM。识别不明确或不是 x64 时不自动投递安装包。下载后打开系统安装工具，完成后手动重新打开客户端。
- iOS／tvOS：只允许 App Store 地址，不下载安装包。点击更新打开商店，商店安装后重新打开；tvOS 返回前台重新检查。App Store 正式可下载后才发布版本号及强制更新，避免审核期间锁定用户。

下载只接受 HTTPS，每次重定向重新检查；安装包不合格不会交给安装器。文件按 SHA-256 存储在应用私有更新目录，超过七天的旧下载在后续启动时清理。不在日志里输出下载链接或凭据。客户端自己的签名必须保持一致，Android 的 versionCode／所有端的 build 必须递增。Debug 和 Release 的包名／签名不同，不能互相升级。

## OSS 配置

放在已签名配置的 `update.platforms` 中。只读取这套结构，不兼容旧版 `latest`、全局更新说明和全局最低版本。每个平台独立配置版本、最低版本、中英文更新说明及安装包。安卓手机和安卓 TV 统一使用 `android`，共用版本、更新说明和 `android.artifacts.arm64` 安装包，不再配置 `android_tv`。直链必须带 SHA-256、类型，建议加文件字节数。
```json
{
  "update": {
    "schema_version": 2,
    "platforms": {
      "android": {
        "enabled": true,
        "source": "direct",
        "latest_version": "3.6.3",
        "build": 9,
        "force": false,
        "min_supported_version": "3.6.0",
        "changelog": {"zh_CN": "更新说明", "en_US": "Release notes"},
        "artifacts": {
          "arm64": {
            "url": "https://downloads.example.com/FastCat-Android-arm64-v8a.apk",
            "package_type": "apk",
            "sha256": "替换为构建生成的64位SHA256",
            "size": 123456789,
            "mirrors": []
          }
        }
      },
      "ios": {
        "enabled": true,
        "source": "app_store",
        "latest_version": "3.6.3",
        "build": 9,
        "force": false,
        "app_id": "替换为AppStore数字ID"
      },
      "tvos": {
        "enabled": true,
        "source": "app_store",
        "latest_version": "3.6.3",
        "build": 9,
        "force": false,
        "app_id": "替换为tvOS对应的AppStore数字ID"
      }
    }
  }
}
```

Windows 使用 `artifacts.universal`（EXE）；macOS 使用 `artifacts.universal`（通用 DMG）；Linux 只使用 `artifacts.x64_deb` 和 `artifacts.x64_rpm`，各自包含对应格式的真实直链、SHA-256 和字节数。Linux 不再配置 ARM64/AppImage 自动更新。`min_supported_build` 可选，配合版本门槛使用。同一版本增加 build 也会识别更新，当前客户端版本高于远程版本时不会降级。

完整配置见 [当前 OSS 明文模板](remote-config-plaintext.example.json)。不包含 `features`、`ticket`、`latency` 或备用客服字段。加入群组和工单入口固定隐藏，其他现有服务菜单固定显示；面板不支持的能力仍遵守原有能力限制。工单只支持文字回复；测速显示原始值；客服仅使用 FastCat Support。

模板带占位符，必须替换版本、build、链接、App Store ID、SHA-256、真实字节数与业务地址。签名封装仍为 `fastcat-config-v2`。不要把明文模板直接上传到当前签名配置地址。

## 构建产物

GitHub 的 Android、Windows、macOS、Linux 构建在上传安装包前自动生成 `dist/update-manifest.json`，包含版本、build、架构、文件大小和 SHA-256。它是发布辅助文件，不会自动发布 OSS 或生成签名。

本地也可以执行：

```sh
python3 scripts/update_manifest.py --directory dist --base-url https://downloads.example.com
```

将对应记录填入 `artifacts`，确认 URL 为实际安装包直链（不是网盘页、登录页），重新签名并发布 OSS。不要在安装包发布前开启强制更新。不再生成或保留旧版 `latest` 下载入口。

## 真机验收流程

使用签名相同、版本及 build 递增的两个测试构建；不要用当前同版本安装包充当更新。

1. 普通更新取消后可继续使用，关于页红点保留；重新进入可继续下载。
2. 下载途中断网，恢复后重试；服务器支持 Range 时续传，不支持时从头安全下载。
3. 损坏文件／HTML 登录页／错误 SHA／重定向到 HTTP 被拒绝，无法安装。
4. 强制更新仅有更新按钮，返回与点击遮罩不能关闭；重试仍可用。
5. Android 手机及电视：拒绝来源权限、允许后返回、取消系统安装、再次安装、升级后打开；原数据保留。
6. Windows：用户权限确认、升级退出、重启新版本；macOS：打开 DMG、替换并重开；Linux：DEB/RPM 正确选择、系统安装器确认及数据保留。
7. iOS／tvOS：商店链接正确、打开失败提示、更新完成后不再提示。App Store 尚未发布时不要开启强制更新。

自动化只验证下载、校验、状态与命令准备，不在开发电脑上实际替换应用或安装测试包。Windows／Linux 系统安装行为仍需对应系统真机验收。

实现参考：[Inno Setup 安装参数](https://jrsoftware.org/ishelp/topic_setupcmdline.htm)、[Windows 安装器启动](https://learn.microsoft.com/en-us/windows/win32/shell/launch)。Windows 内置安装使用系统 ShellExecute 权限交接，由 Inno 单一启动入口重开客户端。

安卓更新仅保留 ARM64 v8 包：只配置 `android.artifacts.arm64`，手机和电视共用 URL、SHA-256、size、版本、build 和中英文更新说明。32 位 ARM 设备不会被错误投递 v8 包。

## Windows 通用包构建

GitHub 的 Windows 选项现在同时构建 x64、ARM64，再由 `windows_universal` 汇总成 `FastCat-Windows-版本号-Setup.exe`。两个 `windows-payload-*` 是一天后到期的中间构建产物，最终用户下载 `FastCat-windows-universal` 中的安装器。

汇总前核对原生 PE 架构、所有文件 SHA-256、版本、build 和提交号，任一架构失败不会发布半成品。包内只安装当前系统对应的文件，不是以模拟运行代替原生 ARM64。辅助服务仍绑定同一构建中的客户端和代理内核。已有安装沿用 AppId、安装目录和数据目录；需要在 Windows x64 与 ARM64 真机分别验证首次安装、覆盖升级、权限拒绝以及 ARM64 上旧 x64 客户端升级到原生 ARM64。

Linux ARM64 的手动构建任务保留，但不配置其 OSS 自动更新；x64 只发布 DEB/RPM 更新信息。示例模板中的 `x64_deb`、`x64_rpm` 是安装包键，不是需要用户手动切换的菜单。
