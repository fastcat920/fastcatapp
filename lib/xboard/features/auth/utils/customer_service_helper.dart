import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:desktop_webview_window/desktop_webview_window.dart';
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

  /// 是否有任何客服渠道可用（仅远程 Crisp）
  static bool get isAvailable => XBoardConfig.crispWebsiteId.isNotEmpty;

  static bool get _isDesktopPlatform =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  static int get _desktopCustomerServiceTitleBarHeight =>
      Platform.isWindows ? 0 : 40;

  /// 预热客服启动所需的轻量资源，减少首次点击后的等待。
  static void prewarm() {
    if (XBoardConfig.crispWebsiteId.trim().isEmpty) {
      unawaited(_fallbackCrispWebsiteId());
    }
    if (XBoardConfig.crispProxyUrl.trim().isEmpty) {
      unawaited(_fallbackCrispProxyUrl());
    }
    if (_isDesktopPlatform) {
      unawaited(_isDesktopWebviewAvailable());
      if (Platform.isWindows) {
        unawaited(_webview2DataFolder());
      }
    }
  }

  /// 获取 WebView2 用户数据目录（可写路径）
  static Future<String> _webview2DataFolder() async {
    return _webview2DataFolderFuture ??= () async {
      final dir = await getApplicationSupportDirectory();
      return '${dir.path}/webview2_data';
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
    final proxyEmbedUri = crispEmbedUri(
      websiteId: websiteId,
      proxyUrl: proxyUrl,
    );
    final usable = await _isCrispProxyEmbedUsable(proxyEmbedUri);
    if (usable) return proxyUrl;
    _logger.warning('[Crisp] 代理预检失败，使用官方域名: $proxyEmbedUri');
    return '';
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
      final crispProxyUrl = await _resolveUsableCrispProxyUrl(crispId);
      if (!context.mounted) return;
      final userScript = _buildCrispUserScript(context);
      if (_isDesktopPlatform) {
        final webview = await _openCrispInDesktopWebview(
          crispId,
          userScript: userScript,
          crispProxyUrl: crispProxyUrl,
        );
        if (webview != null && context.mounted) {
          unawaited(_applyCrispIPDataWhenReady(context, webview));
        }
        return;
      }
      _openCrisp(
        context,
        crispId,
        userScript: userScript,
        crispProxyUrl: crispProxyUrl,
        deferredUserScript: () async {
          final ipData = await _resolveCrispIPData(context);
          if (ipData == null || !context.mounted) return null;
          return _buildCrispUserScript(context, ipData: ipData);
        },
      );
      return;
    }
    XBoardNotification.showError('未配置在线客服');
  }

  // ignore: unused_element
  static void _openSalesmartly(BuildContext context, String scriptUrl) {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      // 桌面端：用 desktop_webview_window 独立窗口
      _openSalesmartlyInDesktopWebview(scriptUrl);
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
      _openSalesmartlyInBrowser(scriptUrl);
    }
  }

  /// Windows/Linux：用 desktop_webview_window 打开独立 WebView 窗口
  ///
  /// 方案：导航到 www.salesmartly.com/robots.txt（轻量 HTTPS 页面），
  /// 通过 addScriptToExecuteOnDocumentCreated 在页面加载后
  /// 用 document.write 重写页面并注入 SDK，使用 ssq.push API 打开聊天窗口。
  static Future<void> _openSalesmartlyInDesktopWebview(String scriptUrl) async {
    try {
      final available = await _isDesktopWebviewAvailable();
      if (!available) {
        _logger.warning('[SalesSmartly] WebView2 不可用，回退浏览器');
        _openSalesmartlyInBrowser(scriptUrl);
        return;
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
        ),
      );

      final scriptUrlEscaped = scriptUrl.replaceAll("'", "\\'");
      // 注入脚本：在 DOMContentLoaded 后用 document.write 重写页面，注入 SDK
      // 使用 ssq.push API（官方文档推荐）
      final injectJs = '''
if(window===window.top){
  document.addEventListener('DOMContentLoaded',function(){
    document.open();
    document.write('<html><head><meta charset=utf-8><meta name=viewport content="width=device-width,initial-scale=1"><title>在线客服</title><style>*{margin:0;padding:0}html,body{width:100%;height:100%;background:#f5f5f5;overflow:hidden}#loading{display:flex;align-items:center;justify-content:center;height:100%;color:#999;font-family:-apple-system,sans-serif;font-size:14px}</style></head><body><div id=loading>正在连接客服...</div><scr'+'ipt src=\\'$scriptUrlEscaped\\' id=ss_chat></scr'+'ipt><scr'+'ipt>(function w(){if(window.ssq&&typeof window.ssq==="function"){ssq.push("chatOpen");ssq.push("onReady",function(){ssq.push("chatOpen");var e=document.getElementById("loading");if(e)e.style.display="none";});}else{setTimeout(w,300);}})();setTimeout(function(){var e=document.getElementById("loading");if(e&&e.style.display!=="none")e.textContent="加载超时，请检查网络";},20000);new MutationObserver(function(){var fs=document.querySelectorAll("iframe");for(var i=0;i<fs.length;i++){var s=fs[i].src||"";if(s.indexOf("salesmartly")!==-1||s.indexOf("ssm")!==-1){fs[i].style.cssText="position:fixed!important;top:0!important;left:0!important;width:100vw!important;height:100vh!important;max-width:none!important;max-height:none!important;border:none!important;border-radius:0!important;z-index:99999!important;";var p=fs[i].parentElement;if(p){p.style.cssText="position:fixed!important;top:0!important;left:0!important;width:100vw!important;height:100vh!important;z-index:99999!important;";}var e=document.getElementById("loading");if(e)e.style.display="none";}}}).observe(document.documentElement,{childList:true,subtree:true,attributes:true});</scr'+'ipt></body></html>');
    document.close();
  });
}''';

      webview.addScriptToExecuteOnDocumentCreated(injectJs);
      // 导航到 salesmartly 官网轻量页面（robots.txt），确保真实 HTTPS origin
      webview.launch('https://www.salesmartly.com/robots.txt');

      _logger.info('[SalesSmartly] 已启动 WebView2，注入客服 SDK');
    } catch (e) {
      _logger.error('[SalesSmartly] WebView2 启动失败，回退浏览器', e);
      _openSalesmartlyInBrowser(scriptUrl);
    }
  }

  /// 生成包含 SalesSmartly SDK 的 HTML
  static String _buildSalesmartlyHtml(String scriptUrl) {
    return '''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>在线客服</title>
  <style>
    * { margin: 0; padding: 0; }
    html, body { width: 100%; height: 100%; background: #f5f5f5; }
    #loading {
      display: flex; align-items: center; justify-content: center;
      height: 100%; color: #999; font-family: -apple-system, sans-serif; font-size: 16px;
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
  static Future<void> _openSalesmartlyInBrowser(String scriptUrl) async {
    HttpServer? server;
    try {
      final html = _buildSalesmartlyHtml(scriptUrl);

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
      unawaited(_openCrispInDesktopWebview(
        websiteId,
        userScript: effectiveUserScript,
        crispProxyUrl: crispProxyUrl,
      ));
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
    required String userScript,
    String? crispProxyUrl,
  }) async {
    final officialUrl = officialCrispEmbedUri(websiteId).toString();
    final preferredUrl =
        crispEmbedUri(websiteId: websiteId, proxyUrl: crispProxyUrl).toString();
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

      final dataFolder = Platform.isWindows ? await _webview2DataFolder() : '';
      final webview = await WebviewWindow.create(
        configuration: CreateConfiguration(
          title: '在线客服',
          windowWidth: _desktopCustomerServiceWindowWidth,
          windowHeight: _desktopCustomerServiceWindowHeight,
          titleBarHeight: _desktopCustomerServiceTitleBarHeight,
          userDataFolderWindows: dataFolder,
          resizable: false,
        ),
      );

      // 直接加载 Crisp embed URL，不用 document.write 注入
      // desktop_webview_window 的 addScriptToExecuteOnDocumentCreated
      // 在 embed 页面上下文执行，可以直接操作 Crisp SDK
      final injectJs = '''
(function(){
  var done=false;
  function hideLoading(){
    if(done)return;
    done=true;
  }
  function tryOpen(){
    try{
      window.\$crisp=window.\$crisp||[];
      $userScript
      if(window.\$crisp&&typeof window.\$crisp.push==="function"){
        \$crisp.push(["do","chat:show"]);
        \$crisp.push(["do","chat:open"]);
        hideLoading();
      }
    }catch(e){}
  }
  var iv=setInterval(tryOpen,800);
  setTimeout(function(){clearInterval(iv);tryOpen();},20000);
  // 监听 DOM 变化，Crisp 渲染后强制展开
  new MutationObserver(function(){
    tryOpen();
    // 让 Crisp iframe 全屏
    var fs=document.querySelectorAll("iframe");
    for(var i=0;i<fs.length;i++){
      var s=fs[i].src||"";
      if(s.indexOf("crisp")!==-1){
        fs[i].style.cssText="position:fixed!important;top:0!important;left:0!important;width:100vw!important;height:100vh!important;max-width:none!important;max-height:none!important;border:none!important;border-radius:0!important;z-index:99999!important;";
        var p=fs[i].parentElement;
        if(p)p.style.cssText="position:fixed!important;top:0!important;left:0!important;width:100vw!important;height:100vh!important;z-index:99999!important;";
      }
    }
  }).observe(document.documentElement,{childList:true,subtree:true,attributes:true});
})();''';

      webview.addScriptToExecuteOnDocumentCreated(injectJs);
      _startDesktopProxyFallbackTimer(
        webview,
        officialUrl: officialUrl,
        proxyWasUsed: isCrispProxyConfigured(crispProxyUrl),
      );
      // 直接加载 Crisp embed 页面，SDK 自动初始化
      webview.launch(preferredUrl);

      _logger.info('[Crisp] 已启动 WebView2，注入客服 SDK');
      return webview;
    } catch (e) {
      _logger.error('[Crisp] WebView2 启动失败，回退浏览器', e);
      launchUrl(
        Uri.parse(officialUrl),
        mode: LaunchMode.externalApplication,
      );
      return null;
    }
  }

  static void _startDesktopProxyFallbackTimer(
    Webview webview, {
    required String officialUrl,
    required bool proxyWasUsed,
  }) {
    if (!proxyWasUsed) return;
    final timer = Timer(crispProxyFallbackDelay, () {
      if (!webview.isNavigating.value) return;
      _logger.warning('[Crisp] 代理加载超时，回退官方域名');
      webview.launch(officialUrl);
    });
    unawaited(webview.onClose.whenComplete(timer.cancel));
  }

  static Future<void> _applyCrispIPDataWhenReady(
    BuildContext context,
    Webview webview,
  ) async {
    try {
      final ipData = await _resolveCrispIPData(context);
      if (ipData == null || !context.mounted) return;
      final script = _buildCrispUserScript(context, ipData: ipData);
      await webview.evaluateJavaScript(script);
      _logger.debug('[Crisp] 已后台补充客服 IP 数据');
    } catch (e) {
      _logger.debug('[Crisp] 后台补充客服 IP 数据失败: $e');
    }
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
