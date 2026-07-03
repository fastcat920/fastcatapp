import 'dart:async';
import 'dart:io';

import 'package:webview_cef/webview_cef.dart' as cef;

const linuxCefDesktopUserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
    'AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/125.0.0.0 Safari/537.36 FastCat/3.5.5';

class LinuxCefWebviewManager {
  LinuxCefWebviewManager._();

  static Future<void>? _initializing;

  static Future<void> ensureInitialized({
    String userAgent = linuxCefDesktopUserAgent,
  }) {
    if (!Platform.isLinux) {
      return Future<void>.error(
        UnsupportedError('CEF WebView is only enabled on Linux'),
      );
    }

    final manager = cef.WebviewManager();
    if (manager.value) return Future<void>.value();
    return _initializing ??= _initialize(userAgent);
  }

  static Future<void> _initialize(String userAgent) async {
    try {
      await cef.WebviewManager().initialize(userAgent: userAgent);
    } catch (_) {
      _initializing = null;
      rethrow;
    }
  }

  static String htmlDataUrl(String html) {
    return 'data:text/html;charset=utf-8,${Uri.encodeComponent(html)}';
  }
}
