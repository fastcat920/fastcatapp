import 'dart:io';

import 'package:win32_registry/win32_registry.dart';

/// 检测系统是否安装了 WebView2 Runtime。
///
/// LTSC / 精简版 Win11 默认不带 Edge，意味着也不带 WebView2 Runtime——
/// 任何 webview_flutter / desktop_webview_window 触发的 WebView2 初始化
/// 都会让那个页面白屏（主窗口 Flutter Skia 不依赖 WebView2，不受影响）。
///
/// 检测依据：微软官方文档列出的三个注册表位置，任一存在且 `pv` 非空即视为已装。
/// 文档参考：learn.microsoft.com/microsoft-edge/webview2/concepts/distribution
class WebView2Check {
  static bool? _cached;

  /// 缓存结果，第一次调用查注册表，后续直接返回。
  static bool isInstalled() {
    if (_cached != null) return _cached!;
    if (!Platform.isWindows) {
      _cached = true; // 非 Windows 平台不需要这个 Runtime
      return true;
    }
    _cached = _probeRegistry();
    return _cached!;
  }

  /// 强制重新检查（用户安装 Runtime 后能立刻生效，不必重启 App）。
  static void invalidateCache() {
    _cached = null;
  }

  static bool _probeRegistry() {
    const guid = '{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}';
    // 三个候选位置：x64 系统级、x86 系统级、用户级
    final candidates = <(RegistryHive, String)>[
      (RegistryHive.localMachine,
          r'SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\' + guid),
      (RegistryHive.localMachine,
          r'SOFTWARE\Microsoft\EdgeUpdate\Clients\' + guid),
      (RegistryHive.currentUser,
          r'SOFTWARE\Microsoft\EdgeUpdate\Clients\' + guid),
    ];
    for (final (hive, path) in candidates) {
      try {
        final key = Registry.openPath(hive, path: path);
        final pv = key.getValueAsString('pv');
        key.close();
        if (pv != null && pv.isNotEmpty && pv != '0.0.0.0') {
          return true;
        }
      } catch (_) {
        // 这个候选不存在 / 没权限，继续下一个
      }
    }
    return false;
  }
}
