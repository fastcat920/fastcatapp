import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/common/webview2_check.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/core/core.dart';
import 'package:fl_clash/xboard/features/auth/utils/crisp_url_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart' as iaw;

final _logger = FileLogger('windows_chat_page.dart');

String _crispLocaleFromTag(String? localeTag) {
  final normalized =
      (localeTag ?? '').trim().replaceAll('_', '-').toLowerCase();
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

/// Windows desktop customer-service page using WebView2.
///
/// Matches the Mac CrispChatPage feature set:
/// - SDK bootstrap → proxy embed → official embed fallback chain
/// - Proxy domain support with timeout auto-fallback
/// - User info pre-injection via userScript / deferredUserScript
/// - Dark mode / locale sync
class WindowsChatPage extends StatefulWidget {
  final String? salesmartlyScriptUrl;
  final String? crispWebsiteId;
  final String? crispProxyUrl;
  final String? userScript;
  final Future<String?> Function()? deferredUserScript;

  const WindowsChatPage({
    super.key,
    this.salesmartlyScriptUrl,
    this.crispWebsiteId,
    this.crispProxyUrl,
    this.userScript,
    this.deferredUserScript,
  }) : assert(
          salesmartlyScriptUrl != null || crispWebsiteId != null,
          'salesmartlyScriptUrl or crispWebsiteId is required',
        );

  static bool get isSupported => Platform.isWindows;

  @override
  State<WindowsChatPage> createState() => _WindowsChatPageState();
}

class _WindowsChatPageState extends State<WindowsChatPage> {
  iaw.InAppWebViewController? _controller;
  Timer? _sdkFallbackTimer;
  Timer? _embedFallbackTimer;
  bool _usingSdkBootstrap = true;
  bool _usingProxy = false;
  bool _didFallbackToOfficial = false;
  bool _isLoading = true;
  bool _hasTimedOut = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _didStartLoading = false;
  bool _deferredUserScriptStarted = false;
  String? _localeTag;
  bool _isDarkMode = false;

  static const _sdkFallbackDelay = Duration(seconds: 5);
  static const _embedTimeoutDelay = Duration(seconds: 25);

  @override
  void initState() {
    super.initState();
    _logger.info('[WindowsChat] initState: crispWebsiteId=${widget.crispWebsiteId != null ? "present" : "empty"}, crispProxyUrl=${widget.crispProxyUrl != null ? "present" : "empty"}, userScript=${widget.userScript != null ? "present" : "empty"}');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextIsDarkMode = Theme.of(context).brightness == Brightness.dark;
    final nextLocaleTag = Localizations.localeOf(context).toLanguageTag();
    if (_isDarkMode != nextIsDarkMode) {
      _isDarkMode = nextIsDarkMode;
      unawaited(_applySystemTheme());
    }
    if (_localeTag != nextLocaleTag) {
      _localeTag = nextLocaleTag;
      unawaited(_applySystemLocale());
    }
    if (!_didStartLoading) {
      _didStartLoading = true;
      _loadSdkBootstrap();
    }
  }

  @override
  void dispose() {
    _sdkFallbackTimer?.cancel();
    _embedFallbackTimer?.cancel();
    super.dispose();
  }

  // ── dark / locale sync ──────────────────────────────────────────

  Color _backgroundColor() {
    return _isDarkMode ? const Color(0xFF101010) : const Color(0xFFF5F5F5);
  }

  String _backgroundColorValue() {
    return _isDarkMode ? '#101010' : '#f5f5f5';
  }

  String _foregroundColorValue() {
    return _isDarkMode ? '#f3f4f6' : '#999999';
  }

  Future<void> _applySystemTheme() async {
    final script = '''
(function(){
  try {
    if (typeof window.__fastcatApplyCustomerServiceTheme === 'function') {
      window.__fastcatApplyCustomerServiceTheme({
        isDark: ${_isDarkMode ? 'true' : 'false'},
        background: '${_backgroundColorValue()}',
        foreground: '${_foregroundColorValue()}',
        accent: '${_isDarkMode ? '#60a5fa' : '#2563eb'}'
      });
    }
  } catch(_) {}
})();''';
    try {
      await _controller?.evaluateJavascript(source: script);
    } catch (_) {}
  }

  Future<void> _applySystemLocale() async {
    if (!mounted || _localeTag == null) return;
    final l10n = AppLocalizations.of(context);
    final payload = jsonEncode({
      'title': l10n.contactSupport,
      'connecting': l10n.onlineSupportConnecting,
      'loadingSlow': l10n.customerServiceLoadingSlow,
      'loadFailed': l10n.customerServiceLoadFailed,
      'locale': _localeTag!,
      'crispLocale': _crispLocaleFromTag(_localeTag),
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
    } catch(_) {}
    if (typeof window.__fastcatApplyCustomerServiceTheme === 'function') {
      window.__fastcatApplyCustomerServiceTheme({
        isDark: ${_isDarkMode ? 'true' : 'false'},
        background: '${_backgroundColorValue()}',
        foreground: '${_foregroundColorValue()}',
        accent: '${_isDarkMode ? '#60a5fa' : '#2563eb'}'
      });
    }
  } catch(_) {}
})();''';
    try {
      await _controller?.evaluateJavascript(source: script);
    } catch (_) {}
  }

  // ── URL helpers ──────────────────────────────────────────────────

  bool _isProxyUrl(String url) {
    final proxy = normalizeCrispProxyUrl(widget.crispProxyUrl);
    return proxy.isNotEmpty && url.startsWith(proxy);
  }

  Uri _preferredEmbedUri() {
    return _localizedCrispUri(
      crispEmbedUri(
        websiteId: widget.crispWebsiteId!,
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
      final result = await _controller?.evaluateJavascript(source: '''
(function(){
  try { return window.__fastcatCrispReady === true; } catch (_) { return false; }
})();''');
      if (result is bool) return result;
      return result.toString().contains('true');
    } catch (_) {
      return false;
    }
  }

  // ── Fallback chain ───────────────────────────────────────────────

  void _loadSdkBootstrap() {
    _sdkFallbackTimer?.cancel();
    _embedFallbackTimer?.cancel();
    _usingSdkBootstrap = true;
    _usingProxy = false;
    _didFallbackToOfficial = false;
    _hasTimedOut = false;
    _sdkFallbackTimer = Timer(
      _sdkFallbackDelay,
      () => unawaited(_fallbackFromSdkToEmbed()),
    );
  }

  Future<void> _fallbackFromSdkToEmbed() async {
    if (!mounted || !_usingSdkBootstrap) return;
    if (await _isCrispReady()) return;
    final usingProxy = isCrispProxyConfigured(widget.crispProxyUrl);
    _loadEmbed(_preferredEmbedUri(), usingProxy: usingProxy);
  }

  void _loadEmbed(Uri uri, {required bool usingProxy}) {
    _sdkFallbackTimer?.cancel();
    _embedFallbackTimer?.cancel();
    _usingSdkBootstrap = false;
    _usingProxy = usingProxy;
    _hasTimedOut = false;
    _hasError = false;
    if (!usingProxy) _didFallbackToOfficial = true;
    if (mounted) {
      setState(() {
        _hasTimedOut = false;
        _hasError = false;
      });
    }
    _embedFallbackTimer = Timer(
      _embedTimeoutDelay,
      () => unawaited(_handleEmbedTimeout()),
    );
    unawaited(
      _controller?.loadUrl(
        urlRequest: iaw.URLRequest(url: iaw.WebUri(uri.toString())),
      ),
    );
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
    _loadEmbed(
      _localizedCrispUri(
        officialCrispEmbedUri(widget.crispWebsiteId!),
        _localeTag,
      ),
      usingProxy: false,
    );
  }

  void _showTimeout() {
    _sdkFallbackTimer?.cancel();
    _embedFallbackTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _hasTimedOut = true;
      _hasError = false;
    });
  }

  // ── Post-load injection ──────────────────────────────────────────

  Future<void> _injectDirectEmbedMonitor() async {
    final background = _backgroundColorValue();
    final foreground = _foregroundColorValue();
    final userScript = widget.userScript ?? '';
    final localeTag = _localeTag ?? 'en';
    final crispLocale = _crispLocaleFromTag(localeTag);
    final script = '''
(function(){
  try {
    if (window.__fastcatCrispDirectMonitorInstalled) return;
    window.__fastcatCrispDirectMonitorInstalled = true;
    window.\$crisp = window.\$crisp || [];
    try { $userScript } catch(_) {}
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
    function markReady(){ window.__fastcatCrispReady = true; }
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
      childList: true, subtree: true, attributes: true
    });
  } catch(_) {}
})();''';
    try {
      await _controller?.evaluateJavascript(source: script);
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
      await _controller?.evaluateJavascript(source: script);
    } catch (_) {}
  }

  // ── SDK bootstrap HTML ───────────────────────────────────────────

  String _buildSdkBootstrapHtml() {
    final l10n = AppLocalizations.of(context);
    final websiteIdJson = jsonEncode(widget.crispWebsiteId);
    final localeTag = _localeTag ?? 'en';
    final localeTagJson = jsonEncode(localeTag);
    final crispLocaleJson = jsonEncode(_crispLocaleFromTag(localeTag));
    final colorModeJson = jsonEncode(_isDarkMode ? 'dark' : 'light');
    final background = _backgroundColorValue();
    final foreground = _foregroundColorValue();
    final userScript = widget.userScript ?? '';
    final connectingJson = jsonEncode(l10n.onlineSupportConnecting);
    final loadingSlowJson = jsonEncode(l10n.customerServiceLoadingSlow);
    final loadFailedJson = jsonEncode(l10n.customerServiceLoadFailed);
    return '''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
  <link rel="dns-prefetch" href="https://client.crisp.chat">
  <link rel="dns-prefetch" href="https://settings.crisp.chat">
  <link rel="preconnect" href="https://client.crisp.chat" crossorigin>
  <link rel="preconnect" href="https://settings.crisp.chat" crossorigin>
  <title>${l10n.contactSupport}</title>
  <style>
    * { box-sizing: border-box; }
    html, body {
      width: 100%; height: 100%; margin: 0;
      background: $background; color: $foreground; overflow: hidden;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }
    #loading {
      position: fixed; inset: 0; display: flex; align-items: center;
      justify-content: center; gap: 12px;
      background: $background; color: $foreground; font-size: 14px; z-index: 2147483647;
    }
    #spinner {
      width: 18px; height: 18px;
      border: 2px solid rgba(148, 163, 184, 0.35);
      border-top-color: #2563eb; border-radius: 50%;
      animation: spin 0.8s linear infinite;
    }
    @keyframes spin { to { transform: rotate(360deg); } }
  </style>
</head>
<body>
  <div id="loading"><span id="spinner"></span><span id="loading-text">${l10n.onlineSupportConnecting}</span></div>
  <script>
    window.\$crisp = window.\$crisp || [];
    window.CRISP_WEBSITE_ID = $websiteIdJson;
    window.CRISP_RUNTIME_CONFIG = {
      locale: $crispLocaleJson,
      lock_full_view: true
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
        if (spinner) spinner.style.borderTopColor = theme.accent || '#2563eb';
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
      var colorMode = $colorModeJson;
      var connecting = $connectingJson;
      var loadingSlow = $loadingSlowJson;
      var loadFailed = $loadFailedJson;
      var loading = document.getElementById('loading');
      var loadingText = document.getElementById('loading-text');
      var ready = false;
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

      var openTimer = setInterval(function(){ openChat(); expandFrames(); }, 500);
      setTimeout(function(){
        clearInterval(openTimer); openChat(); expandFrames();
        if (!ready && loadingText) loadingText.textContent = loadingSlow;
      }, 15000);

      new MutationObserver(function(){ openChat(); expandFrames(); })
        .observe(document.documentElement, { childList: true, subtree: true, attributes: true });

      var script = document.createElement('script');
      script.src = 'https://client.crisp.chat/l.js';
      script.async = true;
      script.onerror = function(){ if (loadingText) loadingText.textContent = loadFailed; };
      document.head.appendChild(script);
    })();
  </script>
</body>
</html>''';
  }

  String _escapeJsString(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r');
  }

  // ── Salesmartly (legacy) ─────────────────────────────────────────

  Future<void> _injectSalesmartlySDK(
    iaw.InAppWebViewController controller,
  ) async {
    final scriptUrl = widget.salesmartlyScriptUrl!;
    final scriptUrlEscaped = scriptUrl.replaceAll('\\', '\\\\').replaceAll("'", "\\'");
    await controller.evaluateJavascript(source: '''
      document.open();
      document.write('<html><head><meta charset="utf-8"><style>*{margin:0;padding:0}html,body{width:100%;height:100%;background:#f5f5f5}#ss_loading{display:flex;align-items:center;justify-content:center;height:100%;color:#999;font-family:-apple-system,sans-serif;font-size:14px}</style></head><body><div id="ss_loading">正在连接客服...</div></body></html>');
      document.close();
      window.__ssc = window.__ssc || {};
      window.__ssc.setting = { hideIcon: true };
      var s = document.createElement('script');
      s.src = '$scriptUrlEscaped';
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
          } else { setTimeout(w, 300); }
        })();
      };
      s.onerror = function() {
        var e = document.getElementById('ss_loading');
        if (e) e.textContent = '加载失败，请检查网络后重试';
      };
      document.head.appendChild(s);
    ''');
  }

  // ── Build ────────────────────────────────────────────────────────

  bool _hasWebView2Runtime() {
    try {
      return WebView2Check.isInstalled();
    } catch (e, stackTrace) {
      _logger.warning('[WindowsChat] WebView2 runtime check failed', e, stackTrace);
      return false;
    }
  }

  Widget _buildError(BuildContext context, String message) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.support_agent_outlined, size: 40,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _hasError = false;
                  _hasTimedOut = false;
                  _errorMessage = '';
                  _didStartLoading = false;
                });
              },
              icon: const Icon(Icons.refresh),
              label: Text(l10n.refresh),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCrispWebView() {
    if (!_hasWebView2Runtime()) {
      return _buildError(context, 'WebView2 Runtime 未安装，无法加载内嵌客服。');
    }
    final baseUri = _sdkBootstrapBaseUri();
    final backgroundColor = _backgroundColor();
    return Stack(
      fit: StackFit.expand,
      children: [
        iaw.InAppWebView(
          key: const ValueKey('windows-chat-webview'),
          initialData: iaw.InAppWebViewInitialData(
            data: _buildSdkBootstrapHtml(),
            mimeType: 'text/html',
            encoding: 'utf-8',
            baseUrl: iaw.WebUri(baseUri.toString()),
          ),
          initialSettings: iaw.InAppWebViewSettings(
            javaScriptEnabled: true,
            javaScriptCanOpenWindowsAutomatically: false,
            mediaPlaybackRequiresUserGesture: false,
            supportZoom: false,
            transparentBackground: false,
            useShouldOverrideUrlLoading: true,
          ),
          onWebViewCreated: (controller) {
            _controller = controller;
          },
          onLoadStart: (_, url) {
            if (!_usingSdkBootstrap) {
              _usingProxy = _isProxyUrl(url?.toString() ?? '');
            }
            if (mounted) {
              setState(() {
                _hasTimedOut = false;
              });
            }
          },
          onLoadStop: (_, __) async {
            if (_usingSdkBootstrap) {
              unawaited(_runDeferredUserScript());
            } else {
              unawaited(_injectDirectEmbedMonitor());
              unawaited(_runDeferredUserScript());
            }
          },
          onReceivedError: (_, request, error) {
            if (request.isForMainFrame == false) return;
            _logger.warning('[WindowsChat] load error: $error');
            _handleRouteError();
          },
          shouldOverrideUrlLoading: (_, navigationAction) async {
            final uri = navigationAction.request.url;
            final scheme = uri?.scheme.toLowerCase();
            if (scheme == null || scheme == 'http' || scheme == 'https' || scheme == 'about') {
              return iaw.NavigationActionPolicy.ALLOW;
            }
            return iaw.NavigationActionPolicy.CANCEL;
          },
          onCreateWindow: (_, __) async => false,
        ),
        if (_hasTimedOut)
          ColoredBox(
            color: backgroundColor,
            child: Center(
              child: Text(
                AppLocalizations.of(context).xboardConnectionTimeout,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSalesmartlyWebView() {
    if (!_hasWebView2Runtime()) {
      return _buildError(context, 'WebView2 Runtime 未安装，无法加载内嵌客服。');
    }
    final initialUri = Uri.parse('https://www.salesmartly.com/robots.txt');
    return Stack(
      fit: StackFit.expand,
      children: [
        iaw.InAppWebView(
          key: const ValueKey('windows-chat-salesmartly'),
          initialUrlRequest: iaw.URLRequest(url: iaw.WebUri(initialUri.toString())),
          initialSettings: iaw.InAppWebViewSettings(
            javaScriptEnabled: true,
            javaScriptCanOpenWindowsAutomatically: false,
            mediaPlaybackRequiresUserGesture: false,
            supportZoom: false,
            transparentBackground: false,
            useShouldOverrideUrlLoading: true,
          ),
          onWebViewCreated: (controller) {
            _controller = controller;
          },
          onLoadStart: (_, __) {
            if (mounted) setState(() => _isLoading = true);
          },
          onLoadStop: (controller, _) async {
            try {
              await _injectSalesmartlySDK(controller);
            } catch (e, stackTrace) {
              _logger.warning('[WindowsChat] Salesmartly injection failed', e, stackTrace);
            }
          },
          onReceivedError: (_, request, error) {
            if (request.isForMainFrame == false) return;
            _logger.warning('[WindowsChat] Salesmartly load error: $error');
          },
          shouldOverrideUrlLoading: (_, navigationAction) async {
            final uri = navigationAction.request.url;
            final scheme = uri?.scheme.toLowerCase();
            if (scheme == null || scheme == 'http' || scheme == 'https' || scheme == 'about') {
              return iaw.NavigationActionPolicy.ALLOW;
            }
            return iaw.NavigationActionPolicy.CANCEL;
          },
          onCreateWindow: (_, __) async => false,
        ),
        if (_isLoading)
          const ColoredBox(
            color: Color(0xFFF5F5F5),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = _hasError
        ? _buildError(context, _errorMessage)
        : widget.salesmartlyScriptUrl != null
            ? _buildSalesmartlyWebView()
            : _buildCrispWebView();
    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text(AppLocalizations.of(context).onlineSupportTitle),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: body,
      ),
    );
  }
}
