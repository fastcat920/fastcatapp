import 'package:flutter/material.dart';
import 'package:fl_clash/models/models.dart' as fl_models;
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/features/auth/auth.dart';

enum SubscriptionStatusType {
  valid,
  noSubscription,
  expired,
  exhausted,
  banned,
  notLoggedIn,
}

class SubscriptionStatusResult {
  final SubscriptionStatusType type;
  final String Function(BuildContext) messageBuilder;
  final String? Function(BuildContext)? detailMessageBuilder;
  final DateTime? expiredAt;
  final int? remainingDays;
  final bool needsDialog;
  const SubscriptionStatusResult({
    required this.type,
    required this.messageBuilder,
    this.detailMessageBuilder,
    this.expiredAt,
    this.remainingDays,
    this.needsDialog = false,
  });
  String getMessage(BuildContext context) => messageBuilder(context);
  String? getDetailMessage(BuildContext context) =>
      detailMessageBuilder?.call(context);
  bool get shouldShowDialog => needsDialog;
}

class SubscriptionStatusService {
  static const SubscriptionStatusService _instance =
      SubscriptionStatusService._internal();
  factory SubscriptionStatusService() => _instance;
  const SubscriptionStatusService._internal();
  SubscriptionStatusResult checkSubscriptionStatus({
    required UserAuthState userState,
    fl_models.SubscriptionInfo? profileSubscriptionInfo,
    bool isRefreshing = false,
  }) {
    if (!userState.isAuthenticated) {
      return SubscriptionStatusResult(
        type: SubscriptionStatusType.notLoggedIn,
        messageBuilder: (context) =>
            AppLocalizations.of(context).subscriptionNotLoggedIn,
        detailMessageBuilder: (context) =>
            AppLocalizations.of(context).subscriptionNotLoggedInDetail,
        needsDialog: false,
      );
    }

    // 检查账号是否被封禁
    if (userState.userInfo?.banned == true) {
      return SubscriptionStatusResult(
        type: SubscriptionStatusType.banned,
        messageBuilder: (context) =>
            AppLocalizations.of(context).xboardAccountBanned,
        detailMessageBuilder: (context) =>
            AppLocalizations.of(context).xboardAccountBannedDetail,
        needsDialog: true,
      );
    }

    // 只使用 profileSubscriptionInfo 作为数据源
    // profileSubscriptionInfo 为 null 或 total=0 且 expire=0 都视为无套餐
    final hasNoSubscription = profileSubscriptionInfo == null ||
        (profileSubscriptionInfo.total <= 0 &&
            profileSubscriptionInfo.expire == 0);
    if (hasNoSubscription) {
      // 如果正在刷新订阅，返回"刷新中"状态而非"无订阅"，避免 UI 短暂显示购买订阅
      if (isRefreshing) {
        return SubscriptionStatusResult(
          type: SubscriptionStatusType.valid,
          messageBuilder: (context) =>
              AppLocalizations.of(context).subscriptionValid,
          detailMessageBuilder: null,
          needsDialog: false,
        );
      }
      return SubscriptionStatusResult(
        type: SubscriptionStatusType.noSubscription,
        messageBuilder: (context) =>
            AppLocalizations.of(context).subscriptionNoSubscription,
        detailMessageBuilder: (context) =>
            AppLocalizations.of(context).subscriptionNoSubscriptionDetail,
        needsDialog: true,
      );
    }

    // 检查过期时间
    final expiredAt = _getExpiredAt(profileSubscriptionInfo);
    if (expiredAt != null) {
      final remainingDays = _naturalDaysUntil(expiredAt);
      if (remainingDays < 0) {
        return SubscriptionStatusResult(
          type: SubscriptionStatusType.expired,
          messageBuilder: (context) => '套餐已到期，请先续费套餐',
          detailMessageBuilder: (context) => '套餐已到期，请先续费套餐',
          expiredAt: expiredAt,
          remainingDays: remainingDays,
          needsDialog: true,
        );
      }
      if (remainingDays == 0) {
        return SubscriptionStatusResult(
          type: SubscriptionStatusType.valid,
          messageBuilder: (context) =>
              AppLocalizations.of(context).subscriptionExpiresToday,
          detailMessageBuilder: (context) =>
              AppLocalizations.of(context).subscriptionExpiresTodayDetail,
          expiredAt: expiredAt,
          remainingDays: remainingDays,
          needsDialog: false, // 当天到期仍允许连接，不阻断
        );
      }
      if (remainingDays <= 3) {
        return SubscriptionStatusResult(
          type: SubscriptionStatusType.valid,
          messageBuilder: (context) =>
              AppLocalizations.of(context).subscriptionExpiringInDays,
          detailMessageBuilder: (context) => AppLocalizations.of(context)
              .subscriptionExpiringInDaysDetail(remainingDays),
          expiredAt: expiredAt,
          remainingDays: remainingDays,
          needsDialog: false, // 即将过期不强制弹窗
        );
      }
    }

    // 检查流量状态
    final trafficStatus = _checkTrafficStatus(profileSubscriptionInfo);
    if (trafficStatus != null) {
      return trafficStatus;
    }

    final remainingDays =
        expiredAt != null ? _naturalDaysUntil(expiredAt) : null;
    return SubscriptionStatusResult(
      type: SubscriptionStatusType.valid,
      messageBuilder: (context) =>
          AppLocalizations.of(context).subscriptionValid,
      detailMessageBuilder: remainingDays != null
          ? (context) => AppLocalizations.of(context)
              .subscriptionValidDetail(remainingDays)
          : null,
      expiredAt: expiredAt,
      remainingDays: remainingDays,
      needsDialog: false,
    );
  }

  DateTime? _getExpiredAt(
    fl_models.SubscriptionInfo? profileSubscriptionInfo,
  ) {
    if (profileSubscriptionInfo?.expire != null &&
        profileSubscriptionInfo!.expire != 0) {
      final raw = DateTime.fromMillisecondsSinceEpoch(
          profileSubscriptionInfo.expire * 1000);
      // 服务端时间戳通常指向当天 00:00:00，套餐应在当天结束后才过期
      // 将过期时间调整到当天 23:59:59 避免提前一天判定过期
      return DateTime(raw.year, raw.month, raw.day, 23, 59, 59);
    }
    return null;
  }

  int _naturalDaysUntil(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(date.year, date.month, date.day);
    return targetDate.difference(today).inDays;
  }

  SubscriptionStatusResult? _checkTrafficStatus(
    fl_models.SubscriptionInfo? profileSubscriptionInfo,
  ) {
    if (profileSubscriptionInfo == null || profileSubscriptionInfo.total <= 0) {
      return null;
    }

    final usedTraffic =
        (profileSubscriptionInfo.upload + profileSubscriptionInfo.download)
            .toDouble();
    final totalTraffic = profileSubscriptionInfo.total.toDouble();
    final usageRatio = usedTraffic / totalTraffic;

    if (usageRatio >= 1.0) {
      return SubscriptionStatusResult(
        type: SubscriptionStatusType.exhausted,
        messageBuilder: (context) => '套餐流量已用完，请重置流量或升级套餐。',
        detailMessageBuilder: (context) => '套餐流量已用完，请重置流量或升级套餐。',
        needsDialog: true,
      );
    }
    return null;
  }

  bool shouldShowStartupDialog(SubscriptionStatusResult result) {
    // 首页套餐卡片已经展示了所有订阅状态，这里不再弹订阅状态弹窗
    return false;
  }
}

final subscriptionStatusService = SubscriptionStatusService();
