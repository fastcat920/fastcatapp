import 'dart:async';
import 'package:fl_clash/services/desktop_shutdown.dart';
import 'dart:io';

import 'package:fl_clash/clash/clash.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/security/profile_vault.dart';
import 'package:fl_clash/state.dart';
import 'package:path/path.dart' show dirname;

class AppExitService {
  const AppExitService();

  Future<void> savePreferences() async {
    commonPrint.log('save preferences');
    await preferences.saveConfig(globalState.config);
  }

  Future<void> handleExit() async {
    try {
      await savePreferences();
      await _shutdownRuntimeForRestart();
      system.exit();
    } catch (error) {
      commonPrint
          .log('[Exit] cleanup failed; keeping application open: $error');
      globalState.showNotifier(appLocalizations.xboardCoreDisconnectFailed);
    }
  }

  Future<void> handleClearCacheAndRestart() async {
    var releasedLock = false;
    try {
      if (globalState.isStart &&
          !await globalState.appController.updateStatus(false)) {
        throw StateError('Connection operation is still in progress');
      }
      await _shutdownRuntimeForRestart();
      await appPath.markClearCacheOnNextStart();
      await singleInstanceLock.release();
      releasedLock = true;
      await _restartApplication();
      system.exit();
    } catch (error) {
      if (releasedLock) await singleInstanceLock.acquire();
      commonPrint.log('[Restart] cleanup or launch failed: $error');
      globalState.showNotifier(appLocalizations.xboardCoreDisconnectFailed);
    }
  }

  Future<void> handleClear() async {
    await preferences.clearPreferences();
    commonPrint.log('clear preferences');
    globalState.config = Config(
      themeProps: defaultThemeProps,
    );
  }

  Future<void> _shutdownRuntimeForRestart() async {
    await runOrderedDesktopShutdown(
      restoreRouting: () async {
        if (await proxy?.stopProxy() == false) return false;
        return system.setMacOSDns(true);
      },
      shutdownCore: () async {
        await clashCore.shutdown();
        final profileId = globalState.config.currentProfileId;
        if (profileId != null) {
          await ProfileVault.instance.snapshotRuntimeProviders(profileId);
          await ProfileVault.instance.clearRuntimeProviders(profileId);
        }
      },
      destroyService: () async {
        await clashService?.destroy();
      },
    );
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
        'wscript.exe',
        [
          '//B',
          '//Nologo',
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
      'FastCat_restart_${DateTime.now().microsecondsSinceEpoch}.vbs',
    );
    await script.writeAsString(
      r'''
Option Explicit

If WScript.Arguments.Count < 3 Then
  WScript.Quit 1
End If

Dim oldPid, appExe, appDir, shell, fso, wmi, processes, waitCount
oldPid = WScript.Arguments.Item(0)
appExe = WScript.Arguments.Item(1)
appDir = WScript.Arguments.Item(2)
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

On Error Resume Next
Set wmi = GetObject("winmgmts:\\.\root\cimv2")
If Err.Number <> 0 Then
  Set wmi = Nothing
  Err.Clear
End If
On Error GoTo 0

waitCount = 0

If Len(oldPid) > 0 And Not wmi Is Nothing Then
  Do While waitCount < 60
    On Error Resume Next
    Set processes = wmi.ExecQuery("SELECT ProcessId FROM Win32_Process WHERE ProcessId = " & oldPid)
    If Err.Number <> 0 Then
      Err.Clear
      Exit Do
    End If
    On Error GoTo 0
    If processes.Count = 0 Then
      Exit Do
    End If
    WScript.Sleep 500
    waitCount = waitCount + 1
  Loop
End If

On Error Resume Next
shell.CurrentDirectory = appDir
shell.Run """" & appExe & """", 1, False

fso.DeleteFile WScript.ScriptFullName, True
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
