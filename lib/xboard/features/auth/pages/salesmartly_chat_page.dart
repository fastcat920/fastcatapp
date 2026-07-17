import 'dart:async';
import 'dart:io';
import 'package:fl_clash/xboard/features/auth/utils/customer_service_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:fl_clash/l10n/l10n.dart';

/// SalesSmartly 客服嵌入页面（Android/iOS/macOS）
///
/// 官方 JSSDK 文档：https://help.salesmartly.com/docs/development-docking
///
/// Android/iOS: loadHtmlString 加载含 SDK 的 HTML
/// macOS: loadHtmlString/document.write 在 WKWebView 中有灰屏/黑屏问题，
///        改为启动本地 HTTP 服务器提供 HTML，WebView 加载 localhost URL
class SalesmarylyChatPage extends StatefulWidget {
  final String scriptUrl;
  final VoidCallback? onBackPressed;
  final ValueListenable<CustomerServiceSessionState>? sessionListenable;

  const SalesmarylyChatPage({
    super.key,
    required this.scriptUrl,
    this.onBackPressed,
    this.sessionListenable,
  });

  static bool get isSupported =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  @override
  State<SalesmarylyChatPage> createState() => _SalesmarylyChatPageState();
}

class _SalesmarylyChatPageState extends State<SalesmarylyChatPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;
  late bool _isDarkMode;
  bool _didStartLoading = false;
  HttpServer? _localServer;
  int _lastAppliedRestoreToken = -1;

  String _buildHtml() {
    final escaped =
        widget.scriptUrl.replaceAll('&', '&amp;').replaceAll('"', '&quot;');
    final background = _customerServiceBackgroundColor(_isDarkMode);
    final foreground = _customerServiceForegroundColor(_isDarkMode);
    return '''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body { width: 100%; height: 100%; background: $background; }
    #ss_loading {
      display: flex; align-items: center; justify-content: center;
      height: 100%; color: $foreground;
      font-family: -apple-system, sans-serif; font-size: 14px;
    }
  </style>
</head>
<body>
  <div id="ss_loading">正在连接客服...</div>
  <script>
    var s = document.createElement('script');
    s.src = "$escaped";
    s.id = 'ss_chat';
    s.onload = function() {
      (function w() {
        if (window.ssq && typeof window.ssq === 'function') {
          ssq.push('chatOpen');
          ssq.push('onReady', function() {
            ssq.push('chatOpen');
            var e = document.getElementById('ss_loading');
            if (e) e.style.display = 'none';
          });
        } else {
          setTimeout(w, 300);
        }
      })();
    };
    s.onerror = function() {
      var e = document.getElementById('ss_loading');
      if (e) e.textContent = '加载失败，请检查网络后重试';
    };
    document.head.appendChild(s);

    new MutationObserver(function() {
      var fs = document.querySelectorAll('iframe');
      for (var i = 0; i < fs.length; i++) {
        var src = fs[i].src || '';
        if (src.indexOf('salesmartly') !== -1 || src.indexOf('ssm') !== -1) {
          fs[i].style.cssText = 'position:fixed!important;top:0!important;left:0!important;width:100vw!important;height:100vh!important;max-width:none!important;max-height:none!important;border:none!important;border-radius:0!important;z-index:99999!important;';
          var p = fs[i].parentElement;
          if (p) p.style.cssText = 'position:fixed!important;top:0!important;left:0!important;width:100vw!important;height:100vh!important;z-index:99999!important;';
          var e = document.getElementById('ss_loading');
          if (e) e.style.display = 'none';
        }
      }
    }).observe(document.documentElement, { childList: true, subtree: true, attributes: true });

    setTimeout(function() {
      var e = document.getElementById('ss_loading');
      if (e && e.style.display !== 'none') e.textContent = '加载超时，请检查网络后重试';
    }, 20000);
  </script>
</body>
</html>''';
  }

  /// macOS：启动本地 HTTP 服务器，返回端口号
  Future<int> _startLocalServer() async {
    _localServer?.close();
    final html = _buildHtml();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _localServer = server;
    server.listen((request) {
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.html
        ..headers.set('Cache-Control', 'no-cache')
        ..write(html);
      request.response.close();
    });
    return server.port;
  }

  @override
  void initState() {
    super.initState();
    _isDarkMode =
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(_webViewBackgroundColor(_isDarkMode))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame ?? true) {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _hasError = true;
                });
              }
            }
          },
        ),
      );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextIsDarkMode = Theme.of(context).brightness == Brightness.dark;
    if (_isDarkMode != nextIsDarkMode) {
      _isDarkMode = nextIsDarkMode;
      unawaited(_applySystemTheme());
    }
    if (!_didStartLoading) {
      _didStartLoading = true;
      _loadContent();
    }
  }

  Future<void> _loadContent() async {
    if (Platform.isMacOS) {
      // macOS: WKWebView 的 loadHtmlString 有灰屏问题
      // 启动本地 HTTP 服务器，WebView 加载 localhost URL
      final port = await _startLocalServer();
      _controller.loadRequest(Uri.parse('http://localhost:$port'));
    } else {
      _controller.loadHtmlString(_buildHtml(),
          baseUrl: 'https://www.salesmartly.com');
    }
  }

  @override
  void dispose() {
    _localServer?.close();
    super.dispose();
  }

  void _retry() {
    setState(() {
      _hasError = false;
      _isLoading = true;
    });
    _loadContent();
  }

  Color _webViewBackgroundColor(bool isDarkMode) {
    return isDarkMode ? const Color(0xFF101010) : const Color(0xFFF5F5F5);
  }

  String _customerServiceBackgroundColor(bool isDarkMode) {
    return isDarkMode ? '#101010' : '#f5f5f5';
  }

  String _customerServiceForegroundColor(bool isDarkMode) {
    return isDarkMode ? '#d1d5db' : '#999999';
  }

  Future<void> _applySystemTheme() async {
    final background = _customerServiceBackgroundColor(_isDarkMode);
    final foreground = _customerServiceForegroundColor(_isDarkMode);
    try {
      await _controller
          .setBackgroundColor(_webViewBackgroundColor(_isDarkMode));
      await _controller.runJavaScript('''
(function(){
  try {
    document.documentElement.style.background = '$background';
    document.documentElement.style.colorScheme = '${_isDarkMode ? 'dark' : 'light'}';
    if (document.body) {
      document.body.style.background = '$background';
      document.body.style.color = '$foreground';
    }
    var loading = document.getElementById('ss_loading');
    if (loading) {
      loading.style.background = '$background';
      loading.style.color = '$foreground';
    }
    var frames = document.querySelectorAll('iframe');
    for (var i = 0; i < frames.length; i++) {
      frames[i].style.background = '$background';
    }
  } catch (_) {}
})();''');
    } catch (_) {}
  }

  void _syncSessionState(CustomerServiceSessionState session) {
    final nextIsDarkMode = session.brightness == Brightness.dark;
    if (_isDarkMode != nextIsDarkMode) {
      _isDarkMode = nextIsDarkMode;
      unawaited(_applySystemTheme());
    }
    if (session.isVisible && _lastAppliedRestoreToken != session.restoreToken) {
      _lastAppliedRestoreToken = session.restoreToken;
      unawaited(_applySystemTheme());
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget buildScaffold(CustomerServiceSessionState? session) {
      if (session != null) {
        _syncSessionState(session);
      }
      final backgroundColor = _webViewBackgroundColor(_isDarkMode);
      final isVisible = session?.isVisible ?? true;
      return PopScope(
        canPop: widget.onBackPressed == null || !isVisible,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) widget.onBackPressed?.call();
        },
        child: Scaffold(
          backgroundColor: backgroundColor,
          appBar: AppBar(
            title: Text(AppLocalizations.of(context).xboardOnlineSupport),
            leading: BackButton(
              onPressed: widget.onBackPressed ??
                  () => Navigator.of(context, rootNavigator: true).pop(),
            ),
          ),
          body: Stack(
            children: [
              WebViewWidget(controller: _controller),
              if (_isLoading)
                Positioned.fill(
                  child: ColoredBox(
                    color: backgroundColor,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                ),
              if (_hasError)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                          AppLocalizations.of(context)
                              .xboardLoadFailedCheckNetwork,
                          style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _retry,
                        child: Text(AppLocalizations.of(context).xboardRetry),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    }

    final session = widget.sessionListenable;
    if (session == null) return buildScaffold(null);
    return ValueListenableBuilder<CustomerServiceSessionState>(
      valueListenable: session,
      builder: (_, currentSession, __) => buildScaffold(currentSession),
    );
  }
}
