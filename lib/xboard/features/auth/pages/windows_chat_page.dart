import 'dart:async';
import 'dart:io';

import 'package:fl_clash/common/webview2_check.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/core/core.dart';
import 'package:fl_clash/xboard/features/auth/utils/crisp_url_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_windows/webview_windows.dart';

final _logger = FileLogger('windows_chat_page.dart');

/// Windows desktop customer-service page based on Apex's WebView2 panel.
///
/// Windows uses this lightweight WebView2 page directly instead of the richer
/// desktop Crisp implementation. Proxy routing and user metadata injection are
/// intentionally left for a later pass.
class WindowsChatPage extends StatefulWidget {
  final String? salesmartlyScriptUrl;
  final String? crispWebsiteId;
  final Future<void> Function()? onUnavailableFallback;

  const WindowsChatPage({
    super.key,
    this.salesmartlyScriptUrl,
    this.crispWebsiteId,
    this.onUnavailableFallback,
  }) : assert(
          salesmartlyScriptUrl != null || crispWebsiteId != null,
          'salesmartlyScriptUrl or crispWebsiteId is required',
        );

  static bool get isSupported =>
      Platform.isWindows && WebView2Check.isInstalled();

  static Future<bool> isRuntimeAvailable() async {
    if (!isSupported) return false;
    try {
      final version = await WebviewController.getWebViewVersion();
      if (version == null || version.trim().isEmpty) {
        _logger.warning('[WindowsChat] WebView2 Runtime version is empty');
        return false;
      }
      await WebviewController.initializeEnvironment();
      return true;
    } on PlatformException catch (e, stackTrace) {
      if (e.code == 'environment_already_initialized') return true;
      _logger.warning(
        '[WindowsChat] WebView2 runtime probe failed: ${e.code}',
        e,
        stackTrace,
      );
      return false;
    } catch (e, stackTrace) {
      _logger.warning(
          '[WindowsChat] WebView2 runtime probe failed', e, stackTrace);
      return false;
    }
  }

  @override
  State<WindowsChatPage> createState() => _WindowsChatPageState();
}

class _WindowsChatPageState extends State<WindowsChatPage> {
  final _controller = WebviewController();
  bool _isInitialized = false;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _logger.info(
      '[WindowsChat] initState: '
      'salesmartlyScriptUrl=${widget.salesmartlyScriptUrl != null ? "present(${widget.salesmartlyScriptUrl!.length})" : "empty"}, '
      'crispWebsiteId=${widget.crispWebsiteId != null ? "present(${widget.crispWebsiteId!.length})" : "empty"}',
    );
    unawaited(_initWebView());
  }

  Future<void> _initWebView() async {
    try {
      _logger.info('[WindowsChat] Initializing WebviewController...');
      await _controller.initialize();
      _logger.info('[WindowsChat] WebviewController initialized');

      await _controller.setBackgroundColor(const Color(0xFFF5F5F5));
      await _controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);

      if (widget.salesmartlyScriptUrl != null) {
        await _initSalesmartly();
      } else if (widget.crispWebsiteId != null) {
        await _initCrisp();
      }

      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e, stackTrace) {
      _logger.error('[WindowsChat] WebView2 init failed: $e', e, stackTrace);
      if (_shouldUseFallbackFor(e) &&
          widget.onUnavailableFallback != null &&
          mounted) {
        try {
          await widget.onUnavailableFallback!();
          if (mounted) {
            Navigator.of(context, rootNavigator: true).pop();
          }
          return;
        } catch (fallbackError, fallbackStackTrace) {
          _logger.error(
            '[WindowsChat] fallback after WebView2 init failure failed',
            fallbackError,
            fallbackStackTrace,
          );
        }
      }
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  bool _shouldUseFallbackFor(Object error) {
    if (error is! PlatformException) return false;
    return const {
      'unsupported_platform',
      'environment_creation_failed',
      'webview_creation_failed',
    }.contains(error.code);
  }

  Future<void> _initSalesmartly() async {
    final scriptUrl = widget.salesmartlyScriptUrl!;
    final scriptUrlEscaped = scriptUrl.replaceAll('\\', '\\\\').replaceAll(
          "'",
          "\\'",
        );

    _logger.info('[WindowsChat] Salesmartly: waiting navigation completed');

    late final StreamSubscription<LoadingState> subscription;
    subscription = _controller.loadingState.listen((state) {
      _logger.info('[WindowsChat] Salesmartly loadingState=$state');
      if (state == LoadingState.navigationCompleted) {
        subscription.cancel();
        _logger.info('[WindowsChat] Salesmartly: injecting SDK');
        unawaited(_injectSalesmartlySDK(scriptUrlEscaped));
      }
    });

    await _controller.loadUrl('https://www.salesmartly.com/robots.txt');
  }

  Future<void> _injectSalesmartlySDK(String scriptUrl) async {
    await _controller.executeScript('''
      document.open();
      document.write('<html><head><meta charset="utf-8"><style>*{margin:0;padding:0}html,body{width:100%;height:100%;background:#f5f5f5}#ss_loading{display:flex;align-items:center;justify-content:center;height:100%;color:#999;font-family:-apple-system,sans-serif;font-size:14px}</style></head><body><div id="ss_loading">正在连接客服...</div></body></html>');
      document.close();

      window.__ssc = window.__ssc || {};
      window.__ssc.setting = { hideIcon: true };

      var s = document.createElement('script');
      s.src = '$scriptUrl';
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
          } else {
            setTimeout(w, 300);
          }
        })();
      };
      s.onerror = function() {
        var e = document.getElementById('ss_loading');
        if (e) e.textContent = '加载失败，请检查网络后重试';
      };
      document.head.appendChild(s);

      new MutationObserver(function() {
        var fs = document.querySelectorAll('iframe');
        for (var i = 0; i < fs.length; i++) {
          var src = fs[i].src || '';
          if (src.indexOf('salesmartly') !== -1 || src.indexOf('ssm') !== -1) {
            fs[i].style.cssText = 'position:fixed!important;top:0!important;left:0!important;width:100vw!important;height:100vh!important;max-width:none!important;max-height:none!important;border:none!important;border-radius:0!important;z-index:99999!important;';
            var p = fs[i].parentElement;
            if (p) p.style.cssText = 'position:fixed!important;top:0!important;left:0!important;width:100vw!important;height:100vh!important;z-index:99999!important;';
            var e = document.getElementById('ss_loading');
            if (e) e.style.display = 'none';
          }
        }
      }).observe(document.documentElement, { childList: true, subtree: true, attributes: true });

      setTimeout(function() {
        var e = document.getElementById('ss_loading');
        if (e && e.style.display !== 'none') e.textContent = '加载超时，请检查网络后重试';
      }, 20000);
    ''');
  }

  Future<void> _initCrisp() async {
    final websiteId = widget.crispWebsiteId!;
    _logger.info('[WindowsChat] Crisp: loading embed page');
    await _controller.loadUrl(officialCrispEmbedUri(websiteId).toString());
  }

  void _retry() {
    setState(() {
      _hasError = false;
      _isInitialized = false;
    });
    unawaited(_initWebView());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context).onlineSupportTitle),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          ),
        ),
        body: _hasError
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'WebView2 加载失败\n$_errorMessage',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _retry, child: const Text('重试')),
                  ],
                ),
              )
            : !_isInitialized
                ? const Center(child: CircularProgressIndicator())
                : Webview(_controller),
      ),
    );
  }
}
