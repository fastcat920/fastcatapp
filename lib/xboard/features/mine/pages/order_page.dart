import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';
import 'package:fl_clash/xboard/adapter/state/order_state.dart';
import 'package:fl_clash/xboard/features/payment/pages/order_detail_page.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:fl_clash/common/common.dart';

class OrderPage extends ConsumerStatefulWidget {
  const OrderPage({super.key});

  @override
  ConsumerState<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends ConsumerState<OrderPage> {
  final _scrollController = ScrollController();
  final _orders = <OrderModel>[];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  Object? _error;
  int _total = 0;
  static const _pageSize = 30;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isLoadingMore || !_hasMore) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (maxScroll - currentScroll < 200) {
      _loadNextPage();
    }
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final sdk = await ref.read(xboardSdkProvider.future);
      final result =
          await sdk.order.getOrdersPage(page: 1, pageSize: _pageSize);
      if (!mounted) return;
      setState(() {
        _orders.clear();
        _orders.addAll(result.orders);
        _currentPage = 1;
        _total = result.total;
        _hasMore = _orders.length < _total;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadNextPage() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final sdk = await ref.read(xboardSdkProvider.future);
      final result = await sdk.order.getOrdersPage(
        page: _currentPage + 1,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _orders.addAll(result.orders);
        _currentPage++;
        _hasMore = _orders.length < result.total;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _doRefresh() async {
    clearGetOrdersCache();
    await _loadFirstPage();
  }

  @override
  Widget build(BuildContext context) {
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
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _ErrorView(
        message: _error.toString(),
        onRetry: _loadFirstPage,
      );
    }
    if (_orders.isEmpty) {
      return const _EmptyView();
    }
    return RefreshIndicator(
      onRefresh: _doRefresh,
      child: ListView.builder(
        controller: _scrollController,
        padding: XbUiTokens.pagePadding,
        itemCount: _orders.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _orders.length) {
            return _LoadingMoreIndicator(isLoadingMore: _isLoadingMore);
          }
          final order = _orders[index];
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
    );
  }
}

class _LoadingMoreIndicator extends StatelessWidget {
  final bool isLoadingMore;
  const _LoadingMoreIndicator({required this.isLoadingMore});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: isLoadingMore
              ? const CircularProgressIndicator(strokeWidth: 2)
              : null,
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
  const _EmptyView();

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

  const _OrderCard({required this.order, this.onTap});

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
              Row(
                children: [
                  Expanded(
                    child: Text(planName, style: XbUiText.cardTitle(context)),
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
                    Icon(Icons.chevron_right,
                        size: 20, color: theme.colorScheme.onSurfaceVariant),
                  ],
                ],
              ),
              const SizedBox(height: 8),
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
              if (order.createdAt != null) ...[
                const SizedBox(height: 6),
                Text(
                  _formatDate(order.createdAt!),
                  style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.45)),
                ),
              ],
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
