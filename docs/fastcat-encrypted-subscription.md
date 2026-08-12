# FastCat 订阅加密

## 功能作用

FastCat 客户端不再直接接收明文 Clash/Mihomo YAML，而是请求 catboard 的独立
`fastcat-v1` 协议。后端生成配置后使用 AES-256-GCM 加密，客户端完成身份认证式
解密和格式校验后才交给 Mihomo。

该功能主要用于：

- 避免订阅响应被浏览器、普通抓包工具或其他代理客户端直接读取；
- 检测密钥错误、密文损坏和响应篡改；
- 防止新版客户端在后端配置错误时静默退回明文订阅；
- 通过 `kid` 配合两把预置 key 完成平滑密钥切换；
- 保持后端现有 UA 节点筛选、审计和其他客户端协议不变。

它不能阻止有能力逆向安装包的攻击者提取客户端内置密钥，因此不能替代 HTTPS、
订阅 token、设备限制、访问审计和频率限制。

## 端到端流程

```text
登录接口返回原始订阅 URL
  → 客户端实际请求时强制设置 flag=fastcat-v1
  → catboard 继续根据 User-Agent 筛选可用节点
  → FastCatV1 调用 ClashMeta 生成 YAML
  → 后端使用 active kid 对应的 AES-256-GCM key 加密
  → 客户端根据响应 kid 选择 current/next key
  → 验证 GCM tag 并解密
  → 检查 proxies 和 proxy-groups
  → 保存 profile 并加载 Mihomo
```

`flag` 与 User-Agent 的职责不同：

- `flag=fastcat-v1` 决定使用 FastCat 加密输出；
- `User-Agent: FastCat/<版本>` 继续用于节点兼容筛选、版本识别和审计。

客户端会覆盖订阅 URL 中已有的 `flag=meta` 或 `flag=clash`，但不会修改账户中保存的
原始订阅地址。

## 信封协议

服务端返回以下 JSON：

```json
{
  "v": 1,
  "alg": "A256GCM",
  "kid": "2026-01",
  "ts": 1786527548,
  "nonce": "Base64(12 bytes)",
  "data": "Base64(ciphertext)",
  "tag": "Base64(16 bytes)"
}
```

加密参数：

- 算法：AES-256-GCM；
- key：Base64 编码的 32 个随机字节；
- nonce：每次响应重新生成的 12 个随机字节；
- tag：128-bit GCM authentication tag；
- AAD：`fastcat-subscription|v1|<kid>|<ts>`。

`kid`、时间戳或密文被修改后，客户端重建的 AAD 将不一致，GCM 认证失败。相同订阅
连续请求也会因为随机 nonce 得到不同密文。

## 客户端实现

统一解码器位于：

```text
lib/xboard/security/fastcat_subscription_decoder.dart
```

以下入口均使用该解码器：

- 登录后首次订阅下载；
- 普通订阅下载；
- 加密订阅服务；
- 多域名并发竞速；
- Profile 定时或手动更新。

客户端验证：

1. 响应必须是 JSON 对象；
2. `v` 必须为 `1`，`alg` 必须为 `A256GCM`；
3. `kid` 必须命中内置 current/next key；
4. key、nonce、tag 必须分别为 32、12、16 字节；
5. AES-GCM tag 必须认证成功；
6. 明文必须包含有效的 `proxies:` 和 `proxy-groups:` 标记。

正式构建默认 `FASTCAT_REQUIRE_ENCRYPTION=true`。收到明文 YAML、General Base64、旧
XOR 密文、未知 JSON、未知 `kid` 或认证失败响应时，不会自动请求 `flag=meta`。
失败发生在 profile 写入之前，因此不会用无效响应覆盖已有配置。

## 构建参数

必须注入：

```dotenv
FASTCAT_KEY_CURRENT_ID=2026-01
FASTCAT_KEY_CURRENT=<Base64 key A>
FASTCAT_KEY_NEXT_ID=2026-02
FASTCAT_KEY_NEXT=<Base64 key B>
```

建议显式注入：

```dotenv
FASTCAT_SUBSCRIPTION_FLAG=fastcat-v1
FASTCAT_REQUIRE_ENCRYPTION=true
```

后两项的代码默认值与示例相同。参数由 `setup.dart` 转为 `--dart-define`。Android 和
iOS 的独立打包脚本也会显式透传这些参数。

GitHub Actions 使用：

- Secrets：`FASTCAT_KEY_CURRENT`、`FASTCAT_KEY_NEXT`；
- Variables：`FASTCAT_KEY_CURRENT_ID`、`FASTCAT_KEY_NEXT_ID`、
  `FASTCAT_SUBSCRIPTION_FLAG`、`FASTCAT_REQUIRE_ENCRYPTION`。

真实 key 不得写入 assets、源码、普通配置文件、构建日志或 Git。

## 两把 key 的切换

服务端任意时刻只使用一把 active key，客户端同时包含当前和下一把 key。

初始状态：

```text
服务端 active = A / 2026-01
客户端 keys = A / 2026-01 + B / 2026-02
```

切换时只需把服务端 `FASTCAT_ACTIVE_KID` 改为 `2026-02` 并刷新 Laravel 配置缓存。
现有客户端会根据响应 `kid` 自动选择 B。准备下一轮时发布包含 B+C 的客户端，等新版
覆盖后再让服务端切换到 C。

不要在客户端尚未包含下一把 key 时提前切换 active kid，否则客户端会提示密钥版本
未知并拒绝更新订阅。

## 兼容性

- 新版 FastCat：明确请求 `flag=fastcat-v1`，必须接收加密信封；
- 已发布 FastCat：继续使用原有 `flag=meta`，不受影响；
- Clash、Shadowrocket、Sing-box 等客户端：继续使用各自协议，不受影响；
- 后端 UA 节点筛选：发生在协议生成和加密之前，行为保持不变。

后端通用协议扫描明确跳过 `FastCatV1`，旧版 FastCat 的 User-Agent 即使含有
`FastCat`，也不会意外收到加密响应。

## 验证

自动化测试：

```bash
flutter test \
  test/xboard/security/fastcat_subscription_decoder_test.dart \
  test/xboard/features/subscription/fastcat_subscription_url_test.dart
```

端到端成功标准：

1. 响应含 `X-FastCat-Protocol: 1`；
2. 正文为 `v=1`、`alg=A256GCM` 的 JSON，不能直接看到节点字段；
3. 连续请求的 nonce、密文和 SHA-256 不同；
4. 正确 key 的客户端能加载节点；
5. 错误 key、未知 kid 或被修改的 tag 必须导致更新失败；
6. 失败时不得自动降级到 `flag=meta`。

