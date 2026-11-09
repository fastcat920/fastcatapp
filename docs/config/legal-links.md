# 协议链接配置

OSS 配置正文中新增（签名 v2 配置放在签名 payload 内，并重新签名）：

```json
{
  "legal": {
    "privacy_policy_url": "https://www.fastcat6.com/privacy",
    "terms_of_service_url": "https://www.fastcat6.com/terms"
  }
}
```

客户端打包兜底位于 `assets/config/config.yaml` 的同名 `legal` 字段。
每条链接独立按 OSS → 打包 YAML → 内置链接回退，只接受具有主机名、无内嵌账号密码的 HTTP/HTTPS 地址。格式有效不代表网页可访问，本次不增加打开前网络探测。
原有 FASTCAT_PRIVACY_POLICY_URL / FASTCAT_TERMS_OF_SERVICE_URL 编译参数作为 YAML 未配置时的后备，保留兼容。
所有平台的首次弹窗、注册页和协议页脚共用解析逻辑。每次打开协议都会读取当前 OSS 配置，首次安装尚未初始化 OSS 时使用打包链接，不为协议弹窗额外提前联网。

首次按钮：同意并继续 / Agree and Continue。
注册页默认勾选，仍可取消；取消后禁止注册。不会自动提交注册，也不改写已有隐私确认记录。
