import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/xboard/features/connectivity/providers/service_connectivity_provider.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LogoutDialog extends ConsumerWidget {
  const LogoutDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isProtected = !ref.watch(serviceConnectivityProvider).isOnline;
    return AlertDialog(
      shape: XbUiDialog.shape(),
      backgroundColor: XbUiDialog.background(context),
      title: Text(
        isProtected
            ? appLocalizations.xboardLogoutProtectedTitle
            : appLocalizations.xboardLogoutConfirmTitle,
        style: XbUiText.sectionTitle(context),
      ),
      content: Text(
        isProtected
            ? appLocalizations.xboardLogoutProtectedContent
            : appLocalizations.xboardLogoutConfirmContent,
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: XbUiButton.outlinedNeutral(context),
          child: Text(appLocalizations.cancel),
        ),
        FilledButton(
          onPressed: () async {
            if (isProtected) {
              final confirmed = await _confirmForcedLogout(context);
              if (!confirmed || !context.mounted) return;
            }
            if (context.mounted) Navigator.of(context).pop();
            await _performLogout(context, ref, force: isProtected);
          },
          style: XbUiButton.filledDanger(context),
          child: Text(
            isProtected
                ? appLocalizations.xboardLogoutForceAction
                : appLocalizations.exit,
          ),
        ),
      ],
    );
  }

  Future<bool> _confirmForcedLogout(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: XbUiDialog.shape(),
            backgroundColor: XbUiDialog.background(context),
            title: Text(
              appLocalizations.xboardLogoutForceConfirmTitle,
              style: XbUiText.sectionTitle(context),
            ),
            content: Text(appLocalizations.xboardLogoutForceConfirmContent),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: XbUiButton.outlinedNeutral(context),
                child: Text(appLocalizations.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: XbUiButton.filledDanger(context),
                child: Text(appLocalizations.xboardLogoutForceAction),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _performLogout(
    BuildContext context,
    WidgetRef ref, {
    required bool force,
  }) async {
    try {
      await ref
          .read(xboardUserProvider.notifier)
          .logout(allowWhenServiceUnavailable: force);
      if (context.mounted) {
        XBoardNotification.showSuccess(appLocalizations.loggedOutSuccess);
      }
    } catch (e) {
      if (!ref.read(xboardUserProvider).isAuthenticated) {
        return;
      }
      if (context.mounted) {
        XBoardNotification.showError(appLocalizations.logoutFailed(e.toString()));
      }
    }
  }
}
