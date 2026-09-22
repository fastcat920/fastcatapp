import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:fl_clash/xboard/features/shared/widgets/xb_error_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';

class BalanceRecordsPage extends StatelessWidget {
  const BalanceRecordsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    return Scaffold(
      appBar: AppBar(title: Text(zh ? '余额明细' : 'Balance records')),
      body: const SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: XbUiTokens.pagePadding,
        child: BalanceRecordsContent(),
      ),
    );
  }
}

class BalanceRecordsContent extends ConsumerStatefulWidget {
  const BalanceRecordsContent({super.key});

  @override
  ConsumerState<BalanceRecordsContent> createState() =>
      BalanceRecordsContentState();
}

class BalanceRecordsContentState extends ConsumerState<BalanceRecordsContent> {
  static const _pageSize = 10;

  final List<CatboardLedgerEntry> _items = [];
  int _page = 1;
  int _total = 0;
  bool _loading = false;
  Object? _error;

  bool get _zh => Localizations.localeOf(context).languageCode == 'zh';
  String _t(String zh, String en) => _zh ? zh : en;

  @override
  void initState() {
    super.initState();
    Future<void>(() => _load(page: 1));
  }

  Future<void> refresh() => _load(page: 1);

  Future<void> _load({required int page}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sdk = await ref.read(xboardSdkProvider.future);
      final result = await sdk.catboard.getBalanceRecords(
        current: page,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(result.items);
        _page = page;
        _total = result.total;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null && _items.isEmpty) {
      return XbErrorState(
        message: _error,
        onRetry: refresh,
        compact: true,
      );
    }
    if (_items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 12),
              Text(_t('暂无余额明细', 'No balance records')),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        ..._items.map(_recordCard),
        _pagination(),
      ],
    );
  }

  Widget _recordCard(CatboardLedgerEntry entry) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final income = entry.amount >= 0;
    final amountColor =
        income ? theme.colorScheme.primary : theme.colorScheme.error;
    final statusColor = _statusColor(entry.status);
    return Card(
      elevation: 0,
      margin: XbUiTokens.listCardGapBottom10,
      color: isDark ? null : Colors.white,
      shape: XbUiCardStyle.shape(
        context,
        radius: XbUiTokens.radiusCardCompact,
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _typeText(entry.type),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: XbUiText.cardTitle(context),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _date(entry.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _statusText(entry.status),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: statusColor,
                      fontWeight: XbFontWeight.semibold,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${income ? '+' : '-'}${_money(entry.amount.abs())}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: amountColor,
                    fontWeight: XbFontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pagination() {
    final totalPages = _total == 0 ? 1 : (_total / _pageSize).ceil();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: _t('上一页', 'Previous page'),
            onPressed:
                !_loading && _page > 1 ? () => _load(page: _page - 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          const SizedBox(width: 8),
          if (_loading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Text(
              _t('第 $_page / $totalPages 页', 'Page $_page / $totalPages'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: _t('下一页', 'Next page'),
            onPressed: !_loading && _page < totalPages
                ? () => _load(page: _page + 1)
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  String _typeText(String type) => switch (type) {
        'deposit' => _t('余额充值', 'Balance deposit'),
        'purchase' => _t('套餐消费', 'Plan purchase'),
        'refund' => _t('余额退回', 'Balance refund'),
        'giftcard' => _t('礼品卡兑换', 'Gift card redemption'),
        'commission_transfer' => _t('佣金转入', 'Commission transfer'),
        'referral_reward' => _t('邀请奖励', 'Referral reward'),
        'referral_reversal' => _t('邀请奖励冲正', 'Referral reward reversal'),
        'admin_adjustment' => _t('余额调整', 'Balance adjustment'),
        _ => _t('余额变动', 'Balance change'),
      };

  String _statusText(String status) => switch (status) {
        'pending' || 'processing' => _t('处理中', 'Processing'),
        'failed' || 'rejected' => _t('已失败', 'Failed'),
        'cancelled' || 'canceled' => _t('已取消', 'Cancelled'),
        'completed' || 'success' || 'granted' => _t('已完成', 'Completed'),
        _ => status,
      };

  Color _statusColor(String status) => switch (status) {
        'failed' || 'rejected' => Theme.of(context).colorScheme.error,
        'pending' || 'processing' => Colors.orange.shade700,
        'completed' ||
        'success' ||
        'granted' =>
          XbUiStatusColor.success(context),
        _ => Theme.of(context).colorScheme.outline,
      };

  String _money(int cents) => '¥${(cents / 100).toStringAsFixed(2)}';

  String _date(DateTime? date) => date == null
      ? '-'
      : '${date.year}-${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')} '
          '${date.hour.toString().padLeft(2, '0')}:'
          '${date.minute.toString().padLeft(2, '0')}';
}
