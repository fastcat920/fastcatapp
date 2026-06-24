import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:path_provider/path_provider.dart';

import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/adapter/state/order_state.dart';
import 'package:fl_clash/xboard/core/core.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';

const _logger = FileLogger('payment_webview_page.dart');

/// Desktop Chrome UA used on mobile so payment gateways serve the QR-code
/// page instead of the H5 cashier that tries (and fails) to invoke Alipay /
/// WeChat via JSBridge.
const _desktopUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
    'AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/125.0.0.0 Safari/537.36';

/// In-app payment WebView page that replaces the external-browser flow.
///
/// On Android / iOS / macOS an embedded WebView is shown.
/// On Windows / Linux a separate desktop WebView window is opened while this
/// page displays a waiting indicator.  Auto-polling runs on every platform
/// as a reliable fallback.
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
  ConsumerState<PaymentWebViewPage> createState() =>
      _PaymentWebViewPageState();
}

class _PaymentWebViewPageState extends ConsumerState<PaymentWebViewPage> {
  WebViewController? _webViewController;
  Timer? _pollTimer;
  bool _isPolling = false;
  bool _isChecking = false;

  bool get _supportsEmbeddedWebView =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  bool get _supportsDesktopWebView => Platform.isWindows || Platform.isLinux;

  @override
  void initState() {
    super.initState();
    _initWebView();
    _startPolling();
  }

  @override
  void dispose() {
    _stopPolling();
    _webViewController = null;
    super.dispose();
  }

  Future<void> _initWebView() async {
    if (_supportsEmbeddedWebView) {
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setUserAgent(_desktopUserAgent)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) {},
            onUrlChange: _onUrlChange,
            onNavigationRequest: _onNavigationRequest,
            onWebResourceError: (_) {},
          ),
        )
        ..loadRequest(Uri.parse(widget.paymentUrl));
    } else if (_supportsDesktopWebView) {
      unawaited(_openDesktopWebView());
    }
  }

  Future<void> _openDesktopWebView() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final dataFolder = '${appDir.path}/webview2_data';
      final webview = await WebviewWindow.create(
        configuration: CreateConfiguration(
          title: AppLocalizations.of(context).xboardPaymentGateway,
          userDataFolderWindows: dataFolder,
        ),
      );
      webview.launch(widget.paymentUrl);
    } catch (e) {
      _logger.warning('Desktop WebView creation failed: $e');
    }
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
    if (scheme == 'http' || scheme == 'https' ||
        scheme == 'about' || scheme == 'data' || scheme == 'javascript') {
      return NavigationDecision.navigate;
    }

    // For custom schemes (alipays://, weixin://, etc.), forward to system
    _logger.info('Intercepted custom scheme: $scheme, forwarding to system');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      _logger.warning('Failed to launch external app for $scheme: $e');
    }

    // Prevent WebView from showing error page for unknown schemes
    return NavigationDecision.prevent;
  }

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
      XBoardNotification.showSuccess(
        AppLocalizations.of(context).xboardPaymentSuccessful,
      );
      Future<void>.delayed(const Duration(milliseconds: 600), () {
        if (mounted) Navigator.of(context).pop(true);
      });
    }
  }

  void _handleCancel() {
    _stopPolling();
    Navigator.of(context).pop(null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_supportsEmbeddedWebView) {
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
            Expanded(
              child: _webViewController != null
                  ? WebViewWidget(controller: _webViewController!)
                  : const Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.xboardPaymentGateway),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _handleCancel,
        ),
      ),
      body: _DesktopWaitingBody(isPolling: _isPolling),
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

class _DesktopWaitingBody extends StatelessWidget {
  final bool isPolling;
  const _DesktopWaitingBody({required this.isPolling});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.payment,
                  size: 36, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 20),
            Text(l10n.xboardWaitingForPayment,
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              l10n.xboardPaymentPageOpenedCompleteAndReturn,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            if (isPolling)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.primary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(l10n.xboardAutoDetectPaymentStatus,
                      style: theme.textTheme.bodySmall),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
