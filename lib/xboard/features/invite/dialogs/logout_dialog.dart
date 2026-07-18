import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/xboard/features/connectivity/providers/service_connectivity_provider.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LogoutDialog extends ConsumerStatefulWidget {
  const LogoutDialog({super.key});

  @override
  ConsumerState<LogoutDialog> createState() => _LogoutDialogState();
}

class _LogoutDialogState extends ConsumerState<LogoutDialog> {
  bool _isLoggingOut = false;

  @override
  Widget build(BuildContext context) {
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
          onPressed: _isLoggingOut ? null : () => Navigator.of(context).pop(),
          style: XbUiButton.outlinedNeutral(context),
          child: Text(appLocalizations.cancel),
        ),
        FilledButton(
          onPressed: _isLoggingOut
              ? null
              : () async {
                  if (isProtected) {
                    final confirmed = await _confirmForcedLogout(context);
                    if (!confirmed || !context.mounted) return;
                  }
                  setState(() => _isLoggingOut = true);
                  final succeeded = await _performLogout(force: isProtected);
                  if (!mounted) return;
                  if (succeeded) {
                    Navigator.of(context).pop();
                    XBoardNotification.showSuccess(
                        appLocalizations.loggedOutSuccess);
                  } else {
                    setState(() => _isLoggingOut = false);
                  }
                },
          style: XbUiButton.filledDanger(context, busy: _isLoggingOut),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isLoggingOut) ...[
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                isProtected
                    ? appLocalizations.xboardLogoutForceAction
                    : appLocalizations.exit,
              ),
            ],
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

  Future<bool> _performLogout({
    required bool force,
  }) async {
    try {
      await ref
          .read(xboardUserProvider.notifier)
          .logout(allowWhenServiceUnavailable: force);
      return true;
    } catch (e) {
      if (!ref.read(xboardUserProvider).isAuthenticated) {
        return true;
      }
      if (mounted) {
        XBoardNotification.showError(
            appLocalizations.logoutFailed(e.toString()));
      }
      return false;
    }
  }
}
