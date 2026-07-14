import 'dart:io';
import 'package:fl_clash/common/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_clash/xboard/domain/domain.dart';
import 'package:fl_clash/xboard/features/subscription/widgets/subscription_status_dialog.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/xboard/features/subscription/providers/xboard_subscription_provider.dart';
import 'package:fl_clash/xboard/features/payment/pages/plan_purchase_page.dart';
import 'package:fl_clash/xboard/features/payment/pages/plans.dart' show pendingPurchasePlanProvider;
import 'package:fl_clash/xboard/features/subscription/services/traffic_recovery_service.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/core/core.dart';

import 'subscription_status_service.dart';

// 初始化文件级日志器
final _logger = FileLogger('subscription_status_checker.dart');

class SubscriptionStatusChecker {
  static final SubscriptionStatusChecker _instance =
      SubscriptionStatusChecker._internal();
  factory SubscriptionStatusChecker() => _instance;
  SubscriptionStatusChecker._internal();
  bool _isChecking = false;
  DateTime? _lastCheckTime;
  Future<void> checkSubscriptionStatusOnStartup(
    BuildContext context,
    WidgetRef ref,
  ) async {
    if (!context.mounted) return;
    final now = DateTime.now();
    if (_isChecking) {
      _logger.info('[订阅状态检查] 检查正在进行中，跳过重复请求');
      return;
    }
    if (_lastCheckTime != null &&
        now.difference(_lastCheckTime!).inSeconds < 30) {
      _logger.info('[订阅状态检查] 距离上次检查不到30秒，跳过重复请求');
      return;
    }
    _isChecking = true;
    _lastCheckTime = now;
    try {
      _logger.info('[订阅状态检查] 开始检查订阅状态...');
      final userState = ref.read(xboardUserProvider);
      if (!userState.isAuthenticated) {
        _logger.info('[订阅状态检查] 用户未登录，跳过检查');
        return;
      }
      _logger.info('[订阅状态检查] 用户已登录，使用现有订阅状态进行检查');
      // 不再调用 refreshSubscriptionInfo()，避免重复导入
      // Token验证成功后已经通过 _silentUpdateUserData() 获取了最新订阅信息
      final updatedUserState = userState;
      final profileSubscriptionInfo =
          ref.read(currentProfileProvider)?.subscriptionInfo;
      final statusResult = subscriptionStatusService.checkSubscriptionStatus(
        userState: updatedUserState,
        profileSubscriptionInfo: profileSubscriptionInfo,
      );
      _logger.info('[订阅状态检查] 检查结果: ${statusResult.type}');
      _logger.info('[订阅状态检查] 是否需要弹窗: ${statusResult.shouldShowDialog}');
      if (subscriptionStatusService.shouldShowStartupDialog(statusResult)) {
        await _showSubscriptionStatusDialog(
          context,
          ref,
          statusResult,
        );
      } else {
        // 订阅状态正常，不需要额外导入配置
        // 配置导入已由 Token 验证成功后的 _silentUpdateUserData() 完成
        _logger.info('[订阅状态检查] 订阅状态正常，无需额外操作（配置已在Token验证后导入）');
      }
    } catch (e) {
      _logger.error('[订阅状态检查] 检查时出错', e);
    } finally {
      _isChecking = false;
    }
  }

  Future<void> _showSubscriptionStatusDialog(
    BuildContext context,
    WidgetRef ref,
    SubscriptionStatusResult statusResult,
  ) async {
    if (!context.mounted) return;
    _logger.info('[订阅状态弹窗] 显示弹窗: ${statusResult.type}');
    final result = await SubscriptionStatusDialog.show(
      context,
      statusResult,
      onPurchase: () async {
        await _handleRenewFromDialog(context, ref);
      },
      onTrafficRecovery: statusResult.type == SubscriptionStatusType.exhausted
          ? () => showTrafficRecoveryDialog(context: context, ref: ref)
          : null,
      useNewPeriod: isNewPeriodEnabled(ref),
      onRefresh: () async {
        _logger.info('[订阅状态弹窗] 刷新订阅状态...');
        await ref.read(xboardUserProvider.notifier).refreshSubscriptionInfo();
        await Future.delayed(const Duration(seconds: 1));
        if (context.mounted) {
          context.pop();
        }
      },
    );
    _logger.info('[订阅状态弹窗] 操作结果: $result');
    if (result == 'later' || result == null) {
      _logger.info('[订阅状态弹窗] 用户选择稍后处理');
    }
  }

  /// 续费/购买套餐的通用逻辑（供弹窗、个人中心等复用）
  static Future<void> handleRenewAction(
    BuildContext context,
    WidgetRef ref, {
    bool isResetTraffic = false,
    DomainSubscription? subscriptionInfo,
    DomainUser? userInfo,
  }) async {
    if (isResetTraffic &&
        isNewPeriodEnabled(ref, subscriptionInfo: subscriptionInfo)) {
      await showTrafficRecoveryDialog(
        context: context,
        ref: ref,
        subscriptionInfo: subscriptionInfo,
      );
      return;
    }
    final isDesktop = Platform.isLinux ||
        Platform.isWindows ||
        Platform.isMacOS ||
        system.isTV;
    final router = GoRouter.of(context);
    final navigator = Navigator.of(context);

    int? normalizePlanId(int? planId) =>
        planId != null && planId > 0 ? planId : null;

    final userState = ref.read(xboardUserProvider);
    final currentPlanId = normalizePlanId(subscriptionInfo?.planId) ??
        normalizePlanId(userInfo?.planId) ??
        normalizePlanId(ref.read(subscriptionInfoProvider)?.planId) ??
        normalizePlanId(userState.subscriptionInfo?.planId);

    if (currentPlanId != null) {
      final planNotifier = ref.read(xboardSubscriptionProvider.notifier);
      var plans = ref.read(xboardSubscriptionProvider);
      if (plans.isEmpty) {
        await planNotifier.loadPlans();
        plans = ref.read(xboardSubscriptionProvider);
      }

      DomainPlan? currentPlan =
          plans.where((plan) => plan.id == currentPlanId).firstOrNull;
      currentPlan ??= await planNotifier.loadPlanById(currentPlanId);

      if (!context.mounted) return;

      if (currentPlan != null) {
        if (isResetTraffic) {
          await showTrafficRecoveryDialog(
            context: context,
            ref: ref,
            planId: currentPlan.id,
            plan: currentPlan,
            subscriptionInfo: subscriptionInfo,
          );
          return;
        }

        if (isDesktop) {
          ref.read(pendingPurchasePlanProvider.notifier).state = currentPlan;
          router.go('/plans');
        } else {
          navigator.push(MaterialPageRoute(
            builder: (_) => PlanPurchasePage(plan: currentPlan!),
          ));
        }
        return;
      }

      if (!context.mounted) return;
      if (isResetTraffic) {
        await showTrafficRecoveryDialog(
          context: context,
          ref: ref,
          planId: currentPlanId,
          subscriptionInfo: subscriptionInfo,
        );
        return;
      }
    }

    if (isResetTraffic) {
      XBoardNotification.showError(
        AppLocalizations.of(context).xboardPlanNotFound,
      );
      return;
    }

    if (!context.mounted) return;
    if (isDesktop) {
      router.go('/plans');
    } else {
      router.push('/plans');
    }
  }

  Future<void> _handleRenewFromDialog(
      BuildContext context, WidgetRef ref) async {
    await handleRenewAction(context, ref);
  }

  Future<void> manualCheckSubscriptionStatus(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await checkSubscriptionStatusOnStartup(context, ref);
  }

  bool shouldShowSubscriptionReminder(WidgetRef ref) {
    try {
      final userState = ref.read(xboardUserProvider);
      if (!userState.isAuthenticated) return false;
      final profileSubscriptionInfo =
          ref.read(currentProfileProvider)?.subscriptionInfo;
      final statusResult = subscriptionStatusService.checkSubscriptionStatus(
        userState: userState,
        profileSubscriptionInfo: profileSubscriptionInfo,
      );
      return subscriptionStatusService.shouldShowStartupDialog(statusResult);
    } catch (e) {
      _logger.error('[订阅状态检查] 检查订阅提醒状态出错', e);
      return false;
    }
  }

  String getSubscriptionStatusText(BuildContext context, WidgetRef ref) {
    try {
      final userState = ref.read(xboardUserProvider);
      if (!userState.isAuthenticated) return '未登录';
      final profileSubscriptionInfo =
          ref.read(currentProfileProvider)?.subscriptionInfo;
      final statusResult = subscriptionStatusService.checkSubscriptionStatus(
        userState: userState,
        profileSubscriptionInfo: profileSubscriptionInfo,
      );
      return statusResult.getMessage(context);
    } catch (e) {
      return '状态检查失败';
    }
  }
}

final subscriptionStatusChecker = SubscriptionStatusChecker();
