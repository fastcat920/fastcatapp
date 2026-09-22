import 'package:fl_clash/xboard/features/payment/widgets/coupon_entry_button.dart';
import 'package:fl_clash/xboard/features/payment/pages/order_detail_page.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:fl_clash/xboard/features/shared/widgets/xb_error_state.dart';
import 'package:fl_clash/xboard/features/subscription/providers/xboard_subscription_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:go_router/go_router.dart';

class CouponWalletPage extends ConsumerStatefulWidget {
  const CouponWalletPage({super.key});

  @override
  ConsumerState<CouponWalletPage> createState() => _CouponWalletPageState();
}

class _CouponWalletPageState extends ConsumerState<CouponWalletPage> {
  String _filter = 'available';

  bool get _zh => Localizations.localeOf(context).languageCode == 'zh';
  String _t(String zh, String en) => _zh ? zh : en;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ref.read(xboardSubscriptionProvider).isNotEmpty) return;
      // 套餐名称仅用于补充优惠券适用范围；失败不能影响钱包主体。
      ref.read(xboardSubscriptionProvider.notifier).refreshPlans().catchError(
            (_) => <dynamic>[],
          );
    });
  }

  Future<void> _load() async {
    ref.invalidate(couponWalletProvider);
    final wallet = ref.read(couponWalletProvider.future);
    try {
      await ref.read(xboardSubscriptionProvider.notifier).refreshPlans();
    } catch (_) {
      // 套餐加载失败时使用 ID 作为回退标签。
    }
    try {
      await wallet;
    } catch (_) {
      // Provider 的错误状态由页面统一展示。
    }
  }

  String _groupedStatus(String status) => switch (status) {
        'locked' => 'available',
        'revoked' || 'expired' => 'inactive',
        _ => status,
      };

  List<CatboardCoupon> _filtered(List<CatboardCoupon> coupons) => coupons
      .where((coupon) => _groupedStatus(coupon.status) == _filter)
      .toList();

  int _count(List<CatboardCoupon> coupons, String filter) =>
      coupons.where((coupon) => _groupedStatus(coupon.status) == filter).length;

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(couponWalletProvider);
    final coupons = wallet.valueOrNull ?? const <CatboardCoupon>[];
    final filtered = _filtered(coupons);
    final plans = ref.watch(xboardSubscriptionProvider);
    final planNames = {for (final plan in plans) plan.id: plan.name};

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? null
          : const Color(0xFFFAFBFD),
      appBar: AppBar(title: Text(_t('优惠券', 'Coupons'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
              children: [
                Text(
                  _t('我的优惠券', 'My coupons'),
                  style: XbUiText.sectionTitle(context).copyWith(fontSize: 22),
                ),
                const SizedBox(height: 5),
                Text(
                  _t(
                    '购买套餐时会自动推荐符合条件的优惠券，也可以手动选择其他优惠方案。',
                    'Eligible coupons are recommended automatically at checkout, and you can choose another offer.',
                  ),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 18),
                _filterBar(coupons),
                const SizedBox(height: 16),
                if (wallet.isLoading && coupons.isEmpty)
                  const SizedBox(
                    height: 260,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (wallet.hasError && coupons.isEmpty)
                  SizedBox(
                    height: 300,
                    child: XbErrorState(
                      message: wallet.error,
                      onRetry: _load,
                    ),
                  )
                else if (filtered.isEmpty)
                  _emptyState()
                else
                  ...filtered.map(
                    (coupon) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _couponCard(coupon, planNames),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _filterBar(List<CatboardCoupon> coupons) {
    final items = [
      ('available', _t('可使用', 'Available'), _count(coupons, 'available')),
      ('pending', _t('待生效', 'Upcoming'), _count(coupons, 'pending')),
      ('used', _t('已使用', 'Used'), _count(coupons, 'used')),
      ('inactive', _t('已失效', 'Inactive'), _count(coupons, 'inactive')),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return Row(
            children: [
              for (var index = 0; index < items.length; index++) ...[
                if (index > 0) const SizedBox(width: 6),
                Expanded(
                  child: _chip(
                    items[index].$1,
                    items[index].$2,
                    items[index].$3,
                    fillWidth: true,
                  ),
                ),
              ],
            ],
          );
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _chip(item.$1, item.$2, item.$3),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _chip(
    String value,
    String label,
    int count, {
    bool fillWidth = false,
  }) {
    final chip = ChoiceChip(
      selected: _filter == value,
      showCheckmark: false,
      labelPadding: EdgeInsets.symmetric(horizontal: fillWidth ? 2 : 6),
      label: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text('$label $count', maxLines: 1),
      ),
      onSelected: (_) => setState(() => _filter = value),
    );
    return fillWidth ? SizedBox(width: double.infinity, child: chip) : chip;
  }

  Widget _emptyState() => Container(
        height: 220,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Text(_t('暂无此类优惠券', 'No coupons in this category')),
      );

  Widget _couponCard(
    CatboardCoupon coupon,
    Map<int, String> planNames,
  ) {
    final inactive =
        const {'used', 'expired', 'revoked'}.contains(coupon.status);
    return Opacity(
      opacity: inactive ? 0.62 : 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 680;
          final content = _couponContent(
            coupon,
            planNames,
            mobile: !wide,
          );
          final value = _couponValuePanel(coupon, mobile: !wide);
          final action = _couponAction(coupon);

          return Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            elevation: Theme.of(context).brightness == Brightness.dark ? 0 : 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: wide
                ? IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        value,
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: content,
                          ),
                        ),
                        if (action != null)
                          SizedBox(
                            width: 120,
                            child: Center(child: action),
                          ),
                      ],
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      value,
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                        child: content,
                      ),
                      if (action != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          child: SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: action,
                          ),
                        ),
                    ],
                  ),
          );
        },
      ),
    );
  }

  Widget? _couponAction(CatboardCoupon coupon) {
    if (coupon.status == 'available') {
      return FilledButton(
        onPressed: () => context.go('/plans'),
        child: Text(_t('去使用', 'Use now')),
      );
    }
    if (coupon.status == 'locked') {
      final tradeNo = coupon.lockedTradeNo?.trim();
      return FilledButton(
        onPressed:
            tradeNo?.isNotEmpty == true ? () => _viewLockedOrder(coupon) : null,
        child: Text(_t('查看', 'View')),
      );
    }
    return null;
  }

  Future<void> _viewLockedOrder(CatboardCoupon coupon) async {
    final tradeNo = coupon.lockedTradeNo?.trim();
    if (tradeNo == null || tradeNo.isEmpty) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OrderDetailPage(tradeNo: tradeNo),
      ),
    );
    if (mounted) await _load();
  }

  Widget _couponValuePanel(CatboardCoupon coupon, {required bool mobile}) {
    final template = coupon.template;
    final value = template.discountType == 'percent'
        ? '${template.discountValue}%'
        : '¥${(template.discountValue / 100).toStringAsFixed(2)}';
    final valueText = Text(
      value,
      maxLines: 1,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onPrimary,
        fontSize: mobile ? 30 : 30,
        height: 1,
        fontWeight: FontWeight.bold,
      ),
    );
    final typeText = Text(
      template.discountType == 'percent'
          ? _t('折扣券', 'Discount coupon')
          : _t('金额券', 'Amount coupon'),
      textAlign: mobile ? TextAlign.left : TextAlign.center,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.9),
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    );
    return Container(
      width: mobile ? double.infinity : 150,
      constraints: BoxConstraints(minHeight: mobile ? 96 : 0),
      padding: EdgeInsets.symmetric(
        horizontal: mobile ? 20 : 8,
        vertical: 20,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.72),
          ],
        ),
      ),
      child: mobile
          ? Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 110),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(fit: BoxFit.scaleDown, child: valueText),
                      const SizedBox(height: 7),
                      typeText,
                    ],
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: _mobileStatusBadge(coupon.status),
                ),
              ],
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(fit: BoxFit.scaleDown, child: valueText),
                const SizedBox(height: 8),
                typeText,
              ],
            ),
    );
  }

  Widget _mobileStatusBadge(String status) => Container(
        constraints: const BoxConstraints(minHeight: 28),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          _statusText(status),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  Widget _couponContent(
    CatboardCoupon coupon,
    Map<int, String> planNames, {
    required bool mobile,
  }) {
    final theme = Theme.of(context);
    final template = coupon.template;
    final description = _localized(
      template.description,
      template.descriptionEn,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              _localized(template.name, template.nameEn),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (!mobile) _statusBadge(coupon.status),
          ],
        ),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 14),
        _ruleRow(
          _t('适用套餐', 'Plans'),
          template.planIds.isEmpty
              ? [_t('全部套餐', 'All plans')]
              : template.planIds.map((id) => planNames[id] ?? '#$id').toList(),
        ),
        const SizedBox(height: 8),
        _ruleRow(
          _t('适用周期', 'Periods'),
          template.periods.isEmpty
              ? [_t('全部周期', 'All periods')]
              : template.periods.map(_periodText).toList(),
        ),
        const SizedBox(height: 8),
        _ruleRow(
          _t('使用条件', 'Conditions'),
          [
            template.firstOrderOnly
                ? _t('仅限首单', 'First order only')
                : _t('首购/续费/换购可用', 'New, renewal or plan change'),
            template.stackable
                ? _t('可叠加会员折扣', 'Stacks with membership discount')
                : _t('不可叠加会员折扣', 'Cannot stack with membership discount'),
          ],
        ),
        const SizedBox(height: 14),
        _couponMeta(coupon, mobile: mobile),
      ],
    );
  }

  Widget _couponMeta(CatboardCoupon coupon, {required bool mobile}) {
    final theme = Theme.of(context);
    final lines = [
      Text(
        '${_t('有效期', 'Valid')}: ${_date(coupon.startsAt)} – ${_date(coupon.expiresAt)}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      Text(
        '${_t('来源', 'Source')}: ${_sourceText(coupon.source)}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    ];
    if (!mobile) {
      return Wrap(spacing: 16, runSpacing: 4, children: lines);
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          lines.first,
          const SizedBox(height: 4),
          lines.last,
        ],
      ),
    );
  }

  Widget _ruleRow(String label, List<String> values) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 68,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 5,
              children: values
                  .map(
                    (value) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withValues(alpha: 0.42),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(value, style: const TextStyle(fontSize: 11)),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      );

  Widget _statusBadge(String status) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .primaryContainer
              .withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          _statusText(status),
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  String _localized(String? zh, String? en) {
    final preferred = _zh ? zh : en;
    final fallback = _zh ? en : zh;
    if (preferred?.trim().isNotEmpty == true) return preferred!.trim();
    return fallback?.trim() ?? '';
  }

  String _date(DateTime? value) => value == null
      ? '—'
      : MaterialLocalizations.of(context).formatMediumDate(value);

  String _periodText(String period) => switch (period) {
        'month_price' => _t('月付', 'Monthly'),
        'quarter_price' => _t('季度', 'Quarterly'),
        'half_year_price' => _t('半年', 'Half-year'),
        'year_price' => _t('一年', 'Yearly'),
        'two_year_price' => _t('两年', '2 years'),
        'three_year_price' => _t('三年', '3 years'),
        'onetime_price' => _t('一次性', 'One-time'),
        _ => period,
      };

  String _statusText(String status) => switch (status) {
        'available' => _t('可使用', 'Available'),
        'locked' => _t('已锁定', 'Reserved'),
        'pending' => _t('待生效', 'Upcoming'),
        'used' => _t('已使用', 'Used'),
        'expired' => _t('已过期', 'Expired'),
        'revoked' => _t('已撤销', 'Revoked'),
        _ => status,
      };

  String _sourceText(String source) => switch (source) {
        'referral_newcomer' ||
        'newcomer' =>
          _t('新人邀请奖励', 'Newcomer referral reward'),
        'distribution_task' => _t('平台批量发放', 'Platform distribution'),
        'campaign' => _t('邀请活动奖励', 'Referral campaign reward'),
        'manual' => _t('后台手动发放', 'Manual issuance'),
        _ => source.isEmpty ? '—' : source,
      };
}
