import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/xboard/features/invite/providers/invite_provider.dart';
import 'package:fl_clash/xboard/features/invite/dialogs/transfer_dialog.dart';
import 'package:fl_clash/xboard/features/invite/dialogs/withdraw_dialog.dart';
import 'package:fl_clash/xboard/features/mine/pages/ticket_page.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:fl_clash/xboard/features/shared/widgets/widgets.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:fl_clash/xboard/config/xboard_config.dart';

class InvitePage extends ConsumerStatefulWidget {
  const InvitePage({super.key});

  @override
  ConsumerState<InvitePage> createState() => _InvitePageState();
}

class _InvitePageState extends ConsumerState<InvitePage>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  bool _hasInitialized = false;
  bool _isRefreshing = false;
  late final TabController _tabController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_hasInitialized) return;
      _hasInitialized = true;
      await _doRefresh();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _doRefresh() async {
    if (_isRefreshing) return;
    if (mounted) setState(() => _isRefreshing = true);
    try {
      await ref.read(inviteProvider.notifier).refresh();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDesktop =
        Platform.isLinux || Platform.isWindows || Platform.isMacOS;
    final theme = Theme.of(context);
    final inviteState = ref.watch(inviteProvider);

    // 数据未就绪且无错误 → body 整体显示 spinner，避免任何闪烁
    final bool dataReady =
        inviteState.hasInviteData || inviteState.userInfo != null;
    final bool hasError = inviteState.errorMessage != null;

    Widget body;
    if (!dataReady && !hasError) {
      // 全屏加载中
      body = const Center(child: CircularProgressIndicator());
    } else if (!dataReady && hasError) {
      // 加载失败
      final errorContent = XbErrorState(
        message: inviteState.errorMessage!,
        onRetry: _doRefresh,
      );
      body = errorContent;
    } else {
      // 数据已就绪 → 显示完整内容
      body = RefreshIndicator(
        onRefresh: _doRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Desktop title + refresh are now in the fixed AppBar.

                    // ── 余额卡片
                    _BalanceCards(state: inviteState),
                    const SizedBox(height: 12),

                    // ── 操作按钮
                    const _ActionButtons(),
                    const SizedBox(height: 20),

                    // ── 邀请统计
                    _InviteStatsSection(
                        state: inviteState, isDesktop: isDesktop),
                    const SizedBox(height: 20),

                    // ── Tab bar
                    _buildTabBar(theme),
                    const SizedBox(height: 16),

                    // ── Tab 内容
                    _InviteCodesTabContent(
                      tabController: _tabController,
                      state: inviteState,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? null : const Color(0xFFFAFBFD),
      appBar: AppBar(
        title: Text(appLocalizations.invite),
        automaticallyImplyLeading: false,
        actions: isDesktop
            ? [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: IconButton(
                    icon: _isRefreshing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    onPressed: _isRefreshing ? null : _doRefresh,
                    tooltip: appLocalizations.refresh,
                  ),
                ),
              ]
            : null,
      ),
      body: body,
    );
  }

  Widget _buildTabBar(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
            : XbUiTokens.tabBarBackgroundLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: isDark ? theme.colorScheme.onPrimary : Colors.white,
        unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.code, size: 16),
                const SizedBox(width: 6),
                Text(appLocalizations.inviteCode),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.receipt_long_outlined, size: 16),
                const SizedBox(width: 6),
                Text(appLocalizations.commissionHistory),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 余额卡片 ──────────────────────────────────────────────────────────────────

class _BalanceCards extends StatelessWidget {
  final InviteState state;
  const _BalanceCards({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: _BalanceCard(
            title: appLocalizations.availableCommission,
            value: state.formattedAvailableCommission,
            icon: Icons.monetization_on_outlined,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _BalanceCard(
            title: appLocalizations.walletBalance,
            value: state.formattedWalletBalance,
            icon: Icons.account_balance_outlined,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _BalanceCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tintBg = theme.colorScheme.primary.withValues(
      alpha: isDark ? 0.24 : 0.12,
    );
    final iconBg = theme.colorScheme.primary.withValues(
      alpha: isDark ? 0.32 : 0.18,
    );
    final titleColor = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.78)
        : theme.colorScheme.primary.withValues(alpha: 0.88);
    final valueColor = isDark
        ? theme.colorScheme.onSurface
        : theme.colorScheme.primary.withValues(alpha: 0.96);
    final iconColor =
        isDark ? theme.colorScheme.onSurface : theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tintBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color:
              theme.colorScheme.primary.withValues(alpha: isDark ? 0.38 : 0.28),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 14, color: iconColor),
              ),
              const SizedBox(width: 5),
              Text(title, style: TextStyle(color: titleColor, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
                color: valueColor, fontSize: 24, fontWeight: XbFontWeight.bold),
          ),
        ],
      ),
    );
  }
}

// ─── 操作按钮 ──────────────────────────────────────────────────────────────────

class _ActionButtons extends ConsumerWidget {
  const _ActionButtons();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inviteState = ref.watch(inviteProvider);
    if (!inviteState.isWithdrawEnabled) {
      return SizedBox(
        width: double.infinity,
        child: _ResponsiveActionButton(
          onPressed: () => showDialog(
            context: context,
            builder: (_) => const TransferDialog(),
          ),
          icon: const Icon(Icons.swap_horiz, size: 18),
          label: appLocalizations.transferToWallet,
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _ResponsiveActionButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => const WithdrawDialog(),
                  ),
                  icon: const Icon(Icons.account_balance, size: 18),
                  label: appLocalizations.withdraw,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ResponsiveActionButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TicketPage()),
                  ),
                  icon:
                      const Icon(Icons.confirmation_number_outlined, size: 18),
                  label: appLocalizations.ticketRecords,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ResponsiveActionButton(
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const TransferDialog(),
            ),
            icon: const Icon(Icons.swap_horiz, size: 18),
            label: appLocalizations.transferToWallet,
          ),
        ),
      ],
    );
  }
}

class _ResponsiveActionButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget icon;
  final String label;

  const _ResponsiveActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  static const double _iconBreakpoint = 96;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showIcon = constraints.maxWidth >= _iconBreakpoint;
        return FilledButton(
          onPressed: onPressed,
          style: XbUiButton.filledPrimary(context).copyWith(
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showIcon) ...[
                icon,
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── 邀请统计 ──────────────────────────────────────────────────────────────────

class _InviteStatsSection extends StatelessWidget {
  final InviteState state;
  final bool isDesktop;
  const _InviteStatsSection({required this.state, required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pendingCommissionTooltip = state.isWithdrawEnabled
        ? appLocalizations.pendingCommissionTooltipCommissionBalance
        : appLocalizations.pendingCommissionTooltipWalletBalance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.bar_chart, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              appLocalizations.inviteStats,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: XbFontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 外层 build() 已确保 hasInviteData==true 才渲染本 section
        isDesktop
            ? Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: appLocalizations.totalInvites,
                      value: '${state.totalInvites}',
                      icon: Icons.people_outline,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      label: appLocalizations.commissionRate,
                      value: '${state.commissionRate.toStringAsFixed(0)}%',
                      icon: Icons.percent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      label: appLocalizations.totalCommission,
                      value: state.formattedCommission,
                      icon: Icons.savings_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      label: appLocalizations.pendingCommission,
                      value: state.formattedPendingCommission,
                      icon: Icons.hourglass_top_outlined,
                      tooltipMessage: pendingCommissionTooltip,
                      valueColor: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: appLocalizations.totalInvites,
                          value: '${state.totalInvites}',
                          icon: Icons.people_outline,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          label: appLocalizations.commissionRate,
                          value: '${state.commissionRate.toStringAsFixed(0)}%',
                          icon: Icons.percent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: appLocalizations.totalCommission,
                          value: state.formattedCommission,
                          icon: Icons.savings_outlined,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          label: appLocalizations.pendingCommission,
                          value: state.formattedPendingCommission,
                          icon: Icons.hourglass_top_outlined,
                          tooltipMessage: pendingCommissionTooltip,
                          valueColor: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final String? tooltipMessage;
  final Color? valueColor;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.tooltipMessage,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark
                ? theme.colorScheme.outline.withValues(alpha: 0.15)
                : const Color(0xFFEEF0F4)),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              if (tooltipMessage != null) ...[
                const SizedBox(width: 5),
                _StatCardTooltipButton(message: tooltipMessage!),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: XbFontWeight.bold,
              color: valueColor ?? theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCardTooltipButton extends StatelessWidget {
  final String message;

  const _StatCardTooltipButton({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    return Tooltip(
      message: message,
      triggerMode: TooltipTriggerMode.tap,
      preferBelow: false,
      showDuration: const Duration(seconds: 5),
      waitDuration: const Duration(milliseconds: 300),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withValues(alpha: 0.25),
            ),
          ),
          child: Icon(
            Icons.question_mark_rounded,
            size: 11,
            color: color,
          ),
        ),
      ),
    );
  }
}

// ─── Tab 切换内容 ──────────────────────────────────────────────────────────────

class _InviteCodesTabContent extends ConsumerStatefulWidget {
  final TabController tabController;
  final InviteState state;
  const _InviteCodesTabContent(
      {required this.tabController, required this.state});

  @override
  ConsumerState<_InviteCodesTabContent> createState() =>
      _InviteCodesTabContentState();
}

class _InviteCodesTabContentState
    extends ConsumerState<_InviteCodesTabContent> {
  int _lastTabIndex = 0;
  late final VoidCallback _tabListener;

  @override
  void initState() {
    super.initState();
    _lastTabIndex = widget.tabController.index;
    _tabListener = () {
      final idx = widget.tabController.index;
      if (mounted && idx != _lastTabIndex) {
        _lastTabIndex = idx;
        setState(() {});
      }
    };
    widget.tabController.addListener(_tabListener);
  }

  @override
  void dispose() {
    widget.tabController.removeListener(_tabListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final idx = widget.tabController.index;
    final state = widget.state;

    if (idx == 0) {
      final siteUrlAsync = ref.watch(panelSiteUrlProvider);
      final siteUrl = siteUrlAsync.valueOrNull ?? '';
      return _InviteCodesTab(state: state, ref: ref, siteUrl: siteUrl);
    } else {
      return _CommissionHistoryTab(state: state);
    }
  }
}

// ─── 邀请码列表 ────────────────────────────────────────────────────────────────

class _InviteCodesTab extends StatelessWidget {
  final InviteState state;
  final WidgetRef ref;
  final String siteUrl;
  const _InviteCodesTab(
      {required this.state, required this.ref, required this.siteUrl});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final codes = state.inviteData?.codes ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.link, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              '${appLocalizations.inviteCode} (${codes.length})',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: XbFontWeight.semibold),
            ),
            const Spacer(),
            Builder(builder: (context) {
              final btnTheme = Theme.of(context);
              final btnIsDark = btnTheme.brightness == Brightness.dark;
              return FilledButton.icon(
                onPressed: state.isGenerating
                    ? null
                    : () async {
                        final result = await ref
                            .read(inviteProvider.notifier)
                            .generateInviteCode();
                        if (!context.mounted) return;
                        if (result != null) {
                          XBoardNotification.showSuccess(
                              '${appLocalizations.inviteCodeGenerated}：${result.code}');
                        } else {
                          final errorMsg =
                              ref.read(inviteProvider).errorMessage ??
                                  appLocalizations.inviteCodeGenFailed;
                          XBoardNotification.showError(errorMsg);
                        }
                      },
                icon: state.isGenerating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.add, size: 16),
                label: DefaultTextStyle.merge(
                  style: const TextStyle(fontSize: 13),
                  child: Text(appLocalizations.generateInviteCode),
                ),
                style: XbUiButton.filledPrimary(context).copyWith(
                  minimumSize: const WidgetStatePropertyAll(Size(0, 36)),
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  ),
                  backgroundColor: btnIsDark
                      ? null
                      : WidgetStatePropertyAll(theme.colorScheme.primary),
                ),
              );
            }),
          ],
        ),
        const SizedBox(height: 12),
        if (state.isLoading && !state.hasInviteData)
          const Center(child: CircularProgressIndicator())
        else if (codes.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.link_off,
                      size: 48, color: theme.colorScheme.outline),
                  const SizedBox(height: 12),
                  Text(appLocalizations.noInviteCode,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          )
        else
          ...codes.map((code) => _InviteCodeItem(
                code: code.code,
                createdAt: code.createdAt ?? DateTime.now(),
                siteUrl: siteUrl,
              )),
      ],
    );
  }
}

class _InviteCodeItem extends StatelessWidget {
  final String code;
  final DateTime createdAt;
  final String siteUrl;
  const _InviteCodeItem(
      {required this.code, required this.createdAt, required this.siteUrl});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr =
        '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
    final baseUrl = _getSdkBaseUrl();
    final inviteUrl =
        baseUrl.isNotEmpty ? '$baseUrl/#/register?code=$code' : code;

    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? null : Colors.white,
        border: Border.all(
            color: isDark
                ? theme.colorScheme.outline.withValues(alpha: 0.2)
                : const Color(0xFFEEF0F4)),
        borderRadius: BorderRadius.circular(14),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          Icon(Icons.link, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  code,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: XbFontWeight.semibold,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(Icons.schedule,
                        size: 11, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 3),
                    Text(
                      dateStr,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  XBoardNotification.showSuccess(
                      appLocalizations.copiedToClipboard);
                },
                style: XbUiButton.textChipPrimary(context).copyWith(
                  minimumSize: const WidgetStatePropertyAll(Size(0, 28)),
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
                child: Text(
                  appLocalizations.xboardCopyInviteCode,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              const SizedBox(width: 6),
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: inviteUrl));
                  XBoardNotification.showSuccess(
                      appLocalizations.copiedToClipboard);
                },
                style: XbUiButton.textChipPrimary(context).copyWith(
                  minimumSize: const WidgetStatePropertyAll(Size(0, 28)),
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
                child: Text(
                  appLocalizations.xboardCopyInviteLink,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getSdkBaseUrl() {
    try {
      // 优先级：自定义邀请域名 > 面板站点网址(app_url) > API 域名
      final inviteDomain = XBoardConfig.inviteDomain;
      if (inviteDomain.isNotEmpty) return inviteDomain;
      if (siteUrl.isNotEmpty) return siteUrl;
      return XBoardConfig.panelUrl ?? '';
    } catch (_) {
      return '';
    }
  }
}

// ─── 返佣记录 ──────────────────────────────────────────────────────────────────

class _CommissionHistoryTab extends ConsumerWidget {
  final InviteState state;
  const _CommissionHistoryTab({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final history = state.commissionHistory;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.isLoadingHistory && history.isEmpty)
          const Center(child: CircularProgressIndicator())
        else if (history.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.history,
                      size: 48, color: theme.colorScheme.outline),
                  const SizedBox(height: 12),
                  Text(appLocalizations.noCommissionRecord,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          )
        else ...[
          ...history.map((c) {
            final dateStr =
                '${c.createdAt.year}-${c.createdAt.month.toString().padLeft(2, '0')}-${c.createdAt.day.toString().padLeft(2, '0')}';
            final statusColor =
                _commissionStatusColor(context, c.status, theme);
            final amountColor = theme.colorScheme.primary;
            final statusLabel = _commissionStatusLabel(c.status);
            final isDark = theme.brightness == Brightness.dark;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? null : Colors.white,
                border: Border.all(
                    color: isDark
                        ? theme.colorScheme.outline.withValues(alpha: 0.2)
                        : const Color(0xFFEEF0F4)),
                borderRadius: BorderRadius.circular(14),
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Row(
                children: [
                  Icon(Icons.monetization_on, color: amountColor, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '¥${c.amount.toStringAsFixed(2)}',
                          style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: XbFontWeight.bold,
                              color: amountColor),
                        ),
                        Text(
                          c.tradeNo,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateStr,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          if (state.hasMoreHistory)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 16),
              child: Center(
                child: state.isLoadingHistory
                    ? const CircularProgressIndicator()
                    : TextButton.icon(
                        onPressed: () => ref
                            .read(inviteProvider.notifier)
                            .loadNextHistoryPage(),
                        icon: const Icon(Icons.expand_more),
                        label: Text(appLocalizations.loadMore),
                      ),
              ),
            ),
        ],
      ],
    );
  }

  Color _commissionStatusColor(
      BuildContext context, int status, ThemeData theme) {
    switch (status) {
      case 0:
        return XbUiStatusColor.pending(context);
      case 1:
        return XbUiStatusColor.processing(context);
      case 2:
        return XbUiStatusColor.success(context);
      case 3:
        return XbUiStatusColor.error(context);
      default:
        return XbUiStatusColor.muted(context);
    }
  }

  String _commissionStatusLabel(int status) {
    switch (status) {
      case 0:
        return appLocalizations.pendingCommission;
      case 1:
        return appLocalizations.xboardCommissionIssuing;
      case 2:
        return appLocalizations.xboardCommissionConfirmed;
      case 3:
        return appLocalizations.unknown;
      default:
        return appLocalizations.unknown;
    }
  }
}
