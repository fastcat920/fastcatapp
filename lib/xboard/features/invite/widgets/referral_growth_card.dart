import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';

class ReferralGrowthCard extends StatelessWidget {
  const ReferralGrowthCard({super.key, required this.program});

  final CatboardReferralProgram program;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: isDark ? theme.colorScheme.surfaceContainerLow : Colors.white,
      shape: XbUiCardStyle.shape(context, radius: 20),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CurrentLevelBlock(program: program),
          Divider(
            height: 1,
            color: isDark ? null : XbUiTokens.dividerLight,
          ),
          if (program.nextLevel != null)
            _NextLevelBlock(program: program)
          else
            Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                _t(context, '您已达到最高成长等级',
                    'You have reached the highest growth level'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CurrentLevelBlock extends StatelessWidget {
  const _CurrentLevelBlock({required this.program});

  final CatboardReferralProgram program;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final level = program.level;
    final levelName =
        _localizedName(context, level) ?? _t(context, '普通会员', 'Member');
    final discount = _asInt(level?['member_discount']);
    final levelNameColor = isDark
        ? theme.colorScheme.onSurface
        : theme.colorScheme.primary.withValues(alpha: 0.96);
    return Container(
      color: theme.colorScheme.primary.withValues(
        alpha: isDark ? 0.24 : 0.12,
      ),
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final title = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.workspace_premium_rounded,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  levelName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: levelNameColor,
                    fontWeight: XbFontWeight.bold,
                  ),
                ),
              ),
            ],
          );
          final benefits = Wrap(
            spacing: 18,
            runSpacing: 6,
            children: [
              _InlineValue(
                label: _t(context, '佣金比例', 'Commission rate'),
                value: '${program.commissionRate}%',
              ),
              _InlineValue(
                label: _t(context, '套餐优惠', 'Plan discount'),
                value: '$discount%',
              ),
            ],
          );
          if (constraints.maxWidth < 430) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                const SizedBox(height: 12),
                benefits,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: title),
              const SizedBox(width: 16),
              benefits,
            ],
          );
        },
      ),
    );
  }
}

class _NextLevelBlock extends StatelessWidget {
  const _NextLevelBlock({required this.program});

  final CatboardReferralProgram program;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final level = program.nextLevel!;
    final reward = program.nextLevelReward;
    final name = _localizedName(context, level) ?? '-';
    final requiredInvites = _asInt(level['required_invites']);
    final requiredRevenue = _asInt(level['required_revenue']);
    final inviteProgress =
        requiredInvites <= 0 ? 1.0 : program.effectiveInvites / requiredInvites;
    final revenueProgress =
        requiredRevenue <= 0 ? 1.0 : program.referralRevenue / requiredRevenue;
    final progress = [inviteProgress, revenueProgress]
        .reduce((left, right) => left < right ? left : right)
        .clamp(0.0, 1.0)
        .toDouble();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '${_t(context, '下一等级', 'Next level')}：'),
                      TextSpan(
                        text: name,
                        style: const TextStyle(fontWeight: XbFontWeight.bold),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: 12),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${_t(context, '有效邀请数', 'Effective invites')} ',
                    ),
                    TextSpan(
                      text: '${program.effectiveInvites} / $requiredInvites',
                      style: const TextStyle(fontWeight: XbFontWeight.bold),
                    ),
                  ],
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: progress),
          if (reward != null) ...[
            const SizedBox(height: 12),
            _MetaRow(
              label: _t(context, '达标奖励：', 'Achievement reward:'),
              child: Wrap(
                spacing: 18,
                runSpacing: 6,
                children: [
                  _InlineValue(
                    label: _rewardLabel(context, reward),
                    value: _rewardValue(context, reward),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          _MetaRow(
            label: _t(context, '等级特权：', 'Level privileges:'),
            child: Wrap(
              spacing: 18,
              runSpacing: 6,
              children: [
                _InlineValue(
                  label: _t(context, '佣金比例', 'Commission rate'),
                  value: '${_asInt(level['commission_rate'])}%',
                ),
                _InlineValue(
                  label: _t(context, '套餐优惠', 'Plan discount'),
                  value: '${_asInt(level['member_discount'])}%',
                ),
              ],
            ),
          ),
          if (requiredRevenue > 0) ...[
            const SizedBox(height: 12),
            Text(
              '${_t(context, '邀请成交额', 'Referral revenue')}：'
              '${_money(program.referralRevenue)} / ${_money(requiredRevenue)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InlineValue extends StatelessWidget {
  const _InlineValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$label：'),
            TextSpan(
              text: value,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: XbFontWeight.bold,
              ),
            ),
          ],
        ),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      );
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: XbFontWeight.semibold,
                ),
          ),
          const SizedBox(width: 6),
          Expanded(child: child),
        ],
      );
}

String _rewardLabel(BuildContext context, Map<String, dynamic> reward) {
  final type = reward['reward_type']?.toString();
  return switch (type) {
    'traffic' => _t(context, '流量', 'Traffic'),
    'duration' => _t(context, '套餐时长', 'Plan duration'),
    'commission_balance' => _t(context, '推广佣金', 'Commission'),
    _ => _t(context, '账户余额', 'Balance'),
  };
}

String _rewardValue(BuildContext context, Map<String, dynamic> reward) {
  final type = reward['reward_type']?.toString();
  final value = _asInt(reward['reward_value']);
  return switch (type) {
    'traffic' => '$value GB',
    'duration' => _t(context, '$value 天', '$value days'),
    _ => _money(value),
  };
}

String _t(BuildContext context, String chinese, String english) =>
    Localizations.localeOf(context).languageCode == 'zh' ? chinese : english;

String? _localizedName(BuildContext context, Map<String, dynamic>? item) {
  if (item == null) return null;
  final zh = Localizations.localeOf(context).languageCode == 'zh';
  final preferred = item[zh ? 'name' : 'name_en']?.toString().trim();
  if (preferred?.isNotEmpty == true) return preferred;
  return (item['name'] ?? item['name_en'])?.toString();
}

int _asInt(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

String _money(int cents) => '¥${(cents / 100).toStringAsFixed(2)}';
