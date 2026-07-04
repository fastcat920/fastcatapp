import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/adapter/state/order_state.dart';
import 'package:fl_clash/xboard/core/core.dart';
import 'package:fl_clash/xboard/features/shared/utils/desktop_webview_window_helper.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';

const _logger = FileLogger('payment_webview_page.dart');
Webview? _desktopPaymentWebview;
Brightness? _desktopPaymentBrightness;

/// Desktop Chrome UA used on mobile so payment gateways serve the QR-code
/// page instead of the H5 cashier that tries (and fails) to invoke Alipay /
/// WeChat via JSBridge.
const _desktopUserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
    'AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/125.0.0.0 Safari/537.36';

/// Unified in-app payment page for all platforms.
///
/// Non-Linux platforms use an embedded WebView:
/// - Android / iOS / macOS → webview_flutter (system WebView / WKWebView)
/// - Windows → webview_flutter via webview_win_floating
/// - Linux → desktop_webview_window 独立窗口
///
/// Auto-polling runs on every platform as a reliable fallback.
///
/// Returns `true` when the payment succeeds, `null` when the user cancels.
class PaymentWebViewPage extends ConsumerStatefulWidget {
  final String paymentUrl;
  final String tradeNo;

  const PaymentWebViewPage({
    super.key,
    required this.paymentUrl,
    required this.tradeNo,
  });

  /// Opens the unified in-app payment page.
  /// Returns `true` if the payment completed successfully.
  static Future<bool?> open(
    BuildContext context, {
    required String paymentUrl,
    required String tradeNo,
  }) {
    if (Platform.isLinux) {
      return _openLinuxDesktopPaymentWindow(
        context,
        paymentUrl: paymentUrl,
        tradeNo: tradeNo,
      );
    }
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            PaymentWebViewPage(paymentUrl: paymentUrl, tradeNo: tradeNo),
      ),
    );
  }

  static void syncDesktopTheme(Brightness brightness) {
    final webview = _desktopPaymentWebview;
    if (webview == null) return;
    if (_desktopPaymentBrightness == brightness) return;
    _desktopPaymentBrightness = brightness;
    unawaited(_applyDesktopPaymentTheme(webview, brightness: brightness));
  }

  static Future<bool?> _openLinuxDesktopPaymentWindow(
    BuildContext context, {
    required String paymentUrl,
    required String tradeNo,
  }) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final l10n = AppLocalizations.of(context);
    final brightness = Theme.of(context).brightness;
    final languageHeader = _preferredLanguageHeaderStatic();

    Webview? webview;
    Timer? pollTimer;
    var closedByApp = false;
    var isChecking = false;
    final completer = Completer<bool?>();
    late Future<void> Function(Duration delay) scheduleNextPoll;
    late Future<void> Function() checkPaymentStatus;

    Future<void> finish(bool? result) async {
      if (completer.isCompleted) return;
      pollTimer?.cancel();
      if (result == true && webview != null) {
        closedByApp = true;
        webview.close();
      }
      completer.complete(result);
    }

    checkPaymentStatus = () async {
      if (isChecking || completer.isCompleted) return;
      isChecking = true;
      var shouldContinuePolling = true;
      try {
        clearGetOrderCache(tradeNo);
        container.invalidate(getOrderProvider(tradeNo));
        final order = await container.read(getOrderProvider(tradeNo).future);
        if (order != null) {
          if (order.status == 3 || order.status == 4) {
            await finish(true);
            return;
          }
          if (order.status == 2) {
            shouldContinuePolling = false;
            pollTimer?.cancel();
            return;
          }
        }
      } catch (e) {
        _logger.warning('Linux desktop payment status check failed: $e');
      } finally {
        isChecking = false;
        if (shouldContinuePolling &&
            !completer.isCompleted &&
            pollTimer?.isActive != true) {
          unawaited(scheduleNextPoll(const Duration(seconds: 5)));
        }
      }
    };

    scheduleNextPoll = (Duration delay) async {
      pollTimer?.cancel();
      if (completer.isCompleted) return;
      pollTimer = Timer(delay, () {
        unawaited(checkPaymentStatus());
      });
    };

    try {
      webview = await DesktopWebviewWindowHelper.create(
        title: l10n.xboardPaymentGateway,
        windowWidth: 1100,
        windowHeight: 760,
        matchMainWindow: true,
        centerOnMainWindow: true,
        resizable: false,
        brightness: brightness,
      );
      final desktopWebview = webview;
      await desktopWebview.setApplicationNameForUserAgent(
        ' Chrome/125.0.0.0 Safari/537.36 FastCat/3.5.5',
      );
      desktopWebview.addOnUrlRequestCallback((url) {
        final uri = Uri.tryParse(url);
        if (uri == null) return;
        final scheme = uri.scheme.toLowerCase();
        if (_isStandardWebSchemeStatic(scheme)) return;
        _logger.info('Linux desktop payment custom scheme: $scheme');
        unawaited(_launchExternalPaymentUriStatic(uri));
      });
      desktopWebview.addScriptToExecuteOnDocumentCreated(
        _buildLinuxDesktopPaymentDocumentScript(
          languageHeader: languageHeader,
          isDarkMode: brightness == Brightness.dark,
        ),
      );
      _trackDesktopPaymentWindow(desktopWebview, brightness: brightness);
      unawaited(
        desktopWebview.onClose.whenComplete(() async {
          pollTimer?.cancel();
          _clearDesktopPaymentWindow(desktopWebview);
          if (!closedByApp) {
            await finish(null);
          }
        }),
      );
      await desktopWebview.launch(paymentUrl);
      await scheduleNextPoll(const Duration(seconds: 3));
      return await completer.future;
    } catch (e) {
      _logger.warning('Failed to open Linux desktop payment window: $e');
      final uri = Uri.tryParse(paymentUrl);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      await scheduleNextPoll(const Duration(seconds: 3));
      return completer.future;
    }
  }

  static String _preferredLanguageHeaderStatic() {
    final locales = WidgetsBinding.instance.platformDispatcher.locales;
    final tags = locales.isEmpty
        ? <String>[
            WidgetsBinding.instance.platformDispatcher.locale.toLanguageTag(),
          ]
        : locales.map((locale) => locale.toLanguageTag()).toList();
    return tags.take(3).join(',');
  }

  static String _buildLinuxDesktopPaymentDocumentScript({
    required String languageHeader,
    required bool isDarkMode,
  }) {
    final languages = languageHeader
        .split(',')
        .where((tag) => tag.trim().isNotEmpty)
        .map((tag) => tag.trim())
        .toList();
    final primaryLanguage = languages.isEmpty ? 'en' : languages.first;
    final languagesJson = jsonEncode(
      languages.isEmpty ? [primaryLanguage] : languages,
    );
    final primaryLanguageJson = jsonEncode(primaryLanguage);
    final background = isDarkMode ? '#101010' : '#f5f5f5';
    return '''
(function(){
  try {
    var language = $primaryLanguageJson;
    var languages = $languagesJson;
    document.documentElement.lang = language;
    window.__fastcatApplyPaymentTheme = function(theme){
      try {
        document.documentElement.style.colorScheme = theme.isDark ? 'dark' : 'light';
        document.documentElement.style.background = theme.background;
        document.documentElement.style.width = '100%';
        document.documentElement.style.overflowX = 'hidden';
        if (document.body) {
          document.body.style.background = theme.background;
          document.body.style.width = '100%';
          document.body.style.margin = '0';
          document.body.style.overflowX = 'hidden';
        }
        var style = document.getElementById('fastcat-payment-theme');
        if (!style) {
          style = document.createElement('style');
          style.id = 'fastcat-payment-theme';
          (document.head || document.documentElement).appendChild(style);
        }
        style.textContent = ''
          + 'html,body{box-sizing:border-box !important;width:100% !important;height:100% !important;min-width:0 !important;max-width:100% !important;margin:0 !important;overflow-x:hidden !important;overflow-y:auto !important;background:' + theme.background + ' !important;color-scheme:' + (theme.isDark ? 'dark' : 'light') + ' !important;}'
          + '*,*:before,*:after{box-sizing:border-box !important;}'
          + 'body > *{max-width:100% !important;}'
          + 'iframe,frame,embed,object{display:block !important;width:100% !important;max-width:100% !important;border:none !important;overflow-x:hidden !important;overflow-y:auto !important;}'
          + '.container,.wrapper,.content,.page,#app,#root,#main{width:100% !important;max-width:100% !important;min-width:0 !important;overflow-x:hidden !important;}'
          + 'img,video,canvas,svg,table{max-width:100% !important;}';
      } catch (_) {}
    };
    window.__fastcatApplyPaymentTheme({
      isDark: ${isDarkMode ? 'true' : 'false'},
      background: '$background'
    });
    try {
      Object.defineProperty(navigator, 'language', { get: function(){ return language; }, configurable: true });
      Object.defineProperty(navigator, 'languages', { get: function(){ return languages; }, configurable: true });
    } catch (_) {}
    if (!window.__fastcatPaymentExternalBridgeInstalled) {
      window.__fastcatPaymentExternalBridgeInstalled = true;
      var standardSchemes = { http: true, https: true, about: true, data: true, javascript: true };
      function shouldOpenExternally(value) {
        try {
          var url = String(value || '');
          var match = /^([a-zA-Z][a-zA-Z0-9+.-]*):/.exec(url);
          if (!match) return false;
          return !standardSchemes[String(match[1]).toLowerCase()];
        } catch (_) {
          return false;
        }
      }
      function openExternally(value) {
        try {
          var url = String(value || '');
          if (!shouldOpenExternally(url)) return false;
          if (window.flutter_inappwebview && typeof window.flutter_inappwebview.callHandler === 'function') {
            window.flutter_inappwebview.callHandler('FastCatPayment', url);
          }
          return true;
        } catch (_) {
          return false;
        }
      }
      document.addEventListener('click', function(event) {
        var node = event.target;
        while (node && node !== document) {
          if (node.href && openExternally(node.href)) {
            event.preventDefault();
            event.stopPropagation();
            return false;
          }
          node = node.parentElement;
        }
      }, true);
      document.addEventListener('submit', function(event) {
        var form = event.target;
        if (form && form.action && openExternally(form.action)) {
          event.preventDefault();
          event.stopPropagation();
          return false;
        }
      }, true);
      var originalOpen = window.open;
      window.open = function(url) {
        if (openExternally(url)) return null;
        return originalOpen ? originalOpen.apply(window, arguments) : null;
      };
      try {
        var originalAssign = window.location.assign.bind(window.location);
        window.location.assign = function(url) {
          if (openExternally(url)) return;
          return originalAssign(url);
        };
      } catch (_) {}
      try {
        var originalReplace = window.location.replace.bind(window.location);
        window.location.replace = function(url) {
          if (openExternally(url)) return;
          return originalReplace(url);
        };
      } catch (_) {}
      function fillViewport() {
        try {
          var selectors = ['iframe', 'frame', 'embed', 'object', '#app', '#root', '#main', '.container', '.wrapper', '.content', '.page'];
          document.documentElement.style.overflowX = 'hidden';
          document.documentElement.style.overflowY = 'auto';
          document.documentElement.style.maxWidth = '100%';
          if (document.body) {
            document.body.style.overflowX = 'hidden';
            document.body.style.overflowY = 'auto';
            document.body.style.maxWidth = '100%';
          }
          for (var s = 0; s < selectors.length; s++) {
            var nodes = document.querySelectorAll(selectors[s]);
            for (var i = 0; i < nodes.length; i++) {
              var node = nodes[i];
              node.style.minWidth = '0';
              node.style.maxWidth = '100%';
              node.style.width = '100%';
              if (selectors[s] === 'iframe' || selectors[s] === 'frame' || selectors[s] === 'embed' || selectors[s] === 'object') {
                node.style.border = 'none';
                node.style.display = 'block';
                node.style.overflowX = 'hidden';
                node.style.overflowY = 'auto';
              }
            }
          }
        } catch (_) {}
      }
      fillViewport();
      new MutationObserver(fillViewport).observe(document.documentElement, {
        childList: true,
        subtree: true,
        attributes: true
      });
    }
  } catch (_) {}
})();''';
  }

  static void _trackDesktopPaymentWindow(
    Webview webview, {
    required Brightness brightness,
  }) {
    _desktopPaymentWebview = webview;
    _desktopPaymentBrightness = brightness;
    unawaited(
      webview.onClose.whenComplete(() {
        _clearDesktopPaymentWindow(webview);
      }),
    );
  }

  static void _clearDesktopPaymentWindow(Webview webview) {
    if (identical(_desktopPaymentWebview, webview)) {
      _desktopPaymentWebview = null;
      _desktopPaymentBrightness = null;
    }
  }

  static Future<void> _applyDesktopPaymentTheme(
    Webview webview, {
    required Brightness brightness,
  }) async {
    final isDarkMode = brightness == Brightness.dark;
    try {
      webview.setBrightness(brightness);
    } catch (e) {
      _logger.debug('Failed to update Linux desktop payment window theme: $e');
    }
    try {
      await webview.evaluateJavaScript('''
(function(){
  try {
    if (typeof window.__fastcatApplyPaymentTheme !== 'function') return 'missing';
    window.__fastcatApplyPaymentTheme({
      isDark: ${isDarkMode ? 'true' : 'false'},
      background: '${isDarkMode ? '#101010' : '#f5f5f5'}'
    });
    return 'applied';
  } catch (_) {
    return 'failed';
  }
})();''');
    } catch (e) {
      _logger.debug('Failed to update Linux desktop payment page theme: $e');
    }
  }

  static bool _isStandardWebSchemeStatic(String scheme) {
    return scheme == 'http' ||
        scheme == 'https' ||
        scheme == 'about' ||
        scheme == 'data' ||
        scheme == 'javascript';
  }

  static Future<void> _launchExternalPaymentUriStatic(Uri uri) async {
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      _logger.warning(
        'Failed to launch Linux desktop payment URI ${uri.scheme}: $e',
      );
    }
  }

  @override
  ConsumerState<PaymentWebViewPage> createState() => _PaymentWebViewPageState();
}

class _PaymentWebViewPageState extends ConsumerState<PaymentWebViewPage> {
  WebViewController? _webViewController;
  Timer? _pollTimer;
  Timer? _loadStateTimer;
  bool _isPageLoading = true;
  bool _showPageLoadingMessage = false;
  bool _isPolling = false;
  bool _isChecking = false;

  /// Platforms that use webview_flutter (system WebView)
  bool get _useSystemWebView =>
      Platform.isAndroid ||
      Platform.isIOS ||
      Platform.isMacOS ||
      Platform.isWindows;

  @override
  void initState() {
    super.initState();
    if (_useSystemWebView) {
      _initWebView();
    }
    _startPolling();
  }

  @override
  void dispose() {
    _stopPolling();
    _loadStateTimer?.cancel();
    _webViewController = null;
    super.dispose();
  }

  Future<void> _initWebView() async {
    _beginPageLoading();
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_desktopUserAgent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => _beginPageLoading(),
          onProgress: (progress) {
            if (progress >= 100) _finishPageLoading();
          },
          onPageFinished: (_) => _finishPageLoading(),
          onUrlChange: _onUrlChange,
          onNavigationRequest: _onNavigationRequest,
          onWebResourceError: (error) {
            if (error.isForMainFrame == true) {
              _logger.warning(
                'Payment WebView main frame error: ${error.description}',
              );
              _finishPageLoading();
            }
          },
        ),
      )
      ..loadRequest(
        Uri.parse(widget.paymentUrl),
        headers: {'Accept-Language': _preferredLanguageHeader()},
      );
  }

  String _preferredLanguageHeader() {
    final locales = WidgetsBinding.instance.platformDispatcher.locales;
    final tags = locales.isEmpty
        ? <String>[
            WidgetsBinding.instance.platformDispatcher.locale.toLanguageTag(),
          ]
        : locales.map((locale) => locale.toLanguageTag()).toList();
    return tags.take(3).join(',');
  }

  void _beginPageLoading() {
    _loadStateTimer?.cancel();
    _setPageLoadingState(isLoading: true, showMessage: false);
    _loadStateTimer = Timer(const Duration(milliseconds: 650), () {
      if (!mounted || !_isPageLoading) return;
      _setPageLoadingState(isLoading: true, showMessage: true);
    });
  }

  void _finishPageLoading() {
    _loadStateTimer?.cancel();
    _loadStateTimer = null;
    _setPageLoadingState(isLoading: false, showMessage: false);
  }

  void _setPageLoadingState({
    required bool isLoading,
    required bool showMessage,
  }) {
    if (_isPageLoading == isLoading && _showPageLoadingMessage == showMessage) {
      return;
    }
    if (!mounted) {
      _isPageLoading = isLoading;
      _showPageLoadingMessage = showMessage;
      return;
    }
    setState(() {
      _isPageLoading = isLoading;
      _showPageLoadingMessage = showMessage;
    });
  }

  void _onUrlChange(UrlChange change) {
    // 不再根据 host 变化推断支付完成——支付流程中经过中间域名是常态，
    // 误触发会导致顶部状态栏提前显示"支付完成"。支付状态完全由轮询负责。
  }

  Future<NavigationDecision> _onNavigationRequest(
    NavigationRequest request,
  ) async {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.navigate;

    final scheme = uri.scheme.toLowerCase();
    // Allow standard web schemes to navigate normally
    if (_isStandardWebScheme(scheme)) {
      return NavigationDecision.navigate;
    }

    // For custom schemes (alipays://, weixin://, etc.), forward to system
    _logger.info('Intercepted custom scheme: $scheme, forwarding to system');
    await _launchExternalPaymentUri(uri);

    return NavigationDecision.prevent;
  }

  bool _isStandardWebScheme(String scheme) {
    return scheme == 'http' ||
        scheme == 'https' ||
        scheme == 'about' ||
        scheme == 'data' ||
        scheme == 'javascript';
  }

  Future<void> _launchExternalPaymentUri(Uri uri) async {
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      _logger.warning(
        'Failed to launch external payment URI ${uri.scheme}: $e',
      );
    }
  }

  // ── Polling ─────────────────────────────────────────────────────────

  void _startPolling() {
    if (_isPolling) return;
    _isPolling = true;
    _pollTimer = Timer(const Duration(seconds: 3), () {
      _checkPaymentStatus();
    });
  }

  void _stopPolling() {
    _isPolling = false;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _scheduleNextPoll() {
    if (!_isPolling || !mounted) return;
    _pollTimer?.cancel();
    _pollTimer = Timer(const Duration(seconds: 5), () {
      _checkPaymentStatus();
    });
  }

  Future<void> _checkPaymentStatus() async {
    if (!mounted || _isChecking) return;
    _isChecking = true;

    try {
      clearGetOrderCache(widget.tradeNo);
      ref.invalidate(getOrderProvider(widget.tradeNo));
      final order = await ref.read(getOrderProvider(widget.tradeNo).future);
      if (!mounted) return;

      if (order != null) {
        if (order.status == 3 || order.status == 4) {
          _stopPolling();
          _handlePaymentSuccess();
          return;
        }
        if (order.status == 2) {
          _stopPolling();
          return;
        }
      }
    } catch (e) {
      _logger.warning('Order status check failed: $e');
    } finally {
      _isChecking = false;
      if (mounted) _scheduleNextPoll();
    }
  }

  void _handlePaymentSuccess() {
    _stopPolling();
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  void _handleCancel() {
    _stopPolling();
    Navigator.of(context).pop(null);
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.xboardPaymentGateway),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: l10n.xboardCancelPayment,
          onPressed: _handleCancel,
        ),
        actions: const [],
      ),
      body: Column(
        children: [
          _StatusBanner(isPolling: _isPolling),
          Expanded(child: _buildWebView()),
        ],
      ),
    );
  }

  Widget _buildWebView() {
    late final Widget webView;
    if (_useSystemWebView) {
      webView = _webViewController != null
          ? WebViewWidget(controller: _webViewController!)
          : const SizedBox.expand();
    } else {
      webView = const SizedBox.expand();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        webView,
        if (_isPageLoading)
          _PaymentGatewayLoadingOverlay(showMessage: _showPageLoadingMessage),
      ],
    );
  }
}

class _PaymentGatewayLoadingOverlay extends StatelessWidget {
  final bool showMessage;

  const _PaymentGatewayLoadingOverlay({required this.showMessage});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bg = Theme.of(context).colorScheme.surface.withValues(alpha: 0.92);
    final fg = Theme.of(context).colorScheme.onSurface;

    return ColoredBox(
      color: bg,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: showMessage
                  ? Padding(
                      key: const ValueKey('loading-text'),
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(
                        l10n.xboardLoadingPaymentPage,
                        style: TextStyle(
                          color: fg.withValues(alpha: 0.72),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  : const SizedBox(
                      key: ValueKey('loading-placeholder'),
                      height: 0,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final bool isPolling;

  const _StatusBanner({required this.isPolling});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final Color bg;
    final Color fg;
    final String text;
    final IconData icon;

    if (isPolling) {
      bg = XbUiStatusColor.processing(context).withValues(alpha: 0.12);
      fg = XbUiStatusColor.processing(context);
      text = l10n.xboardWaitingForPayment;
      icon = Icons.info_outline;
    } else {
      bg = XbUiStatusColor.muted(context).withValues(alpha: 0.12);
      fg = XbUiStatusColor.muted(context);
      text = l10n.xboardPaymentPageOpenedCompleteAndReturn;
      icon = Icons.info_outline;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: bg,
      child: Row(
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: fg,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
