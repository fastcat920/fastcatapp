import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:fl_clash/xboard/features/payment/widgets/coupon_entry_button.dart';
import 'package:fl_clash/xboard/features/shared/widgets/xb_error_state.dart';

class CouponWalletPage extends ConsumerStatefulWidget {
  const CouponWalletPage({super.key});

  @override
  ConsumerState<CouponWalletPage> createState() => _CouponWalletPageState();
}

class _CouponWalletPageState extends ConsumerState<CouponWalletPage> {
  String _filter = 'available';

  bool get _zh => Localizations.localeOf(context).languageCode == 'zh';
  String _t(String zh, String en) => _zh ? zh : en;

  Future<void> _load() async {
    ref.invalidate(couponWalletProvider);
    try {
      await ref.read(couponWalletProvider.future);
    } catch (_) {
      // The provider exposes the error state to the page retry UI.
    }
  }

  List<CatboardCoupon> _filtered(List<CatboardCoupon> coupons) {
    return coupons.where((coupon) {
      return switch (_filter) {
        'available' => coupon.status == 'available',
        'pending' => coupon.status == 'pending',
        'used' => coupon.status == 'used' || coupon.status == 'locked',
        _ => coupon.status == 'expired' || coupon.status == 'revoked',
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(couponWalletProvider);
    final coupons = wallet.valueOrNull ?? const <CatboardCoupon>[];
    final filtered = _filtered(coupons);
    return Scaffold(
      appBar: AppBar(title: Text(_t('优惠券', 'Coupons'))),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _chip('available', _t('可使用', 'Available')),
                    _chip('pending', _t('待生效', 'Upcoming')),
                    _chip('used', _t('已使用', 'Used')),
                    _chip('inactive', _t('已失效', 'Inactive')),
                  ],
                ),
              ),
            ),
            if (wallet.isLoading && coupons.isEmpty)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (wallet.hasError && coupons.isEmpty)
              SliverFillRemaining(
                child: XbErrorState(
                  message: wallet.error,
                  onRetry: _load,
                ),
              )
            else if (filtered.isEmpty)
              SliverFillRemaining(
                child: Center(child: Text(_t('暂无优惠券', 'No coupons'))),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _couponCard(filtered[index]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String value, String label) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          selected: _filter == value,
          label: Text(label),
          onSelected: (_) => setState(() => _filter = value),
        ),
      );

  Widget _couponCard(CatboardCoupon coupon) {
    final template = coupon.template;
    final discount = template.discountType == 'percent'
        ? '${template.discountValue}% OFF'
        : '¥${(template.discountValue / 100).toStringAsFixed(2)}';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 78,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                discount,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(template.name,
                      style: Theme.of(context).textTheme.titleMedium),
                  if ((template.description ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(template.description!),
                  ],
                  const SizedBox(height: 8),
                  Text(_sourceText(coupon.source),
                      style: Theme.of(context).textTheme.bodySmall),
                  if (coupon.expiresAt != null)
                    Text(
                      '${_t('有效期至', 'Expires')} ${MaterialLocalizations.of(context).formatMediumDate(coupon.expiresAt!)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  Wrap(
                    spacing: 6,
                    children: [
                      if (template.allowRenewal)
                        Chip(label: Text(_t('支持续费', 'Renewal'))),
                      if (template.stackable)
                        Chip(label: Text(_t('可叠加会员折扣', 'Stackable'))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _sourceText(String source) => switch (source) {
        'referral_newcomer' ||
        'newcomer' =>
          _t('新人邀请奖励', 'Newcomer referral reward'),
        'distribution_task' => _t('平台发放', 'Platform distribution'),
        'campaign' => _t('邀请活动奖励', 'Referral campaign reward'),
        _ => _t('平台发放', 'Manual issuance'),
      };
}
