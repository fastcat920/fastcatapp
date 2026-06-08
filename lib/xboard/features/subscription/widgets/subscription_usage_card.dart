import 'dart:io';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/xboard/features/subscription/providers/xboard_subscription_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/models/models.dart' as fl_models;
import 'package:fl_clash/xboard/domain/domain.dart';
import 'package:go_router/go_router.dart';
import '../services/subscription_status_service.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/features/payment/pages/plan_purchase_page.dart';
import 'package:fl_clash/xboard/features/subscription/services/reset_traffic_order_flow.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';

bool get _isDesktop =>
    Platform.isLinux || Platform.isWindows || Platform.isMacOS || system.isTV;

enum _ExpiryState { normal, expiringSoon, expired }

class SubscriptionUsageCard extends ConsumerWidget {
  final DomainSubscription? subscriptionInfo;
  final DomainUser? userInfo;
  final fl_models.SubscriptionInfo? profileSubscriptionInfo;
  final bool showActions;
  final bool usePlainBackground;
  final bool prefixUsedTraffic;
  final double? fixedHeight;
  final double topOffset;
  final bool isSyncing;

  const SubscriptionUsageCard({
    super.key,
    this.subscriptionInfo,
    this.userInfo,
    this.profileSubscriptionInfo,
    this.showActions = true,
    this.usePlainBackground = false,
    this.prefixUsedTraffic = false,
    this.fixedHeight,
    this.topOffset = 0,
    this.isSyncing = false,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final userState = ref.watch(xboardUserProvider);
    // Ensure cached plan list is initialized for offline plan-name fallback.
    ref.watch(xboardSubscriptionProvider);
    SubscriptionStatusResult? subscriptionStatus;
    if (userState.isAuthenticated && subscriptionInfo != null) {
      subscriptionStatus = subscriptionStatusService.checkSubscriptionStatus(
        userState: userState,
        profileSubscriptionInfo: profileSubscriptionInfo,
      );
    }
    if (isSyncing) {
      return _buildSyncingCard(theme, context);
    }
    if (profileSubscriptionInfo == null &&
        userInfo == null &&
        subscriptionInfo == null) {
      return _buildEmptyCard(theme, context);
    }
    if (subscriptionStatus != null &&
        (subscriptionStatus.type == SubscriptionStatusType.expired ||
            subscriptionStatus.type == SubscriptionStatusType.noSubscription ||
            subscriptionStatus.type == SubscriptionStatusType.banned)) {
      if (subscriptionStatus.type == SubscriptionStatusType.expired &&
          subscriptionInfo != null) {
        return _buildUsageCard(theme, context, ref);
      }
      return _buildStatusCard(subscriptionStatus, theme, context);
    }
    return _buildUsageCard(theme, context, ref);
  }

  Widget _buildEmptyCard(ThemeData theme, BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.15)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isDark ? null : Border.all(color: const Color(0xFFEEF0F4)),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF1565C0).withAlpha(15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(
            Icons.cloud_off,
            size: 40,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).xboardNoSubscriptionInfo,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            AppLocalizations.of(context).xboardLoginToViewSubscription,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncingCard(ThemeData theme, BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.15)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isDark ? null : Border.all(color: const Color(0xFFEEF0F4)),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF1565C0).withAlpha(15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '正在同步账号订阅信息...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(SubscriptionStatusResult statusResult,
      ThemeData theme, BuildContext context) {
    IconData statusIcon;
    Color statusColor;
    String statusText;
    String statusDetail;
    switch (statusResult.type) {
      case SubscriptionStatusType.noSubscription:
        statusIcon = Icons.card_giftcard;
        statusColor = theme.colorScheme.primary;
        statusText = AppLocalizations.of(context).xboardNoAvailableSubscription;
        statusDetail =
            AppLocalizations.of(context).xboardPurchaseSubscriptionToUse;
        break;
      case SubscriptionStatusType.expired:
        statusIcon = Icons.schedule;
        statusColor = XbUiStatusColor.error(context);
        statusText = AppLocalizations.of(context).xboardSubscriptionExpired;
        statusDetail = statusResult.getDetailMessage(context) ??
            AppLocalizations.of(context).xboardRenewToContinue;
        break;
      case SubscriptionStatusType.exhausted:
        statusIcon = Icons.data_usage;
        statusColor = XbUiStatusColor.pending(context);
        statusText = AppLocalizations.of(context).xboardTrafficExhausted;
        statusDetail = statusResult.getDetailMessage(context) ??
            AppLocalizations.of(context).xboardBuyMoreTrafficOrUpgrade;
        break;
      case SubscriptionStatusType.banned:
        statusIcon = Icons.block;
        statusColor = XbUiStatusColor.error(context);
        statusText = AppLocalizations.of(context).xboardAccountBanned;
        statusDetail = AppLocalizations.of(context).xboardAccountBannedDetail;
        break;
      default:
        statusIcon = Icons.info;
        statusColor = theme.colorScheme.primary;
        statusText = statusResult.getMessage(context);
        statusDetail = statusResult.getDetailMessage(context) ?? '';
    }
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.15)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        gradient: isDark
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  statusColor.withValues(alpha: 0.03),
                  statusColor.withValues(alpha: 0.01),
                ],
              )
            : null,
        border: isDark ? null : Border.all(color: const Color(0xFFEEF0F4)),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF1565C0).withAlpha(15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  statusIcon,
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusDetail,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (statusResult.expiredAt != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.3)
                    : const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${AppLocalizations.of(context).xboardExpiryTime}: ${_formatDateTime(statusResult.expiredAt!)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // 续费按钮（封禁状态不显示）
          if (showActions &&
              statusResult.type != SubscriptionStatusType.banned) ...[
            const SizedBox(height: 12),
            Consumer(
              builder: (context, ref, child) {
                return SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      await _handleRenewAction(context, ref,
                          isResetTraffic: statusResult.type ==
                              SubscriptionStatusType.exhausted);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: statusColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.shopping_bag, size: 18),
                    label:
                        Text(_getRenewButtonText(statusResult.type, context)),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  String _getRenewButtonText(
      SubscriptionStatusType type, BuildContext context) {
    switch (type) {
      case SubscriptionStatusType.noSubscription:
        return AppLocalizations.of(context).xboardPurchasePlan;
      case SubscriptionStatusType.expired:
        return AppLocalizations.of(context).xboardRenewPlan;
      case SubscriptionStatusType.exhausted:
        return AppLocalizations.of(context).xboardPurchaseTraffic;
      default:
        return AppLocalizations.of(context).xboardPurchasePlan;
    }
  }

  Future<void> _handleRenewAction(BuildContext context, WidgetRef ref,
      {bool isResetTraffic = false}) async {
    final isDesktop = _isDesktop;
    final router = GoRouter.of(context);
    final navigator = Navigator.of(context);
    var hasConfirmedTrafficExhaustedRenew = false;

    Future<bool> confirmTrafficExhaustedRenewIfNeeded() async {
      if (isResetTraffic ||
          hasConfirmedTrafficExhaustedRenew ||
          !_shouldConfirmTrafficExhaustedRenew()) {
        return true;
      }
      final confirmed = await _TrafficExhaustedRenewConfirmDialog.show(context);
      hasConfirmedTrafficExhaustedRenew = confirmed == true;
      return hasConfirmedTrafficExhaustedRenew;
    }

    // 尝试获取用户当前订阅的套餐ID（优先从独立 provider 读取）
    int? normalizePlanId(int? planId) =>
        planId != null && planId > 0 ? planId : null;
    final currentPlanId = normalizePlanId(subscriptionInfo?.planId) ??
        normalizePlanId(userInfo?.planId) ??
        normalizePlanId(ref.read(subscriptionInfoProvider)?.planId) ??
        normalizePlanId(ref.read(xboardUserProvider).subscriptionInfo?.planId);
    final currentPlanName = _normalizePlanName(subscriptionInfo?.planName) ??
        _normalizePlanName(ref.read(subscriptionInfoProvider)?.planName) ??
        _normalizePlanName(
            ref.read(xboardUserProvider).subscriptionInfo?.planName);

    if (currentPlanId != null) {
      // 确保套餐列表已加载
      final planNotifier = ref.read(xboardSubscriptionProvider.notifier);
      var plans = ref.read(xboardSubscriptionProvider);
      if (plans.isEmpty) {
        await planNotifier.loadPlans();
        plans = ref.read(xboardSubscriptionProvider);
      }

      DomainPlan? currentPlan =
          plans.where((plan) => plan.id == currentPlanId).firstOrNull;
      currentPlan ??= await planNotifier.loadPlanById(currentPlanId);
      currentPlan ??= _findPlanByName(plans, currentPlanName);

      if (!context.mounted) return;
      if (currentPlan != null) {
        final planForPurchase = currentPlan;
        if (isResetTraffic) {
          await showResetTrafficOrderDialog(
            context: context,
            ref: ref,
            planId: planForPurchase.id,
            plan: planForPurchase,
          );
          return;
        }

        if (!planForPurchase.hasPrice) {
          if (!await confirmTrafficExhaustedRenewIfNeeded()) return;
          if (!context.mounted) return;
          if (isDesktop) {
            router.go('/plans');
          } else {
            router.push('/plans');
          }
          return;
        }

        if (!await confirmTrafficExhaustedRenewIfNeeded()) return;
        if (!context.mounted) return;
        if (isDesktop) {
          if (planForPurchase.isVisible) {
            router.go('/plans?planId=${planForPurchase.id}');
          } else {
            router.push('/plans/purchase', extra: planForPurchase);
          }
        } else {
          navigator.push(MaterialPageRoute(
            builder: (_) => PlanPurchasePage(
              plan: planForPurchase,
            ),
          ));
        }
        return;
      }

      if (!context.mounted) return;
      if (isResetTraffic) {
        await showResetTrafficOrderDialog(
          context: context,
          ref: ref,
          planId: currentPlanId,
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

    // 没找到套餐：跳转到套餐列表页面
    if (!await confirmTrafficExhaustedRenewIfNeeded()) return;
    if (!context.mounted) return;
    if (isDesktop) {
      router.go('/plans');
    } else {
      router.push('/plans');
    }
  }

  bool _shouldConfirmTrafficExhaustedRenew() {
    if (_getProgressValue() < 1.0) return false;
    final expiryState = _getExpiryState(subscriptionInfo?.expiredAt);
    return expiryState != _ExpiryState.expired;
  }

  DomainPlan? _findPlanByName(List<DomainPlan> plans, String? planName) {
    if (planName == null) return null;
    return plans
        .where((plan) =>
            _normalizePlanName(plan.name) == planName && plan.hasPrice)
        .firstOrNull;
  }

  String? _normalizePlanName(String? value) {
    final normalized = value?.trim().toLowerCase();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  Widget _buildUsageCard(ThemeData theme, BuildContext context, WidgetRef ref) {
    if (!_isDesktop) return _buildMobileUsageCard(theme, context, ref);

    final progress = _getProgressValue();
    final progressValue = progress.clamp(0.0, 1.0).toDouble();
    final progressColor = _getProgressColor(progress, theme);
    final progressPercentText = _formatProgressPercent(progress);
    final usedTraffic = _getUsedTraffic();
    final totalTraffic = _getTotalTraffic();
    final usedTrafficColor =
        progress >= 0.9 ? progressColor : theme.colorScheme.onSurface;
    final nextResetAt = _resolveNextResetAt(ref);
    final resetDay = _getResetDay(nextResetAt, ref);
    final planName = _resolvePlanName(ref);
    final expiredAt = _resolveExpiredAt();
    final expiryState = _getExpiryState(expiredAt);
    final expiryText = _buildExpiryText(context, expiredAt, expiryState);
    final expiryColor = _getExpiryColor(expiryState, theme);
    final isExpired = expiryState == _ExpiryState.expired;
    final shouldShowResetText = !isExpired;
    final shouldShowResetAction = progress >= 0.9 && !isExpired;

    final isDark = theme.brightness == Brightness.dark;
    final card = Container(
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surfaceContainerLow : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? theme.colorScheme.outline.withValues(alpha: 0.18)
              : const Color(0xFFEEF0F4),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF1565C0).withAlpha(15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            planName.isNotEmpty
                ? planName
                : AppLocalizations.of(context).xboardSubscription,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (expiryText != null) ...[
            const SizedBox(height: 5),
            Text(
              expiryText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: expiryColor,
                fontWeight: expiryState == _ExpiryState.normal
                    ? FontWeight.w400
                    : FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (shouldShowResetText) ...[
            const SizedBox(height: 4),
            Text(
              _buildResetText(context, nextResetAt, resetDay),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: 12),

          // ── 进度条 ──
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progressValue,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.6),
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                progressPercentText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: progressColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // ── 已用流量 ──
          Text(
            '${prefixUsedTraffic ? '${AppLocalizations.of(context).xboardUsedTraffic} ' : ''}${_formatBytes(usedTraffic)} / ${AppLocalizations.of(context).xboardTotalTraffic} ${_formatBytes(totalTraffic)}',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: usedTrafficColor,
            ),
          ),

          if (showActions) ...[
            const SizedBox(height: 14),

            // ── 续费按钮 ──
            Consumer(
              builder: (context, ref, _) => Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _handleRenewAction(context, ref),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: Text(AppLocalizations.of(context).xboardRenewPlan),
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            _getRenewButtonColor(expiryState, theme),
                        foregroundColor: Colors.white,
                        iconColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  if (shouldShowResetAction) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _handleRenewAction(context, ref,
                            isResetTraffic: true),
                        icon: const Icon(Icons.restart_alt, size: 16),
                        label: Text(
                            AppLocalizations.of(context).xboardResetTraffic),
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              _getResetButtonColor(progress, theme),
                          foregroundColor: Colors.white,
                          iconColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
    final content = topOffset > 0
        ? Padding(padding: EdgeInsets.only(top: topOffset), child: card)
        : card;
    if (fixedHeight == null) return content;
    return SizedBox(height: fixedHeight! + topOffset, child: content);
  }

  Widget _buildMobileUsageCard(
      ThemeData theme, BuildContext context, WidgetRef ref) {
    final progress = _getProgressValue();
    final progressValue = progress.clamp(0.0, 1.0).toDouble();
    final progressColor = _getProgressColor(progress, theme);
    final progressPercentText = _formatProgressPercent(progress);
    final usedTraffic = _getUsedTraffic();
    final totalTraffic = _getTotalTraffic();
    final planName = _resolvePlanName(ref);
    final expiredAt = _resolveExpiredAt();
    final nextResetAt = _resolveNextResetAt(ref);
    final resetDay = _getResetDay(nextResetAt, ref);
    final expiryState = _getExpiryState(expiredAt);
    final expiryText = _buildExpiryText(context, expiredAt, expiryState);
    final expiryColor = _getExpiryColor(expiryState, theme);
    final isExpired = expiryState == _ExpiryState.expired;
    final shouldShowResetText = !isExpired;
    final shouldShowResetAction = progress >= 0.9 && !isExpired;
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final plainTextColor = theme.colorScheme.onSurface;
    final plainSubtleColor = theme.colorScheme.onSurfaceVariant;
    final cardTextColor = usePlainBackground ? plainTextColor : Colors.white;
    final cardSubtleColor = usePlainBackground
        ? plainSubtleColor
        : Colors.white.withValues(alpha: 0.75);
    final usedTrafficColor = progress >= 0.9 ? progressColor : cardTextColor;

    final card = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: usePlainBackground
            ? (isDark ? theme.colorScheme.surfaceContainerLow : Colors.white)
            : null,
        gradient: usePlainBackground
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.primary,
                  Color.lerp(colorScheme.primary, colorScheme.tertiary, 0.45) ??
                      colorScheme.primary,
                ],
              ),
        border: usePlainBackground
            ? Border.all(
                color: isDark
                    ? theme.colorScheme.outline.withValues(alpha: 0.18)
                    : const Color(0xFFEEF0F4),
              )
            : null,
        boxShadow: usePlainBackground
            ? (isDark
                ? null
                : [
                    BoxShadow(
                      color: const Color(0xFF1565C0).withAlpha(15),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ])
            : [
                BoxShadow(
                  color: isDark
                      ? colorScheme.primary.withValues(alpha: 0.28)
                      : colorScheme.primary.withValues(alpha: 0.30),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 套餐名 ──
          Row(
            children: [
              Expanded(
                child: Text(
                  planName.isNotEmpty
                      ? planName
                      : AppLocalizations.of(context).xboardSubscription,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cardTextColor,
                    letterSpacing: 0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          if (expiryText != null) ...[
            const SizedBox(height: 4),
            Text(
              expiryText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: expiryState == _ExpiryState.normal
                    ? cardSubtleColor
                    : expiryColor,
                fontWeight: expiryState == _ExpiryState.normal
                    ? FontWeight.w400
                    : FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (shouldShowResetText) ...[
            const SizedBox(height: 3),
            Text(
              _buildResetText(context, nextResetAt, resetDay),
              style: theme.textTheme.bodySmall?.copyWith(
                color: cardSubtleColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: 10),

          // ── 进度条 ──
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progressValue,
                    backgroundColor: usePlainBackground
                        ? theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.25),
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    minHeight: 5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                progressPercentText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: progressColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            '${prefixUsedTraffic ? '${AppLocalizations.of(context).xboardUsedTraffic} ' : ''}${_formatBytes(usedTraffic)} / ${AppLocalizations.of(context).xboardTotalTraffic} ${_formatBytes(totalTraffic)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: usedTrafficColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (showActions) ...[
            const SizedBox(height: 12),
            Consumer(
              builder: (context, ref, _) => Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _handleRenewAction(context, ref),
                      style: FilledButton.styleFrom(
                        backgroundColor: usePlainBackground
                            ? _getRenewButtonColor(expiryState, theme)
                            : (expiryState == _ExpiryState.normal
                                ? Colors.white.withValues(alpha: 0.24)
                                : _getRenewButtonColor(expiryState, theme)),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: usePlainBackground
                              ? BorderSide.none
                              : BorderSide(
                                  color: Colors.white.withValues(alpha: 0.38),
                                ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.refresh, size: 16),
                          const SizedBox(width: 6),
                          Text(AppLocalizations.of(context).xboardRenewPlan),
                        ],
                      ),
                    ),
                  ),
                  if (shouldShowResetAction) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => _handleRenewAction(context, ref,
                            isResetTraffic: true),
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              _getResetButtonColor(progress, theme),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.restart_alt, size: 16),
                            const SizedBox(width: 6),
                            Text(AppLocalizations.of(context)
                                .xboardResetTraffic),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
    final content = topOffset > 0
        ? Padding(padding: EdgeInsets.only(top: topOffset), child: card)
        : card;
    if (fixedHeight == null) return content;
    return SizedBox(height: fixedHeight! + topOffset, child: content);
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String? _buildExpiryText(
      BuildContext context, DateTime? expiredAt, _ExpiryState state) {
    if (expiredAt == null) return null;
    final l10n = AppLocalizations.of(context);
    final formattedDate = _formatDate(expiredAt);
    if (state == _ExpiryState.expired) {
      return l10n.xboardExpiredOnDate(formattedDate);
    }
    final remainingDays = _naturalDaysUntil(expiredAt);
    return l10n.xboardExpiresOnWithDays(
      formattedDate,
      remainingDays < 0 ? 0 : remainingDays,
    );
  }

  _ExpiryState _getExpiryState(DateTime? expiredAt) {
    if (expiredAt == null) return _ExpiryState.normal;
    final remainingDays = _naturalDaysUntil(expiredAt);
    if (remainingDays < 0) return _ExpiryState.expired;
    if (remainingDays < 7) return _ExpiryState.expiringSoon;
    return _ExpiryState.normal;
  }

  int _naturalDaysUntil(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(date.year, date.month, date.day);
    return targetDate.difference(today).inDays;
  }

  Color _getExpiryColor(_ExpiryState state, ThemeData theme) {
    switch (state) {
      case _ExpiryState.expired:
        return XbUiStatusColor.errorByTheme(theme);
      case _ExpiryState.expiringSoon:
        return XbUiStatusColor.pendingByTheme(theme);
      case _ExpiryState.normal:
        return theme.colorScheme.onSurfaceVariant;
    }
  }

  Color _getRenewButtonColor(_ExpiryState state, ThemeData theme) {
    switch (state) {
      case _ExpiryState.expired:
        return XbUiStatusColor.errorByTheme(theme);
      case _ExpiryState.expiringSoon:
        return XbUiStatusColor.pendingByTheme(theme);
      case _ExpiryState.normal:
        return theme.colorScheme.primary;
    }
  }

  String _formatProgressPercent(double progress) {
    final percent = progress * 100;
    if (percent >= 100 || percent == percent.roundToDouble()) {
      return '${percent.round()}%';
    }
    return '${percent.toStringAsFixed(1)}%';
  }

  String _buildResetText(BuildContext context, DateTime? nextReset,
      [int? resetDay]) {
    final l10n = AppLocalizations.of(context);
    if (resetDay != null && resetDay >= 0) {
      return l10n.xboardResetTrafficInDays(resetDay);
    }
    if (nextReset == null) return l10n.xboardResetTrafficByPlanCycle;
    final days = nextReset.difference(DateTime.now()).inDays;
    final resetDays = days < 0 ? 0 : days;
    return l10n.xboardResetTrafficInDays(resetDays);
  }

  int? _getResetDay(DateTime? nextResetAt, WidgetRef ref) {
    int? parseResetDay(dynamic value) {
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    final directResetDay =
        parseResetDay(subscriptionInfo?.metadata['resetDay']);
    if (directResetDay != null) return directResetDay;

    final stateSubscription = ref.read(xboardUserProvider).subscriptionInfo;
    final stateResetDay =
        parseResetDay(stateSubscription?.metadata['resetDay']);
    if (stateResetDay != null) return stateResetDay;

    if (nextResetAt != null) {
      final days = nextResetAt.difference(DateTime.now()).inDays;
      return days < 0 ? 0 : days;
    }
    return null;
  }

  String _resolvePlanName(WidgetRef ref) {
    final directName = subscriptionInfo?.planName?.trim() ?? '';
    if (directName.isNotEmpty) return directName;

    final stateSubscription = ref.read(xboardUserProvider).subscriptionInfo;
    final stateName = stateSubscription?.planName?.trim() ?? '';
    if (stateName.isNotEmpty) return stateName;

    final planId = subscriptionInfo?.planId ??
        stateSubscription?.planId ??
        userInfo?.planId ??
        0;
    if (planId > 0) {
      final plans = ref.read(xboardSubscriptionProvider);
      final matched = plans.where((plan) => plan.id == planId).firstOrNull;
      final planName = matched?.name.trim() ?? '';
      if (planName.isNotEmpty) return planName;
    }
    return '';
  }

  DateTime? _resolveExpiredAt() {
    return subscriptionInfo?.expiredAt ??
        userInfo?.expiredAt ??
        _profileExpireDateTime();
  }

  DateTime? _resolveNextResetAt(WidgetRef ref) {
    return subscriptionInfo?.nextResetAt ??
        ref.read(xboardUserProvider).subscriptionInfo?.nextResetAt;
  }

  DateTime? _profileExpireDateTime() {
    final epochSeconds = profileSubscriptionInfo?.expire;
    if (epochSeconds == null || epochSeconds <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000);
  }

  String _formatBytes(double bytes) {
    if (bytes < 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    double size = bytes;
    int unitIndex = 0;
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    String formatted;
    if (size >= 100) {
      formatted = size.toStringAsFixed(0);
    } else if (size >= 10) {
      formatted = size.toStringAsFixed(1);
    } else {
      formatted = size.toStringAsFixed(2);
    }
    // Strip trailing zeros after decimal point (e.g. "1.00" → "1", "1.50" → "1.5")
    if (formatted.contains('.')) {
      formatted = formatted.replaceAll(RegExp(r'0+$'), '');
      if (formatted.endsWith('.')) {
        formatted = formatted.substring(0, formatted.length - 1);
      }
    }
    return '$formatted ${units[unitIndex]}';
  }

  double _getProgressValue() {
    if (profileSubscriptionInfo != null && profileSubscriptionInfo!.total > 0) {
      final used =
          profileSubscriptionInfo!.upload + profileSubscriptionInfo!.download;
      return used / profileSubscriptionInfo!.total;
    }
    return 0.0;
  }

  double _getUsedTraffic() {
    if (profileSubscriptionInfo != null) {
      return (profileSubscriptionInfo!.upload +
              profileSubscriptionInfo!.download)
          .toDouble();
    }
    return 0;
  }

  double _getTotalTraffic() {
    if (profileSubscriptionInfo != null && profileSubscriptionInfo!.total > 0) {
      return profileSubscriptionInfo!.total.toDouble();
    }
    return userInfo?.transferLimit.toDouble() ?? 0;
  }

  Color _getProgressColor(double progress, ThemeData theme) {
    if (progress >= 1.0) {
      return XbUiStatusColor.errorByTheme(theme);
    } else if (progress >= 0.9) {
      return XbUiStatusColor.pendingByTheme(theme);
    } else {
      return theme.colorScheme.primary;
    }
  }

  Color _getResetButtonColor(double progress, ThemeData theme) {
    if (progress >= 1.0) return XbUiStatusColor.errorByTheme(theme);
    if (progress >= 0.9) return XbUiStatusColor.pendingByTheme(theme);
    return theme.colorScheme.primary;
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

class _TrafficExhaustedRenewConfirmDialog extends StatelessWidget {
  const _TrafficExhaustedRenewConfirmDialog();

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _TrafficExhaustedRenewConfirmDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      shape: XbUiDialog.shape(),
      backgroundColor: XbUiDialog.background(context),
      icon: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: XbUiStatusColor.pending(context).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.shopping_bag_outlined,
          color: XbUiStatusColor.pending(context),
          size: 32,
        ),
      ),
      title: Text(
        l10n.xboardConfirmRenewPlan,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
        textAlign: TextAlign.center,
      ),
      content: Text(
        l10n.xboardTrafficExhaustedRenewConfirmContent,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
        ),
        textAlign: TextAlign.center,
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: XbUiButton.outlinedNeutral(context),
                child: Text(l10n.cancel),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: XbUiButton.filledPrimary(context).copyWith(
                  backgroundColor:
                      WidgetStatePropertyAll(XbUiStatusColor.pending(context)),
                ),
                child: Text(l10n.confirm),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
