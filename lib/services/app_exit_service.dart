import 'dart:async';
import 'dart:io';

import 'package:fl_clash/clash/clash.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/state.dart';

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

    final fallbackExitTimer = Timer(commonDuration, exitOnce);
    try {
      await system.setMacOSDns(true);
      await proxy?.stopProxy();
      await clashCore.shutdown();
      await clashService?.destroy();
      await _clearDesktopCache();
      await Process.start(
        Platform.resolvedExecutable,
        const [],
        mode: ProcessStartMode.detached,
      );
    } finally {
      fallbackExitTimer.cancel();
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

  Future<void> _clearDesktopCache() async {
    final sharedPreferencesFile = File(await appPath.sharedPreferencesPath);
    if (await sharedPreferencesFile.exists()) {
      await sharedPreferencesFile.delete();
    }
    final profilesDirectory = Directory(await appPath.profilesPath);
    if (await profilesDirectory.exists()) {
      await profilesDirectory.delete(recursive: true);
    }
    commonPrint.log('clear cache files');
  }
}
