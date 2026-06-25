import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Crisp 客服嵌入页面
///
/// 在应用内通过 WebView 加载 Crisp 聊天窗口，无需跳转外部浏览器。
/// 支持 Android、iOS；桌面端使用 desktop_webview_window 独立窗口。
class CrispChatPage extends StatefulWidget {
  final String websiteId;
  final String? userScript;

  const CrispChatPage({
    super.key,
    required this.websiteId,
    this.userScript,
  });

  /// 是否支持内嵌 WebView（桌面端统一使用独立窗口）
  static bool get isSupported => Platform.isAndroid || Platform.isIOS;

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
    unawaited(_configureAndroidFileSelection(_controller));

    // 所有平台统一直接加载 embed URL（macOS 去掉沙箱后不再有限制）
    _controller.loadRequest(
      Uri.parse(
          'https://go.crisp.chat/chat/embed/?website_id=${widget.websiteId}'),
    );
  }

  Future<void> _configureAndroidFileSelection(
      WebViewController controller) async {
    if (!Platform.isAndroid) return;

    final platformController = controller.platform;
    if (platformController is AndroidWebViewController) {
      await platformController.setOnShowFileSelector(_showAndroidFileSelector);
    }
  }

  Future<List<String>> _showAndroidFileSelector(
    FileSelectorParams params,
  ) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: params.mode == FileSelectorMode.openMultiple,
      type: _filePickerType(params.acceptTypes),
      withData: false,
    );

    if (result == null) return <String>[];

    return result.files
        .map(_fileSelectorUriForAndroid)
        .whereType<String>()
        .toList(growable: false);
  }

  FileType _filePickerType(List<String> acceptTypes) {
    final types = acceptTypes
        .map((type) => type.trim().toLowerCase())
        .where((type) => type.isNotEmpty)
        .toList(growable: false);
    if (types.isEmpty || types.contains('*/*')) return FileType.any;
    if (types.every((type) => type == 'image/*' || type.startsWith('image/'))) {
      return FileType.image;
    }
    if (types.every((type) => type == 'video/*' || type.startsWith('video/'))) {
      return FileType.video;
    }
    if (types.every((type) => type == 'audio/*' || type.startsWith('audio/'))) {
      return FileType.audio;
    }
    return FileType.any;
  }

  String? _fileSelectorUriForAndroid(PlatformFile file) {
    final identifier = file.identifier;
    if (identifier != null && identifier.isNotEmpty) return identifier;

    final path = file.path;
    if (path == null || path.isEmpty) return null;
    return Uri.file(path).toString();
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
