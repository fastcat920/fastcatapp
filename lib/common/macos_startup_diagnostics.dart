import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'boot_diag.dart';

class MacOSStartupDiagnostics {
  static const _channel = MethodChannel('fastcat/startup_diagnostics');
  static Timer? _firstFrameWatchdog;

  static void armFirstFrameWatchdog() {
    if (!Platform.isMacOS || _firstFrameWatchdog != null) return;
    _firstFrameWatchdog = Timer(const Duration(seconds: 20), () {
      _firstFrameWatchdog = null;
      bootDiagLog(
        'startup watchdog: Flutter first frame was not reached within 20s',
      );
    });
  }

  static Future<void> captureRendererInfo() async {
    if (!Platform.isMacOS) return;
    try {
      final result = await _channel
          .invokeMapMethod<String, dynamic>('getRendererInfo')
          .timeout(const Duration(seconds: 2));
      await bootDiagLog('macOS renderer info: ${result ?? const {}}');
    } catch (error) {
      await bootDiagLog('macOS renderer info unavailable: $error');
    }
  }

  static Future<void> markFirstFrame() async {
    if (!Platform.isMacOS) return;
    _firstFrameWatchdog?.cancel();
    _firstFrameWatchdog = null;
    try {
      await _channel
          .invokeMethod<void>('firstFrameRendered')
          .timeout(const Duration(seconds: 2));
    } catch (error) {
      await bootDiagLog('macOS first-frame native marker failed: $error');
    }
  }
}
