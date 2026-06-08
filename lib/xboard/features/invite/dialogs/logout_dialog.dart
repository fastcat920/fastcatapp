import 'package:flutter/material.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';

class LogoutDialog extends ConsumerWidget {
  const LogoutDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AlertDialog(
      shape: XbUiDialog.shape(),
      backgroundColor: XbUiDialog.background(context),
      title: Text(
        appLocalizations.xboardLogoutConfirmTitle,
        style: XbUiText.sectionTitle(context),
      ),
      content: Text(appLocalizations.xboardLogoutConfirmContent),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: XbUiButton.outlinedNeutral(context),
          child: Text(appLocalizations.cancel),
        ),
        FilledButton(
          onPressed: () async {
            Navigator.of(context).pop();
            await _performLogout(context, ref);
          },
          style: XbUiButton.filledDanger(context),
          child: Text(appLocalizations.exit),
        ),
      ],
    );
  }

  Future<void> _performLogout(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(xboardUserProvider.notifier).logout();
      if (context.mounted) {
        XBoardNotification.showSuccess(appLocalizations.loggedOutSuccess);
      }
    } catch (e) {
      if (!ref.read(xboardUserProvider).isAuthenticated) {
        return;
      }
      if (context.mounted) {
        XBoardNotification.showError(
            appLocalizations.logoutFailed(e.toString()));
      }
    }
  }
}
