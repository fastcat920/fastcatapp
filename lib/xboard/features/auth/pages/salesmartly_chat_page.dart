import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// SalesSmartly 客服嵌入页面（Android/iOS/macOS）
///
/// 官方 JSSDK 文档：https://help.salesmartly.com/docs/development-docking
///
/// Android/iOS: loadHtmlString 加载含 SDK 的 HTML
/// macOS: loadHtmlString/document.write 在 WKWebView 中有灰屏/黑屏问题，
///        改为启动本地 HTTP 服务器提供 HTML，WebView 加载 localhost URL
class SalesmarylyChatPage extends StatefulWidget {
  final String scriptUrl;

  const SalesmarylyChatPage({super.key, required this.scriptUrl});

  static bool get isSupported =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  @override
  State<SalesmarylyChatPage> createState() => _SalesmarylyChatPageState();
}

class _SalesmarylyChatPageState extends State<SalesmarylyChatPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;
  HttpServer? _localServer;

  String _buildHtml() {
    final escaped = widget.scriptUrl
        .replaceAll('&', '&amp;')
        .replaceAll('"', '&quot;');
    return '''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body { width: 100%; height: 100%; background: #f5f5f5; }
    #ss_loading {
      display: flex; align-items: center; justify-content: center;
      height: 100%; color: #999;
      font-family: -apple-system, sans-serif; font-size: 14px;
    }
  </style>
</head>
<body>
  <div id="ss_loading">正在连接客服...</div>
  <script>
    var s = document.createElement('script');
    s.src = "$escaped";
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
  </script>
</body>
</html>''';
  }

  /// macOS：启动本地 HTTP 服务器，返回端口号
  Future<int> _startLocalServer() async {
    _localServer?.close();
    final html = _buildHtml();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _localServer = server;
    server.listen((request) {
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.html
        ..headers.set('Cache-Control', 'no-cache')
        ..write(html);
      request.response.close();
    });
    return server.port;
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFF5F5F5))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame ?? true) {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _hasError = true;
                });
              }
            }
          },
        ),
      );

    _loadContent();
  }

  Future<void> _loadContent() async {
    if (Platform.isMacOS) {
      // macOS: WKWebView 的 loadHtmlString 有灰屏问题
      // 启动本地 HTTP 服务器，WebView 加载 localhost URL
      final port = await _startLocalServer();
      _controller.loadRequest(Uri.parse('http://localhost:$port'));
    } else {
      _controller.loadHtmlString(_buildHtml(), baseUrl: 'https://www.salesmartly.com');
    }
  }

  @override
  void dispose() {
    _localServer?.close();
    super.dispose();
  }

  void _retry() {
    setState(() {
      _hasError = false;
      _isLoading = true;
    });
    _loadContent();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('在线客服'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          ),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading)
              Container(
                color: const Color(0xFFF5F5F5),
                child: const Center(child: CircularProgressIndicator()),
              ),
            if (_hasError)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text('加载失败，请检查网络', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _retry, child: const Text('重试')),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
