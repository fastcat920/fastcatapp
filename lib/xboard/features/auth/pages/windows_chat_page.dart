import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/common/webview2_check.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/core/core.dart';
import 'package:fl_clash/xboard/features/auth/utils/crisp_url_helper.dart';
import 'package:flutter/foundation.dart';
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
/// Loads the Crisp embed URL directly (proxy-first, official fallback).
/// No longer uses the l.js SDK bootstrap.
class WindowsChatPage extends StatefulWidget {
  final String? salesmartlyScriptUrl;
  final String? crispWebsiteId;
  final String? crispProxyUrl;
  final String? userScript;
  final Future<String?> Function()? deferredUserScript;
  final VoidCallback? onBackPressed;
  final ValueListenable<bool>? visibilityListenable;

  const WindowsChatPage({
    super.key,
    this.salesmartlyScriptUrl,
    this.crispWebsiteId,
    this.crispProxyUrl,
    this.userScript,
    this.deferredUserScript,
    this.onBackPressed,
    this.visibilityListenable,
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
  Timer? _embedFallbackTimer;
  bool _usingProxy = false;
  bool _didFallbackToOfficial = false;
  bool _isLoading = true;
  bool _hasError = false;
  Timer? _readyPollTimer;
  bool _didStartLoading = false;
  bool _deferredUserScriptStarted = false;
  String? _localeTag;
  bool _isDarkMode = false;

  static const _embedTimeoutDelay = Duration(seconds: 25);

  @override
  void initState() {
    super.initState();
    _logger.info(
        '[WindowsChat] initState: crispWebsiteId=${widget.crispWebsiteId != null ? "present" : "empty"}, crispProxyUrl=${widget.crispProxyUrl != null ? "present" : "empty"}');
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
      _loadEmbed();
    }
  }

  @override
  void dispose() {
    _embedFallbackTimer?.cancel();
    _readyPollTimer?.cancel();
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

  // ── Embed loading & fallback chain ──────────────────────────────

  void _loadEmbed({bool useProxy = true}) {
    _embedFallbackTimer?.cancel();
    _stopReadyPolling();
    final actualUseProxy =
        useProxy && isCrispProxyConfigured(widget.crispProxyUrl);
    _usingProxy = actualUseProxy;
    _didFallbackToOfficial = !actualUseProxy;
    _hasError = false;
    _isLoading = true;
    if (mounted) {
      setState(() {
        _hasError = false;
        _isLoading = true;
      });
    }
    final uri = actualUseProxy
        ? _preferredEmbedUri()
        : _localizedCrispUri(
            officialCrispEmbedUri(widget.crispWebsiteId!),
            _localeTag,
          );
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
    if (!mounted) return;
    if (await _isCrispReady()) return;
    if (_usingProxy && !_didFallbackToOfficial) {
      _fallbackToOfficialIfNeeded();
      return;
    }
    _showError();
  }

  void _handleRouteError() {
    if (_usingProxy && !_didFallbackToOfficial) {
      _fallbackToOfficialIfNeeded();
      return;
    }
    _showError();
  }

  void _fallbackToOfficialIfNeeded() {
    if (!_usingProxy || _didFallbackToOfficial) {
      _showError();
      return;
    }
    _didFallbackToOfficial = true;
    _loadEmbed(useProxy: false);
  }

  void _showError() {
    _embedFallbackTimer?.cancel();
    _stopReadyPolling();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _hasError = true;
    });
  }

  void _startReadyPolling() {
    _readyPollTimer?.cancel();
    _readyPollTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      unawaited(_checkAndHideLoading());
    });
  }

  Future<void> _checkAndHideLoading() async {
    if (!mounted || !_isLoading) return;
    if (await _isCrispReady()) {
      _stopReadyPolling();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _stopReadyPolling() {
    _readyPollTimer?.cancel();
    _readyPollTimer = null;
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

  // ── Salesmartly (legacy) ─────────────────────────────────────────

  Future<void> _injectSalesmartlySDK(
    iaw.InAppWebViewController controller,
  ) async {
    final scriptUrl = widget.salesmartlyScriptUrl!;
    final scriptUrlEscaped =
        scriptUrl.replaceAll('\\', '\\\\').replaceAll("'", "\\'");
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
      _logger.warning(
          '[WindowsChat] WebView2 runtime check failed', e, stackTrace);
      return false;
    }
  }

  Widget _buildErrorPage(BuildContext context, String message,
      {bool canRetry = true}) {
    final l10n = AppLocalizations.of(context);
    final isDark = _isDarkMode;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              canRetry ? Icons.cloud_off : Icons.warning_amber_rounded,
              size: 48,
              color: isDark ? Colors.white38 : Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white54 : Colors.grey,
              ),
            ),
            if (canRetry) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _loadEmbed(),
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(l10n.refresh),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCrispWebView() {
    final l10n = AppLocalizations.of(context);
    if (!_hasWebView2Runtime()) {
      return _buildErrorPage(context, 'WebView2 Runtime 未安装，无法加载内嵌客服。',
          canRetry: false);
    }
    final preferredUri = _preferredEmbedUri();
    final backgroundColor = _backgroundColor();
    return Stack(
      fit: StackFit.expand,
      children: [
        iaw.InAppWebView(
          key: const ValueKey('windows-chat-webview'),
          initialUrlRequest:
              iaw.URLRequest(url: iaw.WebUri(preferredUri.toString())),
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
            _usingProxy = _isProxyUrl(url?.toString() ?? '');
            if (mounted) {
              setState(() {
                _hasError = false;
              });
            }
          },
          onLoadStop: (_, __) async {
            unawaited(_injectDirectEmbedMonitor());
            unawaited(_runDeferredUserScript());
            _startReadyPolling();
          },
          onReceivedError: (_, request, error) {
            if (request.isForMainFrame == false) return;
            _logger.warning('[WindowsChat] load error: $error');
            _handleRouteError();
          },
          shouldOverrideUrlLoading: (_, navigationAction) async {
            final uri = navigationAction.request.url;
            final scheme = uri?.scheme.toLowerCase();
            if (scheme == null ||
                scheme == 'http' ||
                scheme == 'https' ||
                scheme == 'about') {
              return iaw.NavigationActionPolicy.ALLOW;
            }
            return iaw.NavigationActionPolicy.CANCEL;
          },
          onCreateWindow: (_, __) async => false,
        ),
        if (_hasError)
          _buildErrorPage(context, l10n.customerServiceLoadFailed)
        else if (_isLoading)
          Positioned.fill(
            child: ColoredBox(
              color: backgroundColor,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l10n.onlineSupportConnecting,
                      style: TextStyle(
                        fontSize: 14,
                        color: _isDarkMode ? Colors.white70 : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSalesmartlyWebView() {
    if (!_hasWebView2Runtime()) {
      return _buildErrorPage(context, 'WebView2 Runtime 未安装，无法加载内嵌客服。',
          canRetry: false);
    }
    final initialUri = Uri.parse('https://www.salesmartly.com/robots.txt');
    return Stack(
      fit: StackFit.expand,
      children: [
        iaw.InAppWebView(
          key: const ValueKey('windows-chat-salesmartly'),
          initialUrlRequest:
              iaw.URLRequest(url: iaw.WebUri(initialUri.toString())),
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
              _logger.warning(
                  '[WindowsChat] Salesmartly injection failed', e, stackTrace);
            }
          },
          onReceivedError: (_, request, error) {
            if (request.isForMainFrame == false) return;
            _logger.warning('[WindowsChat] Salesmartly load error: $error');
          },
          shouldOverrideUrlLoading: (_, navigationAction) async {
            final uri = navigationAction.request.url;
            final scheme = uri?.scheme.toLowerCase();
            if (scheme == null ||
                scheme == 'http' ||
                scheme == 'https' ||
                scheme == 'about') {
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
    final body = widget.salesmartlyScriptUrl != null
        ? _buildSalesmartlyWebView()
        : _buildCrispWebView();
    Widget buildScaffold(bool isVisible) {
      return PopScope(
        canPop: widget.onBackPressed == null || !isVisible,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) widget.onBackPressed?.call();
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(AppLocalizations.of(context).onlineSupportTitle),
            leading: BackButton(
              onPressed:
                  widget.onBackPressed ?? () => Navigator.of(context).pop(),
            ),
          ),
          body: body,
        ),
      );
    }

    final visibility = widget.visibilityListenable;
    if (visibility == null) return buildScaffold(true);
    return ValueListenableBuilder<bool>(
      valueListenable: visibility,
      builder: (_, isVisible, __) => buildScaffold(isVisible),
    );
  }

  String _escapeJsString(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r');
  }
}
