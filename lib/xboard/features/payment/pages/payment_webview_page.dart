import 'dart:async';
import 'dart:io';

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_win_floating/webview_win_floating.dart' as winwv;
import 'package:url_launcher/url_launcher.dart';

import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/adapter/state/order_state.dart';
import 'package:fl_clash/xboard/core/core.dart';
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
/// - Windows / Linux → webview_win_floating (native embedded WebView)
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
  winwv.WinWebViewController? _desktopFloatingWebViewController;
  Webview? _linuxDesktopWebview;
  Timer? _pollTimer;
  Timer? _loadStateTimer;
  bool _isPageLoading = true;
  bool _showPageLoadingMessage = false;
  bool _isPolling = false;
  bool _isChecking = false;
  bool _linuxWindowOpen = false;
  bool _linuxWindowLaunchFailed = false;

  /// Platforms that use webview_flutter (system WebView)
  bool get _useSystemWebView =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  bool get _useDesktopFloatingWebView => Platform.isWindows;
  bool get _useLinuxDesktopWindow => Platform.isLinux;

  @override
  void initState() {
    super.initState();
    if (_useSystemWebView) {
      _initWebView();
    } else if (_useLinuxDesktopWindow) {
      _initLinuxDesktopWindow();
    } else if (_useDesktopFloatingWebView) {
      _initDesktopFloatingWebView();
    }
    _startPolling();
  }

  @override
  void dispose() {
    _stopPolling();
    _loadStateTimer?.cancel();
    _webViewController = null;
    final desktopController = _desktopFloatingWebViewController;
    _desktopFloatingWebViewController = null;
    final linuxWebview = _linuxDesktopWebview;
    _linuxDesktopWebview = null;
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
    if (linuxWebview != null) {
      unawaited(Future<void>(() async {
        try {
          linuxWebview.close();
        } catch (e) {
          _logger.debug('Linux desktop payment window dispose failed: $e');
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
    final controller = Platform.isWindows
        ? winwv.WinWebViewController(
            params: const winwv.WindowsWebViewControllerCreationParams(
              profileName: 'fastcat-payment',
              suspendDuringDeactive: false,
            ),
          )
        : winwv.WinWebViewController();
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

  Future<void> _initLinuxDesktopWindow() async {
    _beginPageLoading();
    _linuxWindowLaunchFailed = false;
    try {
      final webview = await WebviewWindow.create(
        configuration: CreateConfiguration(
          title: '支付网关',
          windowWidth: 980,
          windowHeight: 760,
          resizable: true,
          showTitleBarActions: true,
        ),
      );
      _linuxDesktopWebview = webview;
      _linuxWindowOpen = true;
      unawaited(webview.onClose.whenComplete(() {
        _linuxWindowOpen = false;
        if (mounted) {
          setState(() {});
        }
      }));
      await webview.launch(widget.paymentUrl);
      _finishPageLoading();
      if (mounted) setState(() {});
    } catch (e) {
      _linuxWindowLaunchFailed = true;
      _finishPageLoading();
      _logger.error('Linux desktop payment window start failed', e);
      if (mounted) setState(() {});
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
    try {
      _linuxDesktopWebview?.close();
    } catch (_) {}
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  void _handleCancel() {
    _stopPolling();
    try {
      _linuxDesktopWebview?.close();
    } catch (_) {}
    Navigator.of(context).pop(null);
  }

  Future<void> _reopenLinuxDesktopWindow() async {
    final webview = _linuxDesktopWebview;
    if (webview != null && _linuxWindowOpen) {
      try {
        await webview.setWebviewWindowVisibility(true);
        return;
      } catch (_) {}
    }
    await _initLinuxDesktopWindow();
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
    } else if (_useLinuxDesktopWindow) {
      webView = _LinuxDesktopWindowPanel(
        isWindowOpen: _linuxWindowOpen,
        launchFailed: _linuxWindowLaunchFailed,
        onOpenWindow: _reopenLinuxDesktopWindow,
      );
    } else if (_useDesktopFloatingWebView) {
      webView = _desktopFloatingWebViewController != null
          ? winwv.WinWebViewWidget(
              controller: _desktopFloatingWebViewController!,
            )
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

class _LinuxDesktopWindowPanel extends StatelessWidget {
  final bool isWindowOpen;
  final bool launchFailed;
  final Future<void> Function() onOpenWindow;

  const _LinuxDesktopWindowPanel({
    required this.isWindowOpen,
    required this.launchFailed,
    required this.onOpenWindow,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final text = launchFailed
        ? l10n.onlineSupportConnectionError
        : isWindowOpen
            ? l10n.xboardPaymentPageOpenedCompleteAndReturn
            : l10n.xboardLoadingPaymentPage;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.open_in_new,
                size: 40,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                text,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onOpenWindow,
                icon: const Icon(Icons.open_in_new),
                label: Text(l10n.xboardPaymentGateway),
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
