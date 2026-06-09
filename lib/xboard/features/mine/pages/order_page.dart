import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/adapter/state/order_state.dart';
import 'package:fl_clash/xboard/features/payment/pages/order_detail_page.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:fl_clash/common/common.dart';

class OrderPage extends ConsumerStatefulWidget {
  const OrderPage({super.key});

  @override
  ConsumerState<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends ConsumerState<OrderPage>
    with SingleTickerProviderStateMixin {
  @override
  void activate() {
    super.activate();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
  }

  late final AnimationController _refreshAnim;

  @override
  void initState() {
    super.initState();
    _refreshAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  @override
  void dispose() {
    _refreshAnim.dispose();
    super.dispose();
  }

  Future<void> _doRefresh() async {
    _refreshAnim.repeat();
    try {
      clearGetOrdersCache();
      ref.invalidate(getOrdersProvider);
      await ref.read(getOrdersProvider.future);
    } catch (_) {}
    if (mounted) {
      final remaining = 1.0 - _refreshAnim.value;
      if (remaining > 0.01) {
        await _refreshAnim.animateTo(
          1.0,
          duration: Duration(milliseconds: (remaining * 700).round()),
        );
      }
      _refreshAnim.stop();
      _refreshAnim.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(getOrdersProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? null : XbUiTokens.pageBackgroundLight,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).xboardOrderRecords),
        actions: [
          if (Platform.isLinux ||
              Platform.isWindows ||
              Platform.isMacOS ||
              system.isTV)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _doRefresh,
              ),
            ),
        ],
      ),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          message: e.toString(),
          onRetry: _doRefresh,
        ),
        data: (orders) => orders.isEmpty
            ? _EmptyView()
            : RefreshIndicator(
                onRefresh: _doRefresh,
                child: ListView.builder(
                  padding: XbUiTokens.pagePadding,
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return _OrderCard(
                      order: order,
                      onTap: order.tradeNo == null || order.tradeNo!.isEmpty
                          ? null
                          : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => OrderDetailPage(
                                    tradeNo: order.tradeNo!,
                                    discountAmount: order.couponPrice != null
                                        ? order.couponPrice! / 100
                                        : order.discountAmount != null
                                            ? order.discountAmount! / 100
                                            : null,
                                  ),
                                ),
                              ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 56, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(AppLocalizations.of(context).xboardLoadingFailed,
                style: XbUiText.sectionTitle(context)),
            const SizedBox(height: 6),
            Text(message,
                style: XbUiText.bodySmall(context),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 16),
            FilledButton(
                onPressed: onRetry,
                child: Text(AppLocalizations.of(context).xboardRetry)),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text(AppLocalizations.of(context).xboardNoOrderRecords,
              style: XbUiText.sectionTitle(context).copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback? onTap;

  const _OrderCard({
    required this.order,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(context, order.status);
    final statusLabel = _statusLabel(order.status, context);
    final isDeposit = order.period == 'deposit';
    final planName = isDeposit
        ? AppLocalizations.of(context).xboardRechargeBalance
        : (order.orderPlan?.name ??
            AppLocalizations.of(context).xboardUnknownPlan);
    final period = _formatPeriod(order.period, context);
    final amount = (order.totalAmount ?? 0.0) / 100;

    final isDark = theme.brightness == Brightness.dark;
    return Card(
      elevation: 0,
      margin: XbUiTokens.listCardGapBottom10,
      color: isDark ? null : Colors.white,
      shape: XbUiCardStyle.shape(context, radius: XbUiTokens.radiusCardCompact),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 套餐名 + 状态
              Row(
                children: [
                  Expanded(
                    child: Text(
                      planName,
                      style: XbUiText.cardTitle(context),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      statusLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (onTap != null) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              // 周期 + 金额
              Row(
                children: [
                  Icon(Icons.access_time_outlined,
                      size: 14, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(period,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                  const Spacer(),
                  Text(
                    '¥ ${amount.toStringAsFixed(2)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              // 创建时间
              if (order.createdAt != null) ...[
                const SizedBox(height: 6),
                Text(
                  _formatDate(order.createdAt!),
                  style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.45)),
                ),
              ],
              // 订单号
              if (order.tradeNo != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${AppLocalizations.of(context).xboardOrderNumber}: ${order.tradeNo}',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      fontSize: 11),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(BuildContext context, int? status) {
    switch (status) {
      case 0:
        return XbUiStatusColor.pending(context);
      case 1:
        return XbUiStatusColor.info(context);
      case 2:
        return XbUiStatusColor.error(context);
      case 3:
        return XbUiStatusColor.success(context);
      case 4:
        return XbUiStatusColor.offset(context);
      default:
        return XbUiStatusColor.muted(context);
    }
  }

  String _statusLabel(int? status, BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (status) {
      case 0:
        return l10n.xboardOrderStatusPending;
      case 1:
        return l10n.xboardOrderStatusOpening;
      case 2:
        return l10n.xboardOrderStatusCancelled;
      case 3:
        return l10n.xboardOrderStatusCompleted;
      case 4:
        return l10n.xboardOrderStatusOffset;
      default:
        return l10n.unknown;
    }
  }

  String _formatPeriod(String? period, BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (period) {
      case 'month_price':
        return l10n.xboardMonthlyPayment;
      case 'quarter_price':
        return l10n.xboardQuarterlyPayment;
      case 'half_year_price':
        return l10n.xboardHalfYearlyPayment;
      case 'year_price':
        return l10n.xboardYearlyPayment;
      case 'two_year_price':
        return l10n.xboardTwoYearPayment;
      case 'three_year_price':
        return l10n.xboardThreeYearPayment;
      case 'onetime_price':
        return l10n.xboardOneTimePayment;
      case 'reset_price':
        return l10n.xboardResetTraffic;
      case 'deposit':
        return l10n.xboardRecharge;
      default:
        return period ?? l10n.xboardUnknownPeriod;
    }
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')} '
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}
