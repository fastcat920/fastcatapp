import 'dart:io';

import 'package:fl_clash/common/boot_diag.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

class Window {
  init(int version) async {
    await bootDiagLog('window.init begin');
    final props = globalState.config.windowProps;
    final initialSize = const Size(800, 600);
    final acquire = await singleInstanceLock.acquire();
    if (!acquire) {
      await bootDiagLog('singleInstanceLock denied, exiting');
      exit(0);
    }
    if (Platform.isWindows) {
      protocol.register("clash");
      protocol.register("clashmeta");
      protocol.register("flclash");
    }
    await windowManager.ensureInitialized().timeout(
          const Duration(seconds: 8),
        );
    await bootDiagLog('windowManager.ensureInitialized complete');
    final windowOptions = WindowOptions(
      size: initialSize,
      minimumSize: initialSize,
      maximumSize: initialSize,
    );
    if (!Platform.isMacOS || version > 10) {
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    }
    if (!Platform.isMacOS) {
      final left = props.left ?? 0;
      final top = props.top ?? 0;
      final right = left + initialSize.width;
      final bottom = top + initialSize.height;
      final shouldCenterWindow = left == 0 && top == 0;
      if (shouldCenterWindow) {
        await windowManager.setAlignment(Alignment.center);
      } else {
        final displays = await screenRetriever.getAllDisplays();
        final isPositionValid = displays.any(
          (display) {
            final displayBounds = Rect.fromLTWH(
              display.visiblePosition!.dx,
              display.visiblePosition!.dy,
              display.size.width,
              display.size.height,
            );
            return displayBounds.contains(Offset(left, top)) ||
                displayBounds.contains(Offset(right, bottom));
          },
        );
        if (isPositionValid) {
          await windowManager.setPosition(Offset(left, top));
        } else {
          await windowManager.setAlignment(Alignment.center);
        }
      }
    }
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await bootDiagLog('waitUntilReadyToShow callback begin');
      await windowManager.setPreventClose(true);
      await windowManager.setMinimumSize(initialSize);
      await windowManager.setMaximumSize(initialSize);
      await windowManager.setSize(initialSize);
      await windowManager.setResizable(false);
      final left = props.left ?? 0;
      final top = props.top ?? 0;
      if (!Platform.isMacOS && left == 0 && top == 0) {
        await windowManager.setAlignment(Alignment.center);
      }
      await bootDiagLog('waitUntilReadyToShow callback complete');
    }).timeout(const Duration(seconds: 8));
    await bootDiagLog('window.init end');
  }

  show() async {
    await bootDiagLog('window.show begin');
    render?.resume();
    await _bestEffortWindowAction('show', windowManager.show);
    await _bestEffortWindowAction('focus', windowManager.focus);
    await _bestEffortWindowAction(
      'setSkipTaskbar(false)',
      () => windowManager.setSkipTaskbar(false),
    );
    await bootDiagLog('window.show complete');
  }

  Future<void> _bestEffortWindowAction(
    String name,
    Future<void> Function() action,
  ) async {
    try {
      await action().timeout(const Duration(seconds: 5));
    } catch (error) {
      await bootDiagLog('window.$name failed: $error');
    }
  }

  Future<bool> get isVisible async {
    final value = await windowManager.isVisible();
    commonPrint.log("window visible check: $value");
    return value;
  }

  close() async {
    exit(0);
  }

  hide() async {
    render?.pause();
    await windowManager.hide();
    await windowManager.setSkipTaskbar(true);
  }
}

final window = system.isDesktop ? Window() : null;
