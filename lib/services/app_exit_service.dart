import 'dart:async';
import 'dart:io';

import 'package:fl_clash/clash/clash.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/state.dart';
import 'package:path/path.dart' show dirname;

class AppExitService {
  const AppExitService();

  Future<void> savePreferences() async {
    commonPrint.log('save preferences');
    await preferences.saveConfig(globalState.config);
  }

  Future<void> handleExit() async {
    var didExit = false;
    void exitOnce() {
      if (didExit) return;
      didExit = true;
      system.exit();
    }

    final fallbackExitTimer = Timer(commonDuration, exitOnce);
    try {
      await savePreferences();
      await system.setMacOSDns(true);
      await proxy?.stopProxy();
      await clashCore.shutdown();
      await clashService?.destroy();
    } finally {
      fallbackExitTimer.cancel();
      exitOnce();
    }
  }

  Future<void> handleClearCacheAndRestart() async {
    var didExit = false;
    void exitOnce() {
      if (didExit) return;
      didExit = true;
      system.exit();
    }

    try {
      await appPath.markClearCacheOnNextStart();
      await _shutdownRuntimeForRestart(
        timeout: const Duration(milliseconds: 700),
      );
      await singleInstanceLock.release();
      await _restartApplication();
    } finally {
      exitOnce();
    }
  }

  Future<void> handleClear() async {
    await preferences.clearPreferences();
    commonPrint.log('clear preferences');
    globalState.config = Config(
      themeProps: defaultThemeProps,
    );
  }

  Future<void> _shutdownRuntimeForRestart({
    required Duration timeout,
  }) async {
    try {
      final shutdownTasks = <Future<void>>[
        system.setMacOSDns(true),
        clashCore.shutdown(),
      ];
      final proxyStop = proxy?.stopProxy();
      if (proxyStop != null) {
        shutdownTasks.add(_ignoreTaskResult(proxyStop));
      }
      final serviceDestroy = clashService?.destroy();
      if (serviceDestroy != null) {
        shutdownTasks.add(_ignoreTaskResult(serviceDestroy));
      }
      await Future.wait<void>(shutdownTasks).timeout(timeout);
    } catch (e) {
      commonPrint.log('shutdown before restart timeout or failed: $e');
    }
  }

  Future<void> _ignoreTaskResult(FutureOr<dynamic> task) async {
    await task;
  }

  Future<void> _restartApplication() async {
    if (Platform.isMacOS) {
      final appBundlePath = _macOSAppBundlePath();
      if (appBundlePath != null) {
        await Process.start(
          'open',
          ['-n', appBundlePath],
          mode: ProcessStartMode.detached,
        );
        return;
      }
    }
    if (Platform.isWindows) {
      final executablePath = Platform.resolvedExecutable;
      final executableDir = dirname(executablePath);
      final launched = windows?.launch(
            executablePath,
            workingDirectory: executableDir,
          ) ??
          false;
      if (launched) return;
      await Process.start(
        'cmd.exe',
        [
          '/d',
          '/c',
          'start "" /D "${_escapeWindowsCommandArgument(executableDir)}" '
              '"${_escapeWindowsCommandArgument(executablePath)}"',
        ],
        workingDirectory: executableDir,
        mode: ProcessStartMode.detached,
      );
      return;
    }
    await Process.start(
      Platform.resolvedExecutable,
      const [],
      mode: ProcessStartMode.detached,
    );
  }

  String? _macOSAppBundlePath() {
    final executablePath = Platform.resolvedExecutable;
    final marker = '.app/Contents/MacOS/';
    final markerIndex = executablePath.indexOf(marker);
    if (markerIndex == -1) return null;
    return executablePath.substring(0, markerIndex + '.app'.length);
  }

  String _escapeWindowsCommandArgument(String value) {
    return value.replaceAll('"', r'\"');
  }
}
