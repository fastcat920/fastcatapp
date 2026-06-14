import 'dart:async';
import 'dart:io';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart' as fl_models;
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/features/auth/auth.dart';
import 'package:fl_clash/xboard/features/auth/utils/customer_service_helper.dart';
import 'package:fl_clash/xboard/domain/domain.dart';
import 'package:fl_clash/xboard/config/xboard_config.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fl_clash/views/tools.dart';
import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';
import 'package:fl_clash/xboard/features/subscription/widgets/subscription_usage_card.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'order_page.dart';
import 'ticket_page.dart';
import 'package:fl_clash/xboard/features/docs/pages/docs_page.dart';
import 'package:fl_clash/xboard/features/payment/pages/recharge_page.dart';

class MinePage extends ConsumerStatefulWidget {
  const MinePage({super.key});

  @override
  ConsumerState<MinePage> createState() => _MinePageState();
}

class _MinePageState extends ConsumerState<MinePage>
    with SingleTickerProviderStateMixin {
  @override
  void activate() {
    super.activate();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
  }

  late final AnimationController _refreshAnim;
  StreamSubscription? _configSub;

  @override
  void initState() {
    super.initState();
    _refreshAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _configSub = XBoardConfig.configChangeStream.listen((_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(xboardUserProvider.notifier).ensureUserSnapshotLoaded();
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
      await ref.read(xboardUserProvider.notifier).refreshSubscriptionInfo();
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
    return TextButton.icon(
      style: XbUiButton.textChipPrimary(context),
      icon: Icon(
        Icons.support_agent_outlined,
        size: 18,
        color: theme.colorScheme.primary,
      ),
      label: Text(
        appLocalizations.contactSupport,
        style: TextStyle(color: theme.colorScheme.primary),
      ),
      onPressed: () => CustomerServiceHelper.open(context),
    );
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
            fontWeight: FontWeight.w600,
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
                : const Color(0xFFBCC3CE)),
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
      appBar: isDesktop
          ? null
          : AppBar(
              title: Text(appLocalizations.userCenter),
              automaticallyImplyLeading: false,
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: _buildCustomerServiceButton(context),
                ),
              ],
            ),
      body: RefreshIndicator(
        onRefresh: _doRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16, isDesktop ? 6 : 12, 16, 12),
          children: [
            if (isDesktop) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    appLocalizations.userCenter,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildCustomerServiceButton(context),
                      _buildRefreshButton(),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
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
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ─── 服务卡片（订单/流量/工单/客服/官网/群组） ───────────────────────────────

  Widget _buildServicesCard(BuildContext context, WidgetRef ref,
      DomainUser? userInfo, ThemeData theme, bool isDark) {
    return Card(
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
              onTap: () => _showGiftCardSheet(context),
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
                builder: (_) => Scaffold(
                  appBar:
                      AppBar(title: Text(appLocalizations.xboardToolsSettings)),
                  body: const ToolsView(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 动作方法 ─────────────────────────────────────────────────────────────

  void _showGiftCardSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _GiftCardSheet(),
    );
  }

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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(appLocalizations.xboardGroupLinkNotConfigured)),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(appLocalizations.xboardGetGroupLinkFailed)),
        );
      }
    }
  }

  // ─── 公共 UI 组件 ────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
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
    return ListTile(
      visualDensity: const VisualDensity(vertical: -1.5),
      leading: leadingWidget,
      title: Text(label, style: TextStyle(color: labelColor)),
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
                  : const Color(0xFFBCC3CE),
            ),
        ],
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }

  Widget _divider() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      height: 1,
      indent: 56,
      endIndent: 16,
      color: isDark ? null : const Color(0xFFF0F2F5),
    );
  }
}

// ─── 礼品卡兑换底部弹窗 ─────────────────────────────────────────────────────

class _GiftCardSheet extends ConsumerStatefulWidget {
  const _GiftCardSheet();

  @override
  ConsumerState<_GiftCardSheet> createState() => _GiftCardSheetState();
}

class _GiftCardSheetState extends ConsumerState<_GiftCardSheet> {
  final _codeCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(appLocalizations.xboardPleaseEnterGiftCardCode)));
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final sdk = await ref.read(xboardSdkProvider.future);
      final isV2Board = XBoardConfig.provider.getPanelType() == 'v2board';
      final endpoint =
          isV2Board ? '/user/redeemgiftcard' : '/user/gift-card/redeem';
      final body = isV2Board ? {'giftcard': code} : {'code': code};
      final resp = await sdk.httpService.postRequest(endpoint, body);
      if (mounted) {
        final data = resp['data'];
        final success = data != null && data != false;
        final msg = resp['message'] as String? ??
            (success
                ? appLocalizations.xboardRedeemSuccess
                : appLocalizations.xboardRedeemFailed);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                appLocalizations.xboardRedeemFailedWithError(e.toString()))));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(appLocalizations.xboardGiftCardRedeem,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop()),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _codeCtrl,
            decoration: InputDecoration(
              labelText: appLocalizations.xboardGiftCardCodeLabel,
              hintText: appLocalizations.xboardEnterGiftCardCodeHint,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              prefixIcon: const Icon(Icons.card_giftcard_outlined),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isSubmitting ? null : _redeem,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(appLocalizations.xboardRedeemNow),
            ),
          ),
        ],
      ),
    );
  }
}
