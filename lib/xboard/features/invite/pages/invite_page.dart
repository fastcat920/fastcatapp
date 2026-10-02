import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/features/invite/providers/invite_provider.dart';
import 'package:fl_clash/xboard/features/invite/providers/referral_program_provider.dart';
import 'package:fl_clash/xboard/features/invite/dialogs/transfer_dialog.dart';
import 'package:fl_clash/xboard/features/invite/dialogs/withdraw_dialog.dart';
import 'package:fl_clash/xboard/features/invite/widgets/adaptive_amount_text.dart';
import 'package:fl_clash/xboard/features/invite/widgets/referral_growth_card.dart';
import 'package:fl_clash/xboard/features/mine/pages/ticket_page.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:fl_clash/xboard/features/shared/widgets/widgets.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:fl_clash/xboard/config/xboard_config.dart';
import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';

part '../widgets/invite_sections.dart';

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
    _tabController = TabController(length: 3, vsync: this);
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
      await Future.wait([
        ref.read(inviteProvider.notifier).refresh(),
        ref.read(referralProgramProvider.notifier).refresh(),
      ]);
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
    final referralProgram = ref.watch(
      referralProgramProvider.select((state) => state.program),
    );

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

                    // ── 会员等级成长
                    if (referralProgram != null) ...[
                      ReferralGrowthCard(program: referralProgram),
                      const SizedBox(height: 12),
                    ],

                    // ── 余额卡片
                    _BalanceCards(state: inviteState),
                    const SizedBox(height: 12),

                    // ── 操作按钮
                    const _ActionButtons(),
                    const SizedBox(height: 20),

                    // ── 邀请统计
                    _InviteStatsSection(
                      state: inviteState,
                      isDesktop: isDesktop,
                      effectiveInvites: referralProgram?.effectiveInvites,
                    ),
                    const SizedBox(height: 20),

                    // ── Tab bar
                    _buildTabBar(theme),
                    const SizedBox(height: 16),

                    // ── Tab 内容
                    _InviteCodesTabContent(
                      tabController: _tabController,
                      state: inviteState,
                      rewardRestrictionPolicy:
                          referralProgram?.rewardRestrictionPolicy,
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
                const Icon(Icons.group_outlined, size: 16),
                const SizedBox(width: 6),
                Text(_copy(context, '邀请用户', 'Users')),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.receipt_long_outlined, size: 16),
                const SizedBox(width: 6),
                Text(_copy(context, '佣金记录', 'Commission records')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
