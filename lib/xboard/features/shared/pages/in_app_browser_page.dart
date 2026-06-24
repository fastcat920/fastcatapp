import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

/// 软件内 WebView 页面（通用）
///
/// Android / iOS / macOS → 内嵌 WebView（webview_flutter）
/// Windows / Linux → 独立 WebView 窗口（desktop_webview_window）
class InAppBrowserPage extends StatefulWidget {
  final String url;
  final String title;

  const InAppBrowserPage({
    super.key,
    required this.url,
    required this.title,
  });

  /// 判断当前平台是否支持内嵌 WebView（仅 Android/iOS/macOS）
  static bool get isSupported =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  /// 统一入口：
  /// - Android/iOS/macOS → push 内嵌 WebView 页面
  /// - Windows/Linux → desktop_webview_window 独立窗口
  /// - 其他 → 外部浏览器
  static Future<void> open(
    BuildContext context, {
    required String url,
    required String title,
  }) async {
    if (url.isEmpty) return;
    if (isSupported) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => InAppBrowserPage(url: url, title: title),
        ),
      );
    } else if (Platform.isWindows || Platform.isLinux) {
      try {
        final appDir = await getApplicationSupportDirectory();
        final dataFolder = '${appDir.path}/webview2_data';

        // 获取主客户端窗口逻辑大小和位置，乘以 DPI 缩放比转为物理像素
        final mainSize = await windowManager.getSize();
        final mainPos = await windowManager.getPosition();
        final views = WidgetsBinding.instance.platformDispatcher.views;
        final ratio = views.isNotEmpty ? views.first.devicePixelRatio : 1.0;

        final webview = await WebviewWindow.create(
          configuration: CreateConfiguration(
            title: title,
            windowWidth: (mainSize.width * ratio).toInt(),
            windowHeight: (mainSize.height * ratio).toInt(),
            windowPosX: (mainPos.dx * ratio).toInt(),
            windowPosY: (mainPos.dy * ratio).toInt(),
            useWindowPositionAndSize: true,
            resizable: false,
            userDataFolderWindows: dataFolder,
          ),
        );
        webview.launch(url);
      } catch (_) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } else {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  State<InAppBrowserPage> createState() => _InAppBrowserPageState();
}

class _InAppBrowserPageState extends State<InAppBrowserPage> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            tooltip: '在浏览器中打开',
            onPressed: () => launchUrl(
              Uri.parse(widget.url),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const LinearProgressIndicator(minHeight: 3),
        ],
      ),
    );
  }
}
