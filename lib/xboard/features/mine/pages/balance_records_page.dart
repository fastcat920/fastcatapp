import 'package:flutter/material.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:fl_clash/xboard/features/shared/widgets/xb_error_state.dart';

class BalanceRecordsPage extends StatefulWidget {
  const BalanceRecordsPage({super.key});

  @override
  State<BalanceRecordsPage> createState() => _BalanceRecordsPageState();
}

class _BalanceRecordsPageState extends State<BalanceRecordsPage> {
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
    _load(refresh: true);
  }

  Future<void> _load({bool refresh = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final nextPage = refresh ? 1 : _page + 1;
      final result = await XBoardSDK.instance.catboard
          .getBalanceRecords(current: nextPage);
      if (!mounted) return;
      setState(() {
        if (refresh) _items.clear();
        final known = _items.map((entry) => entry.id).toSet();
        _items.addAll(result.items.where((entry) => !known.contains(entry.id)));
        _page = nextPage;
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
    return Scaffold(
      appBar: AppBar(title: Text(_t('余额明细', 'Balance records'))),
      body: !_loading && _error != null && _items.isEmpty
          ? XbErrorState(
              message: _error,
              onRetry: () => _load(refresh: true),
            )
          : RefreshIndicator(
              onRefresh: () => _load(refresh: true),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: _items.length + 1,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  if (index == _items.length) return _footer();
                  final entry = _items[index];
                  final positive = entry.amount >= 0;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: CircleAvatar(
                      child: Icon(positive ? Icons.add : Icons.remove),
                    ),
                    title: Text(_typeText(entry.type)),
                    subtitle: Text([
                      if (entry.createdAt != null)
                        MaterialLocalizations.of(context)
                            .formatFullDate(entry.createdAt!),
                      if (entry.tradeNo?.isNotEmpty == true) entry.tradeNo!,
                      if (entry.balanceAfter != null)
                        '${_t('余额', 'Balance')} ¥${(entry.balanceAfter! / 100).toStringAsFixed(2)}',
                    ].join(' · ')),
                    trailing: Text(
                      '${positive ? '+' : '-'}¥${(entry.amount.abs() / 100).toStringAsFixed(2)}',
                      style: TextStyle(
                        color: positive
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _footer() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return XbErrorState(
        message: _error,
        onRetry: _load,
        compact: true,
      );
    }
    if (_items.length < _total) {
      return TextButton(
        onPressed: _load,
        child: Text(_t('加载更多', 'Load more')),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(child: Text(_t('没有更多记录', 'No more records'))),
    );
  }

  String _typeText(String type) => switch (type) {
        'deposit' => _t('余额充值', 'Balance deposit'),
        'purchase' => _t('套餐消费', 'Plan purchase'),
        'refund' => _t('余额退回', 'Balance refund'),
        'giftcard' => _t('礼品卡兑换', 'Gift card'),
        'commission_transfer' => _t('佣金划转', 'Commission transfer'),
        'referral_reward' => _t('邀请奖励', 'Referral reward'),
        'referral_reversal' => _t('奖励撤销', 'Reward reversal'),
        'admin_adjustment' => _t('后台调整', 'Admin adjustment'),
        _ => _t('余额变动', 'Balance change'),
      };
}
