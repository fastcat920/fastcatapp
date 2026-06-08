import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/features/auth/auth.dart';
import 'package:fl_clash/xboard/features/invite/dialogs/logout_dialog.dart';
import 'package:fl_clash/xboard/features/mine/widgets/change_password_sheet.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:flutter/material.dart';
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
            : const BorderSide(color: Color(0xFFEEF0F4), width: 1),
      ),
      child: child,
    );
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
      backgroundColor: isDark ? null : const Color(0xFFFAFBFD),
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
                SwitchListTile.adaptive(
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
                  color: isDark ? null : const Color(0xFFF0F2F5),
                ),
                SwitchListTile.adaptive(
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
            child: ListTile(
              leading:
                  Icon(Icons.lock_outline, color: theme.colorScheme.primary),
              title: Text(l10n.xboardChangePassword),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showChangePasswordSheet(context, ref),
            ),
          ),
          const SizedBox(height: 12),
          _buildCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => const LogoutDialog(),
                  ),
                  icon: const Icon(Icons.logout),
                  label: Text(l10n.xboardLogout),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red.shade500,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
