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
      await _restartWindowsApplication();
      return;
    }
    await Process.start(
      Platform.resolvedExecutable,
      const [],
      mode: ProcessStartMode.detached,
    );
  }

  Future<void> _restartWindowsApplication() async {
    final executablePath = Platform.resolvedExecutable;
    final executableDir = dirname(executablePath);
    try {
      final restartScript = await _createWindowsRestartScript();
      await Process.start(
        'cmd.exe',
        [
          '/d',
          '/c',
          'call',
          restartScript.path,
          pid.toString(),
          executablePath,
          executableDir,
        ],
        workingDirectory: executableDir,
        mode: ProcessStartMode.detached,
      );
      return;
    } catch (e) {
      commonPrint.log('start restart script failed: $e');
    }

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
  }

  Future<File> _createWindowsRestartScript() async {
    final script = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'FastCat_restart_${DateTime.now().microsecondsSinceEpoch}.cmd',
    );
    await script.writeAsString(
      '''
@echo off
setlocal
set "OLD_PID=%~1"
set "APP_EXE=%~2"
set "APP_DIR=%~3"
set /a WAIT_COUNT=0

:wait_for_exit
if "%OLD_PID%"=="" goto launch_app
if %WAIT_COUNT% GEQ 30 goto launch_app
tasklist /FI "PID eq %OLD_PID%" 2>NUL | find "%OLD_PID%" >NUL
if errorlevel 1 goto launch_app
set /a WAIT_COUNT+=1
timeout /t 1 /nobreak >NUL
goto wait_for_exit

:launch_app
start "" /D "%APP_DIR%" "%APP_EXE%"
del "%~f0" >NUL 2>NUL
''',
      flush: true,
    );
    return script;
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
