import 'dart:async';
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

/// Windows desktop customer-service page using an embedded WebView2 widget.
///
/// The outer 400x600 panel stays aligned with Apex's Windows customer-service
/// UI, but the renderer uses flutter_inappwebview on Windows to avoid the
/// webview_windows Graphics Capture path that can return unsupported_platform.
class WindowsChatPage extends StatefulWidget {
  final String? salesmartlyScriptUrl;
  final String? crispWebsiteId;

  const WindowsChatPage({
    super.key,
    this.salesmartlyScriptUrl,
    this.crispWebsiteId,
  }) : assert(
          salesmartlyScriptUrl != null || crispWebsiteId != null,
          'salesmartlyScriptUrl or crispWebsiteId is required',
        );

  static bool get isSupported => Platform.isWindows;

  @override
  State<WindowsChatPage> createState() => _WindowsChatPageState();
}

class _WindowsChatPageState extends State<WindowsChatPage> {
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  int _reloadToken = 0;

  @override
  void initState() {
    super.initState();
    _logger.info(
      '[WindowsChat] initState: '
      'salesmartlyScriptUrl=${widget.salesmartlyScriptUrl != null ? "present(${widget.salesmartlyScriptUrl!.length})" : "empty"}, '
      'crispWebsiteId=${widget.crispWebsiteId != null ? "present(${widget.crispWebsiteId!.length})" : "empty"}',
    );
  }

  Uri _initialUri(BuildContext context) {
    if (widget.salesmartlyScriptUrl != null) {
      return Uri.parse('https://www.salesmartly.com/robots.txt');
    }
    return _localizedCrispUri(
      officialCrispEmbedUri(widget.crispWebsiteId!),
      Localizations.localeOf(context).toLanguageTag(),
    );
  }

  bool _hasWebView2Runtime() {
    try {
      return WebView2Check.isInstalled();
    } catch (e, stackTrace) {
      _logger.warning(
          '[WindowsChat] WebView2 runtime check failed', e, stackTrace);
      return false;
    }
  }

  Future<void> _injectAfterLoad(iaw.InAppWebViewController controller) async {
    if (widget.salesmartlyScriptUrl != null) {
      await _injectSalesmartlySDK(controller);
      return;
    }
    await _injectCrispLayout(controller);
  }

  Future<void> _injectSalesmartlySDK(
    iaw.InAppWebViewController controller,
  ) async {
    final scriptUrl = widget.salesmartlyScriptUrl!;
    final scriptUrlEscaped = scriptUrl.replaceAll('\\', '\\\\').replaceAll(
          "'",
          "\\'",
        );
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
    ''');
  }

  Future<void> _injectCrispLayout(iaw.InAppWebViewController controller) async {
    await controller.evaluateJavascript(source: '''
(function(){
  try {
    window.\$crisp = window.\$crisp || [];
    window.\$crisp.push(["do", "chat:show"]);
    window.\$crisp.push(["do", "chat:open"]);
    var style = document.getElementById("fastcat-windows-crisp-style");
    if (!style) {
      style = document.createElement("style");
      style.id = "fastcat-windows-crisp-style";
      (document.head || document.documentElement).appendChild(style);
    }
    style.textContent =
      "html,body{width:100%!important;height:100%!important;margin:0!important;overflow:hidden!important;background:#f5f5f5!important;}" +
      "iframe[src*=crisp],.crisp-client,[class*=crisp],[id*=crisp]{position:fixed!important;inset:0!important;width:100%!important;height:100%!important;max-width:none!important;max-height:none!important;margin:0!important;padding:0!important;border:0!important;border-radius:0!important;}";
  } catch (_) {}
})();''');
  }

  void _setLoading(bool value) {
    if (!mounted || _isLoading == value) return;
    setState(() => _isLoading = value);
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _hasError = true;
      _errorMessage = message;
    });
  }

  void _retry() {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
      _reloadToken++;
    });
  }

  Widget _buildError(BuildContext context, String message) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.support_agent_outlined,
              size: 40,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.refresh),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebView(BuildContext context) {
    if (!_hasWebView2Runtime()) {
      return _buildError(
        context,
        'WebView2 Runtime 未安装，无法加载内嵌客服。',
      );
    }
    final initialUri = _initialUri(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        iaw.InAppWebView(
          key: ValueKey(_reloadToken),
          initialUrlRequest: iaw.URLRequest(
            url: iaw.WebUri(initialUri.toString()),
          ),
          initialSettings: iaw.InAppWebViewSettings(
            javaScriptEnabled: true,
            javaScriptCanOpenWindowsAutomatically: false,
            mediaPlaybackRequiresUserGesture: false,
            supportZoom: false,
            transparentBackground: false,
            useShouldOverrideUrlLoading: true,
          ),
          onLoadStart: (_, __) {
            _setLoading(true);
          },
          onLoadStop: (controller, _) async {
            try {
              await _injectAfterLoad(controller);
            } catch (e, stackTrace) {
              _logger.warning(
                '[WindowsChat] post-load script injection failed',
                e,
                stackTrace,
              );
            }
            _setLoading(false);
          },
          onReceivedError: (_, request, error) {
            if (request.isForMainFrame == false) return;
            _logger.warning('[WindowsChat] load error: $error');
            _showError(error.description);
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
    final body = _hasError
        ? _buildError(context, _errorMessage)
        : _buildWebView(context);
    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text(AppLocalizations.of(context).onlineSupportTitle),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          ),
        ),
        body: body,
      ),
    );
  }
}
