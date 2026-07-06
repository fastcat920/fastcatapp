import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:fl_clash/xboard/features/auth/utils/crisp_url_helper.dart';

String _crispLocaleFromTag(String localeTag) {
  final normalized = localeTag.trim().replaceAll('_', '-').toLowerCase();
  if (normalized.isEmpty) return 'en';
  final language = normalized.split('-').first;
  return switch (language) {
    'zh' => 'zh',
    'ja' => 'ja',
    'ko' => 'ko',
    'en' => 'en',
    _ => language,
  };
}

Uri _localizedCrispUri(Uri uri, String? localeTag) {
  final tag =
      (localeTag == null || localeTag.trim().isEmpty) ? 'en' : localeTag.trim();
  return uri.replace(
    queryParameters: {
      ...uri.queryParameters,
      'locale': _crispLocaleFromTag(tag),
      'lang': tag,
    },
  );
}

/// Crisp 客服嵌入页面
///
/// 在应用内通过 WebView 加载 Crisp 聊天窗口，无需跳转外部浏览器。
/// Android/iOS/macOS 使用系统 WebView。

/// UA getter: mobile UA on Android/iOS so Crisp renders the mobile-optimised chat,
/// desktop Chrome UA on macOS for the full desktop experience.
String get _crispUserAgent => Platform.isAndroid || Platform.isIOS
    ? _mobileCrispUserAgent
    : _desktopCrispUserAgent;

const _desktopCrispUserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
    'AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/125.0.0.0 Safari/537.36';

const _mobileCrispUserAgent = 'Mozilla/5.0 (Linux; Android 14; Pixel 8) '
    'AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/125.0.0.0 Mobile Safari/537.36';
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

  /// 是否支持系统内嵌 WebView
  static bool get isSupported =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  @override
  State<CrispChatPage> createState() => _CrispChatPageState();
}

class _CustomerServiceStrings {
  const _CustomerServiceStrings({
    required this.title,
    required this.connecting,
    required this.loadingSlow,
    required this.loadFailed,
    required this.timeout,
  });

  final String title;
  final String connecting;
  final String loadingSlow;
  final String loadFailed;
  final String timeout;

  static _CustomerServiceStrings of(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _CustomerServiceStrings(
      title: l10n.contactSupport,
      connecting: l10n.onlineSupportConnecting,
      loadingSlow: l10n.customerServiceLoadingSlow,
      loadFailed: l10n.customerServiceLoadFailed,
      timeout: l10n.xboardConnectionTimeout,
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
  bool _hasTimedOut = false;
  bool _deferredUserScriptStarted = false;
  late bool _isDarkMode;
  bool _didStartLoading = false;
  String? _localeTag;

  @override
  void initState() {
    super.initState();
    _isDarkMode =
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;
    _controller = WebViewController()
      ..setUserAgent(_crispUserAgent)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (!_usingSdkBootstrap) {
              _usingProxy = _isProxyUrl(url);
            }
            if (mounted) {
              setState(() {
                _hasTimedOut = false;
              });
            }
          },
          onPageFinished: (_) {
            if (!_usingSdkBootstrap) {
              unawaited(_injectDirectEmbedMonitor());
              unawaited(_runDeferredUserScript());
            }
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
    unawaited(_applySystemWebViewBackgroundColor());
    unawaited(_configureAndroidFileSelection(_controller));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextIsDarkMode = Theme.of(context).brightness == Brightness.dark;
    final nextLocaleTag = Localizations.localeOf(context).toLanguageTag();
    if (_isDarkMode != nextIsDarkMode) {
      _isDarkMode = nextIsDarkMode;
      unawaited(_applySystemWebViewBackgroundColor());
      unawaited(_applySystemTheme());
    }
    if (_localeTag != nextLocaleTag) {
      _localeTag = nextLocaleTag;
      unawaited(_applySystemLocale());
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
    _loadEmbed(
      _localizedCrispUri(officialCrispEmbedUri(widget.websiteId), _localeTag),
      usingProxy: false,
    );
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
    return _localizedCrispUri(
      crispEmbedUri(
        websiteId: widget.websiteId,
        proxyUrl: widget.crispProxyUrl,
      ),
      _localeTag,
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
      _hasTimedOut = true;
    });
  }

  String _buildSdkBootstrapHtml() {
    final strings = _strings;
    final websiteIdJson = jsonEncode(widget.websiteId);
    final localeTag = _localeTag ?? 'en';
    final localeTagJson = jsonEncode(localeTag);
    final crispLocaleJson = jsonEncode(_crispLocaleFromTag(localeTag));
    final colorModeJson = jsonEncode(_isDarkMode ? 'dark' : 'light');
    final background = _customerServiceBackgroundColorValue(_isDarkMode);
    final foreground = _customerServiceForegroundColorValue(_isDarkMode);
    final userScript = widget.userScript ?? '';
    final titleJson = jsonEncode(strings.title);
    final connectingJson = jsonEncode(strings.connecting);
    final loadingSlowJson = jsonEncode(strings.loadingSlow);
    final loadFailedJson = jsonEncode(strings.loadFailed);
    return '''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
  <link rel="dns-prefetch" href="https://client.crisp.chat">
  <link rel="dns-prefetch" href="https://settings.crisp.chat">
  <link rel="preconnect" href="https://client.crisp.chat" crossorigin>
  <link rel="preconnect" href="https://settings.crisp.chat" crossorigin>
  <title>${strings.title}</title>
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
  <div id="loading"><span id="spinner"></span><span id="loading-text">${strings.connecting}</span></div>
  <script>
    window.\$crisp = window.\$crisp || [];
    window.CRISP_WEBSITE_ID = $websiteIdJson;
    window.CRISP_RUNTIME_CONFIG = {
      locale: $crispLocaleJson,
    };
    window.__fastcatCrispReady = false;
    window.__fastcatCustomerServiceLocale = $localeTagJson;
    window.__fastcatCustomerServiceCrispLocale = $crispLocaleJson;
    window.__fastcatApplyCustomerServiceTheme = function(theme){
      try {
        document.documentElement.style.background = theme.background;
        document.documentElement.style.colorScheme = theme.isDark ? 'dark' : 'light';
        if (document.body) {
          document.body.style.background = theme.background;
          document.body.style.color = theme.foreground;
        }
        var loading = document.getElementById('loading');
        if (loading) {
          loading.style.background = theme.background;
          loading.style.color = theme.foreground;
        }
        var spinner = document.getElementById('spinner');
        if (spinner) {
          spinner.style.borderTopColor = theme.accent || '#2563eb';
        }
        window.\$crisp = window.\$crisp || [];
        window.\$crisp.push(["config", "locale", [window.__fastcatCustomerServiceCrispLocale || 'en']]);
        window.\$crisp.push(["config", "color:mode", [theme.isDark ? "dark" : "light"]]);
        window.CRISP_RUNTIME_CONFIG = window.CRISP_RUNTIME_CONFIG || {};
        window.CRISP_RUNTIME_CONFIG.locale = window.__fastcatCustomerServiceCrispLocale || 'en';
      } catch (_) {}
    };
    try {
      Object.defineProperty(navigator, 'language', { get: function(){ return window.__fastcatCustomerServiceLocale; }, configurable: true });
      Object.defineProperty(navigator, 'languages', { get: function(){ return [window.__fastcatCustomerServiceLocale]; }, configurable: true });
    } catch (_) {}
    $userScript

    (function(){
      var title = $titleJson;
      var colorMode = $colorModeJson;
      var connecting = $connectingJson;
      var loadingSlow = $loadingSlowJson;
      var loadFailed = $loadFailedJson;
      var loading = document.getElementById('loading');
      var loadingText = document.getElementById('loading-text');
      var ready = false;
      document.title = title;
      document.documentElement.lang = window.__fastcatCustomerServiceLocale || 'en';
      window.__fastcatApplyCustomerServiceTheme({
        isDark: colorMode === 'dark',
        background: '$background',
        foreground: '$foreground'
      });

      function openChat(){
        try {
          window.\$crisp = window.\$crisp || [];
          window.\$crisp.push(["config", "locale", [window.__fastcatCustomerServiceCrispLocale || 'en']]);
          window.\$crisp.push(["config", "color:mode", [colorMode]]);
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
        if (!ready && loadingText) loadingText.textContent = loadingSlow;
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
        if (loadingText) loadingText.textContent = loadFailed;
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
    final localeTag = _localeTag ?? 'en';
    final crispLocale = _crispLocaleFromTag(localeTag);
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
    window.__fastcatCustomerServiceLocale = '${_escapeJsString(localeTag)}';
    window.__fastcatCustomerServiceCrispLocale = '${_escapeJsString(crispLocale)}';
    window.CRISP_RUNTIME_CONFIG = window.CRISP_RUNTIME_CONFIG || {};
    window.CRISP_RUNTIME_CONFIG.locale = window.__fastcatCustomerServiceCrispLocale;
    window.__fastcatApplyCustomerServiceTheme = function(theme){
      try {
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
        style.textContent = ''
          + 'html,body{background:' + theme.background + ' !important;color:' + theme.foreground + ' !important;color-scheme:' + (theme.isDark ? 'dark' : 'light') + ' !important;}'
          + '#loading{background:' + theme.background + ' !important;color:' + theme.foreground + ' !important;}'
          + '#spinner{border:2px solid rgba(148,163,184,0.35) !important;border-top-color:' + (theme.accent || '#2563eb') + ' !important;}'
          + 'iframe[src*="crisp"],.crisp-client,[class*="crisp"],[id*="crisp"]{width:100% !important;height:100% !important;max-width:none !important;max-height:none !important;position:fixed !important;top:0 !important;left:0 !important;margin:0 !important;padding:0 !important;border:none !important;border-radius:0 !important;background:' + theme.background + ' !important;color-scheme:' + (theme.isDark ? 'dark' : 'light') + ' !important;}';
        window.\$crisp = window.\$crisp || [];
        window.\$crisp.push(["config", "locale", [window.__fastcatCustomerServiceCrispLocale || 'en']]);
        window.\$crisp.push(["config", "color:mode", [theme.isDark ? "dark" : "light"]]);
        window.CRISP_RUNTIME_CONFIG = window.CRISP_RUNTIME_CONFIG || {};
        window.CRISP_RUNTIME_CONFIG.locale = window.__fastcatCustomerServiceCrispLocale || 'en';
      } catch (_) {}
    };
    document.documentElement.style.background = '$background';
    document.documentElement.style.colorScheme = '${_isDarkMode ? 'dark' : 'light'}';
    document.documentElement.lang = window.__fastcatCustomerServiceLocale;
    if (document.body) {
      document.body.style.background = '$background';
      document.body.style.color = '$foreground';
    }
    window.__fastcatApplyCustomerServiceTheme({
      isDark: ${_isDarkMode ? 'true' : 'false'},
      background: '$background',
      foreground: '$foreground'
    });
    function markReady(){
      window.__fastcatCrispReady = true;
    }
    function directLooksReady(){
      try {
        window.\$crisp = window.\$crisp || [];
        window.\$crisp.push(["config", "locale", [window.__fastcatCustomerServiceCrispLocale || 'en']]);
        window.\$crisp.push(["config", "color:mode", [${_isDarkMode ? '"dark"' : '"light"'}]]);
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

  Future<void> _applySystemWebViewBackgroundColor() async {
    if (!(Platform.isAndroid || Platform.isIOS)) return;
    try {
      await _controller.setBackgroundColor(
        _customerServiceBackgroundColor(_isDarkMode),
      );
    } catch (_) {}
  }

  Future<void> _applySystemTheme() async {
    final script = '''
(function(){
  try {
    if (typeof window.__fastcatApplyCustomerServiceTheme !== 'function') return;
    window.__fastcatApplyCustomerServiceTheme({
      isDark: ${_isDarkMode ? 'true' : 'false'},
      background: '${_customerServiceBackgroundColorValue(_isDarkMode)}',
      foreground: '${_customerServiceForegroundColorValue(_isDarkMode)}',
      accent: '${_isDarkMode ? '#60a5fa' : '#2563eb'}'
    });
  } catch(_) {}
})();''';
    try {
      await _controller.runJavaScript(script);
    } catch (_) {}
  }

  Future<void> _applySystemLocale() async {
    if (!mounted) return;
    final strings = _strings;
    final payload = jsonEncode({
      'title': strings.title,
      'connecting': strings.connecting,
      'loadingSlow': strings.loadingSlow,
      'loadFailed': strings.loadFailed,
      'locale': _localeTag ?? 'en',
      'crispLocale': _crispLocaleFromTag(_localeTag ?? 'en'),
    });
    final script = '''
(function(){
  try {
    var payload = $payload;
    window.__fastcatCustomerServiceLocale = payload.locale;
    window.__fastcatCustomerServiceCrispLocale = payload.crispLocale || payload.locale;
    document.title = payload.title;
    document.documentElement.lang = payload.locale;
    try {
      window.\$crisp = window.\$crisp || [];
      window.\$crisp.push(["config", "locale", [window.__fastcatCustomerServiceCrispLocale]]);
      window.CRISP_RUNTIME_CONFIG = window.CRISP_RUNTIME_CONFIG || {};
      window.CRISP_RUNTIME_CONFIG.locale = window.__fastcatCustomerServiceCrispLocale;
    } catch(_) {}
    var loadingText = document.getElementById('loading-text');
    if (loadingText && loadingText.textContent) {
      var current = loadingText.textContent;
      if (current !== payload.loadingSlow && current !== payload.loadFailed) {
        loadingText.textContent = payload.connecting;
      }
    }
    if (typeof window.__fastcatApplyCustomerServiceTheme === 'function') {
      window.__fastcatApplyCustomerServiceTheme({
        isDark: ${_isDarkMode ? 'true' : 'false'},
        background: '${_customerServiceBackgroundColorValue(_isDarkMode)}',
        foreground: '${_customerServiceForegroundColorValue(_isDarkMode)}',
        accent: '${_isDarkMode ? '#60a5fa' : '#2563eb'}'
      });
    }
  } catch(_) {}
})();''';
    try {
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

  _CustomerServiceStrings get _strings => mounted
      ? _CustomerServiceStrings.of(context)
      : const _CustomerServiceStrings(
          title: 'Support',
          connecting: 'Connecting...',
          loadingSlow: 'Loading is taking longer than expected, please wait...',
          loadFailed:
              'Support failed to load, please check your network and try again.',
          timeout: 'Connection timeout, please check network connection',
        );

  String _escapeJsString(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r');
  }

  @override
  Widget build(BuildContext context) {
    final strings = _strings;
    final backgroundColor = _customerServiceBackgroundColor(_isDarkMode);
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        centerTitle: true,
        title: Text(strings.title),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_hasTimedOut)
            Positioned.fill(
              child: ColoredBox(
                color: backgroundColor,
                child: Center(
                  child: Text(
                    strings.timeout,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
