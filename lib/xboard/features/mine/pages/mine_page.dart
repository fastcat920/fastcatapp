import 'dart:async';
import 'dart:io';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart' as fl_models;
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/features/auth/auth.dart';
import 'package:fl_clash/xboard/features/auth/utils/customer_service_helper.dart';
import 'package:fl_clash/xboard/domain/domain.dart';
import 'package:fl_clash/xboard/config/xboard_config.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fl_clash/xboard/features/settings/pages/fastcat_settings_page.dart';
import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';
import 'package:fl_clash/xboard/features/subscription/widgets/subscription_usage_card.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'order_page.dart';
import 'gift_card_page.dart';
import 'ticket_page.dart';
import 'package:fl_clash/xboard/features/docs/pages/docs_page.dart';
import 'package:fl_clash/xboard/features/payment/pages/recharge_page.dart';
import 'package:fl_clash/xboard/features/update_check/providers/update_check_provider.dart';
import 'package:fl_clash/xboard/features/about/pages/fastcat_about_page.dart';

class MinePage extends ConsumerStatefulWidget {
  const MinePage({super.key});

  @override
  ConsumerState<MinePage> createState() => _MinePageState();
}

class _MinePageState extends ConsumerState<MinePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _refreshAnim;
  StreamSubscription? _configSub;
  bool _isOpeningCustomerService = false;

  @override
  void initState() {
    super.initState();
    _refreshAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _configSub = XBoardConfig.configChangeStream.listen((_) {
      CustomerServiceHelper.prewarm();
      if (mounted) setState(() {});
    });
    CustomerServiceHelper.prewarm();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(xboardUserProvider.notifier).ensureUserSnapshotLoaded();
      CustomerServiceHelper.prewarm();
    });
  }

  @override
  void dispose() {
    _configSub?.cancel();
    _refreshAnim.dispose();
    super.dispose();
  }

  Future<void> _doRefresh() async {
    _refreshAnim.repeat();
    try {
      await ref.read(xboardUserAuthProvider.notifier).refreshUserInfo();
    } finally {
      // 补完当前整圈后停止，避免猛然定格
      if (_refreshAnim.isAnimating) {
        final remaining = 1.0 - (_refreshAnim.value % 1.0);
        await _refreshAnim.animateTo(
          _refreshAnim.value + remaining,
          duration: Duration(
            milliseconds: (remaining * 700).round(),
          ),
        );
        _refreshAnim.stop();
        _refreshAnim.reset();
      }
    }
  }

  Widget _buildRefreshButton() {
    return RotationTransition(
      turns: _refreshAnim,
      child: IconButton(
        icon: const Icon(Icons.refresh),
        onPressed: _doRefresh,
      ),
    );
  }

  Widget _buildCustomerServiceButton(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return TextButton.icon(
      style: XbUiButton.textChipPrimary(context),
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: _isOpeningCustomerService
            ? SizedBox(
                key: const ValueKey('opening'),
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(primary),
                ),
              )
            : Icon(
                Icons.support_agent_outlined,
                key: const ValueKey('support'),
                size: 18,
                color: primary,
              ),
      ),
      label: Text(
        appLocalizations.contactSupport,
        style: TextStyle(color: primary),
      ),
      onPressed: _isOpeningCustomerService
          ? null
          : () => _openCustomerService(context),
    );
  }

  Future<void> _openCustomerService(BuildContext context) async {
    if (_isOpeningCustomerService) return;
    setState(() => _isOpeningCustomerService = true);
    try {
      await CustomerServiceHelper.open(context);
    } finally {
      if (mounted) {
        setState(() => _isOpeningCustomerService = false);
      }
    }
  }

  Widget _buildAccountInfoCard(
    BuildContext context,
    UserAuthState userState,
    DomainUser? userInfo,
    DomainSubscription? subscriptionInfo,
    ThemeData theme,
    bool isDark,
  ) {
    final email = userState.email ??
        userInfo?.email ??
        userState.userInfo?.email ??
        subscriptionInfo?.email ??
        userState.subscriptionInfo?.email ??
        '';
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      elevation: isDark ? 0 : 1,
      shadowColor: isDark ? null : Colors.black.withValues(alpha: 0.08),
      color: isDark ? theme.colorScheme.surfaceContainerLow : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: isDark
            ? BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.18),
                width: 1,
              )
            : const BorderSide(color: Color(0xFFEEF0F4), width: 1),
      ),
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.person_outline,
              color: theme.colorScheme.primary, size: 20),
        ),
        title: Text(
          appLocalizations.xboardAccountInfo,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: XbFontWeight.semibold,
          ),
        ),
        subtitle: Text(
          email.isEmpty ? '—' : email,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(Icons.chevron_right,
            color: isDark
                ? theme.colorScheme.onSurfaceVariant
                : XbUiTokens.chevronLight),
        onTap: () => context.push('/mine/account'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),
    );
  }

  Widget _buildSubscriptionSection(
    BuildContext context,
    DomainSubscription? subscriptionInfo,
    DomainUser? userInfo,
    fl_models.SubscriptionInfo? profileSubscriptionInfo,
  ) {
    return SubscriptionUsageCard(
      subscriptionInfo: subscriptionInfo,
      userInfo: userInfo,
      profileSubscriptionInfo: profileSubscriptionInfo,
      showActions: true,
      usePlainBackground: true,
      prefixUsedTraffic: true,
      topOffset: 12,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = AppLocalizations.of(context);
    final userState = ref.watch(xboardUserProvider);
    final subscriptionInfo =
        ref.watch(subscriptionInfoProvider) ?? userState.subscriptionInfo;
    final userInfo = ref.watch(userInfoProvider) ?? userState.userInfo;
    final currentProfile = ref.watch(currentProfileProvider);
    final isDesktop = Platform.isLinux ||
        Platform.isWindows ||
        Platform.isMacOS ||
        system.isTV;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final updateState = ref.watch(updateCheckProvider);
    fl_models.SubscriptionInfo? profileSubscriptionInfo =
        currentProfile?.subscriptionInfo;
    if (profileSubscriptionInfo == null &&
        subscriptionInfo != null &&
        subscriptionInfo.planId > 0) {
      profileSubscriptionInfo = fl_models.SubscriptionInfo(
        upload: subscriptionInfo.uploadedBytes,
        download: subscriptionInfo.downloadedBytes,
        total: subscriptionInfo.transferLimit,
        expire: subscriptionInfo.expiredAt != null
            ? subscriptionInfo.expiredAt!.millisecondsSinceEpoch ~/ 1000
            : 0,
      );
    }

    return Scaffold(
      backgroundColor: isDark ? null : const Color(0xFFFAFBFD),
      appBar: AppBar(
        title: Text(appLocalizations.userCenter),
        automaticallyImplyLeading: false,
        actions: [
          if (!isDesktop)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _buildCustomerServiceButton(context),
            ),
          if (isDesktop) ...[
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _buildCustomerServiceButton(context),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _buildRefreshButton(),
            ),
          ],
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _doRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          children: [
// Desktop title + actions are now in the fixed AppBar.
            _buildAccountInfoCard(
              context,
              userState,
              userInfo,
              subscriptionInfo,
              theme,
              isDark,
            ),
            const SizedBox(height: 8),
            _buildSubscriptionSection(
              context,
              subscriptionInfo,
              userInfo,
              profileSubscriptionInfo,
            ),
            const SizedBox(height: 16),
            _buildSectionHeader(appLocalizations.xboardMyServices, theme),
            _buildServicesCard(context, ref, userInfo, theme, isDark),
            const SizedBox(height: 16),
            _buildSectionHeader(appLocalizations.xboardSoftwareSettings, theme),
            _buildSettingsCard(context, isDesktop, theme, isDark),
            const SizedBox(height: 20),
            _buildVersionFooter(
              context,
              version: globalState.packageInfo.version,
              hasUpdate: updateState.hasUpdate,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionFooter(
    BuildContext context, {
    required String version,
    required bool hasUpdate,
  }) {
    final theme = Theme.of(context);
    return Center(
      child: XbPointerCursor(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const FastCatAboutPage(),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  appLocalizations.updateCheckCurrentVersion('V$version'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (hasUpdate) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── 服务卡片（订单/流量/工单/客服/官网/群组） ───────────────────────────────

  Widget _buildServicesCard(BuildContext context, WidgetRef ref,
      DomainUser? userInfo, ThemeData theme, bool isDark) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      elevation: isDark ? 0 : 1,
      shadowColor: isDark ? null : Colors.black.withValues(alpha: 0.08),
      color: isDark ? theme.colorScheme.surfaceContainerLow : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: isDark
            ? BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.18),
                width: 1,
              )
            : const BorderSide(color: Color(0xFFEEF0F4), width: 1),
      ),
      child: Column(
        children: [
          if (XBoardConfig.isOrdersEnabled) ...[
            _tile(
              icon: Icons.receipt_long_outlined,
              label: appLocalizations.xboardOrderRecords,
              iconColor: theme.colorScheme.primary,
              iconBgColor: theme.colorScheme.primary.withValues(alpha: 0.1),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const OrderPage()),
              ),
            ),
            _divider(),
          ],
          if (XBoardConfig.isDevicesEnabled) ...[
            _tile(
              icon: Icons.devices_outlined,
              label: appLocalizations.xboardDeviceManagement,
              iconColor: theme.colorScheme.primary,
              iconBgColor: theme.colorScheme.primary.withValues(alpha: 0.1),
              onTap: () => context.go('/mine/devices'),
            ),
            _divider(),
          ],
          if (XBoardConfig.isTrafficDetailsEnabled) ...[
            _tile(
              icon: Icons.data_usage_outlined,
              label: appLocalizations.xboardTrafficDetails,
              iconColor: theme.colorScheme.primary,
              iconBgColor: theme.colorScheme.primary.withValues(alpha: 0.1),
              onTap: () => context.go('/mine/subscription'),
            ),
            _divider(),
          ],
          // 余额充值：features.balance_enabled 开关 + 仅 v2board 面板支持
          if (XBoardConfig.isBalanceEnabled &&
              XBoardConfig.isInitialized &&
              XBoardConfig.provider.getPanelType() != 'xboard') ...[
            _tile(
              icon: Icons.account_balance_wallet_outlined,
              label: appLocalizations.walletBalance,
              iconColor: theme.colorScheme.primary,
              iconBgColor: theme.colorScheme.primary.withValues(alpha: 0.1),
              trailingText: appLocalizations.xboardBalanceWithAmount(
                  (userInfo?.balanceInYuan ?? 0).toStringAsFixed(2)),
              onTap: () async {
                final result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const RechargePage()),
                );
                if (result == true) {
                  ref.read(xboardUserAuthProvider.notifier).refreshUserInfo();
                }
              },
            ),
            _divider(),
          ],
          if (XBoardConfig.isTicketsEnabled) ...[
            _tile(
              icon: Icons.confirmation_number_outlined,
              label: appLocalizations.xboardMyTickets,
              iconColor: theme.colorScheme.primary,
              iconBgColor: theme.colorScheme.primary.withValues(alpha: 0.1),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TicketPage()),
              ),
            ),
            _divider(),
          ],
          if (XBoardConfig.isKnowledgeBaseEnabled) ...[
            _tile(
              icon: Icons.menu_book_outlined,
              label: appLocalizations.xboardDocsCenter,
              iconColor: theme.colorScheme.primary,
              iconBgColor: theme.colorScheme.primary.withValues(alpha: 0.1),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DocsPage()),
              ),
            ),
            _divider(),
          ],
          if (XBoardConfig.isGiftCardEnabled) ...[
            _tile(
              icon: Icons.card_giftcard_outlined,
              label: appLocalizations.xboardGiftCardRedeem,
              iconColor: theme.colorScheme.primary,
              iconBgColor: theme.colorScheme.primary.withValues(alpha: 0.1),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const GiftCardPage()),
              ),
            ),
            _divider(),
          ],
          if (XBoardConfig.isJoinGroupEnabled) ...[
            _tile(
              icon: Icons.send_outlined,
              label: appLocalizations.xboardJoinGroup,
              iconColor: theme.colorScheme.primary,
              iconBgColor: theme.colorScheme.primary.withValues(alpha: 0.1),
              onTap: () => _openTelegramGroup(context),
            ),
          ],
        ],
      ),
    );
  }

  // ─── 设置卡片（工具设置） ──────────────────────────────────────────

  Widget _buildSettingsCard(
      BuildContext context, bool isDesktop, ThemeData theme, bool isDark) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      elevation: isDark ? 0 : 1,
      shadowColor: isDark ? null : Colors.black.withValues(alpha: 0.08),
      color: isDark ? null : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: isDark
            ? BorderSide.none
            : const BorderSide(color: Color(0xFFEEF0F4), width: 1),
      ),
      child: Column(
        children: [
          _tile(
            icon: Icons.settings_outlined,
            label: appLocalizations.xboardToolsSettings,
            iconColor: theme.colorScheme.primary,
            iconBgColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const FastCatSettingsPage(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 动作方法 ─────────────────────────────────────────────────────────────

  // 加入群组：优先读远程配置文件 contact.telegram_group，回退到 API telegram_discuss_link
  Future<void> _openTelegramGroup(BuildContext context) async {
    // 1. 优先：远程配置文件 contact.telegram_group
    final configTg = XBoardConfig.telegramGroupUrl;
    if (configTg.isNotEmpty) {
      launchUrl(Uri.parse(configTg), mode: LaunchMode.externalApplication);
      return;
    }
    // 2. 回退：从 /api/v1/user/comm/config 的 telegram_discuss_link 字段读取
    try {
      final sdk = await ref.read(xboardSdkProvider.future);
      final resp = await sdk.httpService.getRequest('/user/comm/config');
      final data = resp['data'] as Map<String, dynamic>?;
      final telegramLink = data?['telegram_discuss_link'] as String?;
      if (telegramLink != null && telegramLink.isNotEmpty) {
        launchUrl(Uri.parse(telegramLink),
            mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          XBoardNotification.showError(
            appLocalizations.xboardGroupLinkNotConfigured,
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        XBoardNotification.showError(
          appLocalizations.xboardGetGroupLinkFailed,
        );
      }
    }
  }

  // ─── 公共 UI 组件 ────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 0, bottom: 10),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: XbFontWeight.semibold,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? iconColor,
    Color? iconBgColor,
    Color? labelColor,
    String? trailingText,
    String? subtitle,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final effectiveIconColor = iconColor ?? theme.colorScheme.primary;
    Widget leadingWidget;
    if (!isDark && iconBgColor != null) {
      leadingWidget = Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconBgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: effectiveIconColor, size: 20),
      );
    } else {
      leadingWidget = Icon(icon, color: effectiveIconColor);
    }
    return XbPointerCursor(
      child: ListTile(
        visualDensity: const VisualDensity(vertical: -1.5),
        leading: leadingWidget,
        title: Text(label, style: TextStyle(color: labelColor)),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trailingText != null) ...[
              Text(
                trailingText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 4),
            ],
            if (iconColor == null || iconBgColor != null)
              Icon(
                Icons.chevron_right,
                size: 20,
                color: isDark
                    ? theme.colorScheme.onSurfaceVariant
                    : XbUiTokens.chevronLight,
              ),
          ],
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),
    );
  }

  Widget _divider() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      height: 1,
      indent: 56,
      endIndent: 16,
      color: isDark ? null : XbUiTokens.dividerLight,
    );
  }
}
