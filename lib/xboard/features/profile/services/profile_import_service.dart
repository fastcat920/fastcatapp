import 'package:fl_clash/security/local_test_profile_scope.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/xboard/features/settings/utils/account_routing_store.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/clash/clash.dart';
import 'package:fl_clash/xboard/features/auth/providers/session_epoch_provider.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:fl_clash/common/common.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/xboard/features/profile/profile.dart';
import 'package:fl_clash/xboard/features/subscription/services/encrypted_subscription_service.dart';
import 'package:fl_clash/xboard/features/subscription/services/subscription_downloader.dart';
import 'package:fl_clash/xboard/features/subscription/utils/utils.dart';
import 'package:fl_clash/xboard/core/core.dart';
import 'package:fl_clash/xboard/config/utils/config_file_loader.dart';
import 'package:fl_clash/xboard/features/connectivity/connectivity.dart';
import 'package:fl_clash/security/profile_vault.dart';
import 'package:fl_clash/security/profile_retention.dart';

// 初始化文件级日志器
final _logger = FileLogger('profile_import_service.dart');

final xboardProfileImportServiceProvider =
    Provider<XBoardProfileImportService>((ref) {
  return XBoardProfileImportService(ref);
});

class XBoardProfileImportService {
  final Ref _ref;
  bool _isImporting = false;
  Completer<void>? _importDone;
  Future<void>? _cancelAndWaitFuture;
  final Future<ImportResult> Function(SubscriptionDownloadCancelToken)?
      _importForTesting;
  SubscriptionDownloadCancelToken? _downloadCancelToken;
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);
  XBoardProfileImportService(this._ref) : _importForTesting = null;

  @visibleForTesting
  XBoardProfileImportService.forTesting(
    this._ref, {
    required Future<ImportResult> Function(SubscriptionDownloadCancelToken)
        importOperation,
  }) : _importForTesting = importOperation;

  bool get hasPendingImport => _importDone != null;
  Future<ImportResult> importSubscription(
    String url, {
    bool backgroundAccountSync = false,
    Function(ImportStatus, double, String?)? onProgress,
  }) async {
    if (_isImporting || _cancelAndWaitFuture != null) {
      return ImportResult.failure(
        errorMessage: '正在导入中，请稍候',
        errorType: ImportErrorType.concurrentImport,
      );
    }
    _isImporting = true;
    final importDone = Completer<void>();
    _importDone = importDone;
    final cancelToken = SubscriptionDownloadCancelToken();
    _downloadCancelToken = cancelToken;
    final stopwatch = Stopwatch()..start();
    try {
      final testOperation = _importForTesting;
      if (testOperation != null) return await testOperation(cancelToken);
      _logger.info('开始导入订阅配置: ${SensitiveMasker.maskUrl(url)}');

      // 1. 先下载并验证新配置（不删除旧配置）
      onProgress?.call(ImportStatus.downloading, 0.3,
          appLocalizations.xboardDownloadingConfig);

      // 用户配置属于本地状态，订阅刷新只能替换远端内容，不能把节点选择
      // 或自定义分流一并覆盖掉。
      final epoch = _ref.read(sessionEpochProvider);
      final active = _ref.read(currentProfileProvider);
      final oldProfile =
          keepSelectedSubscription(active, accountSync: backgroundAccountSync)
              ? latestAccountProfileForUrl(_ref.read(profilesProvider), url)
              : active;
      final oldSelectedMap = oldProfile?.type == ProfileType.url
          ? scopedProfileSelections(
              oldProfile?.id, oldProfile?.selectedMap ?? {})
          : <String, String>{};
      final oldOverrideData = oldProfile?.overrideData;
      final routingAccount = _ref.read(userInfoProvider)?.uuid ?? '';
      void checkOwner() {
        _throwIfCancelled(cancelToken);
        if (_ref.read(sessionEpochProvider) != epoch ||
            (_ref.read(userInfoProvider)?.uuid ?? '') != routingAccount) {
          throw StateError('Account changed during import');
        }
      }

      final savedRules = await AccountRoutingStore.load(routingAccount);

      final connectivity = _ref.read(serviceConnectivityProvider);
      if (connectivity.isOffline) {
        throw const SocketException('当前处于离线模式');
      }
      final downloadTimeout = connectivity.isOnline
          ? const Duration(seconds: 20)
          : const Duration(seconds: 10);
      final profile = await _downloadAndValidateProfile(
        url,
        cancelToken: cancelToken,
      ).timeout(downloadTimeout, onTimeout: () {
        _downloadCancelToken?.cancel();
        throw TimeoutException('订阅下载超时', downloadTimeout);
      });
      onProgress?.call(ImportStatus.validating, 0.6,
          appLocalizations.xboardValidatingConfigFormat);
      _throwIfCancelled(cancelToken);

      // 继承旧的节点选择与自定义分流，避免刷新订阅后本地规则丢失。
      final profileWithSelection = profile.copyWith(
        selectedMap:
            oldSelectedMap.isNotEmpty ? oldSelectedMap : profile.selectedMap,
        overrideData: savedRules == null
            ? oldOverrideData ?? profile.overrideData
            : (oldOverrideData ?? profile.overrideData).copyWith(
                enable: (oldOverrideData ?? profile.overrideData).enable ||
                    savedRules.isNotEmpty,
                rule: (oldOverrideData ?? profile.overrideData).rule.copyWith(
                    type: OverrideRuleType.added, addedRules: savedRules)),
      );

      // 2. 先添加新配置（保持 groups 非空，VPN 不断线）
      onProgress?.call(
          ImportStatus.adding, 0.8, appLocalizations.xboardAddingToConfigList);
      _throwIfCancelled(cancelToken);
      final committed =
          await globalState.appController.runProfileImport(() async {
        checkOwner();
        // Re-check after the download, under the same lock as a user selection.
        if (keepSelectedSubscription(_ref.read(currentProfileProvider),
            accountSync: backgroundAccountSync)) {
          final previous =
              latestAccountProfileForUrl(_ref.read(profilesProvider), url);
          var keepId = false;
          try {
            final yaml = await ProfileVault.instance.readText(profile.id);
            final error = await clashCore.validateConfig(yaml);
            if (error.isNotEmpty) {
              throw const FormatException('Invalid account profile');
            }
            checkOwner();
            final cache = previous == null
                ? profile
                : previous.copyWith(
                    lastUpdateDate: profile.lastUpdateDate,
                    subscriptionInfo: profile.subscriptionInfo,
                  );
            if (cache.id != profile.id) {
              await ProfileVault.instance
                  .copyDownloadedProfile(profile.id, cache.id);
            }
            checkOwner();
            _ref.read(profilesProvider.notifier).setProfile(cache);
            keepId = cache.id == profile.id;
            // An inactive refresh owns its staging file only. The active-account
            // import handles retention after a successful configuration switch.
            return cache;
          } finally {
            if (!keepId &&
                !_ref.read(profilesProvider).any((p) => p.id == profile.id)) {
              await _clearProfileFiles(profile.id);
            }
          }
        }
        final rollbackSnapshot = _ProfileImportSnapshot.capture(_ref);
        try {
          _throwIfCancelled(cancelToken);
          await _addProfile(profileWithSelection);
          _throwIfCancelled(cancelToken);
        } catch (_) {
          await _rollbackProfileImport(
            rollbackSnapshot,
            candidateProfileId: profileWithSelection.id,
          );
          rethrow;
        }

        // Only prune after acknowledgement, while the import still owns the
        // operation lock. Never wrap application in a shorter UI timeout.
        onProgress?.call(ImportStatus.cleaning, 0.95,
            appLocalizations.xboardCleaningOldConfig);
        await _pruneOldUrlProfiles(profile.id);
        _logProfileDiff(
          rollbackSnapshot.profiles,
          _ref.read(profilesProvider),
        );
        return profileWithSelection;
      });

      stopwatch.stop();
      onProgress?.call(
          ImportStatus.success, 1.0, appLocalizations.xboardImportSuccess);
      _logger.info('订阅配置导入成功，耗时: ${stopwatch.elapsedMilliseconds}ms');
      return ImportResult.success(
        profile: committed,
        duration: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      _logger.error('订阅配置导入失败', e);
      final errorType = _classifyError(e);
      final userMessage = _getUserFriendlyErrorMessage(e, errorType);
      onProgress?.call(ImportStatus.failed, 0.0, userMessage);
      return ImportResult.failure(
        errorMessage: userMessage,
        errorType: errorType,
        duration: stopwatch.elapsed,
      );
    } finally {
      if (identical(_downloadCancelToken, cancelToken)) {
        _downloadCancelToken = null;
      }
      _isImporting = false;
      if (identical(_importDone, importDone)) _importDone = null;
      importDone.complete();
    }
  }

  void cancelCurrentImport() {
    _downloadCancelToken?.cancel();
  }

  /// Wait for native application AND its rollback. Cancelling the download or
  /// hiding progress is not proof that a configuration operation has finished.
  Future<void> cancelCurrentImportAndWait() {
    final pending = _cancelAndWaitFuture;
    if (pending != null) return pending;
    final completion = _importDone?.future;
    cancelCurrentImport();
    if (completion == null) return Future.value();
    return _cancelAndWaitFuture = completion.whenComplete(() {
      _cancelAndWaitFuture = null;
    });
  }

  void _throwIfCancelled(SubscriptionDownloadCancelToken cancelToken) {
    if (cancelToken.isCancelled) {
      throw Exception('任务已取消');
    }
  }

  Future<ImportResult> importSubscriptionWithRetry(
    String url, {
    Function(ImportStatus, double, String?)? onProgress,
    int retries = maxRetries,
  }) async {
    for (int attempt = 1; attempt <= retries; attempt++) {
      _logger.debug('导入尝试 $attempt/$retries');
      final result = await importSubscription(url, onProgress: onProgress);
      if (result.isSuccess) {
        return result;
      }
      if (result.errorType != ImportErrorType.networkError &&
          result.errorType != ImportErrorType.downloadError) {
        return result;
      }
      if (attempt == retries) {
        return result;
      }
      _logger.debug('等待 ${retryDelay.inSeconds} 秒后重试');
      onProgress?.call(
          ImportStatus.downloading, 0.0, '第 $attempt 次尝试失败，等待重试...');
      await Future.delayed(retryDelay);
    }
    return ImportResult.failure(
      errorMessage: '多次重试后仍然失败',
      errorType: ImportErrorType.networkError,
    );
  }

  /// 清理旧的 URL 配置，保留当前配置与最近两份成功快照。
  /// 必须在 _addProfile() 之后调用，这样新配置已成为当前配置，
  /// 删除旧配置不会导致 groups 短暂为空或 VPN 断线。
  Future<void> _pruneOldUrlProfiles(String keepId) async {
    try {
      final plan = buildProfileRetentionPlan(
        _ref.read(profilesProvider),
        activeProfileId: keepId,
      );
      _ref.read(profilesProvider.notifier).value = plan.profiles;

      for (final profile in plan.removedProfiles) {
        _logger.debug('删除过期URL配置: ${profile.label ?? profile.id}');
        await _clearProfileFiles(profile.id);
      }

      final retainedIds = plan.profiles.map((profile) => profile.id).toSet();
      final orphanCount = await ProfileVault.instance.pruneOrphanedProfiles(
          retainedIds,
          minimumOrphanAge: const Duration(hours: 1));
      _logger.info(
        '订阅缓存清理完成: 删除配置=${plan.removedProfiles.length}, '
        '删除孤儿项=$orphanCount, 最多保留=$subscriptionProfileRetentionLimit',
      );
    } catch (e) {
      _logger.warning('清理旧配置时出错', e);
      // 新配置已经成功应用。缓存清理属于维护操作，失败不能把本次
      // 订阅刷新标记为失败，也不能触发对可用配置的回滚。
    }
  }

  Future<void> _rollbackProfileImport(
    _ProfileImportSnapshot snapshot, {
    required String candidateProfileId,
  }) async {
    _logger.warning('新订阅 apply 失败，回滚到上一份可用配置');
    _ref.read(profilesProvider.notifier).value = snapshot.profiles;
    _ref.read(currentProfileIdProvider.notifier).value =
        snapshot.currentProfileId;
    _ref.read(groupsProvider.notifier).value = snapshot.groups;
    final controller = globalState.appController;
    try {
      if (snapshot.currentProfileId == null) {
        await controller.stopAfterConfigurationFailure();
      } else {
        // Restore the native configuration too, not just the cached UI list.
        await controller.applyProfile(silence: true);
        if (snapshot.wasConnected) await controller.restoreProfileConnection();
      }
    } catch (error) {
      _logger.warning('上一份配置恢复失败，停止连接', error);
      await controller.stopAfterConfigurationFailure();
    }
    await _clearProfileFiles(candidateProfileId);
  }

  Future<void> _clearProfileFiles(String profileId) async {
    try {
      await ProfileVault.instance.delete(profileId);
      await ProfileVault.instance.removeProviders(profileId);
    } catch (e) {
      _logger.warning('清理候选配置文件失败', e);
    }
  }

  void _logProfileDiff(List<Profile> before, List<Profile> after) {
    final beforeIds = before.map((item) => item.id).toSet();
    final afterIds = after.map((item) => item.id).toSet();
    final added = afterIds.difference(beforeIds);
    final removed = beforeIds.difference(afterIds);
    final kept = afterIds.intersection(beforeIds);
    _logger.info(
      '订阅配置 diff: added=${added.length}, removed=${removed.length}, kept=${kept.length}',
    );
  }

  Future<Profile> _downloadAndValidateProfile(
    String url, {
    required SubscriptionDownloadCancelToken cancelToken,
  }) async {
    final sw = Stopwatch()..start();
    try {
      _logger.info('🚀 [0ms] 开始下载配置: ${SensitiveMasker.maskUrl(url)}');

      // 先检查用户配置是否禁用了加密订阅
      final preferEncrypt = await ConfigFileLoaderHelper.getPreferEncrypt();

      // 用户启用加密，检查URL是否需要使用加密订阅服务
      if (preferEncrypt &&
          SubscriptionUrlHelper.shouldUseEncryptedService(url)) {
        _logger.info('🔐 [${sw.elapsedMilliseconds}ms] 检测到加密订阅URL，使用加密解密服务');
        _throwIfCancelled(cancelToken);
        return await _downloadEncryptedProfile(url);
      }

      // 使用 XBoard 订阅下载服务（直连，跳过 validateConfig IPC）
      _logger.info('📄 [${sw.elapsedMilliseconds}ms] 开始 HTTP 下载（直连，90s超时）...');
      final profile = await SubscriptionDownloader.downloadSubscription(
        url,
        cancelToken: cancelToken,
      );

      _logger.info(
          '✅ [${sw.elapsedMilliseconds}ms] 配置下载完成: ${profile.label ?? profile.id}');
      return profile;
    } on TimeoutException catch (e) {
      throw Exception('下载超时: ${e.message}');
    } on SocketException catch (e) {
      throw Exception('网络连接失败: ${e.message}');
    } on HttpException catch (e) {
      throw Exception('HTTP请求失败: ${e.message}');
    } catch (e) {
      if (e.toString().contains('validateConfig')) {
        throw Exception('配置文件格式错误: $e');
      }
      throw Exception('下载配置失败: $e');
    }
  }

  /// 下载加密的订阅配置
  Future<Profile> _downloadEncryptedProfile(String url) async {
    try {
      _logger.info('📦 开始下载加密订阅配置流程');
      _logger.debug('🔗 目标URL: ${SensitiveMasker.maskUrl(url)}');

      // 从本地配置读取订阅偏好设置（竞速自动跟随加密选项）
      final preferEncrypt = await ConfigFileLoaderHelper.getPreferEncrypt();

      _logger.info(
          '📝 本地配置: preferEncrypt=$preferEncrypt (竞速: ${preferEncrypt ? "启用" : "禁用"})');

      // 优先从登录数据获取token，如果失败再从URL解析
      String? token;
      SubscriptionResult result;

      try {
        _logger.debug('🔑 尝试从登录数据获取token');
        result = await EncryptedSubscriptionService.getSubscriptionSmart(
          null,
          preferEncrypt: preferEncrypt,
          enableRace: preferEncrypt, // 竞速自动等于加密选项
        );

        if (!result.success) {
          // 如果从登录数据获取失败，尝试从URL提取token
          _logger.warning('⚠️ 从登录数据获取失败，尝试从URL提取token: ${result.error}');
          token = SubscriptionUrlHelper.extractTokenFromUrl(url);
          if (token == null) {
            throw Exception('无法从URL中提取token且登录数据获取失败: $url');
          }

          _logger.debug('🔑 已从订阅 URL 提取认证令牌');
          result = await EncryptedSubscriptionService.getSubscriptionSmart(
            token,
            preferEncrypt: preferEncrypt,
            enableRace: preferEncrypt, // 竞速自动等于加密选项
          );
        } else {
          _logger.info('✅ 成功从登录数据获取订阅');
        }
      } catch (e) {
        // 最后的fallback：从URL提取token
        _logger.warning('⚠️ 登录方式失败，fallback到URL解析', e);
        token = SubscriptionUrlHelper.extractTokenFromUrl(url);
        if (token == null) {
          throw Exception('所有token获取方式都失败: $url');
        }

        _logger.debug('🔄 Fallback - 已从订阅 URL 提取认证令牌');
        result = await EncryptedSubscriptionService.getSubscriptionSmart(
          token,
          preferEncrypt: preferEncrypt,
          enableRace: preferEncrypt, // 竞速自动等于加密选项
        );
      }

      if (!result.success) {
        throw Exception('加密订阅获取失败: ${result.error}');
      }

      _logger.info('🎉 加密订阅获取成功！加密模式: ${result.encryptionUsed}');
      if (result.keyUsed != null) {
        _logger.debug('🔑 已使用当前有效密钥完成订阅解密');
      }

      // 验证解密后的配置内容
      _logger.debug('📄 验证解密后的配置内容，长度: ${result.content!.length}');
      if (result.content!.trim().isEmpty) {
        throw Exception('解密后的配置内容为空');
      }

      // 记录配置内容的基本统计信息
      final lines = result.content!.split('\n');
      final nonEmptyLines =
          lines.where((line) => line.trim().isNotEmpty).length;
      _logger.debug('📄 配置内容统计: 总行数 ${lines.length}, 非空行数 $nonEmptyLines');

      // 移除冗余的格式检查，让ClashMeta核心进行权威验证
      _logger.debug('⚡ 跳过客户端格式验证，将由ClashMeta核心进行权威验证');

      // 保存至设备密钥保护的本地 vault，跳过 validateConfig IPC（桌面端 ClashCore.exe 未就绪时等 30s）
      _logger.debug('💾 写入加密本地配置缓存（跳过 validateConfig IPC）...');
      final profile = Profile.normal(url: url);
      if (result.encryptedEnvelope != null) {
        await ProfileVault.instance.writeEncryptedEnvelope(
          profile.id,
          result.encryptedEnvelope!,
        );
      } else {
        await ProfileVault.instance.writeText(profile.id, result.content!);
      }
      final profileWithContent =
          profile.copyWith(lastUpdateDate: DateTime.now());
      _logger.info('✅ 加密配置内容已写入，格式验证由 applyProfile 阶段完成');

      // 获取订阅信息并更新Profile
      _logger.info('📊 开始获取加密订阅的订阅信息...');
      final subscriptionInfo =
          await ProfileSubscriptionInfoService.instance.getSubscriptionInfo(
        subscriptionUserInfo: result.subscriptionUserInfo,
      );
      _logger.info(
          '📊 Profile订阅信息获取完成: upload=${subscriptionInfo.upload}, download=${subscriptionInfo.download}, total=${subscriptionInfo.total}');

      // 返回带有订阅信息的Profile
      final updatedProfile = profileWithContent.copyWith(
        subscriptionInfo: subscriptionInfo,
      );

      _logger.info(
          '🎉 加密配置验证和保存成功！最终Profile订阅信息: ${updatedProfile.subscriptionInfo}');
      _logger.debug('✅ 完整的加密订阅处理流程已成功完成');
      return updatedProfile;
    } catch (e) {
      _logger.error('💥 加密配置下载失败', e);
      _logger.debug('❌ 加密订阅处理流程异常终止');
      throw Exception('加密订阅处理失败: $e');
    }
  }

  Future<void> _addProfile(Profile profile) async {
    // An import may have started before the user activated a local test.
    if (isLocalFastCatProfile(_ref.read(currentProfileIdProvider))) {
      throw StateError('Local test configuration is active');
    }
    final sw = Stopwatch()..start();
    try {
      // 1. 添加配置到列表
      _ref.read(profilesProvider.notifier).setProfile(profile);
      _logger.info(
          '✅ [${sw.elapsedMilliseconds}ms] Profile 已加入列表: ${profile.label ?? profile.id}');

      // runProfileImport owns the listener guard through apply AND rollback.
      // 2. 强制设置为当前配置（订阅导入是用户主动操作，应该立即生效）
      final currentProfileIdNotifier =
          _ref.read(currentProfileIdProvider.notifier);
      currentProfileIdNotifier.value = profile.id;
      _logger.info(
          '✅ [${sw.elapsedMilliseconds}ms] currentProfileId 已设置: ${profile.id}');

      // 4. 同步等待 applyProfile 完成（与 Orange 一致）
      // 必须 await，否则后续的 _pruneOldUrlProfiles 可能在 applyProfile 完成前执行，
      // 导致竞态条件：旧配置被删除但新配置尚未加载，用户看到空白节点列表。
      _logger.info(
          '📋 [${sw.elapsedMilliseconds}ms] 开始 await applyProfile(silence: true)...');
      try {
        await globalState.appController.applyProfile(silence: true);
        _logger.info('✅ [${sw.elapsedMilliseconds}ms] applyProfile 完成');

        // 检查节点是否已加载
        final groups = _ref.read(groupsProvider);
        _logger.info('📊 当前 groups 数量: ${groups.length}');
        if (groups.isEmpty) {
          _logger.warning('⚠️ applyProfile 完成但 groups 为空，尝试延迟重试...');
          // 等待一段时间后重试一次（适配 Windows 便携版 ClashCore 慢启动）
          await Future.delayed(const Duration(seconds: 5));
          await globalState.appController.applyProfile(silence: true);
          final retryGroups = _ref.read(groupsProvider);
          _logger.info('📊 重试后 groups 数量: ${retryGroups.length}');
          if (retryGroups.isEmpty) {
            throw Exception('新订阅应用后节点组仍为空');
          }
        }
      } catch (e) {
        _logger.error('❌ applyProfile 失败', e);
        // 必须抛出异常！否则后续 _pruneOldUrlProfiles 会删除旧配置，
        // 导致旧配置被清除、新配置未加载成功 → 用户看到空白节点列表。
        // 配置文件已保存在磁盘，下次启动时会自动加载。
        throw Exception('applyProfile 失败: $e');
      }

      _logger.info(
          '✅ [${sw.elapsedMilliseconds}ms] _addProfile 完成: ${profile.label ?? profile.id}');
    } catch (e) {
      throw Exception('添加配置失败: $e');
    }
  }

  ImportErrorType _classifyError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    if (errorString.contains('timeout') ||
        errorString.contains('连接失败') ||
        errorString.contains('network')) {
      return ImportErrorType.networkError;
    }
    if (errorString.contains('下载') ||
        errorString.contains('http') ||
        errorString.contains('响应')) {
      return ImportErrorType.downloadError;
    }
    if (errorString.contains('validateconfig') ||
        errorString.contains('格式错误') ||
        errorString.contains('解析') ||
        errorString.contains('配置文件格式错误') ||
        errorString.contains('clash配置') ||
        errorString.contains('invalid config')) {
      return ImportErrorType.validationError;
    }
    if (errorString.contains('存储') ||
        errorString.contains('文件') ||
        errorString.contains('保存')) {
      return ImportErrorType.storageError;
    }
    return ImportErrorType.unknownError;
  }

  String _getUserFriendlyErrorMessage(
      dynamic error, ImportErrorType errorType) {
    return ImportState(
            lastResult: ImportResult.failure(
          errorMessage: '',
          errorType: errorType,
        )).errorTypeMessage ??
        appLocalizations.xboardImportFailed;
  }

  bool get isImporting => _isImporting;
}

class _ProfileImportSnapshot {
  const _ProfileImportSnapshot({
    required this.profiles,
    required this.currentProfileId,
    required this.groups,
    required this.wasConnected,
  });

  final List<Profile> profiles;
  final String? currentProfileId;
  final List<Group> groups;
  final bool wasConnected;

  factory _ProfileImportSnapshot.capture(Ref ref) {
    return _ProfileImportSnapshot(
      profiles: List<Profile>.from(ref.read(profilesProvider)),
      currentProfileId: ref.read(currentProfileIdProvider),
      groups: List<Group>.from(ref.read(groupsProvider)),
      wasConnected: ref.read(runTimeProvider) != null,
    );
  }
}
