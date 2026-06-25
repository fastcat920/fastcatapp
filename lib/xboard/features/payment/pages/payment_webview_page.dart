import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/scheduler.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart' as iaw;

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

const _windowsPrecisionTouchpadScrollScript = r'''
(function () {
  if (window.__fastcatPrecisionTouchpadScrollInstalled) return;
  window.__fastcatPrecisionTouchpadScrollInstalled = true;

  var pendingY = 0;
  var pendingX = 0;
  var frame = 0;
  var lastTarget = null;
  var lastWheelAt = 0;
  var recentWheelCount = 0;
  var gestureActiveUntil = 0;
  var gain = 1.25;
  var maxEventDelta = 620;
  var maxFrameDelta = 180;
  var gestureKeepAliveMs = 220;

  function clamp(value, min, max) {
    return Math.max(min, Math.min(max, value));
  }

  function isScrollable(element) {
    if (!element || element === document || element === document.body) {
      return false;
    }
    var style = window.getComputedStyle(element);
    var overflowY = style.overflowY;
    var overflowX = style.overflowX;
    return ((overflowY === 'auto' || overflowY === 'scroll') &&
            element.scrollHeight > element.clientHeight) ||
           ((overflowX === 'auto' || overflowX === 'scroll') &&
            element.scrollWidth > element.clientWidth);
  }

  function findScrollTarget(start) {
    var element = start;
    while (element && element !== document.body) {
      if (isScrollable(element)) return element;
      element = element.parentElement;
    }
    return document.scrollingElement || document.documentElement;
  }

  function canScroll(target, deltaY, deltaX) {
    if (!target) return false;
    var canY = deltaY > 0
        ? target.scrollTop + target.clientHeight < target.scrollHeight
        : target.scrollTop > 0;
    var canX = deltaX > 0
        ? target.scrollLeft + target.clientWidth < target.scrollWidth
        : target.scrollLeft > 0;
    return (Math.abs(deltaY) > Math.abs(deltaX) && canY) ||
           (Math.abs(deltaX) >= Math.abs(deltaY) && canX);
  }

  function looksLikePrecisionTouchpad(event, now, absY, absX) {
    if (absY <= 0 && absX <= 0) return false;
    if (absY > maxEventDelta || absX > maxEventDelta) return false;

    var dt = lastWheelAt > 0 ? now - lastWheelAt : 999;
    if (dt > 140) recentWheelCount = 0;
    recentWheelCount += 1;

    var fractional = event.deltaY % 1 !== 0 || event.deltaX % 1 !== 0;
    var smallContinuous = absY < 96 && absX < 96;
    var rapidBurst = dt < 70 && recentWheelCount >= 2;
    var activeGesture = now < gestureActiveUntil;
    var diagonalMovement = absX > 0 && absX < 240 && dt < 120;

    return fractional ||
           smallContinuous ||
           rapidBurst ||
           activeGesture ||
           diagonalMovement;
  }

  function flush() {
    if (!lastTarget) {
      pendingY = 0;
      pendingX = 0;
      frame = 0;
      return;
    }
    var y = clamp(pendingY, -maxFrameDelta, maxFrameDelta);
    var x = clamp(pendingX, -maxFrameDelta, maxFrameDelta);
    pendingY -= y;
    pendingX -= x;
    if (Math.abs(pendingY) < 0.5) pendingY = 0;
    if (Math.abs(pendingX) < 0.5) pendingX = 0;
    lastTarget.scrollBy({ top: y, left: x, behavior: 'auto' });
    if (pendingY !== 0 || pendingX !== 0) {
      frame = window.requestAnimationFrame(flush);
    } else {
      frame = 0;
    }
  }

  window.addEventListener('wheel', function (event) {
    if (event.ctrlKey || event.defaultPrevented || event.deltaMode !== 0) {
      return;
    }

    var now = window.performance && performance.now
        ? performance.now()
        : Date.now();
    var absY = Math.abs(event.deltaY);
    var absX = Math.abs(event.deltaX);
    var shouldHandle = looksLikePrecisionTouchpad(event, now, absY, absX);
    lastWheelAt = now;
    if (!shouldHandle) return;

    var target = findScrollTarget(event.target);
    if (!canScroll(target, event.deltaY, event.deltaX)) return;

    gestureActiveUntil = now + gestureKeepAliveMs;
    lastTarget = target;
    event.preventDefault();
    pendingY += clamp(event.deltaY * gain, -maxEventDelta, maxEventDelta);
    pendingX += clamp(event.deltaX * gain, -maxEventDelta, maxEventDelta);
    if (!frame) {
      frame = window.requestAnimationFrame(flush);
    }
  }, { passive: false, capture: true });
})();
''';

/// In-app payment WebView page that replaces the external-browser flow.
///
/// All platforms use an embedded WebView:
/// - Android / iOS / macOS → webview_flutter (system WebView / WKWebView)
/// - Windows / Linux → flutter_inappwebview (Edge WebView2 / WebKitGTK)
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
  iaw.InAppWebViewController? _desktopWebViewController;
  Timer? _pollTimer;
  bool _isPolling = false;
  bool _isChecking = false;
  int _lastPointerScrollAtMicros = 0;
  int _pointerScrollBurstCount = 0;
  int _desktopTouchpadGestureUntilMicros = 0;
  double _pendingDesktopScrollX = 0;
  double _pendingDesktopScrollY = 0;
  bool _desktopScrollFlushScheduled = false;

  /// Platforms that use webview_flutter (system WebView)
  bool get _useSystemWebView =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

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
    _webViewController = null;
    _desktopWebViewController = null;
    super.dispose();
  }

  Future<void> _initWebView() async {
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
      ..loadRequest(iaw.WebUri(widget.paymentUrl));
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
    if (scheme == 'http' ||
        scheme == 'https' ||
        scheme == 'about' ||
        scheme == 'data' ||
        scheme == 'javascript') {
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

    return NavigationDecision.prevent;
  }

  /// Handle custom scheme redirects for desktop (InAppWebView).
  Future<iaw.NavigationActionPolicy> _onDesktopNavigation(
      iaw.InAppWebViewController controller,
      iaw.NavigationAction navigationAction) async {
    final url = navigationAction.request.url?.toString() ?? '';
    final uri = Uri.tryParse(url);
    if (uri == null) return iaw.NavigationActionPolicy.ALLOW;

    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'http' ||
        scheme == 'https' ||
        scheme == 'about' ||
        scheme == 'data' ||
        scheme == 'javascript') {
      return iaw.NavigationActionPolicy.ALLOW;
    }

    _logger.info('Intercepted custom scheme: $scheme, forwarding to system');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      _logger.warning('Failed to launch external app for $scheme: $e');
    }

    return iaw.NavigationActionPolicy.CANCEL;
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

  // ── Windows touchpad scroll fallback ───────────────────────────────

  void _handleDesktopPointerSignal(PointerSignalEvent event) {
    if (!Platform.isWindows || event is! PointerScrollEvent) return;
    final controller = _desktopWebViewController;
    if (controller == null) return;
    final delta = event.scrollDelta;
    if (!_shouldUseDesktopScrollFallback(delta)) return;

    _pendingDesktopScrollX += _clampDouble(delta.dx * 1.15, -520, 520);
    _pendingDesktopScrollY += _clampDouble(delta.dy * 1.15, -520, 520);
    _scheduleDesktopScrollFlush();
  }

  bool _shouldUseDesktopScrollFallback(Offset delta) {
    final absY = delta.dy.abs();
    final absX = delta.dx.abs();
    if (absY == 0 && absX == 0) return false;
    if (absY > 1200 || absX > 1200) return false;

    final now = DateTime.now().microsecondsSinceEpoch;
    final dtMicros = _lastPointerScrollAtMicros == 0
        ? 999000
        : now - _lastPointerScrollAtMicros;
    if (dtMicros > 140000) {
      _pointerScrollBurstCount = 0;
    }
    _pointerScrollBurstCount += 1;
    _lastPointerScrollAtMicros = now;

    final fractional = delta.dy % 1 != 0 || delta.dx % 1 != 0;
    final activeGesture = now < _desktopTouchpadGestureUntilMicros;
    final rapidBurst = dtMicros < 70000 && _pointerScrollBurstCount >= 2;
    final smallContinuous = absY < 96 && absX < 96 && rapidBurst;
    final fastContinuous = absY >= 80 && absY < 760 && rapidBurst;
    final diagonalMovement = absX > 0 && absX < 260 && dtMicros < 120000;

    final shouldHandle = fractional ||
        activeGesture ||
        smallContinuous ||
        fastContinuous ||
        diagonalMovement;
    if (shouldHandle) {
      _desktopTouchpadGestureUntilMicros = now + 240000;
    }
    return shouldHandle;
  }

  void _scheduleDesktopScrollFlush() {
    if (_desktopScrollFlushScheduled) return;
    _desktopScrollFlushScheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      _desktopScrollFlushScheduled = false;
      unawaited(_flushDesktopScroll());
    });
  }

  Future<void> _flushDesktopScroll() async {
    final controller = _desktopWebViewController;
    if (controller == null) {
      _pendingDesktopScrollX = 0;
      _pendingDesktopScrollY = 0;
      return;
    }

    final x = _clampDouble(_pendingDesktopScrollX, -180, 180);
    final y = _clampDouble(_pendingDesktopScrollY, -180, 180);
    _pendingDesktopScrollX -= x;
    _pendingDesktopScrollY -= y;
    if (_pendingDesktopScrollX.abs() < 0.5) _pendingDesktopScrollX = 0;
    if (_pendingDesktopScrollY.abs() < 0.5) _pendingDesktopScrollY = 0;

    if (x.abs() >= 0.5 || y.abs() >= 0.5) {
      try {
        await controller.scrollBy(
          x: x.round(),
          y: y.round(),
          animated: false,
        );
      } catch (e) {
        _logger.debug('Windows touchpad scroll fallback failed: $e');
      }
    }

    if (_pendingDesktopScrollX != 0 || _pendingDesktopScrollY != 0) {
      _scheduleDesktopScrollFlush();
    }
  }

  double _clampDouble(double value, double min, double max) {
    return value.clamp(min, max).toDouble();
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
    if (_useSystemWebView) {
      return _webViewController != null
          ? WebViewWidget(controller: _webViewController!)
          : const Center(child: CircularProgressIndicator());
    }

    // Windows / Linux: embedded InAppWebView (Edge WebView2 / WebKitGTK)
    final webView = iaw.InAppWebView(
      initialUrlRequest: iaw.URLRequest(url: iaw.WebUri(widget.paymentUrl)),
      initialUserScripts: Platform.isWindows
          ? UnmodifiableListView<iaw.UserScript>([
              iaw.UserScript(
                groupName: 'fastcat-windows-touchpad-scroll',
                source: _windowsPrecisionTouchpadScrollScript,
                injectionTime: iaw.UserScriptInjectionTime.AT_DOCUMENT_START,
                forMainFrameOnly: false,
              ),
            ])
          : null,
      initialSettings: iaw.InAppWebViewSettings(
        userAgent: _desktopUserAgent,
        javaScriptEnabled: true,
      ),
      onWebViewCreated: (controller) {
        _desktopWebViewController = controller;
      },
      shouldOverrideUrlLoading: _onDesktopNavigation,
    );
    if (!Platform.isWindows) return webView;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerSignal: _handleDesktopPointerSignal,
      child: webView,
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
