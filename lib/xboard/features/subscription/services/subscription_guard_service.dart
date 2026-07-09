import 'dart:async';
import 'package:fl_clash/models/models.dart' as fl_models;
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/xboard/domain/models/subscription.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/xboard/features/subscription/services/subscription_status_service.dart';
import 'package:fl_clash/xboard/core/core.dart';

final _logger = FileLogger('subscription_guard_service.dart');

/// 订阅守护服务
///
/// 负责在连接期间持续监控订阅有效性：
/// 1. 连接前：本地校验过期时间，过期则拦截
/// 2. 连接中：精准过期定时器 + 定期从服务端刷新订阅信息
/// 3. 订阅异常时自动断开连接
class SubscriptionGuardService {
  static final SubscriptionGuardService _instance =
      SubscriptionGuardService._internal();
  factory SubscriptionGuardService() => _instance;
  SubscriptionGuardService._internal();

  WidgetRef? _ref;

  /// 过期精准定时器：到期自动断开
  Timer? _expiryTimer;

  /// 定期刷新订阅信息的定时器
  Timer? _refreshTimer;

  /// 定期刷新间隔（5 分钟）
  static const Duration _refreshInterval = Duration(minutes: 5);

  /// 是否正在守护中
  bool _isGuarding = false;

  void initialize(WidgetRef ref) {
    _ref = ref;
  }

  /// 连接前校验：返回 null 表示允许连接，非 null 表示需拦截
  SubscriptionStatusResult? checkBeforeConnect() {
    final ref = _ref;
    if (ref == null) {
      _logger.warning('[checkBeforeConnect] _ref 为 null，跳过校验');
      return null;
    }

    final userState = ref.read(xboardUserProvider);
    if (!userState.isAuthenticated) return null;

    final effectiveSubInfo = _getEffectiveSubscriptionInfo();

    final status = subscriptionStatusService.checkSubscriptionStatus(
      userState: userState,
      profileSubscriptionInfo: effectiveSubInfo,
    );

    _logger.info(
      '[checkBeforeConnect] 结果: type=${status.type}, '
      'effectiveSubInfo total=${effectiveSubInfo?.total}, '
      'upload=${effectiveSubInfo?.upload}, download=${effectiveSubInfo?.download}',
    );

    if (status.type == SubscriptionStatusType.expired ||
        status.type == SubscriptionStatusType.exhausted ||
        status.type == SubscriptionStatusType.noSubscription ||
        status.type == SubscriptionStatusType.banned) {
      return status;
    }

    // 兜底：直接用 DomainSubscription.usagePercentage 判断流量是否用完
    final domainSub =
        ref.read(subscriptionInfoProvider) ?? userState.subscriptionInfo;
    if (domainSub != null && domainSub.usagePercentage >= 100) {
      _logger.info(
        '[checkBeforeConnect] 兜底命中: usagePercentage=${domainSub.usagePercentage}%, '
        'transferLimit=${domainSub.transferLimit}, '
        'totalUsed=${domainSub.totalUsedBytes}',
      );
      final fallbackStatus = subscriptionStatusService.checkSubscriptionStatus(
        userState: userState,
        profileSubscriptionInfo: fl_models.SubscriptionInfo(
          upload: domainSub.uploadedBytes,
          download: domainSub.downloadedBytes,
          total: domainSub.transferLimit,
          expire: domainSub.expiredAt != null
              ? domainSub.expiredAt!.millisecondsSinceEpoch ~/ 1000
              : 0,
        ),
      );
      if (fallbackStatus.type == SubscriptionStatusType.exhausted) {
        return fallbackStatus;
      }
    }

    return null;
  }

  /// 连接成功后启动守护
  void startGuard() {
    if (_isGuarding) return;
    _isGuarding = true;
    _logger.info('订阅守护已启动');

    _startExpiryTimer();
    _startRefreshTimer();
  }

  /// 断开连接后停止守护
  void stopGuard() {
    if (!_isGuarding) return;
    _isGuarding = false;
    _expiryTimer?.cancel();
    _expiryTimer = null;
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _logger.info('订阅守护已停止');
  }

  /// 订阅信息更新后重新评估（由外部监听器调用）
  void onSubscriptionInfoChanged() {
    if (!_isGuarding) return;

    final status = _checkCurrentStatus();
    if (status != null) {
      _logger.info('订阅信息变更检测到异常: ${status.type}，自动断开');
      _autoDisconnect();
      return;
    }

    // 订阅信息更新了，重新设置过期定时器
    _expiryTimer?.cancel();
    _startExpiryTimer();
  }

  /// 根据过期时间设置精准定时器
  void _startExpiryTimer() {
    final effectiveSubInfo = _getEffectiveSubscriptionInfo();
    if (effectiveSubInfo == null || effectiveSubInfo.expire == 0) return;

    final raw =
        DateTime.fromMillisecondsSinceEpoch(effectiveSubInfo.expire * 1000);
    // 套餐应在到期日当天 23:59:59 后才真正过期
    final expireAt = DateTime(raw.year, raw.month, raw.day, 23, 59, 59);
    final now = DateTime.now();
    final remaining = expireAt.difference(now);

    if (remaining.isNegative) {
      // 已经过期，立即断开
      _logger.info('订阅已过期，立即断开');
      _autoDisconnect();
      return;
    }

    _expiryTimer = Timer(remaining, () {
      _logger.info('订阅到期，自动断开连接');
      _autoDisconnect();
    });

    _logger.info('过期定时器已设置，将在 ${remaining.inMinutes} 分钟后触发');
  }

  /// 启动定期刷新定时器
  void _startRefreshTimer() {
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      _periodicRefresh();
    });
  }

  /// 定期从服务端刷新订阅信息
  Future<void> _periodicRefresh() async {
    final ref = _ref;
    if (ref == null || !_isGuarding) return;

    final userState = ref.read(xboardUserProvider);
    if (!userState.isAuthenticated) return;

    try {
      _logger.info('定期刷新订阅信息...');
      await ref.read(xboardUserProvider.notifier).refreshSubscriptionInfo();
      // 刷新后 subscriptionInfoProvider 会更新，
      // 外部监听器会调用 onSubscriptionInfoChanged()
    } catch (e) {
      _logger.warning('定期刷新订阅信息失败: $e');
    }
  }

  /// 检查当前订阅状态，返回非 null 表示异常
  SubscriptionStatusResult? _checkCurrentStatus() {
    final ref = _ref;
    if (ref == null) return null;

    final userState = ref.read(xboardUserProvider);
    if (!userState.isAuthenticated) return null;

    final effectiveSubInfo = _getEffectiveSubscriptionInfo();
    final status = subscriptionStatusService.checkSubscriptionStatus(
      userState: userState,
      profileSubscriptionInfo: effectiveSubInfo,
    );

    if (status.type == SubscriptionStatusType.expired ||
        status.type == SubscriptionStatusType.exhausted ||
        status.type == SubscriptionStatusType.noSubscription ||
        status.type == SubscriptionStatusType.banned) {
      return status;
    }
    return null;
  }

  /// 获取有效的订阅信息（与首页逻辑一致）
  fl_models.SubscriptionInfo? _getEffectiveSubscriptionInfo() {
    final ref = _ref;
    if (ref == null) return null;

    final currentProfile = ref.read(currentProfileProvider);
    final profileSubInfo = currentProfile?.subscriptionInfo;
    final authState = ref.read(xboardUserProvider);
    final subscriptionInfo =
        ref.read(subscriptionInfoProvider) ?? authState.subscriptionInfo;

    _logger.info(
      '[getEffectiveSubInfo] planId=${subscriptionInfo?.planId}, '
      'transferLimit=${subscriptionInfo?.transferLimit}, '
      'uploaded=${subscriptionInfo?.uploadedBytes}, '
      'downloaded=${subscriptionInfo?.downloadedBytes}, '
      'profileSubInfo total=${profileSubInfo?.total}, '
      'expire=${profileSubInfo?.expire}',
    );

    if (subscriptionInfo != null &&
        (subscriptionInfo.planId > 0 ||
            subscriptionInfo.transferLimit > 0)) {
      final subscriptionExpire = subscriptionInfo.expiredAt != null
          ? subscriptionInfo.expiredAt!.millisecondsSinceEpoch ~/ 1000
          : 0;
      if (profileSubInfo != null) {
        return profileSubInfo.copyWith(
          upload: subscriptionInfo.uploadedBytes,
          download: subscriptionInfo.downloadedBytes,
          total: subscriptionInfo.transferLimit,
          expire: subscriptionExpire > 0
              ? subscriptionExpire
              : profileSubInfo.expire,
        );
      }
      return fl_models.SubscriptionInfo(
        upload: subscriptionInfo.uploadedBytes,
        download: subscriptionInfo.downloadedBytes,
        total: subscriptionInfo.transferLimit,
        expire: subscriptionExpire,
      );
    }
    if (profileSubInfo != null) return profileSubInfo;
    return null;
  }

  /// 自动断开连接
  void _autoDisconnect() {
    stopGuard();
    final isRunning = globalState.appState.runTime != null;
    if (isRunning) {
      globalState.appController.updateStatus(false);
      _logger.info('已自动断开连接');
    }
  }
}

final subscriptionGuardService = SubscriptionGuardService();
