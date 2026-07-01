import 'dart:async';
import 'dart:io';

import 'package:desktop_webview_window/desktop_webview_window.dart'
    as desktopwv;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_win_floating/webview_win_floating.dart' as winwv;
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/adapter/state/order_state.dart';
import 'package:fl_clash/xboard/core/core.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';

const _logger = FileLogger('payment_webview_page.dart');

/// Desktop Chrome UA used on mobile so payment gateways serve the QR-code
/// page instead of the H5 cashier that tries (and fails) to invoke Alipay /
/// WeChat via JSBridge.
const _desktopUserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
    'AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/125.0.0.0 Safari/537.36';

/// In-app payment WebView page that replaces the external-browser flow.
///
/// All platforms use an embedded WebView:
/// - Android / iOS / macOS → webview_flutter (system WebView / WKWebView)
/// - Windows → webview_win_floating (native floating WebView)
/// - Linux → desktop_webview_window (in-app WebView window)
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

  /// Push this page onto the navigator.
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
  winwv.WinWebViewController? _desktopFloatingWebViewController;
  desktopwv.Webview? _desktopWindowWebView;
  VoidCallback? _desktopWindowNavigationListener;
  desktopwv.OnUrlRequestCallback? _desktopWindowUrlRequestCallback;
  Timer? _pollTimer;
  Timer? _loadStateTimer;
  bool _isPageLoading = true;
  bool _showPageLoadingMessage = false;
  bool _isPolling = false;
  bool _isChecking = false;
  bool _desktopWindowOpening = false;
  bool _desktopWindowOpened = false;
  bool _desktopWindowClosed = false;
  String? _desktopWindowError;

  /// Platforms that use webview_flutter (system WebView)
  bool get _useSystemWebView =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  bool get _useDesktopFloatingWebView => Platform.isWindows;
  bool get _useDesktopWindowWebView => Platform.isLinux;

  @override
  void initState() {
    super.initState();
    if (_useSystemWebView) {
      _initWebView();
    } else if (_useDesktopFloatingWebView) {
      _initDesktopFloatingWebView();
    } else if (_useDesktopWindowWebView) {
      unawaited(_openDesktopWindowWebView());
    }
    _startPolling();
  }

  @override
  void dispose() {
    _stopPolling();
    _loadStateTimer?.cancel();
    _webViewController = null;
    _closeDesktopWindowWebView();
    final desktopController = _desktopFloatingWebViewController;
    _desktopFloatingWebViewController = null;
    if (desktopController != null) {
      unawaited(Future<void>(() async {
        try {
          await desktopController.setVisibility(false);
          await desktopController.dispose();
        } catch (e) {
          _logger.debug('Desktop floating WebView dispose failed: $e');
        }
      }));
    }
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
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  Future<void> _initDesktopFloatingWebView() async {
    _beginPageLoading();
    final controller = winwv.WinWebViewController(
      params: const winwv.WindowsWebViewControllerCreationParams(
        profileName: 'fastcat-payment',
        suspendDuringDeactive: false,
      ),
    );
    _desktopFloatingWebViewController = controller;
    if (mounted) setState(() {});
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await controller.setUserAgent(_desktopUserAgent);
    await controller.setNavigationDelegate(
      winwv.WinNavigationDelegate(
        onPageStarted: (_) => _beginPageLoading(),
        onProgress: (progress) {
          if (progress >= 100) _finishPageLoading();
        },
        onPageFinished: (_) => _finishPageLoading(),
        onNavigationRequest: _onNavigationRequest,
        onUrlChange: _onUrlChange,
        onWebResourceError: (error) {
          _logger.warning(
            'Desktop floating WebView resource error: ${error.url} ${error.description}',
          );
          if (error.isForMainFrame == true) {
            _finishPageLoading();
          }
        },
      ),
    );
    await controller.loadRequest(Uri.parse(widget.paymentUrl));
    if (mounted) setState(() {});
  }

  Future<void> _openDesktopWindowWebView() async {
    if (!_useDesktopWindowWebView || _desktopWindowOpening) return;
    final existingWebView = _desktopWindowWebView;
    if (existingWebView != null) {
      try {
        await existingWebView.setWebviewWindowVisibility(true);
        existingWebView.launch(widget.paymentUrl);
        return;
      } catch (e) {
        _logger.warning('Show desktop payment WebView failed: $e');
        _detachDesktopWindowWebView(existingWebView);
      }
    }

    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    _beginPageLoading();
    if (mounted) {
      setState(() {
        _desktopWindowOpening = true;
        _desktopWindowClosed = false;
        _desktopWindowError = null;
      });
    }

    try {
      final webview = await desktopwv.WebviewWindow.create(
        configuration: await _buildDesktopPaymentWindowConfiguration(
            l10n.xboardPaymentGateway),
      );
      if (!mounted) {
        webview.close();
        return;
      }

      void handleDesktopWindowNavigation() {
        if (!mounted) return;
        final isNavigating = webview.isNavigating.value;
        if (isNavigating) {
          _beginPageLoading();
        } else {
          _finishPageLoading();
        }
      }

      final navigationListener = handleDesktopWindowNavigation;
      final urlRequestCallback = _handleDesktopWindowUrlRequest;
      _desktopWindowWebView = webview;
      _desktopWindowNavigationListener = navigationListener;
      _desktopWindowUrlRequestCallback = urlRequestCallback;
      webview.isNavigating.addListener(navigationListener);
      webview.addOnUrlRequestCallback(urlRequestCallback);
      unawaited(webview.setApplicationNameForUserAgent('FastCat'));
      webview.launch(widget.paymentUrl);
      _finishPageLoading();

      if (mounted) {
        setState(() {
          _desktopWindowOpening = false;
          _desktopWindowOpened = true;
          _desktopWindowClosed = false;
          _desktopWindowError = null;
        });
      }

      unawaited(webview.onClose.then((_) {
        if (!mounted) return;
        _detachDesktopWindowWebView(webview);
        _finishPageLoading();
        setState(() {
          _desktopWindowOpening = false;
          _desktopWindowClosed = true;
        });
      }));
    } catch (e, stackTrace) {
      _logger.error('Open desktop payment WebView failed', e, stackTrace);
      _finishPageLoading();
      if (mounted) {
        setState(() {
          _desktopWindowOpening = false;
          _desktopWindowError = l10n.xboardOpenPaymentFailed;
        });
        XBoardNotification.showError(l10n.xboardOpenPaymentFailed);
      }
    }
  }

  Future<desktopwv.CreateConfiguration> _buildDesktopPaymentWindowConfiguration(
    String title,
  ) async {
    const fallbackWidth = 980;
    const fallbackHeight = 680;
    try {
      final mainSize = await windowManager.getSize();
      final mainPosition = await windowManager.getPosition();
      final views = WidgetsBinding.instance.platformDispatcher.views;
      final ratio = views.isNotEmpty ? views.first.devicePixelRatio : 1.0;
      final width = _clampInt((mainSize.width * ratio).round(), 760, 1280);
      final height = _clampInt((mainSize.height * ratio).round(), 560, 900);
      return desktopwv.CreateConfiguration(
        title: title,
        windowWidth: width,
        windowHeight: height,
        windowPosX: (mainPosition.dx * ratio).round(),
        windowPosY: (mainPosition.dy * ratio).round(),
        useWindowPositionAndSize: true,
        resizable: true,
        showTitleBarActions: false,
      );
    } catch (e) {
      _logger.warning('Use fallback desktop payment window size: $e');
      return desktopwv.CreateConfiguration(
        title: title,
        windowWidth: fallbackWidth,
        windowHeight: fallbackHeight,
        resizable: true,
        showTitleBarActions: false,
      );
    }
  }

  int _clampInt(int value, int min, int max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  void _handleDesktopWindowUrlRequest(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final scheme = uri.scheme.toLowerCase();
    if (_isStandardWebScheme(scheme)) return;
    unawaited(_launchExternalPaymentUri(uri));
  }

  void _detachDesktopWindowWebView(desktopwv.Webview webview) {
    final navigationListener = _desktopWindowNavigationListener;
    if (navigationListener != null) {
      webview.isNavigating.removeListener(navigationListener);
    }
    final urlRequestCallback = _desktopWindowUrlRequestCallback;
    if (urlRequestCallback != null) {
      webview.removeOnUrlRequestCallback(urlRequestCallback);
    }
    if (identical(_desktopWindowWebView, webview)) {
      _desktopWindowWebView = null;
    }
    _desktopWindowNavigationListener = null;
    _desktopWindowUrlRequestCallback = null;
  }

  void _closeDesktopWindowWebView() {
    final webview = _desktopWindowWebView;
    if (webview == null) return;
    _detachDesktopWindowWebView(webview);
    try {
      webview.close();
    } catch (e) {
      _logger.debug('Desktop payment WebView close failed: $e');
    }
  }

  Future<void> _copyPaymentUrl() async {
    final l10n = AppLocalizations.of(context);
    try {
      await Clipboard.setData(ClipboardData(text: widget.paymentUrl));
      if (mounted) {
        XBoardNotification.showSuccess(l10n.xboardPaymentLinkCopied);
      }
    } catch (e) {
      _logger.warning('Copy payment URL failed: $e');
    }
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
    _stopPolling();
    _closeDesktopWindowWebView();
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  void _handleCancel() {
    _stopPolling();
    _closeDesktopWindowWebView();
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
    if (_useSystemWebView) {
      webView = _webViewController != null
          ? WebViewWidget(controller: _webViewController!)
          : const SizedBox.expand();
    } else if (_useDesktopFloatingWebView) {
      webView = _desktopFloatingWebViewController != null
          ? winwv.WinWebViewWidget(
              controller: _desktopFloatingWebViewController!,
            )
          : const SizedBox.expand();
    } else if (_useDesktopWindowWebView) {
      webView = _DesktopWindowPaymentStatus(
        isOpening: _desktopWindowOpening,
        isOpened: _desktopWindowOpened,
        isClosed: _desktopWindowClosed,
        errorMessage: _desktopWindowError,
        isChecking: _isChecking,
        onReopen: _openDesktopWindowWebView,
        onCopyLink: _copyPaymentUrl,
        onCheckStatus: _checkPaymentStatus,
      );
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

class _DesktopWindowPaymentStatus extends StatelessWidget {
  final bool isOpening;
  final bool isOpened;
  final bool isClosed;
  final String? errorMessage;
  final bool isChecking;
  final VoidCallback onReopen;
  final VoidCallback onCopyLink;
  final VoidCallback onCheckStatus;

  const _DesktopWindowPaymentStatus({
    required this.isOpening,
    required this.isOpened,
    required this.isClosed,
    required this.errorMessage,
    required this.isChecking,
    required this.onReopen,
    required this.onCopyLink,
    required this.onCheckStatus,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final hasError = errorMessage != null;
    final statusColor = hasError
        ? XbUiStatusColor.error(context)
        : isClosed
            ? XbUiStatusColor.pending(context)
            : XbUiStatusColor.processing(context);
    final statusText = errorMessage ??
        (isOpening
            ? l10n.xboardPreparingPaymentPage
            : isClosed
                ? l10n.xboardReopenPaymentPageTip
                : isOpened
                    ? l10n.xboardPaymentPageOpenedCompleteAndReturn
                    : l10n.xboardPreparingPaymentPage);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasError
                      ? Icons.error_outline
                      : isClosed
                          ? Icons.open_in_new
                          : Icons.payment,
                  color: statusColor,
                  size: 32,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                statusText,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.xboardReturnAfterPaymentAutoDetect,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
                ),
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: isOpening ? null : onReopen,
                    icon: isOpening
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.open_in_new),
                    label: Text(l10n.xboardReopenPayment),
                    style: XbUiButton.filledPrimary(context),
                  ),
                  OutlinedButton.icon(
                    onPressed: onCopyLink,
                    icon: const Icon(Icons.copy),
                    label: Text(l10n.xboardCopyLink),
                    style: XbUiButton.outlinedNeutral(context),
                  ),
                  FilledButton.icon(
                    onPressed: isChecking ? null : onCheckStatus,
                    icon: isChecking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: Text(
                      isChecking ? l10n.xboardChecking : l10n.xboardCheckStatus,
                    ),
                    style: XbUiButton.filledPrimary(context).copyWith(
                      backgroundColor: WidgetStatePropertyAll(
                        XbUiStatusColor.pending(context),
                      ),
                    ),
                  ),
                ],
              ),
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
      text = l10n.xboardCompletePaymentInBrowser;
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
