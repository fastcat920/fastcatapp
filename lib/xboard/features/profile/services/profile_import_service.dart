import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/xboard/features/profile/profile.dart';
import 'package:fl_clash/xboard/features/subscription/services/encrypted_subscription_service.dart';
import 'package:fl_clash/xboard/features/subscription/services/subscription_downloader.dart';
import 'package:fl_clash/xboard/features/subscription/utils/utils.dart';
import 'package:fl_clash/xboard/core/core.dart';
import 'package:fl_clash/xboard/config/utils/config_file_loader.dart';

// 初始化文件级日志器
final _logger = FileLogger('profile_import_service.dart');

final xboardProfileImportServiceProvider = Provider<XBoardProfileImportService>((ref) {
  return XBoardProfileImportService(ref);
});
class XBoardProfileImportService {
  final Ref _ref;
  bool _isImporting = false;
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);
  static const Duration downloadTimeout = Duration(seconds: 90);
  XBoardProfileImportService(this._ref);
  Future<ImportResult> importSubscription(
    String url, {
    Function(ImportStatus, double, String?)? onProgress,
  }) async {
    if (_isImporting) {
      return ImportResult.failure(
        errorMessage: '正在导入中，请稍候',
        errorType: ImportErrorType.unknownError,
      );
    }
    _isImporting = true;
    final stopwatch = Stopwatch()..start();
    try {
      _logger.info('开始导入订阅配置: $url');

      // 1. 先下载并验证新配置（不删除旧配置）
      onProgress?.call(ImportStatus.downloading, 0.3, '下载配置文件');

      // 保存当前 profile 的节点选择，导入后继承，防止节点刷新后重置为 DIRECT
      final oldSelectedMap = _ref.read(currentProfileProvider)?.selectedMap ?? {};

      final profile = await _downloadAndValidateProfile(url);
      onProgress?.call(ImportStatus.validating, 0.6, '验证配置格式');

      // 继承旧的节点选择，避免刷新后丢失用户选择
      final profileWithSelection = oldSelectedMap.isNotEmpty
          ? profile.copyWith(selectedMap: oldSelectedMap)
          : profile;

      // 2. 先添加新配置（保持 groups 非空，VPN 不断线）
      onProgress?.call(ImportStatus.adding, 0.8, '应用新配置');
      await _addProfile(profileWithSelection);

      // 3. 再清理旧配置（新配置已就绪，安全删除旧的）
      onProgress?.call(ImportStatus.cleaning, 0.95, '清理旧配置');
      await _cleanOldUrlProfilesExcept(profile.id);
      
      stopwatch.stop();
      onProgress?.call(ImportStatus.success, 1.0, '导入成功');
      _logger.info('订阅配置导入成功，耗时: ${stopwatch.elapsedMilliseconds}ms');
      return ImportResult.success(
        profile: profile,
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
      _isImporting = false;
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
      onProgress?.call(ImportStatus.downloading, 0.0, '第 $attempt 次尝试失败，等待重试...');
      await Future.delayed(retryDelay);
    }
    return ImportResult.failure(
      errorMessage: '多次重试后仍然失败',
      errorType: ImportErrorType.networkError,
    );
  }
  /// 清理旧的 URL 配置，保留指定 ID 的新配置。
  /// 必须在 _addProfile() 之后调用，这样新配置已成为当前配置，
  /// 删除旧配置不会导致 groups 短暂为空或 VPN 断线。
  Future<void> _cleanOldUrlProfilesExcept(String keepId) async {
    try {
      final profiles = globalState.config.profiles;
      final oldProfiles = profiles
          .where((p) => p.type == ProfileType.url && p.id != keepId)
          .toList();

      for (final profile in oldProfiles) {
        _logger.debug('删除旧的URL配置: ${profile.label ?? profile.id}');
        _ref.read(profilesProvider.notifier).deleteProfileById(profile.id);
        // 不调用 _clearProfileEffect：当前配置已是新 profile，旧的 id 不影响 VPN
      }

      _logger.info('清理了 ${oldProfiles.length} 个旧的URL配置（保留: $keepId）');
    } catch (e) {
      _logger.warning('清理旧配置时出错', e);
      throw Exception('清理旧配置失败: $e');
    }
  }
  Future<Profile> _downloadAndValidateProfile(String url) async {
    final sw = Stopwatch()..start();
    try {
      _logger.info('🚀 [0ms] 开始下载配置: $url');

      // 先检查用户配置是否禁用了加密订阅
      final preferEncrypt = await ConfigFileLoaderHelper.getPreferEncrypt();

      // 用户启用加密，检查URL是否需要使用加密订阅服务
      if (preferEncrypt && SubscriptionUrlHelper.shouldUseEncryptedService(url)) {
        _logger.info('🔐 [${sw.elapsedMilliseconds}ms] 检测到加密订阅URL，使用加密解密服务');
        return await _downloadEncryptedProfile(url);
      }

      // 使用 XBoard 订阅下载服务（直连，跳过 validateConfig IPC）
      _logger.info('📄 [${sw.elapsedMilliseconds}ms] 开始 HTTP 下载（直连，90s超时）...');
      final profile = await SubscriptionDownloader.downloadSubscription(url)
          .timeout(
        downloadTimeout,
        onTimeout: () {
          throw TimeoutException('下载超时', downloadTimeout);
        },
      );

      _logger.info('✅ [${sw.elapsedMilliseconds}ms] 配置下载完成: ${profile.label ?? profile.id}');
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
      _logger.debug('🔗 目标URL: $url');

      // 从本地配置读取订阅偏好设置（竞速自动跟随加密选项）
      final preferEncrypt = await ConfigFileLoaderHelper.getPreferEncrypt();
      
      _logger.info('📝 本地配置: preferEncrypt=$preferEncrypt (竞速: ${preferEncrypt ? "启用" : "禁用"})');

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

          _logger.debug('🔑 从URL提取到token: ${token.substring(0, min(8, token.length))}...');
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

        _logger.debug('🔄 Fallback - 从URL提取到token: ${token.substring(0, min(8, token.length))}...');
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
        _logger.debug('🔑 使用解密密钥: ${result.keyUsed!.substring(0, min(8, result.keyUsed!.length))}...');
      }
      
      // 验证解密后的配置内容
      _logger.debug('📄 验证解密后的配置内容，长度: ${result.content!.length}');
      if (result.content!.trim().isEmpty) {
        throw Exception('解密后的配置内容为空');
      }

      // 记录配置内容的基本统计信息
      final lines = result.content!.split('\n');
      final nonEmptyLines = lines.where((line) => line.trim().isNotEmpty).length;
      _logger.debug('📄 配置内容统计: 总行数 ${lines.length}, 非空行数 $nonEmptyLines');

      // 移除冗余的格式检查，让ClashMeta核心进行权威验证
      _logger.debug('⚡ 跳过客户端格式验证，将由ClashMeta核心进行权威验证');

      // 直接写文件，跳过 validateConfig IPC（桌面端 ClashCore.exe 未就绪时等 30s）
      _logger.debug('💾 直接写入解密配置内容（跳过 validateConfig IPC）...');
      final profile = Profile.normal(url: url);
      final profileFile = await profile.getFile();
      await profileFile.writeAsString(result.content!);
      final profileWithContent = profile.copyWith(lastUpdateDate: DateTime.now());
      _logger.info('✅ 加密配置内容已写入，格式验证由 applyProfile 阶段完成');
      
      // 获取订阅信息并更新Profile
      _logger.info('📊 开始获取加密订阅的订阅信息...');
      final subscriptionInfo = await ProfileSubscriptionInfoService.instance.getSubscriptionInfo(
        subscriptionUserInfo: result.subscriptionUserInfo,
      );
      _logger.info('📊 Profile订阅信息获取完成: upload=${subscriptionInfo.upload}, download=${subscriptionInfo.download}, total=${subscriptionInfo.total}');

      // 返回带有订阅信息的Profile
      final updatedProfile = profileWithContent.copyWith(
        subscriptionInfo: subscriptionInfo,
      );

      _logger.info('🎉 加密配置验证和保存成功！最终Profile订阅信息: ${updatedProfile.subscriptionInfo}');
      _logger.debug('✅ 完整的加密订阅处理流程已成功完成');
      return updatedProfile;
      
    } catch (e) {
      _logger.error('💥 加密配置下载失败', e);
      _logger.debug('❌ 加密订阅处理流程异常终止');
      throw Exception('加密订阅处理失败: $e');
    }
  }

  Future<void> _addProfile(Profile profile) async {
    final sw = Stopwatch()..start();
    try {
      // 1. 添加配置到列表
      _ref.read(profilesProvider.notifier).setProfile(profile);
      _logger.info('✅ [${sw.elapsedMilliseconds}ms] Profile 已加入列表: ${profile.label ?? profile.id}');

      // 2. 设置标志位，防止 ClashManager 的 needSetupProvider 监听器
      //    在 currentProfileId 变更时触发 handleChangeProfile → applyProfile，
      //    与下方的显式 applyProfile 产生并发竞争导致 groups 被清空。
      globalState.appController.isImportApplying = true;

      // 3. 强制设置为当前配置（订阅导入是用户主动操作，应该立即生效）
      final currentProfileIdNotifier = _ref.read(currentProfileIdProvider.notifier);
      currentProfileIdNotifier.value = profile.id;
      _logger.info('✅ [${sw.elapsedMilliseconds}ms] currentProfileId 已设置: ${profile.id}');

      // 4. 同步等待 applyProfile 完成（与 Orange 一致）
      // 必须 await，否则后续的 _cleanOldUrlProfilesExcept 可能在 applyProfile 完成前执行，
      // 导致竞态条件：旧配置被删除但新配置尚未加载，用户看到空白节点列表。
      _logger.info('📋 [${sw.elapsedMilliseconds}ms] 开始 await applyProfile(silence: true)...');
      try {
        await globalState.appController.applyProfile(silence: true)
            .timeout(const Duration(seconds: 30), onTimeout: () {
          _logger.warning('⚠️ applyProfile 超时(30s)，继续执行');
        });
        _logger.info('✅ [${sw.elapsedMilliseconds}ms] applyProfile 完成');

        // 检查节点是否已加载
        final groups = _ref.read(groupsProvider);
        _logger.info('📊 当前 groups 数量: ${groups.length}');
        if (groups.isEmpty) {
          _logger.warning('⚠️ applyProfile 完成但 groups 为空，尝试延迟重试...');
          // 等待一段时间后重试一次（适配 Windows 便携版 ClashCore 慢启动）
          await Future.delayed(const Duration(seconds: 5));
          await globalState.appController.applyProfile(silence: true)
              .timeout(const Duration(seconds: 30), onTimeout: () {
            _logger.warning('⚠️ applyProfile 重试超时(30s)');
          });
          final retryGroups = _ref.read(groupsProvider);
          _logger.info('📊 重试后 groups 数量: ${retryGroups.length}');
        }
      } catch (e) {
        _logger.error('❌ applyProfile 失败', e);
        // 必须抛出异常！否则后续 _cleanOldUrlProfilesExcept 会删除旧配置，
        // 导致旧配置被清除、新配置未加载成功 → 用户看到空白节点列表。
        // 配置文件已保存在磁盘，下次启动时会自动加载。
        throw Exception('applyProfile 失败: $e');
      } finally {
        globalState.appController.isImportApplying = false;
      }

      _logger.info('✅ [${sw.elapsedMilliseconds}ms] _addProfile 完成: ${profile.label ?? profile.id}');
    } catch (e) {
      globalState.appController.isImportApplying = false;
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
  String _getUserFriendlyErrorMessage(dynamic error, ImportErrorType errorType) {
    final errorString = error.toString();
    
    switch (errorType) {
      case ImportErrorType.networkError:
        return '网络连接失败，请检查网络设置后重试';
      case ImportErrorType.downloadError:
        // 特殊处理User-Agent相关错误
        if (errorString.contains('Invalid HTTP header field value')) {
          return '配置文件下载失败：HTTP请求头格式错误，请稍后重试';
        }
        if (errorString.contains('FormatException')) {
          return '配置文件下载失败：请求格式错误，请稍后重试';
        }
        return '配置文件下载失败，请检查订阅链接是否正确';
      case ImportErrorType.validationError:
        return '配置文件格式验证失败，请联系服务提供商检查配置格式';
      case ImportErrorType.storageError:
        return '保存配置失败，请检查存储空间';
      case ImportErrorType.unknownError:
        // 简化未知错误的显示，避免显示技术细节
        if (errorString.contains('Invalid HTTP header field value') || 
            errorString.contains('FormatException')) {
          return '导入失败：应用配置错误，请稍后重试或重启应用';
        }
        return '导入失败，请稍后重试或联系技术支持';
    }
  }
  bool get isImporting => _isImporting;
} 