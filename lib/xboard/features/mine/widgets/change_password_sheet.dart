import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';

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
    final oldPwd = _oldPwdCtrl.text;
    final newPwd = _newPwdCtrl.text;
    final confirmPwd = _confirmPwdCtrl.text;

    if (oldPwd.isEmpty || newPwd.isEmpty || confirmPwd.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请填写所有密码字段')));
      return;
    }
    if (newPwd != confirmPwd) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('两次密码输入不一致')));
      return;
    }
    if (newPwd.length < 8) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('新密码至少需要8位')));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final sdk = await widget.ref.read(xboardSdkProvider.future);
      final resp = await sdk.httpService.postRequest(
        '/user/changePassword',
        {'old_password': oldPwd, 'new_password': newPwd},
      );
      if (mounted) {
        final success = resp['data'] == true;
        if (success) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('密码修改成功')));
        } else {
          final msg = resp['message'] as String? ?? '修改失败';
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(msg)));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('修改失败: $e')));
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
              Text(
                '修改密码',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
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
              labelText: '当前密码',
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
              labelText: '新密码',
              hintText: '至少8位',
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
              labelText: '确认新密码',
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
              child: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('确认修改'),
            ),
          ),
        ],
      ),
    );
  }
}
