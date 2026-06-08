import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Crisp 客服嵌入页面
///
/// 在应用内通过 WebView 加载 Crisp 聊天窗口，无需跳转外部浏览器。
/// 支持 Android、iOS、macOS；Windows/Linux 请调用方回退到外部浏览器。
class CrispChatPage extends StatefulWidget {
  final String websiteId;
  final String? userScript;

  const CrispChatPage({
    super.key,
    required this.websiteId,
    this.userScript,
  });

  /// 是否支持内嵌 WebView（仅 Android/iOS/macOS，Windows/Linux 无 webview_flutter 实现）
  static bool get isSupported =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  @override
  State<CrispChatPage> createState() => _CrispChatPageState();
}

class _CrispChatPageState extends State<CrispChatPage> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFF5F5F5))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            final userScript = widget.userScript;
            if (userScript != null && userScript.isNotEmpty) {
              _controller.runJavaScript(userScript);
            }
            if (mounted) setState(() => _isLoading = false);
          },
        ),
      );

    // 所有平台统一直接加载 embed URL（macOS 去掉沙箱后不再有限制）
    _controller.loadRequest(
      Uri.parse(
          'https://go.crisp.chat/chat/embed/?website_id=${widget.websiteId}'),
    );
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
          WebViewWidget(controller: _controller),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
