import '../models/update_artifact.dart';
import 'linux_update_package_selector.dart';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:fl_clash/xboard/core/core.dart';
import 'package:fl_clash/xboard/config/xboard_config.dart';
import 'package:package_info_plus/package_info_plus.dart';

// 初始化文件级日志器
final _logger = FileLogger('update_service.dart');

class UpdateConfigurationUnavailableException implements Exception {
  const UpdateConfigurationUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}

class UpdateService {
  UpdateService(
      {String Function()? languageCodeProvider,
      Future<String?> Function()? linuxPackageTypeProvider,
      List<String> Function()? architectureProvider})
      : _languageCodeProvider = languageCodeProvider ??
            (() => PlatformDispatcher.instance.locale.languageCode),
        _linuxPackageTypeProvider =
            linuxPackageTypeProvider ?? LinuxUpdatePackageSelector().detect,
        _architectureProvider =
            architectureProvider ?? (() => UpdateArtifact.architectureKeys());

  final String Function() _languageCodeProvider;
  final Future<String?> Function() _linuxPackageTypeProvider;
  final List<String> Function() _architectureProvider;

  Future<UpdateArtifact?> selectArtifact(
      UpdatePlatformInfo info, String platform) async {
    final architectures = _architectureProvider();
    if (platform == 'linux') {
      final architecture = architectures.contains('x64')
          ? 'x64'
          : architectures.contains('arm64')
              ? 'arm64'
              : null;
      if (architecture == null) return null;
      final type = await _linuxPackageTypeProvider();
      if (type != 'deb' && type != 'rpm') return null;
      final artifact = info.artifacts['${architecture}_$type'];
      return artifact?.type == type ? artifact : null;
    }
    if (platform == 'windows') {
      if (!architectures.contains('x64') && !architectures.contains('arm64')) {
        return null;
      }
      return info.artifacts['universal'];
    }
    return info.artifactFor(architectures);
  }

  Future<String> getCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  Future<int> getCurrentBuild() async {
    // Split APK manifest codes include an ABI offset. Compare the original
    // Flutter build number used by OSS, not the per-ABI installer version code.
    if (Platform.isAndroid) {
      try {
        final build = await const MethodChannel('fastcat/update')
            .invokeMethod<int>('getBuild');
        if (build != null) return build;
      } on PlatformException catch (_) {
      } on MissingPluginException catch (_) {}
    }
    return int.tryParse((await PackageInfo.fromPlatform()).buildNumber) ?? 0;
  }

  bool hasNewRelease(
          String current, String latest, int currentBuild, int? build) =>
      isNewerVersion(current, latest) ||
      (!isNewerVersion(latest, current) &&
          !isNewerVersion(current, latest) &&
          (build ?? 0) > currentBuild);

  String getPlatformName() {
    if (Platform.isAndroid) return "android";
    if (Platform.isIOS) return "ios";
    if (Platform.isWindows) return "windows";
    if (Platform.isMacOS) return "macos";
    if (Platform.isLinux) return "linux";
    return "unknown";
  }

  /// 比较语义版本，返回 latest > current
  bool isNewerVersion(String current, String latest) {
    List<int> parse(String value) {
      final normalized = value
          .trim()
          .replaceFirst(RegExp(r'^[vV]'), '')
          .split(RegExp(r'[+-]'))
          .first;
      return normalized
          .split('.')
          .map((part) => int.tryParse(part) ?? 0)
          .toList();
    }

    final c = parse(current);
    final l = parse(latest);
    for (int i = 0; i < 3; i++) {
      final cv = i < c.length ? c[i] : 0;
      final lv = i < l.length ? l[i] : 0;
      if (lv > cv) return true;
      if (lv < cv) return false;
    }
    return false;
  }

  bool shouldForceUpdate({
    required String currentVersion,
    required String latestVersion,
    required bool platformForce,
    String minimumVersion = '',
  }) {
    final hasUpdate = isNewerVersion(currentVersion, latestVersion);
    final belowMinimum = minimumVersion.isNotEmpty &&
        isNewerVersion(currentVersion, minimumVersion);
    return hasUpdate && (platformForce || belowMinimum);
  }

  /// 检查更新（从 OSS 配置中读取，无需额外网络请求）
  Future<Map<String, dynamic>> checkForUpdates() async {
    return checkForUpdatesWithFallback();
  }

  Future<Map<String, dynamic>> checkForUpdatesWithFallback() async {
    final updateConfig = XBoardConfig.updateConfig;
    if (updateConfig == null || updateConfig.isEmpty) {
      throw const UpdateConfigurationUnavailableException(
        'Update configuration is not ready',
      );
    }

    final currentVersion = await getCurrentVersion();
    final platform = getPlatformName();

    final platformInfo = updateConfig.platformInfo(platform);
    if (platformInfo == null) {
      throw UpdateConfigurationUnavailableException(
        'Update configuration is unavailable for $platform',
      );
    }

    if (!platformInfo.enabled) {
      _logger.info('更新检查: $platform 已在远程配置中停用');
      return {
        "currentVersion": currentVersion,
        "latestVersion": platformInfo.version,
        "hasUpdate": false,
        "updateUrl": platformInfo.resolvedUrl,
        "releaseNotes": '',
        "forceUpdate": false,
      };
    }
    if (platformInfo.version.isEmpty) {
      throw UpdateConfigurationUnavailableException(
        'Latest version is unavailable for $platform',
      );
    }

    final currentBuild = await getCurrentBuild();
    final hasUpdate = hasNewRelease(
        currentVersion, platformInfo.version, currentBuild, platformInfo.build);
    final candidate = await selectArtifact(platformInfo, platform);
    final artifact = candidate != null &&
            candidate.supportsPlatform(platform) &&
            candidate.isValid
        ? candidate
        : null;

    final updateUrl = platform == 'ios'
        ? platformInfo.storeUrl
        : artifact?.url ?? platformInfo.resolvedUrl;
    if (hasUpdate && updateUrl.isEmpty) {
      throw UpdateConfigurationUnavailableException(
        'Update URL is unavailable for $platform',
      );
    }

    // Minimum version is independent for each platform.
    final minVersion = platformInfo.minSupportedVersion ?? '';
    // force 只控制“已发现的新版本”是否允许跳过，不能让旧版本配置
    // 对一个更新的客户端反向弹出强制更新。
    final actionable =
        platform == 'ios' ? platformInfo.storeUrl.isNotEmpty : artifact != null;
    final forceUpdate = actionable &&
        XBoardConfig.remoteConfigConfirmed &&
        (shouldForceUpdate(
              currentVersion: currentVersion,
              latestVersion: platformInfo.version,
              platformForce: platformInfo.force,
              minimumVersion: minVersion,
            ) ||
            (hasUpdate && platformInfo.force) ||
            (hasUpdate &&
                currentBuild < (platformInfo.minSupportedBuild ?? 0)));

    _logger.info(
      '更新检查: 当前=$currentVersion, 最新=${platformInfo.version}, '
      'hasUpdate=$hasUpdate, force=$forceUpdate',
    );

    return {
      "currentVersion": currentVersion,
      "latestVersion": platformInfo.version,
      "artifact": artifact,
      "build": platformInfo.build,
      "trusted": XBoardConfig.remoteConfigConfirmed,
      "hasUpdate": hasUpdate,
      "updateUrl": updateUrl,
      "releaseNotes": updateConfig.localizedChangelog(
        platform,
        _languageCodeProvider(),
      ),
      "forceUpdate": forceUpdate,
    };
  }
}
