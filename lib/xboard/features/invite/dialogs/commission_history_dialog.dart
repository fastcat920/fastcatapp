import 'package:fl_clash/xboard/domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/xboard/features/invite/providers/invite_provider.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';

class CommissionHistoryDialog extends ConsumerStatefulWidget {
  const CommissionHistoryDialog({super.key});

  @override
  ConsumerState<CommissionHistoryDialog> createState() => _CommissionHistoryDialogState();
}

class _CommissionHistoryDialogState extends ConsumerState<CommissionHistoryDialog>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late final AnimationController _refreshAnim;

  @override
  void initState() {
    super.initState();
    _refreshAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _refreshAnim.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _doRefresh() async {
    _refreshAnim.repeat();
    try {
      await ref.read(inviteProvider.notifier).refreshCommissionHistory();
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

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      final inviteState = ref.read(inviteProvider);
      if (inviteState.hasMoreHistory && !inviteState.isLoadingHistory) {
        ref.read(inviteProvider.notifier).loadNextHistoryPage();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inviteState = ref.watch(inviteProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      shape: XbUiDialog.shape(),
      backgroundColor: XbUiDialog.background(context),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            appLocalizations.commissionHistory,
            style: XbUiText.sectionTitle(context),
          ),
          RotationTransition(
            turns: _refreshAnim,
            child: IconButton(
              onPressed: _doRefresh,
              icon: const Icon(Icons.refresh),
              tooltip: appLocalizations.refresh,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    appLocalizations.totalRecords(inviteState.commissionHistory.length),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    appLocalizations.pageNumber(inviteState.currentHistoryPage),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: inviteState.commissionHistory.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.history, size: 48, color: Colors.grey),
                          const SizedBox(height: 8),
                          Text(appLocalizations.noCommissionRecord, style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: inviteState.commissionHistory.length + (inviteState.hasMoreHistory ? 1 : 0),
                      itemBuilder: (buildContext, index) {
                        if (index >= inviteState.commissionHistory.length) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            child: Center(
                              child: inviteState.isLoadingHistory
                                  ? Column(
                                      children: [
                                        const CircularProgressIndicator(),
                                        const SizedBox(height: 8),
                                        Text(appLocalizations.loading, style: const TextStyle(color: Colors.grey)),
                                      ],
                                    )
                                  : TextButton.icon(
                                      onPressed: () => ref.read(inviteProvider.notifier).loadNextHistoryPage(),
                                      icon: const Icon(Icons.expand_more),
                                      label: Text(appLocalizations.loadMore),
                                    ),
                            ),
                          );
                        }

                        final commission = inviteState.commissionHistory[index];
                        return _buildCommissionItem(commission, isDark);
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: XbUiButton.outlinedNeutral(context),
          child: Text(appLocalizations.close),
        ),
      ],
    );
  }

  Widget _buildCommissionItem(DomainCommission commission, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? null : Colors.white,
        border: Border.all(
          color: isDark ? Colors.grey.shade200 : const Color(0xFFEEF0F4),
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: isDark ? null : const [
          BoxShadow(
            color: Color(0x0A1565C0),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.monetization_on,
            color: Colors.green[600],
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¥${commission.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  appLocalizations.orderNumber(commission.tradeNo),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${commission.createdAt.year}-${commission.createdAt.month.toString().padLeft(2, '0')}-${commission.createdAt.day.toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
