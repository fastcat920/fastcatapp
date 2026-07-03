import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:desktop_webview_window/desktop_webview_window.dart';

import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/adapter/state/order_state.dart';
import 'package:fl_clash/xboard/core/core.dart';
import 'package:fl_clash/xboard/features/shared/utils/desktop_webview_window_helper.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';

const _logger = FileLogger('payment_webview_page.dart');

/// Desktop Chrome UA used on mobile so payment gateways serve the QR-code
/// page instead of the H5 cashier that tries (and fails) to invoke Alipay /
/// WeChat via JSBridge.
const _desktopUserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
    'AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/125.0.0.0 Safari/537.36';

/// Unified in-app payment page for all platforms.
///
/// All platforms use an embedded WebView:
/// - Android / iOS / macOS → webview_flutter (system WebView / WKWebView)
/// - Windows → webview_flutter via webview_win_floating
/// - Linux → desktop_webview_window, avoiding GTK inline WebView instability
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
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PaymentWebViewPage(
          paymentUrl: paymentUrl,
          tradeNo: tradeNo,
        ),
      ),
    );
  }

  @override
  ConsumerState<PaymentWebViewPage> createState() => _PaymentWebViewPageState();
}

class _PaymentWebViewPageState extends ConsumerState<PaymentWebViewPage> {
  WebViewController? _webViewController;
  Webview? _desktopPaymentWebview;
  Timer? _pollTimer;
  Timer? _loadStateTimer;
  bool _isPageLoading = true;
  bool _showPageLoadingMessage = false;
  bool _isPolling = false;
  bool _isChecking = false;
  bool _isOpeningDesktopWebview = false;
  bool _desktopWebviewOpened = false;
  bool _isCompleting = false;
  bool _isCancelling = false;
  String? _desktopWebviewError;

  /// Platforms that use webview_flutter (system WebView)
  bool get _useSystemWebView =>
      Platform.isAndroid ||
      Platform.isIOS ||
      Platform.isMacOS ||
      Platform.isWindows;

  bool get _useDesktopWindowWebView => Platform.isLinux;

  @override
  void initState() {
    super.initState();
    if (_useDesktopWindowWebView) {
      unawaited(_openDesktopPaymentWebview());
    } else if (_useSystemWebView) {
      _initWebView();
    }
    _startPolling();
  }

  @override
  void dispose() {
    _stopPolling();
    _loadStateTimer?.cancel();
    _webViewController = null;
    _closeDesktopPaymentWebview();
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

  Future<void> _openDesktopPaymentWebview() async {
    if (_isOpeningDesktopWebview) return;
    _isOpeningDesktopWebview = true;
    _desktopWebviewError = null;
    _beginPageLoading();

    final title = AppLocalizations.of(context).xboardPaymentGateway;
    final brightness = Theme.of(context).brightness;
    try {
      final webview = await DesktopWebviewWindowHelper.create(
        title: title,
        matchMainWindow: true,
        resizable: true,
        brightness: brightness,
      );
      if (!mounted) {
        webview.close();
        return;
      }
      _desktopPaymentWebview = webview;
      _desktopWebviewOpened = true;
      _desktopWebviewError = null;
      webview
        ..setBrightness(brightness)
        ..addScriptToExecuteOnDocumentCreated(
          _buildDesktopPaymentDocumentScript(),
        )
        ..addOnUrlRequestCallback(_handleDesktopUrlRequest);
      unawaited(webview.onClose.whenComplete(() {
        if (!mounted) return;
        _desktopPaymentWebview = null;
        if (!_isCompleting && !_isCancelling) {
          _handleCancel();
        }
      }));
      await webview.launch(widget.paymentUrl);
      _finishPageLoading();
    } catch (e) {
      _logger.warning('Failed to open Linux payment WebView window: $e');
      if (mounted) {
        setState(() {
          _desktopWebviewError = e.toString();
          _desktopWebviewOpened = false;
        });
      }
      _finishPageLoading();
    } finally {
      _isOpeningDesktopWebview = false;
    }
  }

  String _buildDesktopPaymentDocumentScript() {
    final languages = _preferredLanguageHeader()
        .split(',')
        .where((tag) => tag.trim().isNotEmpty)
        .map((tag) => tag.trim())
        .toList();
    final primaryLanguage = languages.isEmpty ? 'en' : languages.first;
    final languagesJson =
        jsonEncode(languages.isEmpty ? [primaryLanguage] : languages);
    final primaryLanguageJson = jsonEncode(primaryLanguage);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return '''
(function(){
  try {
    var language = $primaryLanguageJson;
    var languages = $languagesJson;
    document.documentElement.lang = language;
    document.documentElement.style.colorScheme = ${isDarkMode ? "'dark'" : "'light'"};
    try {
      Object.defineProperty(navigator, 'language', { get: function(){ return language; }, configurable: true });
      Object.defineProperty(navigator, 'languages', { get: function(){ return languages; }, configurable: true });
    } catch (_) {}
  } catch (_) {}
})();''';
  }

  void _handleDesktopUrlRequest(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final scheme = uri.scheme.toLowerCase();
    if (_isStandardWebScheme(scheme)) return;
    _logger.info('Desktop payment custom scheme: $scheme');
    unawaited(_launchExternalPaymentUri(uri));
  }

  void _closeDesktopPaymentWebview() {
    final webview = _desktopPaymentWebview;
    _desktopPaymentWebview = null;
    if (webview == null) return;
    try {
      webview.close();
    } catch (e) {
      _logger.debug('Failed to close Linux payment WebView window: $e');
    }
  }

  String _preferredLanguageHeader() {
    final locales = WidgetsBinding.instance.platformDispatcher.locales;
    final tags = locales.isEmpty
        ? <String>[
            WidgetsBinding.instance.platformDispatcher.locale.toLanguageTag()
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
      NavigationRequest request) async {
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
      _logger
          .warning('Failed to launch external payment URI ${uri.scheme}: $e');
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
    _isCompleting = true;
    _stopPolling();
    _closeDesktopPaymentWebview();
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  void _handleCancel() {
    _isCancelling = true;
    _stopPolling();
    _closeDesktopPaymentWebview();
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
          _StatusBanner(
            isPolling: _isPolling,
          ),
          Expanded(child: _buildWebView()),
        ],
      ),
    );
  }

  Widget _buildWebView() {
    late final Widget webView;
    if (_useDesktopWindowWebView) {
      webView = _DesktopPaymentWindowStatus(
        isOpening: _isOpeningDesktopWebview,
        opened: _desktopWebviewOpened,
        error: _desktopWebviewError,
        onRetry: _openDesktopPaymentWebview,
      );
    } else if (_useSystemWebView) {
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
          _PaymentGatewayLoadingOverlay(
            showMessage: _showPageLoadingMessage,
          ),
      ],
    );
  }
}

class _DesktopPaymentWindowStatus extends StatelessWidget {
  final bool isOpening;
  final bool opened;
  final String? error;
  final VoidCallback onRetry;

  const _DesktopPaymentWindowStatus({
    required this.isOpening,
    required this.opened,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final hasError = error != null;
    final text = hasError
        ? l10n.xboardFailedToOpenPaymentPage
        : opened
            ? l10n.xboardPaymentPageOpenedCompleteAndReturn
            : l10n.xboardPreparingPaymentPage;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasError
                    ? Icons.error_outline
                    : opened
                        ? Icons.open_in_new
                        : Icons.payment,
                size: 36,
                color: hasError ? colorScheme.error : colorScheme.primary,
              ),
              const SizedBox(height: 14),
              Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.xboardWaitingForPayment,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurface.withValues(alpha: 0.62),
                ),
              ),
              if (hasError) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: isOpening ? null : onRetry,
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.xboardReopen),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentGatewayLoadingOverlay extends StatelessWidget {
  final bool showMessage;

  const _PaymentGatewayLoadingOverlay({
    required this.showMessage,
  });

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

  const _StatusBanner({
    required this.isPolling,
  });

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
