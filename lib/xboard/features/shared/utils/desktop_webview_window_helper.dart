import 'dart:io';
// ignore: unnecessary_import
import 'dart:ui' show Brightness;

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/widgets.dart';
import 'package:fl_clash/common/path.dart';
import 'package:window_manager/window_manager.dart';

class DesktopWebviewWindowHelper {
  DesktopWebviewWindowHelper._();

  static Future<bool> isAvailable() async {
    if (Platform.isWindows) {
      try {
        return await WebviewWindow.isWebviewAvailable();
      } catch (_) {
        return false;
      }
    }
    return Platform.isLinux || Platform.isMacOS;
  }

  static Future<String> dataFolder({
    String name = 'webview2_data',
  }) async {
    final dir = await appPath.homeDirPath;
    return '$dir/$name';
  }

  static Future<Webview> create({
    required String title,
    int windowWidth = 1100,
    int windowHeight = 760,
    bool matchMainWindow = false,
    bool resizable = true,
    bool showTitleBarActions = true,
    Brightness? brightness,
  }) async {
    final available = await isAvailable();
    if (!available) {
      throw StateError('Desktop WebView runtime is not available');
    }

    var width = windowWidth;
    var height = windowHeight;
    var posX = 0;
    var posY = 0;
    var useWindowPositionAndSize = false;

    if (matchMainWindow) {
      try {
        final mainSize = await windowManager.getSize();
        final mainPos = await windowManager.getPosition();
        final views = WidgetsBinding.instance.platformDispatcher.views;
        final ratio = views.isNotEmpty ? views.first.devicePixelRatio : 1.0;
        width = (mainSize.width * ratio).round();
        height = (mainSize.height * ratio).round();
        posX = (mainPos.dx * ratio).round();
        posY = (mainPos.dy * ratio).round();
        useWindowPositionAndSize = true;
      } catch (_) {
        useWindowPositionAndSize = false;
      }
    }

    return WebviewWindow.create(
      configuration: CreateConfiguration(
        title: title,
        windowWidth: width,
        windowHeight: height,
        windowPosX: posX,
        windowPosY: posY,
        useWindowPositionAndSize: useWindowPositionAndSize,
        titleBarHeight: Platform.isMacOS ? 40 : 0,
        titleBarTopPadding: Platform.isMacOS ? 24 : 0,
        userDataFolderWindows: Platform.isWindows ? await dataFolder() : '',
        resizable: resizable,
        showTitleBarActions: showTitleBarActions,
        brightness: brightness,
      ),
    );
  }
}
