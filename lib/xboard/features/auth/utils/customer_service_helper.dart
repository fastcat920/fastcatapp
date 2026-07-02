import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:fl_clash/common/color.dart';
import 'package:fl_clash/common/path.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';
import 'package:fl_clash/xboard/config/gateway_config.dart';
import 'package:fl_clash/xboard/config/xboard_config.dart';
import 'package:fl_clash/xboard/features/auth/auth.dart';
import 'package:fl_clash/xboard/domain/domain.dart';
import 'package:fl_clash/xboard/features/auth/pages/crisp_chat_page.dart';
import 'package:fl_clash/xboard/features/auth/pages/salesmartly_chat_page.dart';
import 'package:fl_clash/xboard/features/auth/utils/crisp_url_helper.dart';
import 'package:fl_clash/xboard/core/core.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';

const _logger = FileLogger('customer_service_helper.dart');
const _deviceGatewayApiPrefix = gatewayApiPrefix;
const _desktopCustomerServiceWindowWidth = 420;
const _desktopCustomerServiceWindowHeight = 680;
const _crispProxyProbeTimeout = Duration(seconds: 4);
const _crispProxyProbePreviewBytes = 4096;
const _crispProxyUsableCacheTtl = Duration(minutes: 10);
const _crispUserDataResolveTimeout = Duration(milliseconds: 1800);
const _desktopCrispRouteFallbackDelay = Duration(seconds: 12);

/// 统一客服入口：按业务约定仅使用 Crisp（远程优先，本地兜底）
///
/// Android/iOS → 内嵌 WebView（webview_flutter）
/// Windows/macOS/Linux → 独立 WebView 窗口（desktop_webview_window）
class CustomerServiceHelper {
  CustomerServiceHelper._();

  static Future<String>? _webview2DataFolderFuture;
  static Future<bool>? _desktopWebviewAvailableFuture;
  static Future<String>? _fallbackCrispWebsiteIdFuture;
  static Future<String>? _fallbackCrispProxyUrlFuture;
  static _PendingCrispProxyProbe? _usableCrispProxyProbe;
  static _CrispProxyCacheEntry? _usableCrispProxyCache;
  static Webview? _desktopCustomerServiceWebview;
  static Future<Webview?>? _desktopCustomerServiceOpening;
  static Brightness? _desktopCustomerServiceBrightness;
  static String? _desktopCustomerServiceAccent;

  /// 是否有任何客服渠道可用（仅远程 Crisp）
  static bool get isAvailable => XBoardConfig.crispWebsiteId.isNotEmpty;

  static bool get _isDesktopPlatform =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  static int get _desktopCustomerServiceTitleBarHeight =>
      Platform.isWindows || Platform.isLinux ? 0 : 40;

  static bool _isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  static String _customerServiceBackground(bool isDarkMode) {
    return isDarkMode ? '#101010' : '#f5f5f5';
  }

  static String _customerServiceForeground(bool isDarkMode) {
    return isDarkMode ? '#f3f4f6' : '#999999';
  }

  static String _customerServiceAccent(
    bool isDarkMode, {
    Color? accentColor,
  }) {
    return accentColor?.hex ?? (isDarkMode ? '#60a5fa' : '#2563eb');
  }

  static Brightness _customerServiceBrightness(bool isDarkMode) {
    return isDarkMode ? Brightness.dark : Brightness.light;
  }

  static void syncDesktopTheme(
    Brightness brightness, {
    Color? accentColor,
  }) {
    if (!_isDesktopPlatform) return;
    final accent = _customerServiceAccent(
      brightness == Brightness.dark,
      accentColor: accentColor,
    );
    if (_desktopCustomerServiceBrightness == brightness &&
        _desktopCustomerServiceAccent == accent) {
      return;
    }
    _desktopCustomerServiceBrightness = brightness;
    _desktopCustomerServiceAccent = accent;
    final webview = _desktopCustomerServiceWebview;
    if (webview == null) return;
    unawaited(_applyDesktopCustomerServiceTheme(
      webview,
      isDarkMode: brightness == Brightness.dark,
      accent: accent,
    ));
  }

  static Future<void> _applyDesktopCustomerServiceTheme(
    Webview webview, {
    required bool isDarkMode,
    String? accent,
  }) async {
    final brightness = _customerServiceBrightness(isDarkMode);
    final effectiveAccent = accent ??
        _desktopCustomerServiceAccent ??
        _customerServiceAccent(isDarkMode);
    _desktopCustomerServiceBrightness = brightness;
    _desktopCustomerServiceAccent = effectiveAccent;
    try {
      webview.setBrightness(brightness);
    } catch (e) {
      _logger.debug('[CustomerService] 更新客服窗口系统主题失败: $e');
    }
    try {
      await webview.evaluateJavaScript(
        _buildApplyCustomerServiceThemeScript(
          isDarkMode,
          accent: effectiveAccent,
        ),
      );
    } catch (e) {
      _logger.debug('[CustomerService] 更新客服窗口页面主题失败: $e');
    }
  }

  static String _buildApplyCustomerServiceThemeScript(
    bool isDarkMode, {
    required String accent,
  }) {
    final payload = jsonEncode({
      'isDark': isDarkMode,
      'background': _customerServiceBackground(isDarkMode),
      'foreground': _customerServiceForeground(isDarkMode),
      'accent': accent,
    });
    return '''
(function(){
  try {
    var theme = $payload;
    if (typeof window.__fastcatApplyCustomerServiceTheme === 'function') {
      window.__fastcatApplyCustomerServiceTheme(theme);
      return 'applied';
    }
    document.documentElement.style.background = theme.background;
    document.documentElement.style.colorScheme = theme.isDark ? 'dark' : 'light';
    if (document.body) {
      document.body.style.background = theme.background;
      document.body.style.color = theme.foreground;
    }
    var style = document.getElementById('fastcat-customer-service-theme');
    if (!style) {
      style = document.createElement('style');
      style.id = 'fastcat-customer-service-theme';
      (document.head || document.documentElement).appendChild(style);
    }
    style.textContent = 'html,body,#page,.site-wrapper,.chat-common{background:' + theme.background + '!important;color:' + theme.foreground + '!important;color-scheme:' + (theme.isDark ? 'dark' : 'light') + '!important;}';
    return 'applied';
  } catch (_) {
    return 'failed';
  }
})();''';
  }

  static Future<Webview?> _reuseDesktopCustomerServiceWindow({
    required bool isDarkMode,
  }) async {
    final webview = _desktopCustomerServiceWebview;
    if (webview != null) {
      final activated = await _activateDesktopCustomerServiceWindow(
        webview,
        isDarkMode: isDarkMode,
      );
      if (activated) return webview;
      _clearDesktopCustomerServiceWindow(webview);
    }

    final opening = _desktopCustomerServiceOpening;
    if (opening != null) {
      final openingWebview = await opening;
      if (openingWebview != null) {
        final activated = await _activateDesktopCustomerServiceWindow(
          openingWebview,
          isDarkMode: isDarkMode,
        );
        if (activated) return openingWebview;
        _clearDesktopCustomerServiceWindow(openingWebview);
      }
    }
    return null;
  }

  static Future<bool> _activateDesktopCustomerServiceWindow(
    Webview webview, {
    required bool isDarkMode,
  }) async {
    try {
      await webview.setWebviewWindowVisibility(true);
      await _applyDesktopCustomerServiceTheme(
        webview,
        isDarkMode: isDarkMode,
      );
      return true;
    } catch (e) {
      _logger.debug('[CustomerService] 激活已有客服窗口失败: $e');
      return false;
    }
  }

  static void _trackDesktopCustomerServiceWindow(Webview webview) {
    _desktopCustomerServiceWebview = webview;
    unawaited(webview.onClose.whenComplete(() {
      _clearDesktopCustomerServiceWindow(webview);
    }));
  }

  static void _clearDesktopCustomerServiceWindow(Webview? webview) {
    if (webview == null || identical(_desktopCustomerServiceWebview, webview)) {
      _desktopCustomerServiceWebview = null;
      _desktopCustomerServiceBrightness = null;
    }
  }

  /// 预热客服启动所需的轻量资源，减少首次点击后的等待。
  static void prewarm() {
    if (XBoardConfig.crispWebsiteId.trim().isEmpty) {
      unawaited(_fallbackCrispWebsiteId());
    }
    if (XBoardConfig.crispProxyUrl.trim().isEmpty) {
      unawaited(_fallbackCrispProxyUrl());
    }
    unawaited(_prewarmCrispRoute());
    if (_isDesktopPlatform) {
      unawaited(_isDesktopWebviewAvailable());
      if (Platform.isWindows) {
        unawaited(_webview2DataFolder());
      }
    }
  }

  static Future<void> _prewarmCrispRoute() async {
    try {
      final websiteId = await _resolveCrispWebsiteId();
      if (websiteId.isEmpty) return;
      await _resolveUsableCrispProxyUrl(websiteId);
    } catch (e) {
      _logger.debug('[Crisp] 预热客服线路失败: $e');
    }
  }

  /// 获取 WebView2 用户数据目录（可写路径）
  static Future<String> _webview2DataFolder() async {
    return _webview2DataFolderFuture ??= () async {
      final dir = await appPath.homeDirPath;
      return '$dir/webview2_data';
    }();
  }

  /// 检查桌面端 WebView2 是否可用
  static Future<bool> _isDesktopWebviewAvailable() async {
    if (!Platform.isWindows) return true;
    return _desktopWebviewAvailableFuture ??= () async {
      try {
        return await WebviewWindow.isWebviewAvailable();
      } catch (_) {
        return false;
      }
    }();
  }

  static Future<String> _fallbackCrispWebsiteId() {
    return _fallbackCrispWebsiteIdFuture ??= () async {
      try {
        return (await ConfigFileLoaderHelper.getFallbackCrispWebsiteId())
            .trim();
      } catch (e) {
        _logger.debug('[Crisp] 读取本地客服配置失败: $e');
        return '';
      }
    }();
  }

  static Future<String> _fallbackCrispProxyUrl() {
    return _fallbackCrispProxyUrlFuture ??= () async {
      try {
        return normalizeCrispProxyUrl(
          await ConfigFileLoaderHelper.getFallbackCrispProxyUrl(),
        );
      } catch (e) {
        _logger.debug('[Crisp] 读取本地客服代理配置失败: $e');
        return '';
      }
    }();
  }

  static Future<String> _resolveCrispWebsiteId() async {
    final remoteCrispId = XBoardConfig.crispWebsiteId.trim();
    if (remoteCrispId.isNotEmpty) return remoteCrispId;
    return _fallbackCrispWebsiteId();
  }

  static Future<String> _resolveCrispProxyUrl() async {
    final remoteProxyUrl = normalizeCrispProxyUrl(XBoardConfig.crispProxyUrl);
    if (remoteProxyUrl.isNotEmpty) return remoteProxyUrl;
    return _fallbackCrispProxyUrl();
  }

  static Future<String> _resolveUsableCrispProxyUrl(String websiteId) async {
    final proxyUrl = await _resolveCrispProxyUrl();
    if (!isCrispProxyConfigured(proxyUrl)) return '';
    final now = DateTime.now();
    final cached = _usableCrispProxyCache;
    if (cached != null && cached.matches(websiteId, proxyUrl, now)) {
      return cached.usableProxyUrl;
    }

    final pending = _usableCrispProxyProbe;
    if (pending != null &&
        pending.websiteId == websiteId &&
        pending.proxyUrl == proxyUrl) {
      return pending.future;
    }

    final future = () async {
      final proxyEmbedUri = crispEmbedUri(
        websiteId: websiteId,
        proxyUrl: proxyUrl,
      );
      final usable = await _isCrispProxyEmbedUsable(proxyEmbedUri);
      final usableProxyUrl = usable ? proxyUrl : '';
      _usableCrispProxyCache = _CrispProxyCacheEntry(
        websiteId: websiteId,
        proxyUrl: proxyUrl,
        usableProxyUrl: usableProxyUrl,
        createdAt: DateTime.now(),
      );
      if (!usable) {
        _logger.warning('[Crisp] 代理预检失败，使用官方域名: $proxyEmbedUri');
      }
      return usableProxyUrl;
    }();

    _usableCrispProxyProbe = _PendingCrispProxyProbe(
      websiteId: websiteId,
      proxyUrl: proxyUrl,
      future: future,
    );
    try {
      return await future;
    } finally {
      if (identical(_usableCrispProxyProbe?.future, future)) {
        _usableCrispProxyProbe = null;
      }
    }
  }

  static Future<bool> _isCrispProxyEmbedUsable(Uri uri) async {
    final client = HttpClient()..connectionTimeout = _crispProxyProbeTimeout;
    try {
      final request = await client.getUrl(uri).timeout(_crispProxyProbeTimeout);
      request
        ..followRedirects = true
        ..maxRedirects = 3;
      request.headers.set(HttpHeaders.acceptHeader, 'text/html,*/*');
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Fastcat-Crisp-Proxy-Probe',
      );
      final response = await request.close().timeout(_crispProxyProbeTimeout);
      final statusCode = response.statusCode;
      final preview = await _readCrispProxyProbePreview(response);
      if (statusCode < 200 || statusCode >= 400) {
        _logger.warning('[Crisp] 代理预检 HTTP $statusCode: $uri');
        return false;
      }
      if (_looksLikeCrispProxyErrorPage(preview)) {
        _logger.warning('[Crisp] 代理预检命中错误页: $uri');
        return false;
      }
      return true;
    } catch (e) {
      _logger.warning('[Crisp] 代理预检异常: $e');
      return false;
    } finally {
      client.close(force: true);
    }
  }

  static Future<String> _readCrispProxyProbePreview(
    HttpClientResponse response,
  ) async {
    final bytes = <int>[];
    try {
      await for (final chunk in response.timeout(_crispProxyProbeTimeout)) {
        final remaining = _crispProxyProbePreviewBytes - bytes.length;
        if (remaining <= 0) break;
        bytes.addAll(chunk.length > remaining ? chunk.take(remaining) : chunk);
        if (bytes.length >= _crispProxyProbePreviewBytes) break;
      }
    } catch (_) {}
    return utf8.decode(bytes, allowMalformed: true);
  }

  static bool _looksLikeCrispProxyErrorPage(String preview) {
    final lower = preview.toLowerCase();
    return lower.contains('404 not found') ||
        lower.contains('502 bad gateway') ||
        lower.contains('503 service temporarily unavailable') ||
        lower.contains('504 gateway') ||
        lower.contains('upstream') && lower.contains('nginx');
  }

  /// 打开客服页面
  static Future<void> open(BuildContext context) async {
    final crispId = await _resolveCrispWebsiteId();
    if (crispId.isNotEmpty) {
      if (!context.mounted) return;
      final ipDataFuture = _resolveCrispIPDataForInitialInjection(context);
      final crispProxyUrl = await _resolveUsableCrispProxyUrl(crispId);
      if (!context.mounted) return;
      final ipData = await ipDataFuture;
      if (!context.mounted) return;
      final isDarkMode = _isDarkMode(context);
      final userScript = _buildCrispUserScript(context, ipData: ipData);
      if (_isDesktopPlatform) {
        await _openCrispInDesktopWebview(
          crispId,
          crispProxyUrl: crispProxyUrl,
          isDarkMode: isDarkMode,
          userScript: userScript,
        );
        return;
      }
      _openCrisp(
        context,
        crispId,
        userScript: userScript,
        crispProxyUrl: crispProxyUrl,
      );
      return;
    }
    XBoardNotification.showError('未配置在线客服');
  }

  // ignore: unused_element
  static void _openSalesmartly(BuildContext context, String scriptUrl) {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      // 桌面端：用 desktop_webview_window 独立窗口
      _openSalesmartlyInDesktopWebview(
        scriptUrl,
        isDarkMode: _isDarkMode(context),
      );
      return;
    } else if (SalesmarylyChatPage.isSupported) {
      // Android/iOS：内嵌 WebView 全屏
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (_) => SalesmarylyChatPage(scriptUrl: scriptUrl),
        ),
      );
    } else {
      // 其他平台：外部浏览器
      _openSalesmartlyInBrowser(
        scriptUrl,
        isDarkMode: _isDarkMode(context),
      );
    }
  }

  /// Windows/Linux：用 desktop_webview_window 打开独立 WebView 窗口
  ///
  /// 方案：导航到 www.salesmartly.com/robots.txt（轻量 HTTPS 页面），
  /// 通过 addScriptToExecuteOnDocumentCreated 在页面加载后
  /// 用 document.write 重写页面并注入 SDK，使用 ssq.push API 打开聊天窗口。
  static Future<void> _openSalesmartlyInDesktopWebview(
    String scriptUrl, {
    required bool isDarkMode,
  }) async {
    final existing = await _reuseDesktopCustomerServiceWindow(
      isDarkMode: isDarkMode,
    );
    if (existing != null) return;

    final future = _createSalesmartlyDesktopWebview(
      scriptUrl,
      isDarkMode: isDarkMode,
    );
    _desktopCustomerServiceOpening = future;
    try {
      final webview = await future;
      if (webview != null) {
        _trackDesktopCustomerServiceWindow(webview);
      }
    } finally {
      if (identical(_desktopCustomerServiceOpening, future)) {
        _desktopCustomerServiceOpening = null;
      }
    }
  }

  static Future<Webview?> _createSalesmartlyDesktopWebview(
    String scriptUrl, {
    required bool isDarkMode,
  }) async {
    try {
      final available = await _isDesktopWebviewAvailable();
      if (!available) {
        _logger.warning('[SalesSmartly] WebView2 不可用，回退浏览器');
        _openSalesmartlyInBrowser(scriptUrl, isDarkMode: isDarkMode);
        return null;
      }

      final dataFolder = Platform.isWindows ? await _webview2DataFolder() : '';
      final webview = await WebviewWindow.create(
        configuration: CreateConfiguration(
          title: '在线客服',
          windowWidth: _desktopCustomerServiceWindowWidth,
          windowHeight: _desktopCustomerServiceWindowHeight,
          titleBarHeight: _desktopCustomerServiceTitleBarHeight,
          userDataFolderWindows: dataFolder,
          resizable: false,
          showTitleBarActions: false,
          brightness: _customerServiceBrightness(isDarkMode),
        ),
      );
      await _applyDesktopCustomerServiceTheme(
        webview,
        isDarkMode: isDarkMode,
      );

      final scriptUrlEscaped = scriptUrl.replaceAll("'", "\\'");
      final bg = _customerServiceBackground(isDarkMode);
      final fg = _customerServiceForeground(isDarkMode);
      // 注入脚本：在 DOMContentLoaded 后用 document.write 重写页面，注入 SDK
      // 使用 ssq.push API（官方文档推荐）
      final injectJs = '''
if(window===window.top){
  document.addEventListener('DOMContentLoaded',function(){
    document.open();
    document.write('<html><head><meta charset=utf-8><meta name=viewport content="width=device-width,initial-scale=1"><title>在线客服</title><style>*{margin:0;padding:0}html,body{width:100%;height:100%;background:$bg;overflow:hidden}#loading{display:flex;align-items:center;justify-content:center;height:100%;color:$fg;font-family:-apple-system,sans-serif;font-size:14px}</style></head><body><div id=loading>正在连接客服...</div><scr'+'ipt src=\\'$scriptUrlEscaped\\' id=ss_chat></scr'+'ipt><scr'+'ipt>(function w(){if(window.ssq&&typeof window.ssq==="function"){ssq.push("chatOpen");ssq.push("onReady",function(){ssq.push("chatOpen");var e=document.getElementById("loading");if(e)e.style.display="none";});}else{setTimeout(w,300);}})();setTimeout(function(){var e=document.getElementById("loading");if(e&&e.style.display!=="none")e.textContent="加载超时，请检查网络";},20000);new MutationObserver(function(){var fs=document.querySelectorAll("iframe");for(var i=0;i<fs.length;i++){var s=fs[i].src||"";if(s.indexOf("salesmartly")!==-1||s.indexOf("ssm")!==-1){fs[i].style.cssText="position:fixed!important;top:0!important;left:0!important;width:100vw!important;height:100vh!important;max-width:none!important;max-height:none!important;border:none!important;border-radius:0!important;z-index:99999!important;";var p=fs[i].parentElement;if(p){p.style.cssText="position:fixed!important;top:0!important;left:0!important;width:100vw!important;height:100vh!important;z-index:99999!important;";}var e=document.getElementById("loading");if(e)e.style.display="none";}}}).observe(document.documentElement,{childList:true,subtree:true,attributes:true});</scr'+'ipt></body></html>');
    document.close();
  });
}''';

      webview.addScriptToExecuteOnDocumentCreated(injectJs);
      // 导航到 salesmartly 官网轻量页面（robots.txt），确保真实 HTTPS origin
      await webview.launch('https://www.salesmartly.com/robots.txt');

      _logger.info('[SalesSmartly] 已启动 WebView2，注入客服 SDK');
      return webview;
    } catch (e) {
      _logger.error('[SalesSmartly] WebView2 启动失败，回退浏览器', e);
      _openSalesmartlyInBrowser(scriptUrl, isDarkMode: isDarkMode);
      return null;
    }
  }

  /// 生成包含 SalesSmartly SDK 的 HTML
  static String _buildSalesmartlyHtml(
    String scriptUrl, {
    required bool isDarkMode,
  }) {
    final bg = _customerServiceBackground(isDarkMode);
    final fg = _customerServiceForeground(isDarkMode);
    return '''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>在线客服</title>
  <style>
    * { margin: 0; padding: 0; }
    html, body { width: 100%; height: 100%; background: $bg; }
    #loading {
      display: flex; align-items: center; justify-content: center;
      height: 100%; color: $fg; font-family: -apple-system, sans-serif; font-size: 16px;
    }
  </style>
</head>
<body>
  <div id="loading">正在连接客服...</div>
  <script src="$scriptUrl" id="ss_chat"></script>
  <script>
    (function check(){
      if(window.ssq && typeof window.ssq==='function'){
        window.ssq('onReady',function(){
          window.ssq('chatOpen');
          document.getElementById('loading').style.display='none';
        });
        setTimeout(function(){window.ssq('chatOpen');},5000);
      } else {
        setTimeout(check,100);
      }
    })();
  </script>
</body>
</html>''';
  }

  /// Android 等平台：用本地 HTTP 服务器 + Chrome Custom Tab 打开客服
  ///
  /// SDK 在 Android WebView 中无法渲染，必须在完整浏览器环境中运行。
  /// 启动 localhost HTTP 服务器提供 HTML 页面，然后用 inAppBrowserView
  /// （Chrome Custom Tab）打开，视觉上仍在 app 内。
  static Future<void> _openSalesmartlyInBrowser(
    String scriptUrl, {
    required bool isDarkMode,
  }) async {
    HttpServer? server;
    try {
      final html = _buildSalesmartlyHtml(scriptUrl, isDarkMode: isDarkMode);

      // 启动本地 HTTP 服务器
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;

      server.listen((request) {
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.html
          ..headers.set('Cache-Control', 'no-cache')
          ..write(html);
        request.response.close();
      });

      // Chrome Custom Tab 打开（看起来像在 app 内）
      await launchUrl(
        Uri.parse('http://localhost:$port'),
        mode: LaunchMode.inAppBrowserView,
      );

      // 延迟关闭服务器，给浏览器足够时间加载页面
      Future.delayed(const Duration(seconds: 30), () {
        server?.close();
      });
    } catch (e) {
      _logger.error('[SalesSmartly] 浏览器打开失败', e);
      server?.close();
      launchUrl(
        Uri.parse('https://www.salesmartly.com'),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  static Future<_CrispIPData?> _resolveCrispIPDataForInitialInjection(
    BuildContext context,
  ) async {
    try {
      return await _resolveCrispIPData(context).timeout(
        _crispUserDataResolveTimeout,
        onTimeout: () => null,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<_CrispIPData?> _resolveCrispIPData(
    BuildContext context,
  ) async {
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      final sdk = await container.read(xboardSdkProvider.future);
      final token = await sdk.getToken();
      if (token == null || token.isEmpty || !token.contains('dg_')) {
        return null;
      }
      final headers = <String, String>{'Authorization': token};

      Future<_CrispIPData?> request(HttpService http) async {
        try {
          await http.postRequest(
            '/user/devices/heartbeat',
            <String, dynamic>{},
            headers: headers,
          );
        } catch (_) {}

        final response = await http.getRequest(
          '/user/devices',
          headers: headers,
        );
        return _extractCrispIPData(response);
      }

      try {
        final data = await request(sdk.httpService);
        if (data != null) return data;
      } catch (_) {}

      for (final endpoint in _resolveDeviceGatewayEndpoints()) {
        try {
          final http = await HttpService.create(
            endpoint.baseUrl,
            httpConfig: HttpConfig.development(),
            apiPrefix: endpoint.apiPrefix,
          );
          final data = await request(http);
          if (data != null) return data;
        } catch (_) {}
      }
    } catch (_) {}
    return null;
  }

  static _CrispIPData? _extractCrispIPData(Map<String, dynamic> response) {
    final data = _mapOf(response['data']);
    final rawDevices = data?['devices'];
    if (rawDevices is! List) return null;

    final devices = rawDevices
        .map(_mapOf)
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
    for (final device in devices) {
      if (device['is_current'] == true) {
        final data = _ipDataFromDevice(device);
        if (data != null) return data;
      }
    }
    for (final device in devices) {
      if (device['status']?.toString() == 'active') {
        final data = _ipDataFromDevice(device);
        if (data != null) return data;
      }
    }
    for (final device in devices) {
      final data = _ipDataFromDevice(device);
      if (data != null) return data;
    }
    return null;
  }

  static _CrispIPData? _ipDataFromDevice(Map<String, dynamic> device) {
    final ip = _firstString(device, const [
      'last_ip',
      'ip',
      'last_login_ip',
      'login_ip',
    ]);
    final region = _firstString(device, const [
      'last_ip_region',
      'ip_region',
      'ip_location',
      'location',
      'region',
    ]);
    final isp = _firstString(device, const [
      'last_ip_isp',
      'ip_isp',
      'isp',
      'operator',
    ]);
    if (ip.isEmpty && region.isEmpty && isp.isEmpty) return null;
    return _CrispIPData(ip: ip, region: region, isp: isp);
  }

  static List<_DeviceGatewayEndpoint> _resolveDeviceGatewayEndpoints() {
    final endpoints = <_DeviceGatewayEndpoint>[];
    final seen = <String>{};

    void addEndpoint(String baseUrl, String apiPrefix) {
      final base = baseUrl.trim().replaceAll(RegExp(r'/$'), '');
      final prefix = _normalizeApiPrefix(apiPrefix);
      if (base.isEmpty || prefix.isEmpty) return;
      final key = '$base|$prefix';
      if (seen.add(key)) {
        endpoints.add(_DeviceGatewayEndpoint(base, prefix));
      }
    }

    void addFromBaseUrl(String url, {String? apiPrefix}) {
      final uri = Uri.tryParse(url.trim());
      if (uri == null || !uri.hasScheme || uri.host.isEmpty) return;
      final origin = _originFromUri(uri);
      final pathPrefix =
          uri.path.isNotEmpty && uri.path != '/' ? uri.path : null;
      addEndpoint(origin, apiPrefix ?? pathPrefix ?? _configuredApiPrefix());
    }

    final runtime = GatewayRuntimeService.instance;
    runtime.syncFromCurrentConfig();

    final active = runtime.activeConfig;
    if (active != null) {
      addEndpoint(active.baseUrl, active.apiPrefix);
    }
    for (final candidate in runtime.candidates) {
      addEndpoint(candidate.baseUrl, candidate.apiPrefix);
    }

    addFromBaseUrl(
      XBoardSDK.instance.httpService.baseUrl,
      apiPrefix: XBoardSDK.instance.httpService.apiPrefix,
    );
    addFromBaseUrl(productionGatewayUrl, apiPrefix: _deviceGatewayApiPrefix);

    return endpoints;
  }

  static String _configuredApiPrefix() {
    try {
      if (XBoardConfig.isInitialized) {
        return XBoardConfig.provider.getApiPrefix();
      }
    } catch (_) {}
    return _deviceGatewayApiPrefix;
  }

  static String _normalizeApiPrefix(String value) {
    var prefix = value.trim();
    if (prefix.isEmpty || prefix == '/') return _deviceGatewayApiPrefix;
    if (!prefix.startsWith('/')) prefix = '/$prefix';
    return prefix.replaceAll(RegExp(r'/$'), '');
  }

  static String _originFromUri(Uri uri) {
    return uri.replace(path: '', query: '', fragment: '').toString();
  }

  static Map<String, dynamic>? _mapOf(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }

  static String _firstString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return '';
  }

  static void _openCrisp(
    BuildContext context,
    String websiteId, {
    String? userScript,
    String? crispProxyUrl,
    _CrispIPData? ipData,
    Future<String?> Function()? deferredUserScript,
  }) {
    final effectiveUserScript =
        userScript ?? _buildCrispUserScript(context, ipData: ipData);
    if (_isDesktopPlatform) {
      // 桌面端：用 desktop_webview_window 独立窗口
      unawaited(() async {
        await _openCrispInDesktopWebview(
          websiteId,
          crispProxyUrl: crispProxyUrl,
          isDarkMode: _isDarkMode(context),
          userScript: effectiveUserScript,
        );
      }());
      return;
    } else if (CrispChatPage.isSupported) {
      // Android/iOS：内嵌 WebView 全屏
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (_) => CrispChatPage(
            websiteId: websiteId,
            crispProxyUrl: crispProxyUrl,
            userScript: effectiveUserScript,
            deferredUserScript: deferredUserScript,
          ),
        ),
      );
    } else {
      launchUrl(
        crispEmbedUri(websiteId: websiteId, proxyUrl: crispProxyUrl),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  /// 桌面端：用 desktop_webview_window 打开 Crisp 聊天
  /// 用 SDK 注入方式代替直接加载 embed URL（解决 WebView2 空白问题）
  static Future<Webview?> _openCrispInDesktopWebview(
    String websiteId, {
    String? crispProxyUrl,
    required bool isDarkMode,
    required String userScript,
  }) async {
    final existing = await _reuseDesktopCustomerServiceWindow(
      isDarkMode: isDarkMode,
    );
    if (existing != null) {
      await _applyCrispUserScriptToDesktop(existing, userScript);
      return existing;
    }

    final future = _createCrispDesktopWebview(
      websiteId,
      crispProxyUrl: crispProxyUrl,
      isDarkMode: isDarkMode,
      userScript: userScript,
    );
    _desktopCustomerServiceOpening = future;
    try {
      final webview = await future;
      if (webview != null) {
        _trackDesktopCustomerServiceWindow(webview);
      }
      return webview;
    } finally {
      if (identical(_desktopCustomerServiceOpening, future)) {
        _desktopCustomerServiceOpening = null;
      }
    }
  }

  static Future<void> _applyCrispUserScriptToDesktop(
    Webview webview,
    String userScript,
  ) async {
    try {
      await webview.evaluateJavaScript(userScript);
    } catch (e) {
      _logger.debug('[Crisp] 刷新客服用户资料失败: $e');
    }
  }

  static Future<Webview?> _createCrispDesktopWebview(
    String websiteId, {
    String? crispProxyUrl,
    required bool isDarkMode,
    required String userScript,
  }) async {
    final officialUrl = officialCrispEmbedUri(websiteId).toString();
    final preferredUrl =
        crispEmbedUri(websiteId: websiteId, proxyUrl: crispProxyUrl).toString();
    if (Platform.isLinux) {
      return _createLinuxCrispDesktopWebview(
        websiteId: websiteId,
        preferredUrl: preferredUrl,
        officialUrl: officialUrl,
        isDarkMode: isDarkMode,
        userScript: userScript,
      );
    }
    _DesktopCrispBootstrapPage? bootstrapPage;
    Webview? createdWebview;
    try {
      // 先检查 WebView2 Runtime 是否已安装
      final available = await _isDesktopWebviewAvailable();
      if (!available) {
        launchUrl(
          Uri.parse(officialUrl),
          mode: LaunchMode.externalApplication,
        );
        return null;
      }

      bootstrapPage = await _startDesktopCrispBootstrapPage(
        websiteId: websiteId,
        isDarkMode: isDarkMode,
        userScript: userScript,
      );
      final dataFolder = Platform.isWindows ? await _webview2DataFolder() : '';
      final webview = await WebviewWindow.create(
        configuration: CreateConfiguration(
          title: '在线客服',
          windowWidth: _desktopCustomerServiceWindowWidth,
          windowHeight: _desktopCustomerServiceWindowHeight,
          titleBarHeight: _desktopCustomerServiceTitleBarHeight,
          userDataFolderWindows: dataFolder,
          resizable: false,
          showTitleBarActions: false,
          brightness: _customerServiceBrightness(isDarkMode),
        ),
      );
      createdWebview = webview;
      await _applyDesktopCustomerServiceTheme(
        webview,
        isDarkMode: isDarkMode,
      );

      unawaited(webview.onClose.whenComplete(bootstrapPage.close));
      await webview.launch(bootstrapPage.url);

      _logger.info('[Crisp] 已启动桌面 WebView，加载客服 SDK 启动页');
      return webview;
    } catch (e) {
      _logger.error('[Crisp] 桌面客服启动页失败，尝试加载 embed 页面', e);
      await bootstrapPage?.close();
      createdWebview?.close();
      try {
        final dataFolder =
            Platform.isWindows ? await _webview2DataFolder() : '';
        final webview = await WebviewWindow.create(
          configuration: CreateConfiguration(
            title: '在线客服',
            windowWidth: _desktopCustomerServiceWindowWidth,
            windowHeight: _desktopCustomerServiceWindowHeight,
            titleBarHeight: _desktopCustomerServiceTitleBarHeight,
            userDataFolderWindows: dataFolder,
            resizable: false,
            showTitleBarActions: false,
            brightness: _customerServiceBrightness(isDarkMode),
          ),
        );
        webview.addScriptToExecuteOnDocumentCreated(userScript);
        await _applyDesktopCustomerServiceTheme(
          webview,
          isDarkMode: isDarkMode,
        );
        await webview.launch(preferredUrl);
        return webview;
      } catch (fallbackError) {
        _logger.error('[Crisp] WebView2 启动失败，回退浏览器', fallbackError);
      }
      launchUrl(
        Uri.parse(officialUrl),
        mode: LaunchMode.externalApplication,
      );
      return null;
    }
  }

  static Future<Webview?> _createLinuxCrispDesktopWebview({
    required String websiteId,
    required String preferredUrl,
    required String officialUrl,
    required bool isDarkMode,
    required String userScript,
  }) async {
    try {
      final webview = await WebviewWindow.create(
        configuration: CreateConfiguration(
          title: '在线客服',
          windowWidth: _desktopCustomerServiceWindowWidth,
          windowHeight: _desktopCustomerServiceWindowHeight,
          titleBarHeight: _desktopCustomerServiceTitleBarHeight,
          resizable: false,
          showTitleBarActions: false,
          brightness: _customerServiceBrightness(isDarkMode),
        ),
      );
      webview.addScriptToExecuteOnDocumentCreated(
        _buildLinuxCrispSdkBootstrapScript(
          websiteId: websiteId,
          isDarkMode: isDarkMode,
          userScript: userScript,
        ),
      );
      await _applyDesktopCustomerServiceTheme(
        webview,
        isDarkMode: isDarkMode,
      );
      _scheduleDesktopCrispRouteFallback(
        webview,
        preferredUrl: preferredUrl,
        officialUrl: officialUrl,
      );
      await webview.launch(preferredUrl);
      _logger.info('[Crisp] 已启动 Linux 桌面 WebView，加载远端 HTTPS Crisp SDK 启动页');
      return webview;
    } catch (e) {
      _logger.error('[Crisp] Linux 桌面客服启动失败，回退浏览器', e);
      launchUrl(
        Uri.parse(officialUrl),
        mode: LaunchMode.externalApplication,
      );
      return null;
    }
  }

  static String _buildLinuxCrispSdkBootstrapScript({
    required String websiteId,
    required bool isDarkMode,
    required String userScript,
  }) {
    final websiteIdJson = jsonEncode(websiteId);
    final background = _customerServiceBackground(isDarkMode);
    final foreground = _customerServiceForeground(isDarkMode);
    final accent =
        _desktopCustomerServiceAccent ?? _customerServiceAccent(isDarkMode);
    final colorScheme = isDarkMode ? 'dark' : 'light';
    return '''
(function(){
  try {
    if (window.__fastcatCrispBootstrapped) return;
    window.__fastcatCrispBootstrapped = true;
    var background = '$background';
    var foreground = '$foreground';
    var accent = '$accent';
    var colorScheme = '$colorScheme';
    var websiteId = $websiteIdJson;

    function applyTheme(theme) {
      try {
        if (theme) {
          background = theme.background || background;
          foreground = theme.foreground || foreground;
          accent = theme.accent || accent;
          colorScheme = theme.isDark ? 'dark' : 'light';
        }
        document.documentElement.style.background = background;
        document.documentElement.style.colorScheme = colorScheme;
        if (document.body) {
          document.body.style.background = background;
          document.body.style.color = foreground;
        }
        var style = document.getElementById('fastcat-customer-service-theme');
        if (!style) {
          style = document.createElement('style');
          style.id = 'fastcat-customer-service-theme';
          (document.head || document.documentElement).appendChild(style);
        }
        style.textContent = 'html,body{width:100%;height:100%;margin:0;background:' + background + '!important;color:' + foreground + '!important;color-scheme:' + colorScheme + '!important;overflow:hidden;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;}#loading{position:fixed;inset:0;display:flex;align-items:center;justify-content:center;gap:12px;background:' + background + ';color:' + foreground + ';font-size:14px;z-index:2147483647;}#spinner{width:18px;height:18px;border:2px solid rgba(148,163,184,.35);border-top-color:' + accent + ';border-radius:50%;animation:fastcatSpin .8s linear infinite;}@keyframes fastcatSpin{to{transform:rotate(360deg)}}';
      } catch(_) {}
    }

    window.__fastcatApplyCustomerServiceTheme = applyTheme;
    document.open();
    document.write('<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1"><title>在线客服</title></head><body><div id="loading"><span id="spinner"></span><span id="loading-text">正在连接客服...</span></div></body></html>');
    document.close();
    applyTheme();

    window.\$crisp = window.\$crisp || [];
    window.CRISP_WEBSITE_ID = websiteId;
    window.__fastcatCrispReady = false;
    $userScript

    function openChat(){
      try {
        window.\$crisp = window.\$crisp || [];
        window.\$crisp.push(["safe", true]);
        window.\$crisp.push(["do", "chat:show"]);
        window.\$crisp.push(["do", "chat:open"]);
      } catch(_) {}
    }

    function markReady(){
      window.__fastcatCrispReady = true;
      openChat();
      var loading = document.getElementById('loading');
      if (loading) loading.style.display = 'none';
    }

    function expandFrames(){
      var frames = document.querySelectorAll('iframe');
      for (var i = 0; i < frames.length; i++) {
        var src = frames[i].src || '';
        if (src.indexOf('crisp') === -1) continue;
        frames[i].style.cssText = 'position:fixed!important;top:0!important;left:0!important;width:100vw!important;height:100vh!important;max-width:none!important;max-height:none!important;border:none!important;border-radius:0!important;z-index:2147483646!important;background:' + background + '!important;';
        var parent = frames[i].parentElement;
        if (parent) parent.style.cssText = 'position:fixed!important;top:0!important;left:0!important;width:100vw!important;height:100vh!important;z-index:2147483646!important;background:' + background + '!important;';
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
      var loadingText = document.getElementById('loading-text');
      if (!window.__fastcatCrispReady && loadingText) loadingText.textContent = '加载较慢，请稍候...';
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
      var loadingText = document.getElementById('loading-text');
      if (loadingText) loadingText.textContent = '客服加载失败，请检查网络后重试';
    };
    (document.head || document.documentElement).appendChild(script);
  } catch(_) {}
})();''';
  }

  static void _scheduleDesktopCrispRouteFallback(
    Webview webview, {
    required String preferredUrl,
    required String officialUrl,
  }) {
    if (preferredUrl == officialUrl) return;
    final timer = Timer(_desktopCrispRouteFallbackDelay, () async {
      try {
        final result = await webview.evaluateJavaScript('''
(function(){
  try {
    return window.__fastcatCrispReady === true ? 'ready' : 'pending';
  } catch (_) {
    return 'pending';
  }
})();''');
        if (result?.contains('ready') == true) return;
        _logger.warning('[Crisp] 客服代理加载较慢，切换官方线路');
        await webview.launch(officialUrl);
      } catch (e) {
        _logger.debug('[Crisp] 客服线路回退检查失败: $e');
      }
    });
    unawaited(webview.onClose.whenComplete(timer.cancel));
  }

  static Future<_DesktopCrispBootstrapPage> _startDesktopCrispBootstrapPage({
    required String websiteId,
    required bool isDarkMode,
    required String userScript,
  }) async {
    final html = _buildDesktopCrispBootstrapHtml(
      websiteId: websiteId,
      isDarkMode: isDarkMode,
      userScript: userScript,
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) {
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.html
        ..headers.set('Cache-Control', 'no-store')
        ..write(html);
      request.response.close();
    });
    return _DesktopCrispBootstrapPage(
      server: server,
      url: 'http://127.0.0.1:${server.port}/',
    );
  }

  static String _buildDesktopCrispBootstrapHtml({
    required String websiteId,
    required bool isDarkMode,
    required String userScript,
  }) {
    final websiteIdJson = jsonEncode(websiteId);
    final background = _customerServiceBackground(isDarkMode);
    final foreground = _customerServiceForeground(isDarkMode);
    final accent =
        _desktopCustomerServiceAccent ?? _customerServiceAccent(isDarkMode);
    final colorScheme = isDarkMode ? 'dark' : 'light';
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
      border-top-color: $accent;
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
      var background = '$background';
      var foreground = '$foreground';
      var accent = '$accent';
      var colorScheme = '$colorScheme';

      window.__fastcatApplyCustomerServiceTheme = function(theme) {
        try {
          background = theme.background || background;
          foreground = theme.foreground || foreground;
          accent = theme.accent || accent;
          colorScheme = theme.isDark ? 'dark' : 'light';
          document.documentElement.style.background = background;
          document.documentElement.style.colorScheme = colorScheme;
          document.body.style.background = background;
          document.body.style.color = foreground;
          if (loading) {
            loading.style.background = background;
            loading.style.color = foreground;
          }
          var style = document.getElementById('fastcat-customer-service-theme');
          if (!style) {
            style = document.createElement('style');
            style.id = 'fastcat-customer-service-theme';
            document.head.appendChild(style);
          }
          style.textContent = 'html,body,#page,.site-wrapper,.chat-common{background:' + background + '!important;color:' + foreground + '!important;color-scheme:' + colorScheme + '!important;}#spinner{border-top-color:' + accent + '!important;}';
        } catch(_) {}
      };

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
          frames[i].style.cssText = 'position:fixed!important;top:0!important;left:0!important;width:100vw!important;height:100vh!important;max-width:none!important;max-height:none!important;border:none!important;border-radius:0!important;z-index:2147483646!important;background:' + background + '!important;';
          var parent = frames[i].parentElement;
          if (parent) parent.style.cssText = 'position:fixed!important;top:0!important;left:0!important;width:100vw!important;height:100vh!important;z-index:2147483646!important;background:' + background + '!important;';
          markReady();
        }
      }

      window.CRISP_READY_TRIGGER = function(){
        markReady();
      };

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

  static String _buildCrispUserScript(
    BuildContext context, {
    _CrispIPData? ipData,
  }) {
    final data = _buildCrispUserData(context, ipData: ipData);
    final email = (data['email'] as String?)?.trim();
    final nickname = (data['nickname'] as String?)?.trim();
    final sessionData =
        (data['sessionData'] as List<List<String>>).where((entry) {
      return entry.length == 2 && entry[0].trim().isNotEmpty;
    }).toList();
    final emailJson = jsonEncode(email ?? '');
    final nicknameJson = jsonEncode(nickname ?? '');
    final sessionDataJson = jsonEncode(sessionData);

    return '''
(function applyCrispUserData(){
  try {
    window.\$crisp = window.\$crisp || [];
    var email = $emailJson;
    var nickname = $nicknameJson;
    var sessionData = $sessionDataJson;

    function apply() {
      try { window.\$crisp.push(["safe", true]); } catch(_) {}
      if (email) {
        try { window.\$crisp.push(["set","user:email",[email]]); } catch(_) {}
      }
      if (nickname) {
        try { window.\$crisp.push(["set","user:nickname",[nickname]]); } catch(_) {}
      }
      if (sessionData && sessionData.length > 0) {
        try { window.\$crisp.push(["set","session:data",[sessionData]]); } catch(_) {}
      }
    }

    apply();
    if (window.__kuaimaoCrispApplyTimer) {
      clearInterval(window.__kuaimaoCrispApplyTimer);
    }
    var retry = 0;
    window.__kuaimaoCrispApplyTimer = setInterval(function(){
      retry++;
      apply();
      if (retry >= 20) {
        clearInterval(window.__kuaimaoCrispApplyTimer);
        window.__kuaimaoCrispApplyTimer = null;
      }
    }, 500);
  } catch(e) {}
})();''';
  }

  static Map<String, Object?> _buildCrispUserData(
    BuildContext context, {
    _CrispIPData? ipData,
  }) {
    final container = ProviderScope.containerOf(context, listen: false);
    final userState = container.read(xboardUserProvider);
    final userInfo = container.read(userInfoProvider);
    final subscriptionInfo = container.read(subscriptionInfoProvider);
    final profileSubscriptionInfo =
        container.read(currentProfileProvider)?.subscriptionInfo;

    final email = (userInfo?.email ?? userState.email ?? '').trim();
    final appVersion = _getAppVersionText();
    final osText = Platform.operatingSystem;
    final usedTraffic = profileSubscriptionInfo != null
        ? profileSubscriptionInfo.upload + profileSubscriptionInfo.download
        : (subscriptionInfo?.uploadedBytes ?? 0) +
            (subscriptionInfo?.downloadedBytes ?? 0);
    final totalTraffic =
        profileSubscriptionInfo?.total ?? subscriptionInfo?.transferLimit ?? 0;
    final expiredAt = subscriptionInfo?.expiredAt;
    final planName = subscriptionInfo?.planName ?? '';
    final resetDaysLeft = _resolveResetDaysLeft(subscriptionInfo);
    final userIP = _firstNonEmpty(userInfo?.ip, ipData?.ip);
    final userIPRegion = _firstNonEmpty(userInfo?.ipRegion, ipData?.region);
    final userIPISP = _firstNonEmpty(userInfo?.ipIsp, ipData?.isp);

    return {
      'email': email,
      'nickname': email.isEmpty ? null : email.split('@').first,
      'sessionData': <List<String>>[
        ['plan_name', planName],
        ['plan_expired_at', expiredAt?.toIso8601String() ?? ''],
        ['traffic_used', _formatTraffic(usedTraffic)],
        ['traffic_total', _formatTraffic(totalTraffic)],
        ['traffic_reset_days_left', resetDaysLeft?.toString() ?? 'unknown'],
        ['user_ip', userIP],
        ['user_ip_region', userIPRegion],
        ['user_ip_isp', userIPISP],
        ['os', osText],
        ['client_version', appVersion],
      ],
    };
  }

  static String _firstNonEmpty(String? primary, String? fallback) {
    final first = primary?.trim() ?? '';
    if (first.isNotEmpty) return first;
    return fallback?.trim() ?? '';
  }

  static int? _resolveResetDaysLeft(DomainSubscription? subscriptionInfo) {
    if (subscriptionInfo == null) return null;
    final fromNextReset = _calcResetDaysLeft(subscriptionInfo.nextResetAt);
    if (fromNextReset != null) return fromNextReset;
    final metadataValue = subscriptionInfo.metadata['resetDay'];
    if (metadataValue is num) return metadataValue.toInt();
    if (metadataValue is String) return int.tryParse(metadataValue);
    return null;
  }

  static int? _calcResetDaysLeft(DateTime? nextResetAt) {
    if (nextResetAt == null) return null;
    final now = DateTime.now();
    if (!nextResetAt.isAfter(now)) return 0;
    final nowDate = DateTime(now.year, now.month, now.day);
    final resetDate =
        DateTime(nextResetAt.year, nextResetAt.month, nextResetAt.day);
    final days = resetDate.difference(nowDate).inDays;
    return days < 0 ? 0 : days;
  }

  static String _getAppVersionText() {
    try {
      final info = globalState.packageInfo;
      final buildNumber = info.buildNumber.trim();
      return buildNumber.isEmpty
          ? info.version
          : '${info.version}+$buildNumber';
    } catch (_) {
      return '';
    }
  }

  static String _formatTraffic(num bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var unitIndex = 0;
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    final precision = size >= 100
        ? 0
        : size >= 10
            ? 1
            : 2;
    return '${size.toStringAsFixed(precision)} ${units[unitIndex]}';
  }
}

class _DesktopCrispBootstrapPage {
  final HttpServer server;
  final String url;

  const _DesktopCrispBootstrapPage({
    required this.server,
    required this.url,
  });

  Future<void> close() async {
    await server.close(force: true);
  }
}

class _CrispProxyCacheEntry {
  const _CrispProxyCacheEntry({
    required this.websiteId,
    required this.proxyUrl,
    required this.usableProxyUrl,
    required this.createdAt,
  });

  final String websiteId;
  final String proxyUrl;
  final String usableProxyUrl;
  final DateTime createdAt;

  bool matches(String websiteId, String proxyUrl, DateTime now) {
    return this.websiteId == websiteId &&
        this.proxyUrl == proxyUrl &&
        now.difference(createdAt) < _crispProxyUsableCacheTtl;
  }
}

class _PendingCrispProxyProbe {
  const _PendingCrispProxyProbe({
    required this.websiteId,
    required this.proxyUrl,
    required this.future,
  });

  final String websiteId;
  final String proxyUrl;
  final Future<String> future;
}

class _CrispIPData {
  const _CrispIPData({
    required this.ip,
    required this.region,
    required this.isp,
  });

  final String ip;
  final String region;
  final String isp;
}

class _DeviceGatewayEndpoint {
  const _DeviceGatewayEndpoint(this.baseUrl, this.apiPrefix);

  final String baseUrl;
  final String apiPrefix;
}
