import 'dart:async';

import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';
import 'package:fl_clash/xboard/features/auth/auth.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:fl_clash/xboard/utils/backend_message_mapper.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> showChangeEmailSheet(
  BuildContext context,
  WidgetRef ref,
  String currentEmail,
) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ChangeEmailSheet(
      parentRef: ref,
      currentEmail: currentEmail,
    ),
  );
}

class _ChangeEmailSheet extends StatefulWidget {
  const _ChangeEmailSheet({
    required this.parentRef,
    required this.currentEmail,
  });

  final WidgetRef parentRef;
  final String currentEmail;

  @override
  State<_ChangeEmailSheet> createState() => _ChangeEmailSheetState();
}

class _ChangeEmailSheetState extends State<_ChangeEmailSheet> {
  final _newEmailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();
  Timer? _timer;
  int _countdown = 0;
  bool _sending = false;
  bool _submitting = false;
  bool _obscurePassword = true;

  bool get _zh => Localizations.localeOf(context).languageCode == 'zh';

  @override
  void dispose() {
    _timer?.cancel();
    _newEmailController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  String? _validateEmail() {
    final email = _newEmailController.text.trim().toLowerCase();
    if (email.isEmpty) return _zh ? '请输入新邮箱' : 'Enter a new email';
    if (email.length > 64 ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return _zh ? '请输入有效的邮箱地址' : 'Enter a valid email address';
    }
    if (email == widget.currentEmail.trim().toLowerCase()) {
      return _zh
          ? '新邮箱不能与当前邮箱相同'
          : 'The new email must differ from the current email';
    }
    if (_passwordController.text.isEmpty) {
      return _zh ? '请输入当前密码' : 'Enter your current password';
    }
    return null;
  }

  String _error(Object error) => BackendMessageMapper.mapError(
        error,
        context: BackendMessageContext.emailVerify,
        fallback: _zh ? '请求失败，请稍后重试' : 'Request failed. Try again later.',
      );

  Future<void> _sendCode() async {
    final validation = _validateEmail();
    if (validation != null) {
      XBoardNotification.showError(validation);
      return;
    }
    setState(() => _sending = true);
    try {
      final sdk = await widget.parentRef.read(xboardSdkProvider.future);
      final response = await sdk.httpService.postRequest(
        '/user/sendChangeEmailVerify',
        {
          'new_email': _newEmailController.text.trim().toLowerCase(),
          'password': _passwordController.text,
        },
      );
      if (response['data'] != true) {
        throw Exception(response['message']?.toString() ?? 'Request failed');
      }
      if (!mounted) return;
      XBoardNotification.showSuccess(
        _zh ? '验证码已发送到新邮箱' : 'Verification code sent',
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
    final validation = _validateEmail();
    if (validation != null) {
      XBoardNotification.showError(validation);
      return;
    }
    final code = _codeController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      XBoardNotification.showError(
        _zh ? '请输入新邮箱收到的 6 位验证码' : 'Enter the 6-digit verification code',
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final sdk = await widget.parentRef.read(xboardSdkProvider.future);
      final response = await sdk.httpService.postRequest('/user/changeEmail', {
        'new_email': _newEmailController.text.trim().toLowerCase(),
        'password': _passwordController.text,
        'email_code': code,
      });
      if (response['data'] != true) {
        throw Exception(response['message']?.toString() ?? 'Request failed');
      }
      await widget.parentRef.read(xboardUserProvider.notifier).logout(
            allowWhenServiceUnavailable: true,
            preserveSavedCredentials: false,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      XBoardNotification.showSuccess(
        _zh
            ? '邮箱修改成功，请使用新邮箱重新登录'
            : 'Email changed. Sign in again with your new email.',
      );
    } catch (error) {
      if (mounted) XBoardNotification.showError(_error(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        20,
        16,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _zh ? '修改邮箱' : 'Change email',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: XbFontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                onPressed: _submitting ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            readOnly: true,
            initialValue: widget.currentEmail,
            decoration: _decoration(
              _zh ? '当前邮箱' : 'Current email',
              Icons.email_outlined,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _newEmailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: _decoration(
              _zh ? '新邮箱' : 'New email',
              Icons.alternate_email_outlined,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            enableSuggestions: false,
            autocorrect: false,
            decoration: _decoration(
              _zh ? '当前密码' : 'Current password',
              Icons.lock_outline,
            ).copyWith(
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 6,
                  decoration: _decoration(
                    _zh ? '邮箱验证码' : 'Verification code',
                    Icons.verified_outlined,
                  ).copyWith(counterText: ''),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: _sending || _countdown > 0 || _submitting
                      ? null
                      : _sendCode,
                  child: _sending
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _countdown > 0
                              ? '${_countdown}s'
                              : (_zh ? '发送验证码' : 'Send code'),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              style: XbUiButton.filledPrimary(context, busy: _submitting),
              child: _submitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_zh ? '确认修改' : 'Confirm change'),
            ),
          ),
        ],
      ),
    );
  }
}
