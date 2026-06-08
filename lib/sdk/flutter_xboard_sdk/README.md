# Flutter XBoard SDK

<div align="center">

一个功能完善、类型安全的 Flutter SDK，用于轻松集成 XBoard API。

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Dart](https://img.shields.io/badge/Dart->=3.1.0-0175C2?logo=dart)](https://dart.dev)
[![Flutter](https://img.shields.io/badge/Flutter-Compatible-02569B?logo=flutter)](https://flutter.dev)

[功能特性](#-功能特性) • [架构设计](#️-架构设计) • [快速开始](#-快速开始)

</div>

---

## ✨ 功能特性

- 🔐 **认证系统** - 登录/注册、邮箱验证、密码管理、Token 持久化
- 📱 **核心功能** - 用户管理、订阅管理、套餐购买、订单支付
- 💰 **财务系统** - 余额管理、佣金系统、优惠券、多种支付方式
- 🎫 **增值功能** - 工单系统、通知中心、邀请系统、应用配置
- 🛡️ **技术特性** - 类型安全、异常处理、自动重试、Token 持久化

---

## 🏗️ 架构设计

### 策略模式架构

SDK 采用策略模式设计，支持 **XBoard** 和 **V2Board** 两种面板类型，通过工厂模式动态选择对应实现。

```
lib/src/
├── core/              # 核心基础设施
│   ├── factory/       # 策略工厂（面板选择）
│   ├── http/          # HTTP 请求与配置
│   ├── auth/          # 认证与 Token 管理
│   ├── models/        # 核心数据模型
│   └── exceptions/    # 异常定义
├── contracts/         # API 契约接口（16个）
└── panels/            # 面板实现（按类型隔离）
    ├── xboard/        # XBoard 专用实现
    │   ├── apis/      # API 实现
    │   └── models/    # 数据模型
    └── v2board/       # V2Board 专用实现
        ├── apis/
        └── models/
```

### 核心优势

- **面板隔离** - XBoard 和 V2Board 实现完全独立，互不干扰
- **易于扩展** - 添加新面板只需实现契约接口
- **类型安全** - 每个面板使用专属数据模型，无需复杂转换
- **模块化** - 核心功能按职责划分为独立模块

### 使用示例

```dart
// 初始化时指定面板类型
await XBoardSDK.instance.initialize(
  'https://your-api.com',
  panelType: 'xboard',  // 或 'v2board'
);

// 之后的调用自动使用对应面板实现
final inviteInfo = await sdk.invite.getInviteInfo();
```

---

## 🚀 快速开始

### 安装

在 `pubspec.yaml` 中添加依赖：

```yaml
dependencies:
  flutter_xboard_sdk:
    git:
      url: https://github.com/hakimi-x/flutter_xboard_sdk.git
      ref: main
```

或者使用本地路径：

```yaml
dependencies:
  flutter_xboard_sdk:
    path: ./path/to/flutter_xboard_sdk
```

### 初始化

```dart
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 基础初始化
  await XBoardSDK.instance.initialize(
    'https://your-api.com',
    panelType: 'xboard',  // 或 'v2board'
  );
  
  // 使用代理
  await XBoardSDK.instance.initialize(
    'https://your-api.com',
    panelType: 'xboard',
    proxyUrl: '127.0.0.1:7890',  //开发时候仅针对s5开发，http以及其他自测
  );
  
  runApp(MyApp());
}
```

### 配置选项

| 参数 | 类型 | 说明 |
|------|------|------|
| `baseUrl` | `String` | API 基础地址（必填） |
| `panelType` | `String` | 面板类型：`xboard` 或 `v2board`（必填） |
| `proxyUrl` | `String?` | 代理地址，如：`127.0.0.1:7890` |
| `userAgent` | `String?` | 自定义 User-Agent |
| `useMemoryStorage` | `bool` | 使用内存存储（默认 false） |

**高级配置（可选）：**
- 如需更多 HTTP 配置，可传入 `httpConfig` 参数（证书固定、混淆等）

---

## 🔧 关于对接“旧版”Xboard

新版Xboard在HTTP头中，使用标准的"authorization: Bearer $token"格式。
旧版Xboard缺少Bearer字符串，而是使用"authorization: $token"格式。有"Bearer"
存在时调用会认证失败，返回403错误。因此在对接旧版Xboard时需要去掉Bearer
字符串。

这个操作可以在nginx反向代理的配置中实现。例如，

``` nginx
location /api {
    set $auth_header "";
    # Check if the Authorization header exists and starts with "Bearer"
    if ($http_authorization ~* "^Bearer\s+(.+)") {
        set $auth_header $1;
    }
    # Set the modified Authorization header without "Bearer"
    proxy_set_header Authorization $auth_header;

    proxy_pass         http://127.0.0.1:7001/api;
}
```

---

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

---

## 📞 支持

遇到问题？欢迎：

- 📫 提交 [Issue](https://github.com/hakimi-x/flutter_xboard_sdk/issues)
- 💬 参与 [讨论](https://github.com/hakimi-x/flutter_xboard_sdk/discussions)

---

<div align="center">

**[⬆ 回到顶部](#flutter-xboard-sdk)**

Made with ❤️ by Hakimi-X

</div>
