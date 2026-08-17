import 'dart:async';

import 'package:fl_clash/xboard/config/xboard_config.dart';
import 'package:fl_clash/xboard/core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/update_check_state.dart';
import '../services/update_cache_service.dart';
import '../services/update_service.dart';

final _logger = FileLogger('update_check_provider.dart');

final updateServiceProvider = Provider<UpdateService>((ref) => UpdateService());
final updateCacheServiceProvider =
    Provider<UpdateCacheService>((ref) => UpdateCacheService());

final updateCheckProvider =
    StateNotifierProvider<UpdateCheckNotifier, UpdateCheckState>((ref) {
  return UpdateCheckNotifier(
    updateService: ref.watch(updateServiceProvider),
    cacheService: ref.watch(updateCacheServiceProvider),
  );
});

class UpdateCheckNotifier extends StateNotifier<UpdateCheckState> {
  UpdateCheckNotifier({
    required UpdateService updateService,
    required UpdateCacheService cacheService,
  })  : _updateService = updateService,
        _cacheService = cacheService,
        super(const UpdateCheckState());

  final UpdateService _updateService;
  final UpdateCacheService _cacheService;
  Future<void>? _checkFuture;
  bool _interactiveCheckInFlight = false;

  bool get isInteractiveCheckInFlight => _interactiveCheckInFlight;

  Future<void> initialize() async {
    _logger.info('开始检查更新');
    await checkForUpdates();
  }

  Future<void> refresh() async {
    _logger.info('刷新检查更新');
    await checkForUpdates();
  }

  /// 在 OSS 返回前恢复上一次确认过的更新，只用于红点提示。
  Future<void> restoreCachedUpdate() async {
    final cached = await _cacheService.load();
    if (cached == null || !mounted) return;

    final currentVersion = await _updateService.getCurrentVersion();
    final currentPlatform = _updateService.getPlatformName();
    final isUsable = cached.platform == currentPlatform &&
        cached.latestVersion.isNotEmpty &&
        _updateService.isNewerVersion(
          currentVersion,
          cached.latestVersion,
        );
    if (!isUsable) {
      await _cacheService.clear();
      await _cacheService.clearPromptedOptionalVersion();
      return;
    }

    state = state.copyWith(
      hasUpdate: true,
      currentVersion: currentVersion,
      latestVersion: cached.latestVersion,
      updateUrl: cached.updateUrl,
      releaseNotes: cached.releaseNotes,
      // 缓存只恢复红点，强制更新必须由最新 OSS 配置重新确认。
      forceUpdate: false,
      error: null,
    );
    _logger.info('已从本地缓存恢复更新提示: ${cached.latestVersion}');
  }

  Future<void> checkForUpdates({
    bool refreshRemoteConfig = false,
    bool interactive = false,
  }) async {
    if (interactive) {
      _interactiveCheckInFlight = true;
      try {
        final existing = _checkFuture;
        if (existing != null) await existing;
        await _startCheck(refreshRemoteConfig: refreshRemoteConfig);
      } finally {
        _interactiveCheckInFlight = false;
      }
      return;
    }

    final existing = _checkFuture;
    if (existing != null) return existing;
    await _startCheck(refreshRemoteConfig: refreshRemoteConfig);
  }

  Future<void> _startCheck({required bool refreshRemoteConfig}) async {
    final future = _performCheck(refreshRemoteConfig: refreshRemoteConfig);
    _checkFuture = future;
    try {
      await future;
    } finally {
      if (identical(_checkFuture, future)) _checkFuture = null;
    }
  }

  Future<void> _performCheck({required bool refreshRemoteConfig}) async {
    if (!mounted) return;
    state = state.copyWith(isChecking: true, error: null);

    try {
      var configurationConfirmed = !refreshRemoteConfig;
      if (refreshRemoteConfig) {
        try {
          await XBoardConfig.refresh();
          configurationConfirmed = true;
        } catch (error) {
          _logger.warning('主动刷新更新配置失败，尝试使用当前有效配置: $error');
        }
      }

      final currentVersion = await _updateService.getCurrentVersion();
      _logger.info('当前版本: $currentVersion');
      if (mounted) state = state.copyWith(currentVersion: currentVersion);

      final updateInfo = await _updateService.checkForUpdatesWithFallback();
      if (!mounted) return;
      final hasUpdate = updateInfo['hasUpdate'] as bool? ?? false;
      final latestVersion = updateInfo['latestVersion']?.toString() ?? '';
      final updateUrl = updateInfo['updateUrl']?.toString() ?? '';
      final releaseNotes = updateInfo['releaseNotes']?.toString() ?? '';
      final forceUpdate = updateInfo['forceUpdate'] as bool? ?? false;

      if (!hasUpdate && !configurationConfirmed) {
        state = state.copyWith(
          isChecking: false,
          currentVersion: currentVersion,
          error: null,
        );
        _logger.warning('OSS 刷新失败，当前无更新结果不清除本地提示');
        return;
      }

      state = state.copyWith(
        isChecking: false,
        hasUpdate: hasUpdate,
        latestVersion: latestVersion,
        updateUrl: updateUrl,
        releaseNotes: releaseNotes,
        forceUpdate: forceUpdate,
        error: null,
      );

      if (hasUpdate) {
        await _cacheService.save(
          CachedUpdateInfo(
            platform: _updateService.getPlatformName(),
            currentVersion: currentVersion,
            latestVersion: latestVersion,
            updateUrl: updateUrl,
            releaseNotes: releaseNotes,
            forceUpdate: forceUpdate,
            checkedAt: DateTime.now(),
          ),
        );
        _logger.info('发现新版本并保存本地提示: $latestVersion');
      } else if (configurationConfirmed) {
        await _cacheService.clear();
        await _cacheService.clearPromptedOptionalVersion();
        _logger.info('已是最新版本，清除本地更新提示');
      }
    } catch (error) {
      if (!mounted) return;
      _logger.error('检查更新失败', error);
      // 暂时失败时保留从缓存恢复的 hasUpdate 与版本信息。
      state = state.copyWith(
        isChecking: false,
        error: error.toString(),
      );
    }
  }
}
