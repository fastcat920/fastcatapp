import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_win_floating/webview_win_floating.dart' as winwv;
import 'package:fl_clash/xboard/features/auth/utils/crisp_url_helper.dart';

const _desktopCrispUserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
    'AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/125.0.0.0 Safari/537.36';

/// Crisp 客服嵌入页面
///
/// 在应用内通过 WebView 加载 Crisp 聊天窗口，无需跳转外部浏览器。
/// 支持 Android、iOS；桌面端使用 desktop_webview_window 独立窗口。
class CrispChatPage extends StatefulWidget {
  final String websiteId;
  final String? crispProxyUrl;
  final String? userScript;
  final Future<String?> Function()? deferredUserScript;

  const CrispChatPage({
    super.key,
    required this.websiteId,
    this.crispProxyUrl,
    this.userScript,
    this.deferredUserScript,
  });

  /// 是否支持内嵌 WebView（桌面端统一使用独立窗口）
  static bool get isSupported => Platform.isAndroid || Platform.isIOS;

  @override
  State<CrispChatPage> createState() => _CrispChatPageState();
}

/// Windows/Linux 桌面端 Crisp 客服页。
///
/// 使用 webview_win_floating 承载 Crisp。主客户端会在 Windows/Linux
/// 启动一个轻量 Flutter 子进程来显示此页面，保持独立窗口体验，同时避免
/// 旧独立 native WebView 窗口异常时连带关闭主客户端。
class DesktopCrispChatPage extends StatefulWidget {
  final String websiteId;
  final String? crispProxyUrl;
  final String? userScript;
  final bool showAppBar;
  final VoidCallback? onClose;

  const DesktopCrispChatPage({
    super.key,
    required this.websiteId,
    this.crispProxyUrl,
    this.userScript,
    this.showAppBar = true,
    this.onClose,
  });

  static bool get isSupported => Platform.isWindows || Platform.isLinux;

  @override
  State<DesktopCrispChatPage> createState() => _DesktopCrispChatPageState();
}

class _DesktopCrispChatPageState extends State<DesktopCrispChatPage> {
  winwv.WinWebViewController? _controller;
  Timer? _sdkFallbackTimer;
  Timer? _embedFallbackTimer;
  bool _usingSdkBootstrap = false;
  bool _usingProxy = false;
  bool _didFallbackToOfficial = false;
  bool _isLoading = true;
  bool _hasTimedOut = false;
  bool _didStartLoading = false;
  bool _didFailStartup = false;
  late bool _isDarkMode;

  @override
  void initState() {
    super.initState();
    _isDarkMode =
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextIsDarkMode = Theme.of(context).brightness == Brightness.dark;
    if (_isDarkMode != nextIsDarkMode) {
      _isDarkMode = nextIsDarkMode;
      unawaited(
        _controller?.setBackgroundColor(
          _customerServiceBackgroundColor(_isDarkMode),
        ),
      );
    }
    if (!_didStartLoading) {
      _didStartLoading = true;
      unawaited(_initDesktopWebView());
    }
  }

  @override
  void dispose() {
    _sdkFallbackTimer?.cancel();
    _embedFallbackTimer?.cancel();
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      unawaited(Future<void>(() async {
        try {
          await controller.setVisibility(false);
          await controller.dispose();
        } catch (_) {}
      }));
    }
    super.dispose();
  }

  Future<void> _initDesktopWebView() async {
    _setLoading();
    try {
      final controller = Platform.isWindows
          ? winwv.WinWebViewController(
              params: const winwv.WindowsWebViewControllerCreationParams(
                profileName: 'fastcat-support',
                suspendDuringDeactive: false,
              ),
            )
          : winwv.WinWebViewController();
      _controller = controller;
      if (mounted) setState(() {});
      await controller.setBackgroundColor(
        _customerServiceBackgroundColor(_isDarkMode),
      );
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setUserAgent(_desktopCrispUserAgent);
      await controller.setNavigationDelegate(
        winwv.WinNavigationDelegate(
          onPageStarted: (url) {
            if (!_usingSdkBootstrap) {
              _usingProxy = _isProxyUrl(url);
            }
            _setLoading();
          },
          onProgress: (progress) {
            if (progress >= 100 && !_usingSdkBootstrap) {
              _finishLoading();
            }
          },
          onPageFinished: (_) {
            if (!_usingSdkBootstrap) {
              unawaited(_injectDirectEmbedMonitor());
            }
            _finishLoading();
          },
          onHttpError: (error) {
            if (!_isCrispEmbedUri(error.request?.uri)) return;
            _handleRouteError();
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == false) return;
            _handleRouteError();
          },
        ),
      );
      await _loadSdkBootstrap();
    } catch (_) {
      _showStartupFailure();
    }
  }

  void _setLoading() {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasTimedOut = false;
      _didFailStartup = false;
    });
  }

  void _finishLoading() {
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _loadSdkBootstrap() async {
    final controller = _controller;
    if (controller == null) return;
    _sdkFallbackTimer?.cancel();
    _embedFallbackTimer?.cancel();
    _usingSdkBootstrap = true;
    _usingProxy = false;
    _didFallbackToOfficial = false;
    _setLoading();
    _sdkFallbackTimer = Timer(
      crispProxyFallbackDelay,
      () => unawaited(_fallbackFromSdkToEmbed()),
    );
    try {
      await controller.loadHtmlString(
        _buildSdkBootstrapHtml(),
        baseUrl: _sdkBootstrapBaseUri().toString(),
      );
    } catch (_) {
      _showStartupFailure();
    }
  }

  Future<void> _fallbackFromSdkToEmbed() async {
    if (!mounted || !_usingSdkBootstrap) return;
    if (await _isCrispReady()) return;
    final preferred = _preferredEmbedUri();
    final usingProxy = isCrispProxyConfigured(widget.crispProxyUrl);
    _loadEmbed(preferred, usingProxy: usingProxy);
  }

  void _loadEmbed(Uri uri, {required bool usingProxy}) {
    final controller = _controller;
    if (controller == null) {
      _showStartupFailure();
      return;
    }
    _sdkFallbackTimer?.cancel();
    _embedFallbackTimer?.cancel();
    _usingSdkBootstrap = false;
    _usingProxy = usingProxy;
    _hasTimedOut = false;
    if (!usingProxy) {
      _didFallbackToOfficial = true;
    }
    _setLoading();
    _embedFallbackTimer = Timer(
      const Duration(seconds: 25),
      () => unawaited(_handleEmbedTimeout()),
    );
    unawaited(controller.loadRequest(uri).catchError((_) {
      _handleRouteError();
    }));
  }

  Future<void> _handleEmbedTimeout() async {
    if (!mounted || _usingSdkBootstrap) return;
    if (await _isCrispReady()) return;
    if (_usingProxy && !_didFallbackToOfficial) {
      _fallbackToOfficialIfNeeded();
      return;
    }
    _showTimeout();
  }

  void _handleRouteError() {
    if (_usingSdkBootstrap) {
      unawaited(_fallbackFromSdkToEmbed());
      return;
    }
    if (_usingProxy && !_didFallbackToOfficial) {
      _fallbackToOfficialIfNeeded();
      return;
    }
    _showTimeout();
  }

  void _fallbackToOfficialIfNeeded() {
    if (_usingSdkBootstrap) {
      unawaited(_fallbackFromSdkToEmbed());
      return;
    }
    if (!_usingProxy || _didFallbackToOfficial) {
      _showTimeout();
      return;
    }
    _didFallbackToOfficial = true;
    _usingProxy = false;
    _loadEmbed(officialCrispEmbedUri(widget.websiteId), usingProxy: false);
  }

  bool _isProxyUrl(String url) {
    final proxy = normalizeCrispProxyUrl(widget.crispProxyUrl);
    return proxy.isNotEmpty && url.startsWith(proxy);
  }

  bool _isProxyEmbedUri(Uri? uri) {
    if (uri == null) return false;
    final proxy = normalizeCrispProxyUrl(widget.crispProxyUrl);
    if (proxy.isEmpty) return false;
    return uri.toString().startsWith(proxy) && uri.path.contains('/chat/embed');
  }

  bool _isCrispEmbedUri(Uri? uri) {
    if (uri == null) return false;
    if (!uri.path.contains('/chat/embed')) return false;
    if (_isProxyEmbedUri(uri)) return true;
    return uri.host == Uri.parse(crispOfficialBaseUrl).host;
  }

  Uri _preferredEmbedUri() {
    return crispEmbedUri(
      websiteId: widget.websiteId,
      proxyUrl: widget.crispProxyUrl,
    );
  }

  Uri _sdkBootstrapBaseUri() {
    final uri = _preferredEmbedUri();
    return uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        'fastcat_bootstrap': 'sdk',
      },
    );
  }

  Future<bool> _isCrispReady() async {
    try {
      final result = await _controller?.runJavaScriptReturningResult('''
(function(){
  try {
    return window.__fastcatCrispReady === true;
  } catch (_) {
    return false;
  }
})();''');
      if (result is bool) return result;
      return result.toString().contains('true');
    } catch (_) {
      return false;
    }
  }

  void _showTimeout() {
    _sdkFallbackTimer?.cancel();
    _embedFallbackTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _hasTimedOut = true;
      _didFailStartup = false;
    });
  }

  void _showStartupFailure() {
    _sdkFallbackTimer?.cancel();
    _embedFallbackTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _hasTimedOut = true;
      _didFailStartup = true;
    });
  }

  String _buildSdkBootstrapHtml() {
    final websiteIdJson = jsonEncode(widget.websiteId);
    final background = _customerServiceBackgroundColorValue(_isDarkMode);
    final foreground = _customerServiceForegroundColorValue(_isDarkMode);
    final userScript = widget.userScript ?? '';
    return '''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
  <title>在线客服</title>
  <style>
    * { box-sizing: border-box; }
    html, body {
      width: 100%;
      height: 100%;
      margin: 0;
      background: $background;
      color: $foreground;
      overflow: hidden;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }
    #loading {
      position: fixed;
      inset: 0;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 12px;
      background: $background;
      color: $foreground;
      font-size: 14px;
      z-index: 2147483647;
    }
    #spinner {
      width: 18px;
      height: 18px;
      border: 2px solid rgba(148, 163, 184, 0.35);
      border-top-color: #2563eb;
      border-radius: 50%;
      animation: spin 0.8s linear infinite;
    }
    @keyframes spin { to { transform: rotate(360deg); } }
  </style>
</head>
<body>
  <div id="loading"><span id="spinner"></span><span id="loading-text">正在连接客服...</span></div>
  <script>
    window.\$crisp = window.\$crisp || [];
    window.CRISP_WEBSITE_ID = $websiteIdJson;
    window.__fastcatCrispReady = false;
    $userScript

    (function(){
      var loading = document.getElementById('loading');
      var loadingText = document.getElementById('loading-text');
      var ready = false;

      function openChat(){
        try {
          window.\$crisp = window.\$crisp || [];
          window.\$crisp.push(["safe", true]);
          window.\$crisp.push(["do", "chat:show"]);
          window.\$crisp.push(["do", "chat:open"]);
        } catch(_) {}
      }

      function markReady(){
        if (ready) return;
        ready = true;
        window.__fastcatCrispReady = true;
        openChat();
        if (loading) loading.style.display = 'none';
      }

      function expandFrames(){
        var frames = document.querySelectorAll('iframe');
        for (var i = 0; i < frames.length; i++) {
          var src = frames[i].src || '';
          if (src.indexOf('crisp') === -1) continue;
          frames[i].style.cssText = 'position:fixed!important;top:0!important;left:0!important;width:100vw!important;height:100vh!important;max-width:none!important;max-height:none!important;border:none!important;border-radius:0!important;z-index:2147483646!important;background:$background!important;';
          var parent = frames[i].parentElement;
          if (parent) parent.style.cssText = 'position:fixed!important;top:0!important;left:0!important;width:100vw!important;height:100vh!important;z-index:2147483646!important;background:$background!important;';
          markReady();
        }
      }

      window.CRISP_READY_TRIGGER = markReady;

      var openTimer = setInterval(function(){
        openChat();
        expandFrames();
      }, 500);
      setTimeout(function(){
        clearInterval(openTimer);
        openChat();
        expandFrames();
        if (!ready && loadingText) loadingText.textContent = '加载较慢，请稍候...';
      }, 15000);

      new MutationObserver(function(){
        openChat();
        expandFrames();
      }).observe(document.documentElement, {
        childList: true,
        subtree: true,
        attributes: true
      });

      var script = document.createElement('script');
      script.src = 'https://client.crisp.chat/l.js';
      script.async = true;
      script.onerror = function(){
        if (loadingText) loadingText.textContent = '客服加载失败，请检查网络后重试';
      };
      document.head.appendChild(script);
    })();
  </script>
</body>
</html>''';
  }

  Future<void> _injectDirectEmbedMonitor() async {
    final background = _customerServiceBackgroundColorValue(_isDarkMode);
    final foreground = _customerServiceForegroundColorValue(_isDarkMode);
    final userScript = widget.userScript ?? '';
    final script = '''
(function(){
  try {
    if (window.__fastcatCrispDirectMonitorInstalled) return;
    window.__fastcatCrispDirectMonitorInstalled = true;
    window.\$crisp = window.\$crisp || [];
    try {
      $userScript
    } catch(_) {}
    window.__fastcatCrispReady = false;
    document.documentElement.style.background = '$background';
    document.documentElement.style.colorScheme = '${_isDarkMode ? 'dark' : 'light'}';
    if (document.body) {
      document.body.style.background = '$background';
      document.body.style.color = '$foreground';
    }
    function markReady(){
      window.__fastcatCrispReady = true;
    }
    function directLooksReady(){
      try {
        var interactive = document.querySelector('textarea,input,[contenteditable="true"],button,a[href^="mailto:"],iframe[src*="crisp"],.crisp-client,[class*="crisp"]');
        if (interactive) markReady();
      } catch(_) {}
    }
    directLooksReady();
    new MutationObserver(directLooksReady).observe(document.documentElement, {
      childList: true,
      subtree: true,
      attributes: true
    });
  } catch(_) {}
})();''';
    try {
      await _controller?.runJavaScript(script);
    } catch (_) {}
  }

  Future<void> _handleRetry() async {
    if (_controller == null || _didFailStartup) {
      final oldController = _controller;
      _controller = null;
      if (oldController != null) {
        unawaited(oldController.dispose());
      }
      await _initDesktopWebView();
      return;
    }
    await _loadSdkBootstrap();
  }

  Color _customerServiceBackgroundColor(bool isDarkMode) {
    return isDarkMode ? const Color(0xFF101010) : const Color(0xFFF5F5F5);
  }

  String _customerServiceBackgroundColorValue(bool isDarkMode) {
    return isDarkMode ? '#101010' : '#f5f5f5';
  }

  String _customerServiceForegroundColorValue(bool isDarkMode) {
    return isDarkMode ? '#f3f4f6' : '#999999';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final backgroundColor = _customerServiceBackgroundColor(_isDarkMode);
    final controller = _controller;
    final body = Stack(
      fit: StackFit.expand,
      children: [
        if (controller != null)
          winwv.WinWebViewWidget(controller: controller)
        else
          const SizedBox.expand(),
        if (_isLoading)
          ColoredBox(
            color: backgroundColor,
            child: const Center(child: CircularProgressIndicator()),
          ),
        if (_hasTimedOut)
          ColoredBox(
            color: backgroundColor,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.support_agent_outlined,
                      size: 32,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _didFailStartup
                          ? l10n.onlineSupportConnectionError
                          : '客服连接超时',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _handleRetry,
                      icon: const Icon(Icons.refresh),
                      label: Text(l10n.refresh),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: widget.showAppBar
          ? AppBar(
              title: Text(l10n.onlineSupportTitle),
              leading: IconButton(
                icon: const Icon(Icons.close),
                tooltip: l10n.close,
                onPressed: widget.onClose ??
                    () => Navigator.of(context, rootNavigator: true).pop(),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: l10n.refresh,
                  onPressed: _handleRetry,
                ),
              ],
            )
          : null,
      body: body,
    );
  }
}

class _CrispChatPageState extends State<CrispChatPage> {
  late final WebViewController _controller;
  Timer? _sdkFallbackTimer;
  Timer? _embedFallbackTimer;
  bool _usingSdkBootstrap = false;
  bool _usingProxy = false;
  bool _didFallbackToOfficial = false;
  bool _isLoading = true;
  bool _hasTimedOut = false;
  bool _deferredUserScriptStarted = false;
  late bool _isDarkMode;
  bool _didStartLoading = false;

  @override
  void initState() {
    super.initState();
    _isDarkMode =
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(_customerServiceBackgroundColor(_isDarkMode))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (!_usingSdkBootstrap) {
              _usingProxy = _isProxyUrl(url);
            }
            if (mounted) {
              setState(() {
                _isLoading = true;
                _hasTimedOut = false;
              });
            }
          },
          onPageFinished: (_) {
            if (!_usingSdkBootstrap) {
              unawaited(_injectDirectEmbedMonitor());
              unawaited(_runDeferredUserScript());
            }
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == false) return;
            _handleRouteError();
          },
          onHttpError: (error) {
            if (!_isCrispEmbedUri(error.request?.uri)) return;
            _handleRouteError();
          },
        ),
      );
    unawaited(_configureAndroidFileSelection(_controller));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextIsDarkMode = Theme.of(context).brightness == Brightness.dark;
    if (_isDarkMode != nextIsDarkMode) {
      _isDarkMode = nextIsDarkMode;
      unawaited(
        _controller.setBackgroundColor(
          _customerServiceBackgroundColor(_isDarkMode),
        ),
      );
    }
    if (!_didStartLoading) {
      _didStartLoading = true;
      _loadPreferredCrispUrl();
    }
  }

  @override
  void dispose() {
    _sdkFallbackTimer?.cancel();
    _embedFallbackTimer?.cancel();
    super.dispose();
  }

  void _loadPreferredCrispUrl() {
    _loadSdkBootstrap();
  }

  void _loadSdkBootstrap() {
    _sdkFallbackTimer?.cancel();
    _embedFallbackTimer?.cancel();
    _usingSdkBootstrap = true;
    _usingProxy = false;
    _didFallbackToOfficial = false;
    _hasTimedOut = false;
    if (mounted) setState(() => _isLoading = true);
    _sdkFallbackTimer = Timer(
      crispProxyFallbackDelay,
      () => unawaited(_fallbackFromSdkToEmbed()),
    );
    unawaited(
      _controller.loadHtmlString(
        _buildSdkBootstrapHtml(),
        baseUrl: _sdkBootstrapBaseUri().toString(),
      ),
    );
  }

  Future<void> _fallbackFromSdkToEmbed() async {
    if (!mounted || !_usingSdkBootstrap) return;
    if (await _isCrispReady()) return;
    final preferred = _preferredEmbedUri();
    final usingProxy = isCrispProxyConfigured(widget.crispProxyUrl);
    _loadEmbed(preferred, usingProxy: usingProxy);
  }

  void _loadEmbed(Uri uri, {required bool usingProxy}) {
    _sdkFallbackTimer?.cancel();
    _embedFallbackTimer?.cancel();
    _usingSdkBootstrap = false;
    _usingProxy = usingProxy;
    _hasTimedOut = false;
    if (!usingProxy) {
      _didFallbackToOfficial = true;
    }
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasTimedOut = false;
      });
    }
    _embedFallbackTimer = Timer(
      const Duration(seconds: 25),
      () => unawaited(_handleEmbedTimeout()),
    );
    unawaited(_controller.loadRequest(uri));
  }

  Future<void> _handleEmbedTimeout() async {
    if (!mounted || _usingSdkBootstrap) return;
    if (await _isCrispReady()) return;
    if (_usingProxy && !_didFallbackToOfficial) {
      _fallbackToOfficialIfNeeded();
      return;
    }
    _showTimeout();
  }

  void _handleRouteError() {
    if (_usingSdkBootstrap) {
      unawaited(_fallbackFromSdkToEmbed());
      return;
    }
    if (_usingProxy && !_didFallbackToOfficial) {
      _fallbackToOfficialIfNeeded();
      return;
    }
    _showTimeout();
  }

  void _fallbackToOfficialIfNeeded() {
    if (_usingSdkBootstrap) {
      unawaited(_fallbackFromSdkToEmbed());
      return;
    }
    if (!_usingProxy || _didFallbackToOfficial) {
      _showTimeout();
      return;
    }
    _didFallbackToOfficial = true;
    _usingProxy = false;
    _loadEmbed(officialCrispEmbedUri(widget.websiteId), usingProxy: false);
  }

  bool _isProxyUrl(String url) {
    final proxy = normalizeCrispProxyUrl(widget.crispProxyUrl);
    return proxy.isNotEmpty && url.startsWith(proxy);
  }

  bool _isProxyEmbedUri(Uri? uri) {
    if (uri == null) return false;
    final proxy = normalizeCrispProxyUrl(widget.crispProxyUrl);
    if (proxy.isEmpty) return false;
    return uri.toString().startsWith(proxy) && uri.path.contains('/chat/embed');
  }

  bool _isCrispEmbedUri(Uri? uri) {
    if (uri == null) return false;
    if (!uri.path.contains('/chat/embed')) return false;
    if (_isProxyEmbedUri(uri)) return true;
    return uri.host == Uri.parse(crispOfficialBaseUrl).host;
  }

  Uri _preferredEmbedUri() {
    return crispEmbedUri(
      websiteId: widget.websiteId,
      proxyUrl: widget.crispProxyUrl,
    );
  }

  Uri _sdkBootstrapBaseUri() {
    final uri = _preferredEmbedUri();
    return uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        'fastcat_bootstrap': 'sdk',
      },
    );
  }

  Future<bool> _isCrispReady() async {
    try {
      final result = await _controller.runJavaScriptReturningResult('''
(function(){
  try {
    return window.__fastcatCrispReady === true;
  } catch (_) {
    return false;
  }
})();''');
      if (result is bool) return result;
      return result.toString().contains('true');
    } catch (_) {
      return false;
    }
  }

  void _showTimeout() {
    _sdkFallbackTimer?.cancel();
    _embedFallbackTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _hasTimedOut = true;
    });
  }

  String _buildSdkBootstrapHtml() {
    final websiteIdJson = jsonEncode(widget.websiteId);
    final background = _customerServiceBackgroundColorValue(_isDarkMode);
    final foreground = _customerServiceForegroundColorValue(_isDarkMode);
    final userScript = widget.userScript ?? '';
    return '''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
  <title>在线客服</title>
  <style>
    * { box-sizing: border-box; }
    html, body {
      width: 100%;
      height: 100%;
      margin: 0;
      background: $background;
      color: $foreground;
      overflow: hidden;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }
    #loading {
      position: fixed;
      inset: 0;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 12px;
      background: $background;
      color: $foreground;
      font-size: 14px;
      z-index: 2147483647;
    }
    #spinner {
      width: 18px;
      height: 18px;
      border: 2px solid rgba(148, 163, 184, 0.35);
      border-top-color: #2563eb;
      border-radius: 50%;
      animation: spin 0.8s linear infinite;
    }
    @keyframes spin { to { transform: rotate(360deg); } }
  </style>
</head>
<body>
  <div id="loading"><span id="spinner"></span><span id="loading-text">正在连接客服...</span></div>
  <script>
    window.\$crisp = window.\$crisp || [];
    window.CRISP_WEBSITE_ID = $websiteIdJson;
    window.__fastcatCrispReady = false;
    $userScript

    (function(){
      var loading = document.getElementById('loading');
      var loadingText = document.getElementById('loading-text');
      var ready = false;

      function openChat(){
        try {
          window.\$crisp = window.\$crisp || [];
          window.\$crisp.push(["safe", true]);
          window.\$crisp.push(["do", "chat:show"]);
          window.\$crisp.push(["do", "chat:open"]);
        } catch(_) {}
      }

      function markReady(){
        if (ready) return;
        ready = true;
        window.__fastcatCrispReady = true;
        openChat();
        if (loading) loading.style.display = 'none';
      }

      function expandFrames(){
        var frames = document.querySelectorAll('iframe');
        for (var i = 0; i < frames.length; i++) {
          var src = frames[i].src || '';
          if (src.indexOf('crisp') === -1) continue;
          frames[i].style.cssText = 'position:fixed!important;top:0!important;left:0!important;width:100vw!important;height:100vh!important;max-width:none!important;max-height:none!important;border:none!important;border-radius:0!important;z-index:2147483646!important;background:$background!important;';
          var parent = frames[i].parentElement;
          if (parent) parent.style.cssText = 'position:fixed!important;top:0!important;left:0!important;width:100vw!important;height:100vh!important;z-index:2147483646!important;background:$background!important;';
          markReady();
        }
      }

      window.CRISP_READY_TRIGGER = markReady;

      var openTimer = setInterval(function(){
        openChat();
        expandFrames();
      }, 500);
      setTimeout(function(){
        clearInterval(openTimer);
        openChat();
        expandFrames();
        if (!ready && loadingText) loadingText.textContent = '加载较慢，请稍候...';
      }, 15000);

      new MutationObserver(function(){
        openChat();
        expandFrames();
      }).observe(document.documentElement, {
        childList: true,
        subtree: true,
        attributes: true
      });

      var script = document.createElement('script');
      script.src = 'https://client.crisp.chat/l.js';
      script.async = true;
      script.onerror = function(){
        if (loadingText) loadingText.textContent = '客服加载失败，请检查网络后重试';
      };
      document.head.appendChild(script);
    })();
  </script>
</body>
</html>''';
  }

  Future<void> _injectDirectEmbedMonitor() async {
    final background = _customerServiceBackgroundColorValue(_isDarkMode);
    final foreground = _customerServiceForegroundColorValue(_isDarkMode);
    final userScript = widget.userScript ?? '';
    final script = '''
(function(){
  try {
    if (window.__fastcatCrispDirectMonitorInstalled) return;
    window.__fastcatCrispDirectMonitorInstalled = true;
    window.\$crisp = window.\$crisp || [];
    try {
      $userScript
    } catch(_) {}
    window.__fastcatCrispReady = false;
    document.documentElement.style.background = '$background';
    document.documentElement.style.colorScheme = '${_isDarkMode ? 'dark' : 'light'}';
    if (document.body) {
      document.body.style.background = '$background';
      document.body.style.color = '$foreground';
    }
    function markReady(){
      window.__fastcatCrispReady = true;
    }
    function directLooksReady(){
      try {
        var interactive = document.querySelector('textarea,input,[contenteditable="true"],button,a[href^="mailto:"],iframe[src*="crisp"],.crisp-client,[class*="crisp"]');
        if (interactive) markReady();
      } catch(_) {}
    }
    directLooksReady();
    new MutationObserver(directLooksReady).observe(document.documentElement, {
      childList: true,
      subtree: true,
      attributes: true
    });
  } catch(_) {}
})();''';
    try {
      await _controller.runJavaScript(script);
    } catch (_) {}
  }

  Future<void> _runDeferredUserScript() async {
    if (_deferredUserScriptStarted) return;
    final deferredUserScript = widget.deferredUserScript;
    if (deferredUserScript == null) return;
    _deferredUserScriptStarted = true;
    try {
      final script = await deferredUserScript();
      if (!mounted || script == null || script.isEmpty) return;
      await _controller.runJavaScript(script);
    } catch (_) {}
  }

  Future<void> _configureAndroidFileSelection(
      WebViewController controller) async {
    if (!Platform.isAndroid) return;

    final platformController = controller.platform;
    if (platformController is AndroidWebViewController) {
      await platformController.setOnShowFileSelector(_showAndroidFileSelector);
    }
  }

  Future<List<String>> _showAndroidFileSelector(
    FileSelectorParams params,
  ) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: params.mode == FileSelectorMode.openMultiple,
      type: _filePickerType(params.acceptTypes),
      withData: false,
    );

    if (result == null) return <String>[];

    return result.files
        .map(_fileSelectorUriForAndroid)
        .whereType<String>()
        .toList(growable: false);
  }

  FileType _filePickerType(List<String> acceptTypes) {
    final types = acceptTypes
        .map((type) => type.trim().toLowerCase())
        .where((type) => type.isNotEmpty)
        .toList(growable: false);
    if (types.isEmpty || types.contains('*/*')) return FileType.any;
    if (types.every((type) => type == 'image/*' || type.startsWith('image/'))) {
      return FileType.image;
    }
    if (types.every((type) => type == 'video/*' || type.startsWith('video/'))) {
      return FileType.video;
    }
    if (types.every((type) => type == 'audio/*' || type.startsWith('audio/'))) {
      return FileType.audio;
    }
    return FileType.any;
  }

  String? _fileSelectorUriForAndroid(PlatformFile file) {
    final identifier = file.identifier;
    if (identifier != null && identifier.isNotEmpty) return identifier;

    final path = file.path;
    if (path == null || path.isEmpty) return null;
    return Uri.file(path).toString();
  }

  Color _customerServiceBackgroundColor(bool isDarkMode) {
    return isDarkMode ? const Color(0xFF101010) : const Color(0xFFF5F5F5);
  }

  String _customerServiceBackgroundColorValue(bool isDarkMode) {
    return isDarkMode ? '#101010' : '#f5f5f5';
  }

  String _customerServiceForegroundColorValue(bool isDarkMode) {
    return isDarkMode ? '#f3f4f6' : '#999999';
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = _customerServiceBackgroundColor(_isDarkMode);
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('在线客服'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
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
          if (_hasTimedOut)
            Positioned.fill(
              child: ColoredBox(
                color: backgroundColor,
                child: const Center(
                  child: Text(
                    '客服连接超时',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
