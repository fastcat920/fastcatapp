import 'dart:async';

import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';
import 'package:fl_clash/xboard/features/auth/auth.dart';
import 'package:fl_clash/xboard/utils/backend_message_mapper.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<bool?> showAccountDeletionSheet(
  BuildContext context,
  WidgetRef ref,
  String email,
) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _AccountDeletionSheet(parentRef: ref, email: email),
  );
}

class _AccountDeletionSheet extends StatefulWidget {
  const _AccountDeletionSheet({required this.parentRef, required this.email});

  final WidgetRef parentRef;
  final String email;

  @override
  State<_AccountDeletionSheet> createState() => _AccountDeletionSheetState();
}

class _AccountDeletionSheetState extends State<_AccountDeletionSheet> {
  final _codeController = TextEditingController();
  Timer? _timer;
  int _countdown = 0;
  bool _sending = false;
  bool _submitting = false;

  bool get _zh => Localizations.localeOf(context).languageCode == 'zh';
  bool get _canSubmit =>
      RegExp(r'^\d{6}$').hasMatch(_codeController.text.trim());

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  String _error(Object error) => BackendMessageMapper.mapError(
        error,
        context: BackendMessageContext.emailVerify,
        fallback: _zh ? '请求失败，请稍后重试' : 'Request failed. Try again later.',
      );

  Future<void> _sendCode() async {
    setState(() => _sending = true);
    try {
      final sdk = await widget.parentRef.read(xboardSdkProvider.future);
      final response = await sdk.httpService.postRequest(
        '/user/account/sendDeleteVerify',
        const <String, dynamic>{},
      );
      if (response['data'] != true) {
        throw Exception(response['message']?.toString() ?? 'Request failed');
      }
      if (!mounted) return;
      XBoardNotification.showSuccess(
        _zh ? '验证码已发送，请查收邮箱' : 'Verification code sent. Check your email.',
      );
      _startCountdown();
    } catch (error) {
      if (mounted) XBoardNotification.showError(_error(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _countdown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _countdown <= 1) {
        timer.cancel();
        if (mounted) setState(() => _countdown = 0);
      } else {
        setState(() => _countdown--);
      }
    });
  }

  Future<void> _submit() async {
    if (!_canSubmit) {
      XBoardNotification.showError(
        _zh ? '请输入 6 位验证码' : 'Enter the 6-digit verification code.',
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final sdk = await widget.parentRef.read(xboardSdkProvider.future);
      final response = await sdk.httpService.postRequest(
        '/user/account/delete',
        <String, dynamic>{
          'email_code': _codeController.text.trim(),
          'confirm': 'DELETE',
        },
      );
      if (response['data'] != true) {
        throw Exception(response['message']?.toString() ?? 'Request failed');
      }

      // The server revokes all sessions first. Clear every local credential so
      // the anonymized email cannot be prefilled on the next login.
      await widget.parentRef.read(xboardUserProvider.notifier).logout(
            allowWhenServiceUnavailable: true,
            preserveSavedCredentials: false,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      XBoardNotification.showSuccess(
        _zh ? '账号已注销' : 'Your account has been deleted.',
      );
    } catch (error) {
      if (mounted) XBoardNotification.showError(_error(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = theme.colorScheme.error;
    final errorContainer = theme.colorScheme.errorContainer;
    final onErrorContainer = theme.colorScheme.onErrorContainer;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _zh ? '注销账号' : 'Delete account',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            DecoratedBox(
              decoration: BoxDecoration(
                color: errorContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  _zh
                      ? '注销后无法继续登录，当前账号的套餐、余额、佣金、订阅及登录会话都将失效，此操作不可撤销。'
                      : 'All devices will be signed out and cannot sign in again. Your plan, balance, commission, subscriptions, and login sessions will become invalid. This cannot be undone.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: onErrorContainer,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _zh
                  ? '验证码将发送至 ${widget.email.trim().isEmpty ? "当前邮箱" : widget.email.trim()}'
                  : 'A verification code will be sent to ${widget.email.trim().isEmpty ? "your current email" : widget.email.trim()}.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 6,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: _zh ? '6 位邮箱验证码' : '6-digit email code',
                prefixIcon: const Icon(Icons.mark_email_read_outlined),
                suffixIcon: TextButton(
                  onPressed: _sending || _countdown > 0 ? null : _sendCode,
                  child: Text(
                    _countdown > 0
                        ? '${_countdown}s'
                        : (_zh ? '发送验证码' : 'Send code'),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _submitting ? null : () => Navigator.of(context).pop(),
                    child: Text(_zh ? '取消' : 'Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _submitting || !_canSubmit ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: error,
                      foregroundColor: theme.colorScheme.onError,
                    ),
                    icon: _submitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_forever_outlined),
                    label: Text(_zh ? '确认注销' : 'Delete account'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
