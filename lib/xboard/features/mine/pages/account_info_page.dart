import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/features/auth/auth.dart';
import 'package:fl_clash/xboard/features/invite/dialogs/logout_dialog.dart';
import 'package:fl_clash/xboard/features/mine/widgets/change_password_sheet.dart';
import 'package:fl_clash/xboard/features/mine/widgets/change_email_sheet.dart';
import 'package:fl_clash/xboard/features/mine/widgets/account_deletion_sheet.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:flutter/material.dart';
import 'package:fl_clash/xboard/features/shared/shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AccountInfoPage extends ConsumerStatefulWidget {
  const AccountInfoPage({super.key});

  @override
  ConsumerState<AccountInfoPage> createState() => _AccountInfoPageState();
}

class _AccountInfoPageState extends ConsumerState<AccountInfoPage> {
  bool _updatingExpire = false;
  bool _updatingTraffic = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(xboardUserProvider).isAuthenticated) {
        if (ref.read(userInfoProvider) == null) {
          ref.read(xboardUserProvider.notifier).refreshUserInfo();
        }
        if (ref.read(subscriptionInfoProvider) == null) {
          ref.read(xboardUserProvider.notifier).refreshSubscriptionInfo();
        }
      }
    });
  }

  Future<void> _toggleReminder({
    required bool remindExpire,
    required bool value,
  }) async {
    if (remindExpire) {
      setState(() => _updatingExpire = true);
    } else {
      setState(() => _updatingTraffic = true);
    }

    final success =
        await ref.read(xboardUserProvider.notifier).updateReminderSettings(
              remindExpire: remindExpire ? value : null,
              remindTraffic: remindExpire ? null : value,
            );

    if (!mounted) return;
    if (!success) {
      XBoardNotification.showError('更新通知设置失败');
    }

    setState(() {
      _updatingExpire = false;
      _updatingTraffic = false;
    });
  }

  Widget _buildCard({
    required Widget child,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Card(
      elevation: isDark ? 0 : 1,
      shadowColor: isDark ? null : Colors.black.withValues(alpha: 0.08),
      color: isDark ? null : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: isDark
            ? BorderSide.none
            : const BorderSide(color: XbUiTokens.cardBorderLight, width: 1),
      ),
      child: child,
    );
  }

  Future<void> _showAccountDeletionFlow(String email) async {
    final chinese = Localizations.localeOf(context).languageCode == 'zh';
    final confirmed = await XbConfirmDialog.show(
      context,
      title: chinese ? '确认进入注销流程？' : 'Start account deletion?',
      message: chinese
          ? '注销账号会使所有设备退出登录，并立即停止套餐与订阅。'
          : 'Deleting your account signs out all devices and stops subscriptions immediately.',
      confirmLabel: chinese ? '继续' : 'Continue',
      tone: XbDialogTone.danger,
      icon: Icons.delete_forever_outlined,
    );
    if (confirmed && mounted) {
      await showAccountDeletionSheet(context, ref, email);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final userInfo = ref.watch(userInfoProvider);
    final userState = ref.watch(xboardUserProvider);
    final subscriptionInfo = ref.watch(subscriptionInfoProvider);
    final email =
        userInfo?.email ?? userState.email ?? subscriptionInfo?.email ?? '';
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? null : XbUiTokens.pageBackgroundLight,
      appBar: AppBar(
        title: Text(l10n.xboardAccountInfo),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        children: [
          _buildCard(
            child: ListTile(
              leading:
                  Icon(Icons.email_outlined, color: theme.colorScheme.primary),
              title: Text(l10n.xboardEmail),
              subtitle:
                  Text(email.isEmpty ? l10n.xboardEmailUnavailable : email),
            ),
          ),
          const SizedBox(height: 12),
          _buildCard(
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  secondary: Icon(Icons.event_available_outlined,
                      color: theme.colorScheme.primary),
                  title: Text(l10n.xboardPlanExpiryReminder),
                  value: userInfo?.remindExpire ?? true,
                  onChanged: _updatingExpire
                      ? null
                      : (value) => _toggleReminder(
                            remindExpire: true,
                            value: value,
                          ),
                ),
                Divider(
                  height: 1,
                  indent: 56,
                  endIndent: 16,
                  color: isDark ? null : XbUiTokens.dividerLight,
                ),
                SwitchListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  secondary: Icon(Icons.data_usage_outlined,
                      color: theme.colorScheme.primary),
                  title: Text(l10n.xboardTrafficReminder),
                  value: userInfo?.remindTraffic ?? true,
                  onChanged: _updatingTraffic
                      ? null
                      : (value) => _toggleReminder(
                            remindExpire: false,
                            value: value,
                          ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildCard(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.alternate_email_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(
                    Localizations.localeOf(context).languageCode == 'zh'
                        ? '修改邮箱'
                        : 'Change email',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showChangeEmailSheet(context, ref, email),
                ),
                Divider(
                  height: 1,
                  indent: 56,
                  endIndent: 16,
                  color: isDark ? null : XbUiTokens.dividerLight,
                ),
                ListTile(
                  leading: Icon(
                    Icons.lock_outline,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(l10n.xboardChangePassword),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showChangePasswordSheet(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => const LogoutDialog(),
                ),
                icon: const Icon(Icons.logout_outlined),
                label: Text(l10n.xboardLogout),
                style: FilledButton.styleFrom(
                  backgroundColor: isDark
                      ? theme.colorScheme.surfaceContainerHighest
                      : const Color(0xFFE8EDF3),
                  foregroundColor: isDark
                      ? theme.colorScheme.onSurface
                      : const Color(0xFF344054),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          _DangerZone(
            onDelete: () => _showAccountDeletionFlow(email),
          ),
        ],
      ),
    );
  }
}

class _DangerZone extends StatelessWidget {
  const _DangerZone({required this.onDelete});

  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chinese = Localizations.localeOf(context).languageCode == 'zh';
    final error = theme.colorScheme.error;
    return Center(
      child: TextButton.icon(
        onPressed: onDelete,
        icon: const Icon(Icons.delete_forever_outlined, size: 18),
        label: Text(chinese ? '注销账号' : 'Delete account'),
        style: TextButton.styleFrom(
          foregroundColor: error,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }
}
