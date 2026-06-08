/// XBoard 数据存储服务
///
/// 提供XBoard相关数据的存储和读取
library;

import 'dart:convert';
import 'package:fl_clash/xboard/core/core.dart';
import 'package:fl_clash/xboard/infrastructure/infrastructure.dart';
import 'package:fl_clash/xboard/domain/domain.dart';

/// XBoard 存储服务
///
/// 负责存储和读取XBoard相关数据，如用户信息、订阅信息等
class XBoardStorageService {
  final StorageInterface _storage;

  XBoardStorageService(this._storage);

  // 存储键定义
  static const String _userEmailKey = 'xboard_user_email';
  static const String _userInfoKey = 'xboard_user_info'; // 保留兼容
  static const String _subscriptionInfoKey = 'xboard_subscription_info'; // 保留兼容
  static const String _domainUserKey = 'xboard_domain_user'; // 新：领域模型
  static const String _domainSubscriptionKey =
      'xboard_domain_subscription'; // 新：领域模型
  static const String _domainPlansKey = 'xboard_domain_plans';
  static const String _domainInviteKey = 'xboard_domain_invite';
  static const String _domainCommissionHistoryKey =
      'xboard_domain_commission_history';
  static const String _tunFirstUseKey = 'xboard_tun_first_use_shown';
  static const String _savedEmailKey = 'xboard_saved_email';
  static const String _savedPasswordKey = 'xboard_saved_password';
  static const String _rememberPasswordKey = 'xboard_remember_password';
  static const String _autoLoginKey = 'xboard_auto_login';
  static const String _ossModeKey = 'xboard_oss_mode'; // 0=打包OSS, 1=内置OSS
  static const String _cachedApiEndpointKey = 'xboard_cached_api_endpoint';

  Future<Result<bool>> saveUserEmail(String email) async {
    return await _storage.setString(_userEmailKey, email);
  }

  Future<Result<String?>> getUserEmail() async {
    return await _storage.getString(_userEmailKey);
  }

  Future<Result<bool>> saveDomainUser(DomainUser user) async {
    try {
      final userJson = jsonEncode(user.toJson());
      return await _storage.setString(_domainUserKey, userJson);
    } catch (e, stackTrace) {
      return Result.failure(XBoardStorageException(
        message: '保存领域用户信息失败',
        operation: 'write',
        key: _domainUserKey,
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }

  Future<Result<DomainUser?>> getDomainUser() async {
    final result = await _storage.getString(_domainUserKey);
    return result.when(
      success: (userJson) {
        if (userJson == null) return Result.success(null);
        try {
          final Map<String, dynamic> userMap = jsonDecode(userJson);
          return Result.success(DomainUser.fromJson(userMap));
        } catch (e, stackTrace) {
          return Result.failure(XBoardParseException(
            message: '解析领域用户信息失败',
            dataType: 'DomainUser',
            originalError: e,
            stackTrace: stackTrace,
          ));
        }
      },
      failure: (error) => Result.failure(error),
    );
  }

  // ===== 领域模型：订阅信息 =====

  Future<Result<bool>> saveDomainSubscription(
      DomainSubscription subscription) async {
    try {
      final subscriptionJson = jsonEncode(subscription.toJson());
      return await _storage.setString(_domainSubscriptionKey, subscriptionJson);
    } catch (e, stackTrace) {
      return Result.failure(XBoardStorageException(
        message: '保存领域订阅信息失败',
        operation: 'write',
        key: _domainSubscriptionKey,
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }

  Future<Result<DomainSubscription?>> getDomainSubscription() async {
    final result = await _storage.getString(_domainSubscriptionKey);
    return result.when(
      success: (subscriptionJson) {
        if (subscriptionJson == null) return Result.success(null);
        try {
          final Map<String, dynamic> subscriptionMap =
              jsonDecode(subscriptionJson);
          return Result.success(DomainSubscription.fromJson(subscriptionMap));
        } catch (e, stackTrace) {
          return Result.failure(XBoardParseException(
            message: '解析领域订阅信息失败',
            dataType: 'DomainSubscription',
            originalError: e,
            stackTrace: stackTrace,
          ));
        }
      },
      failure: (error) => Result.failure(error),
    );
  }

  Future<Result<bool>> saveDomainPlans(List<DomainPlan> plans) async {
    try {
      final plansJson = jsonEncode(plans.map((plan) => plan.toJson()).toList());
      return await _storage.setString(_domainPlansKey, plansJson);
    } catch (e, stackTrace) {
      return Result.failure(XBoardStorageException(
        message: '保存套餐列表失败',
        operation: 'write',
        key: _domainPlansKey,
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }

  Future<Result<List<DomainPlan>>> getDomainPlans() async {
    final result = await _storage.getString(_domainPlansKey);
    return result.when(
      success: (plansJson) {
        if (plansJson == null || plansJson.isEmpty) {
          return Result.success(<DomainPlan>[]);
        }
        try {
          final plansList = (jsonDecode(plansJson) as List)
              .map((item) => DomainPlan.fromJson(item as Map<String, dynamic>))
              .toList();
          return Result.success(plansList);
        } catch (e, stackTrace) {
          return Result.failure(XBoardParseException(
            message: '解析套餐列表失败',
            dataType: 'List<DomainPlan>',
            originalError: e,
            stackTrace: stackTrace,
          ));
        }
      },
      failure: (error) => Result.failure(error),
    );
  }

  Future<Result<bool>> saveDomainInvite(DomainInvite invite) async {
    try {
      final inviteJson = jsonEncode(invite.toJson());
      return await _storage.setString(_domainInviteKey, inviteJson);
    } catch (e, stackTrace) {
      return Result.failure(XBoardStorageException(
        message: '保存邀请信息失败',
        operation: 'write',
        key: _domainInviteKey,
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }

  Future<Result<DomainInvite?>> getDomainInvite() async {
    final result = await _storage.getString(_domainInviteKey);
    return result.when(
      success: (inviteJson) {
        if (inviteJson == null || inviteJson.isEmpty) {
          return Result.success(null);
        }
        try {
          final inviteMap = jsonDecode(inviteJson) as Map<String, dynamic>;
          return Result.success(DomainInvite.fromJson(inviteMap));
        } catch (e, stackTrace) {
          return Result.failure(XBoardParseException(
            message: '解析邀请信息失败',
            dataType: 'DomainInvite',
            originalError: e,
            stackTrace: stackTrace,
          ));
        }
      },
      failure: (error) => Result.failure(error),
    );
  }

  Future<Result<bool>> saveDomainCommissionHistory(
    List<DomainCommission> history,
  ) async {
    try {
      final historyJson =
          jsonEncode(history.map((item) => item.toJson()).toList());
      return await _storage.setString(
        _domainCommissionHistoryKey,
        historyJson,
      );
    } catch (e, stackTrace) {
      return Result.failure(XBoardStorageException(
        message: '保存佣金明细失败',
        operation: 'write',
        key: _domainCommissionHistoryKey,
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }

  Future<Result<List<DomainCommission>>> getDomainCommissionHistory() async {
    final result = await _storage.getString(_domainCommissionHistoryKey);
    return result.when(
      success: (historyJson) {
        if (historyJson == null || historyJson.isEmpty) {
          return Result.success(<DomainCommission>[]);
        }
        try {
          final history = (jsonDecode(historyJson) as List)
              .map((item) =>
                  DomainCommission.fromJson(item as Map<String, dynamic>))
              .toList();
          return Result.success(history);
        } catch (e, stackTrace) {
          return Result.failure(XBoardParseException(
            message: '解析佣金明细失败',
            dataType: 'List<DomainCommission>',
            originalError: e,
            stackTrace: stackTrace,
          ));
        }
      },
      failure: (error) => Result.failure(error),
    );
  }

  // ===== 订阅信息（已移除，使用DomainSubscription代替） =====

  // ===== 认证数据清理 =====

  Future<Result<bool>> clearAuthData() async {
    final results = await Future.wait([
      _storage.remove(_userEmailKey),
      _storage.remove(_userInfoKey),
      _storage.remove(_subscriptionInfoKey),
      _storage.remove(_domainUserKey), // 清理领域模型
      _storage.remove(_domainSubscriptionKey), // 清理领域模型
      _storage.remove(_domainPlansKey),
      _storage.remove(_domainInviteKey),
      _storage.remove(_domainCommissionHistoryKey),
    ]);

    final allSuccess = results.every((r) => r.dataOrNull == true);
    return Result.success(allSuccess);
  }

  // ===== TUN 首次使用标记 =====

  Future<Result<bool>> hasTunFirstUseShown() async {
    final result = await _storage.getBool(_tunFirstUseKey);
    return result.map((value) => value ?? false);
  }

  Future<Result<bool>> markTunFirstUseShown() async {
    return await _storage.setBool(_tunFirstUseKey, true);
  }

  // ===== 登录凭据 =====

  Future<Result<bool>> saveCredentials(
    String email,
    String password,
    bool rememberPassword,
  ) async {
    final results = await Future.wait([
      _storage.setString(_savedEmailKey, email),
      _storage.setString(_savedPasswordKey, rememberPassword ? password : ''),
      _storage.setBool(_rememberPasswordKey, rememberPassword),
    ]);

    final allSuccess = results.every((r) => r.dataOrNull == true);
    return Result.success(allSuccess);
  }

  Future<Result<Map<String, dynamic>>> getSavedCredentials() async {
    final emailResult = await _storage.getString(_savedEmailKey);
    final passwordResult = await _storage.getString(_savedPasswordKey);
    final rememberResult = await _storage.getBool(_rememberPasswordKey);

    return Result.success({
      'email': emailResult.dataOrNull,
      'password': passwordResult.dataOrNull,
      'rememberPassword': rememberResult.dataOrNull ?? false,
    });
  }

  // 便捷方法：获取单个保存的凭据字段
  Future<String?> getSavedEmail() async {
    final result = await _storage.getString(_savedEmailKey);
    return result.dataOrNull;
  }

  Future<String?> getSavedPassword() async {
    final result = await _storage.getString(_savedPasswordKey);
    return result.dataOrNull;
  }

  Future<bool> getRememberPassword() async {
    final result = await _storage.getBool(_rememberPasswordKey);
    return result.dataOrNull ?? false;
  }

  Future<bool> hasRememberPasswordSetting() async {
    final result = await _storage.containsKey(_rememberPasswordKey);
    return result.dataOrNull ?? false;
  }

  Future<bool> getAutoLogin() async {
    final result = await _storage.getBool(_autoLoginKey);
    return result.dataOrNull ?? false;
  }

  Future<Result<bool>> saveAutoLogin(bool autoLogin) async {
    return await _storage.setBool(_autoLoginKey, autoLogin);
  }

  // ===== OSS 模式缓存 =====

  /// 获取 OSS 模式：0=打包OSS, 1=内置OSS
  Future<int> getOssMode() async {
    final result = await _storage.getInt(_ossModeKey);
    return result.dataOrNull ?? 0;
  }

  /// 设置 OSS 模式
  Future<void> setOssMode(int mode) async {
    await _storage.setInt(_ossModeKey, mode);
  }

  /// 清除 OSS 模式（登出时调用）
  Future<void> clearOssMode() async {
    await _storage.remove(_ossModeKey);
  }

  // ===== 启动缓存：最后一次可用 API 端点 =====

  Future<Result<bool>> saveCachedApiEndpoint({
    required String baseUrl,
    required String apiPrefix,
    required String panelType,
    required String sourceTag,
    DateTime? updatedAt,
  }) async {
    try {
      final payload = <String, dynamic>{
        'base_url': baseUrl,
        'api_prefix': apiPrefix,
        'panel_type': panelType,
        'source_tag': sourceTag,
        'updated_at': (updatedAt ?? DateTime.now()).toIso8601String(),
      };
      return await _storage.setString(
        _cachedApiEndpointKey,
        jsonEncode(payload),
      );
    } catch (e, stackTrace) {
      return Result.failure(XBoardStorageException(
        message: '保存 API 启动缓存失败',
        operation: 'write',
        key: _cachedApiEndpointKey,
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }

  Future<Result<Map<String, dynamic>?>> getCachedApiEndpoint() async {
    final result = await _storage.getString(_cachedApiEndpointKey);
    return result.when(
      success: (jsonText) {
        if (jsonText == null || jsonText.isEmpty) return Result.success(null);
        try {
          final raw = jsonDecode(jsonText);
          if (raw is Map<String, dynamic>) return Result.success(raw);
          if (raw is Map) {
            return Result.success(raw.map((k, v) => MapEntry(k.toString(), v)));
          }
          return Result.success(null);
        } catch (e, stackTrace) {
          return Result.failure(XBoardParseException(
            message: '解析 API 启动缓存失败',
            dataType: 'Map<String,dynamic>',
            originalError: e,
            stackTrace: stackTrace,
          ));
        }
      },
      failure: (error) => Result.failure(error),
    );
  }

  Future<Result<bool>> clearCachedApiEndpoint() async {
    return await _storage.remove(_cachedApiEndpointKey);
  }

  Future<Result<bool>> clearSavedCredentials() async {
    final results = await Future.wait([
      _storage.remove(_savedEmailKey),
      _storage.remove(_savedPasswordKey),
      _storage.remove(_rememberPasswordKey),
    ]);

    final allSuccess = results.every((r) => r.dataOrNull == true);
    return Result.success(allSuccess);
  }
}
