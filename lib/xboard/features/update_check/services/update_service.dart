import 'dart:io';
import 'package:fl_clash/xboard/core/core.dart';
import 'package:fl_clash/xboard/config/xboard_config.dart';
import 'package:package_info_plus/package_info_plus.dart';

// 初始化文件级日志器
final _logger = FileLogger('update_service.dart');

class UpdateService {
  Future<String> getCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  String _getPlatformName() {
    if (Platform.isAndroid) return "android";
    if (Platform.isIOS) return "ios";
    if (Platform.isWindows) return "windows";
    if (Platform.isMacOS) return "macos";
    if (Platform.isLinux) return "linux";
    return "unknown";
  }

  /// 比较语义版本，返回 latest > current
  bool _isNewerVersion(String current, String latest) {
    final c = current.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final l = latest.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    for (int i = 0; i < 3; i++) {
      final cv = i < c.length ? c[i] : 0;
      final lv = i < l.length ? l[i] : 0;
      if (lv > cv) return true;
      if (lv < cv) return false;
    }
    return false;
  }

  /// 检查更新（从 OSS 配置中读取，无需额外网络请求）
  Future<Map<String, dynamic>> checkForUpdates() async {
    return checkForUpdatesWithFallback();
  }

  Future<Map<String, dynamic>> checkForUpdatesWithFallback() async {
    final updateConfig = XBoardConfig.updateConfig;
    if (updateConfig == null || updateConfig.isEmpty) {
      return {"hasUpdate": false};
    }

    final currentVersion = await getCurrentVersion();
    final platform = _getPlatformName();

    final platformInfo = updateConfig.platformInfo(platform);
    if (platformInfo == null || platformInfo.version.isEmpty) {
      return {"hasUpdate": false};
    }

    final hasUpdate = _isNewerVersion(currentVersion, platformInfo.version);

    // minVersion 强制更新逻辑：当前版本低于最低要求版本时强制更新
    final minVersion = updateConfig.minVersion ?? '';
    final belowMin =
        minVersion.isNotEmpty && _isNewerVersion(currentVersion, minVersion);
    final forceUpdate = platformInfo.force || belowMin;

    _logger.info(
      '更新检查: 当前=$currentVersion, 最新=${platformInfo.version}, '
      'hasUpdate=$hasUpdate, force=$forceUpdate',
    );

    return {
      "currentVersion": currentVersion,
      "latestVersion": platformInfo.version,
      "hasUpdate": hasUpdate,
      "updateUrl": platformInfo.url,
      "releaseNotes": updateConfig.changelog ?? "",
      "forceUpdate": forceUpdate,
    };
  }
}
