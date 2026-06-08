import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Linux 桌面端内嵌客服页面（基于 flutter_inappwebview / WebKit2GTK）
///
/// 仅用于 Linux，其他平台使用 webview_flutter 或 flutter_inappwebview。
/// WebKit2GTK 的 loadData/initialData 不支持真实 HTTPS origin，
/// 外部 SDK 脚本会被 CORS 阻止。
/// 因此先导航到客服官网轻量页面（建立 HTTPS origin），
/// 导航完成后用 JS 重写页面并注入 SDK（与 Windows 版相同策略）。
class LinuxChatPage extends StatefulWidget {
  final String? salesmartlyScriptUrl;
  final String? crispWebsiteId;
  final String? crispUserScript;

  const LinuxChatPage({
    super.key,
    this.salesmartlyScriptUrl,
    this.crispWebsiteId,
    this.crispUserScript,
  }) : assert(
          salesmartlyScriptUrl != null || crispWebsiteId != null,
          'Must provide either salesmartlyScriptUrl or crispWebsiteId',
        );

  static bool get isSupported => Platform.isLinux;

  @override
  State<LinuxChatPage> createState() => _LinuxChatPageState();
}

class _LinuxChatPageState extends State<LinuxChatPage> {
  bool _isLoading = true;
  bool _injected = false;

  String get _initialUrl {
    if (widget.crispWebsiteId != null) {
      return 'https://go.crisp.chat/robots.txt';
    }
    return 'https://www.salesmartly.com/robots.txt';
  }

  String _buildCrispInjectJs(String websiteId) {
    final escaped = websiteId.replaceAll('\\', '\\\\').replaceAll("'", "\\'");
    final userScript = widget.crispUserScript ?? '';
    return '''
      document.open();
      document.write('<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><style>*{margin:0;padding:0}html,body{width:100%;height:100%;background:#f5f5f5;overflow:hidden}#crisp_loading{display:flex;align-items:center;justify-content:center;height:100%;color:#999;font-family:-apple-system,sans-serif;font-size:14px}</style></head><body><div id="crisp_loading">正在连接客服...</div></body></html>');
      document.close();

      window.\$crisp = [];
      window.CRISP_WEBSITE_ID = '$escaped';
      $userScript

      (function(){
        var d = document;
        var s = d.createElement('script');
        s.src = 'https://client.crisp.chat/l.js';
        s.async = 1;
        d.getElementsByTagName('head')[0].appendChild(s);
      })();

      (function poll() {
        try {
          if (window.\$crisp && typeof \$crisp.push === 'function' && \$crisp.is) {
            if (!\$crisp.is('chat:opened')) {
              \$crisp.push(['do', 'chat:open']);
            }
            if (\$crisp.is('chat:opened')) {
              var e = document.getElementById('crisp_loading');
              if (e) e.style.display = 'none';
              return;
            }
          }
        } catch(ex) {}
        setTimeout(poll, 500);
      })();

      new MutationObserver(function() {
        var fs = document.querySelectorAll('iframe');
        for (var i = 0; i < fs.length; i++) {
          var src = fs[i].src || fs[i].getAttribute('data-from-crisp') || '';
          if (src.indexOf('crisp') !== -1 || fs[i].id.indexOf('crisp') !== -1 || (fs[i].className && fs[i].className.indexOf('crisp') !== -1)) {
            fs[i].style.cssText = 'position:fixed!important;top:0!important;left:0!important;width:100vw!important;height:100vh!important;max-width:none!important;max-height:none!important;border:none!important;border-radius:0!important;z-index:99999!important;';
            var p = fs[i].parentElement;
            if (p) p.style.cssText = 'position:fixed!important;top:0!important;left:0!important;width:100vw!important;height:100vh!important;z-index:99999!important;';
            var e = document.getElementById('crisp_loading');
            if (e) e.style.display = 'none';
          }
        }
      }).observe(document.documentElement, { childList: true, subtree: true, attributes: true });

      setTimeout(function() {
        var e = document.getElementById('crisp_loading');
        if (e && e.style.display !== 'none') e.textContent = '加载超时，请检查网络后重试';
      }, 30000);
    ''';
  }

  String _buildSalesmartlyInjectJs(String scriptUrl) {
    final escaped = scriptUrl.replaceAll('\\', '\\\\').replaceAll("'", "\\'");
    return '''
      document.open();
      document.write('<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><style>*{margin:0;padding:0}html,body{width:100%;height:100%;background:#f5f5f5;overflow:hidden}#ss_loading{display:flex;align-items:center;justify-content:center;height:100%;color:#999;font-family:-apple-system,sans-serif;font-size:14px}</style></head><body><div id="ss_loading">正在连接客服...</div></body></html>');
      document.close();

      var s = document.createElement('script');
      s.src = '$escaped';
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
            fs[i].style.cssText = 'position:fixed!important;top:0!important;left:0!important;width:100vw!important;height:100vh!important;border:none!important;z-index:99999!important;';
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
    ''';
  }

  void _onLoadStop(InAppWebViewController controller, WebUri? url) {
    if (_injected) return;
    _injected = true;

    final js = widget.crispWebsiteId != null
        ? _buildCrispInjectJs(widget.crispWebsiteId!)
        : _buildSalesmartlyInjectJs(widget.salesmartlyScriptUrl!);

    controller.evaluateJavascript(source: js);
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('在线客服'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
        ),
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(_initialUrl)),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              mediaPlaybackRequiresUserGesture: false,
            ),
            onLoadStop: _onLoadStop,
          ),
          if (_isLoading)
            Container(
              color: const Color(0xFFF5F5F5),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
