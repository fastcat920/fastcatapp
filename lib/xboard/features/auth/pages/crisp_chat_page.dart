import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_win_floating/webview_plugin.dart';
import 'package:fl_clash/xboard/features/auth/utils/crisp_url_helper.dart';
import 'package:fl_clash/xboard/features/auth/utils/customer_service_helper.dart';

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
  final VoidCallback? onBackPressed;
  final ValueListenable<CustomerServiceSessionState>? sessionListenable;

  const CrispChatPage({
    super.key,
    required this.websiteId,
    this.crispProxyUrl,
    this.userScript,
    this.deferredUserScript,
    this.onBackPressed,
    this.sessionListenable,
  });

  /// 是否支持系统内嵌 WebView
  static bool get isSupported =>
      Platform.isAndroid ||
      Platform.isIOS ||
      Platform.isMacOS ||
      Platform.isLinux;

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
  Timer? _embedFallbackTimer;
  bool _usingProxy = false;
  bool _didFallbackToOfficial = false;
  bool _isLoading = true;
  bool _hasError = false;
  Timer? _readyPollTimer;
  bool _deferredUserScriptStarted = false;
  late bool _isDarkMode;
  bool _didStartLoading = false;
  String? _localeTag;
  int _lastAppliedRestoreToken = -1;
  bool? _lastLinuxVisibility;
  bool _linuxLoadingMaskRegistered = false;

  @override
  void initState() {
    super.initState();
    _isDarkMode =
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;
    final prewarmed = CustomerServiceHelper.consumePrewarmedMacController(
      brightness: Brightness.light,
      localeTag: 'en',
    );
    if (prewarmed != null) {
      _controller = prewarmed;
    } else {
      _controller = WebViewController()
        ..setUserAgent(_crispUserAgent)
        ..setJavaScriptMode(JavaScriptMode.unrestricted);
    }
    _controller.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (url) {
          _usingProxy = _isProxyUrl(url);
          unawaited(_setLinuxWebViewVisibility(true));
          if (mounted) {
            setState(() {
              _hasError = false;
            });
          }
        },
        onPageFinished: (_) {
          unawaited(_injectDirectEmbedMonitor());
          unawaited(_runDeferredUserScript());
          _startReadyPolling();
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
    unawaited(_setLinuxWebViewVisibility(false));
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
      unawaited(_loadPreferredCrispUrl());
    }
  }

  @override
  void dispose() {
    _embedFallbackTimer?.cancel();
    _readyPollTimer?.cancel();
    final platformController = _controller.platform;
    if (Platform.isLinux &&
        platformController is WindowsPlatformWebViewController) {
      unawaited(platformController.controller.dispose());
    }
    super.dispose();
  }

  Future<void> _setLinuxWebViewVisibility(bool visible) async {
    if (!Platform.isLinux || _lastLinuxVisibility == visible) return;
    _lastLinuxVisibility = visible;
    final platformController = _controller.platform;
    if (platformController is! WindowsPlatformWebViewController) return;
    try {
      await platformController.controller.setVisibility(visible);
    } catch (_) {
      // The native WebView may still be initializing or already disposed.
    }
  }

  Future<void> _handleBackPressed() async {
    await _setLinuxWebViewVisibility(false);
    if (!mounted) return;
    final callback = widget.onBackPressed;
    if (callback != null) {
      callback();
    } else {
      Navigator.of(context).pop();
    }
  }

  // ── Embed loading ────────────────────────────────────────────────

  Future<void> _loadPreferredCrispUrl() async {
    await _ensureLinuxLoadingMaskRegistered();
    if (!mounted) return;
    final usingProxy = isCrispProxyConfigured(widget.crispProxyUrl);
    _loadEmbed(_preferredEmbedUri(), usingProxy: usingProxy);
  }

  void _loadEmbed(Uri uri, {required bool usingProxy}) {
    _embedFallbackTimer?.cancel();
    _stopReadyPolling();
    _usingProxy = usingProxy;
    _didFallbackToOfficial = !usingProxy;
    _hasError = false;
    _isLoading = true;
    if (mounted) {
      setState(() {
        _hasError = false;
        _isLoading = true;
      });
    }
    _embedFallbackTimer = Timer(
      const Duration(seconds: 25),
      () => unawaited(_handleEmbedTimeout()),
    );
    unawaited(_controller.loadRequest(uri));
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
    _loadEmbed(
      CustomerServiceHelper.localizedCrispUri(
          officialCrispEmbedUri(widget.websiteId), _localeTag),
      usingProxy: false,
    );
  }

  void _showError() {
    _embedFallbackTimer?.cancel();
    _stopReadyPolling();
    if (!mounted) return;
    unawaited(_setLinuxWebViewVisibility(false));
    setState(() {
      _hasError = true;
      _isLoading = false;
    });
  }

  void _startReadyPolling() {
    _readyPollTimer?.cancel();
    _readyPollTimer = Timer.periodic(const Duration(milliseconds: 150), (_) {
      unawaited(_checkAndHideLoading());
    });
  }

  Future<void> _checkAndHideLoading() async {
    if (!mounted || !_isLoading) return;
    if (await _isCrispReady()) {
      _stopReadyPolling();
      // 延迟 200ms 再移除遮罩，留给 Crisp 内部渲染时间，避免闪现原生加载转圈
      await Future.delayed(const Duration(milliseconds: 80));
      await _hideLinuxLoadingMask();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _ensureLinuxLoadingMaskRegistered() async {
    if (!Platform.isLinux || _linuxLoadingMaskRegistered) return;
    final platformController = _controller.platform;
    if (platformController is! WindowsPlatformWebViewController) return;
    final background = _customerServiceBackgroundColorValue(_isDarkMode);
    final foreground = _customerServiceForegroundColorValue(_isDarkMode);
    final accent = _isDarkMode ? '#60a5fa' : '#2563eb';
    final connecting = jsonEncode(_strings.connecting);
    final script = '''
(function(){
  window.__fastcatInstallLoadingMask = function(){
    try {
      if (document.getElementById('fastcat-linux-support-mask')) return;
      var style = document.createElement('style');
      style.id = 'fastcat-linux-support-mask-style';
      style.textContent = '@keyframes fastcat-spin{to{transform:rotate(360deg)}}'
        + '#fastcat-linux-support-mask{position:fixed;inset:0;z-index:2147483647;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:16px;background:$background;color:$foreground;font-family:system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;opacity:1;transition:opacity .16s ease}'
        + '#fastcat-linux-support-mask.fastcat-hide{opacity:0;pointer-events:none}'
        + '#fastcat-linux-support-mask .fastcat-spinner{width:30px;height:30px;border:3px solid rgba(148,163,184,.28);border-top-color:$accent;border-radius:50%;animation:fastcat-spin .8s linear infinite}'
        + '#fastcat-linux-support-mask .fastcat-label{font-size:14px;line-height:20px}';
      (document.head || document.documentElement).appendChild(style);
      var mask = document.createElement('div');
      mask.id = 'fastcat-linux-support-mask';
      mask.innerHTML = '<div class="fastcat-spinner"></div><div class="fastcat-label"></div>';
      mask.querySelector('.fastcat-label').textContent = $connecting;
      (document.body || document.documentElement).appendChild(mask);
      window.__fastcatHideLoadingMask = function(){
        var current = document.getElementById('fastcat-linux-support-mask');
        if (!current) return;
        current.classList.add('fastcat-hide');
        setTimeout(function(){ current.remove(); }, 180);
      };
    } catch (_) {}
  };
  window.__fastcatInstallLoadingMask();
  if (!document.getElementById('fastcat-linux-support-mask')) {
    document.addEventListener('DOMContentLoaded', window.__fastcatInstallLoadingMask, {once:true});
  }
})();''';
    try {
      await platformController.controller.addUserScriptAtDocumentStart(script);
      _linuxLoadingMaskRegistered = true;
    } catch (_) {}
  }

  Future<void> _hideLinuxLoadingMask() async {
    if (!Platform.isLinux) return;
    try {
      await _controller.runJavaScript('''
if (typeof window.__fastcatHideLoadingMask === 'function') {
  window.__fastcatHideLoadingMask();
}''');
    } catch (_) {}
  }

  void _stopReadyPolling() {
    _readyPollTimer?.cancel();
    _readyPollTimer = null;
  }

  // ── URL helpers ──────────────────────────────────────────────────

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
    return CustomerServiceHelper.localizedCrispUri(
      crispEmbedUri(
        websiteId: widget.websiteId,
        proxyUrl: widget.crispProxyUrl,
      ),
      _localeTag,
    );
  }

  Future<bool> _isCrispReady() async {
    try {
      final result = await _controller.runJavaScriptReturningResult('''
(function(){
  try { return window.__fastcatCrispReady === true; } catch (_) { return false; }
})();''');
      if (result is bool) return result;
      return result.toString().contains('true');
    } catch (_) {
      return false;
    }
  }

  // ── Post-load injection ──────────────────────────────────────────

  Future<void> _injectDirectEmbedMonitor() async {
    final background = _customerServiceBackgroundColorValue(_isDarkMode);
    final foreground = _customerServiceForegroundColorValue(_isDarkMode);
    final userScript = widget.userScript ?? '';
    final localeTag = _localeTag ?? 'en';
    final crispLocale = CustomerServiceHelper.crispLocaleFromTag(localeTag);
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
        window.__fastcatCustomerServiceTheme = theme;
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
    function markReady(){ window.__fastcatCrispReady = true; }
    function directLooksReady(){
      try {
        window.\$crisp = window.\$crisp || [];
        window.\$crisp.push(["config", "locale", [window.__fastcatCustomerServiceCrispLocale || 'en']]);
        var theme = window.__fastcatCustomerServiceTheme || { isDark: ${_isDarkMode ? 'true' : 'false'} };
        window.\$crisp.push(["config", "color:mode", [theme.isDark ? "dark" : "light"]]);
        var interactive = document.querySelector('textarea,input,[contenteditable="true"],button,[role="button"],a[href^="mailto:"],iframe[src*="crisp"]');
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

  // ── Theme & locale sync ──────────────────────────────────────────

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
    var theme = {
      isDark: ${_isDarkMode ? 'true' : 'false'},
      background: '${_customerServiceBackgroundColorValue(_isDarkMode)}',
      foreground: '${_customerServiceForegroundColorValue(_isDarkMode)}',
      accent: '${_isDarkMode ? '#60a5fa' : '#2563eb'}'
    };
    window.__fastcatCustomerServiceTheme = theme;
    if (typeof window.__fastcatApplyCustomerServiceTheme === 'function') {
      window.__fastcatApplyCustomerServiceTheme(theme);
    }
    try {
      window.\$crisp = window.\$crisp || [];
      window.\$crisp.push(["config", "color:mode", [theme.isDark ? "dark" : "light"]]);
    } catch(_) {}
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
      'crispLocale':
          CustomerServiceHelper.crispLocaleFromTag(_localeTag ?? 'en'),
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

  void _syncSessionState(CustomerServiceSessionState session) {
    final nextIsDarkMode = session.brightness == Brightness.dark;
    final nextLocaleTag = session.localeTag;
    final themeChanged = _isDarkMode != nextIsDarkMode;
    final localeChanged = _localeTag != nextLocaleTag;
    unawaited(_setLinuxWebViewVisibility(session.isVisible));

    if (themeChanged) {
      _isDarkMode = nextIsDarkMode;
      unawaited(_applySystemWebViewBackgroundColor());
      unawaited(_applySystemTheme());
    }
    if (localeChanged) {
      _localeTag = nextLocaleTag;
      unawaited(_applySystemLocale());
    }
    if (session.isVisible && _lastAppliedRestoreToken != session.restoreToken) {
      _lastAppliedRestoreToken = session.restoreToken;
      unawaited(_applySystemWebViewBackgroundColor());
      unawaited(_applySystemTheme());
      unawaited(_applySystemLocale());
    }
  }

  // ── File picker (Android) ────────────────────────────────────────

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

  // ── Color helpers ────────────────────────────────────────────────

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

  // ── Build ────────────────────────────────────────────────────────

  Widget _buildLoadingOverlay(BuildContext context) {
    final strings = _strings;
    final spinnerColor = Theme.of(context).colorScheme.primary;
    final isDark = _isDarkMode;
    return Positioned.fill(
      child: ColoredBox(
        color: _customerServiceBackgroundColor(isDark),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: spinnerColor,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                strings.connecting,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorPage(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final strings = _strings;
    final isDark = _isDarkMode;
    return Positioned.fill(
      child: ColoredBox(
        color: _customerServiceBackgroundColor(isDark),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off,
                  size: 48,
                  color: isDark ? Colors.white38 : Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  strings.loadFailed,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white54 : Colors.grey,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => _loadPreferredCrispUrl(),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(l10n.refresh),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget buildScaffold(CustomerServiceSessionState? session) {
      if (session != null) {
        _syncSessionState(session);
      }
      final strings = _strings;
      final backgroundColor = _customerServiceBackgroundColor(_isDarkMode);
      final isVisible = session?.isVisible ?? true;
      return PopScope(
        canPop: widget.onBackPressed == null || !isVisible,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) unawaited(_handleBackPressed());
        },
        child: Scaffold(
          backgroundColor: backgroundColor,
          appBar: AppBar(
            title: Text(strings.title),
            leading: BackButton(
              onPressed: () => unawaited(_handleBackPressed()),
            ),
          ),
          body: Stack(
            children: [
              WebViewWidget(controller: _controller),
              if (_hasError)
                _buildErrorPage(context)
              else if (_isLoading)
                _buildLoadingOverlay(context),
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
