import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';
import 'package:fl_clash/xboard/utils/backend_message_mapper.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:fl_clash/xboard/features/auth/providers/session_epoch_provider.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/xboard/services/storage/xboard_storage_provider.dart';

Future<void> showChangePasswordSheet(
  BuildContext context,
  WidgetRef ref,
) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ChangePasswordSheet(ref: ref),
  );
}

class _ChangePasswordSheet extends ConsumerStatefulWidget {
  final WidgetRef ref;

  const _ChangePasswordSheet({required this.ref});

  @override
  ConsumerState<_ChangePasswordSheet> createState() =>
      _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<_ChangePasswordSheet> {
  final _oldPwdCtrl = TextEditingController();
  final _newPwdCtrl = TextEditingController();
  final _confirmPwdCtrl = TextEditingController();
  bool _isSubmitting = false;
  bool _oldObscure = true;
  bool _newObscure = true;
  bool _confirmObscure = true;

  @override
  void dispose() {
    _oldPwdCtrl.dispose();
    _newPwdCtrl.dispose();
    _confirmPwdCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final oldPwd = _oldPwdCtrl.text;
    final newPwd = _newPwdCtrl.text;
    final confirmPwd = _confirmPwdCtrl.text;

    if (oldPwd.isEmpty || newPwd.isEmpty || confirmPwd.isEmpty) {
      XBoardNotification.showError(l10n.pleaseEnterPassword);
      return;
    }
    if (newPwd != confirmPwd) {
      XBoardNotification.showError(l10n.passwordsDoNotMatch);
      return;
    }
    if (newPwd.length < 8) {
      XBoardNotification.showError(l10n.passwordMin8Chars);
      return;
    }

    setState(() => _isSubmitting = true);
    final container = ProviderScope.containerOf(context, listen: false);
    final epoch = container.read(sessionEpochProvider);
    final user = container.read(xboardUserProvider);
    final email = user.userInfo?.email ?? user.email;
    final storage = container.read(storageServiceProvider);
    bool isCurrentSession() => container.read(sessionEpochProvider) == epoch;
    try {
      final sdk = await container.read(xboardSdkProvider.future);
      if (!isCurrentSession()) return;
      final resp = await sdk.httpService.postRequest(
        '/user/changePassword',
        {'old_password': oldPwd, 'new_password': newPwd},
      );
      if (!isCurrentSession()) return;
      final success = resp['data'] == true;
      var rememberedPasswordUpdated = true;
      if (success && email != null && email.isNotEmpty) {
        try {
          final saved = await storage.updateRememberedPassword(
            email: email,
            previousPassword: oldPwd,
            newPassword: newPwd,
            isCurrentSession: isCurrentSession,
          );
          rememberedPasswordUpdated = saved.dataOrNull == true;
        } catch (_) {
          // A local save failure must not mask a successful server change.
          rememberedPasswordUpdated = false;
        }
        if (!isCurrentSession()) return;
      }
      if (mounted && isCurrentSession()) {
        if (success) {
          Navigator.of(context).pop();
          if (rememberedPasswordUpdated) {
            XBoardNotification.showSuccess(l10n.xboardPasswordChanged);
          } else {
            XBoardNotification.showInfo(
                l10n.xboardPasswordChangedRememberFailed);
          }
        } else {
          final msg = BackendMessageMapper.map(
            resp['message'] as String?,
            context: BackendMessageContext.password,
          );
          XBoardNotification.showError(msg);
        }
      }
    } catch (e) {
      if (mounted && isCurrentSession()) {
        XBoardNotification.showError(
          BackendMessageMapper.mapError(
            e,
            context: BackendMessageContext.password,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
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
              Text(
                l10n.xboardChangePassword,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: XbFontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _oldPwdCtrl,
            obscureText: _oldObscure,
            decoration: InputDecoration(
              labelText: l10n.xboardCurrentPassword,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_oldObscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined),
                onPressed: () => setState(() => _oldObscure = !_oldObscure),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _newPwdCtrl,
            obscureText: _newObscure,
            decoration: InputDecoration(
              labelText: l10n.newPassword,
              hintText: l10n.passwordMin8Chars,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              prefixIcon: const Icon(Icons.lock_reset_outlined),
              suffixIcon: IconButton(
                icon: Icon(_newObscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined),
                onPressed: () => setState(() => _newObscure = !_newObscure),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _confirmPwdCtrl,
            obscureText: _confirmObscure,
            decoration: InputDecoration(
              labelText: l10n.confirmNewPassword,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              prefixIcon: const Icon(Icons.lock_reset_outlined),
              suffixIcon: IconButton(
                icon: Icon(_confirmObscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined),
                onPressed: () =>
                    setState(() => _confirmObscure = !_confirmObscure),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              style: XbUiButton.filledPrimary(
                context,
                busy: _isSubmitting,
              ),
              child: _isSubmitting
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    )
                  : Text(l10n.xboardConfirm),
            ),
          ),
        ],
      ),
    );
  }
}
