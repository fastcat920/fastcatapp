/// User-Agent 配置管理
library;

import 'package:fl_clash/state.dart';

/// User-Agent 使用场景枚举
enum UserAgentScenario {
  /// 订阅下载
  subscription,

  /// 并发订阅竞速
  subscriptionRacing,

  /// 消息附件下载
  attachment,
}

/// User-Agent 配置
///
/// 订阅下载使用与主程序相同的 UA（含 clash-verge/meta/flclash 标识），
/// 确保服务端正确匹配 ClashMeta 协议（支持 TUIC/Hysteria 等）。
class UserAgentConfig {
  static Future<String> get(UserAgentScenario scenario) async {
    final rawUa = switch (scenario) {
      UserAgentScenario.subscription => globalState.ua,
      UserAgentScenario.subscriptionRacing => globalState.ua,
      UserAgentScenario.attachment => globalState.ua,
    };
    // HTTP header 只允许 ASCII 可打印字符 (0x20-0x7E)。
    // 用户自定义 UA 可能包含中文等非 ASCII 字符，会导致 dart:io
    // 的 HttpClientRequest.headers.set 抛出 FormatException。
    // 这里将非 ASCII 字符替换为 '?'，保证 HTTP 请求不会因 UA 崩溃。
    return _sanitizeForHttp(rawUa);
  }

  /// 将字符串中的非 ASCII 字符替换为 '?'，确保可安全用于 HTTP header
  static String _sanitizeForHttp(String value) {
    final buffer = StringBuffer();
    for (final codeUnit in value.codeUnits) {
      if (codeUnit >= 0x20 && codeUnit <= 0x7E) {
        buffer.writeCharCode(codeUnit);
      } else {
        buffer.write('?');
      }
    }
    return buffer.toString();
  }
}
