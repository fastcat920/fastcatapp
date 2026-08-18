import 'package:fl_clash/xboard/features/auth/auth.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart' show ConfigModel;
import 'package:fl_clash/common/common.dart';
import 'package:flutter/material.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/xboard/features/shared/shared.dart';
import 'package:fl_clash/xboard/services/services.dart';
import 'package:fl_clash/xboard/utils/backend_message_mapper.dart';
import 'package:go_router/go_router.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});
  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _inviteCodeController = TextEditingController();
  final _emailCodeController = TextEditingController();
  bool _isRegistering = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isSendingEmailCode = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _inviteCodeController.dispose();
    _emailCodeController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    // 获取配置
    final configAsync = ref.read(configProvider);
    final config = configAsync.value;
    final isInviteForce = config?.isInviteForce ?? false;
    final isEmailVerify = config?.isEmailVerify ?? false;

    // 检查邮请码是否必填
    if (isInviteForce && _inviteCodeController.text.trim().isEmpty) {
      _showInviteCodeDialog();
      return;
    }

    // 检查邮箱验证码是否必填
    if (isEmailVerify && _emailCodeController.text.trim().isEmpty) {
      XBoardNotification.showError(
          appLocalizations.pleaseEnterEmailVerificationCode);
      return;
    }

    if (_formKey.currentState!.validate()) {
      setState(() {
        _isRegistering = true;
      });
      try {
        final success = await ref.read(xboardUserProvider.notifier).register(
              _emailController.text,
              _passwordController.text,
              _inviteCodeController.text.trim().isNotEmpty
                  ? _inviteCodeController.text
                  : null,
              isEmailVerify && _emailCodeController.text.trim().isNotEmpty
                  ? _emailCodeController.text
                  : null,
            );

        if (!success) {
          final message = ref.read(xboardUserProvider).errorMessage ??
              appLocalizations.xboardRegisterFailed;
          XBoardNotification.showError(message);
          return;
        }

        if (mounted) {
          final storageService = ref.read(storageServiceProvider);
          await storageService.saveCredentials(
            _emailController.text,
            '',
            false,
          );
          if (mounted) {
            XBoardNotification.showSuccess(
                appLocalizations.xboardRegisterSuccess);
          }
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              context.pop();
            }
          });
        }
      } catch (e) {
        if (mounted) {
          final errorMessage = BackendMessageMapper.mapError(
            e,
            context: BackendMessageContext.register,
          );

          XBoardNotification.showError(errorMessage);
        }
      } finally {
        if (mounted) {
          setState(() {
            _isRegistering = false;
          });
        }
      }
    }
  }

  Future<void> _sendEmailCode() async {
    if (_emailController.text.isEmpty) {
      XBoardNotification.showError(appLocalizations.pleaseEnterEmailAddress);
      return;
    }

    if (!_emailController.text.contains('@')) {
      XBoardNotification.showError(
          appLocalizations.pleaseEnterValidEmailAddress);
      return;
    }

    setState(() {
      _isSendingEmailCode = true;
    });

    try {
      final success = await ref
          .read(xboardUserProvider.notifier)
          .sendVerificationCode(_emailController.text);
      if (!success) {
        final message = ref.read(xboardUserProvider).errorMessage ??
            appLocalizations.sendCodeFailed;
        throw Exception(message);
      }

      if (mounted) {
        XBoardNotification.showSuccess(
            appLocalizations.verificationCodeSentCheckEmail);
      }
    } catch (e) {
      if (mounted) {
        XBoardNotification.showError(
          appLocalizations.sendVerificationCodeFailed(
            BackendMessageMapper.mapError(
              e,
              context: BackendMessageContext.emailVerify,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSendingEmailCode = false;
        });
      }
    }
  }

  void _showInviteCodeDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(appLocalizations.inviteCodeRequired),
          content: Text(appLocalizations.inviteCodeRequiredMessage),
          actions: [
            TextButton(
              onPressed: () {
                context.pop();
              },
              child: Text(appLocalizations.iUnderstand),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final configAsync = ref.watch(configProvider);

    // 处理异步加载状态
    return configAsync.when(
      loading: () => Scaffold(
        backgroundColor: colorScheme.brightness == Brightness.dark
            ? colorScheme.surface
            : const Color(0xFFFAFBFD),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => _buildPage(context, colorScheme, null),
      data: (config) => _buildPage(context, colorScheme, config),
    );
  }

  Widget _buildPage(
      BuildContext context, ColorScheme colorScheme, ConfigModel? config) {
    return Scaffold(
      backgroundColor: colorScheme.brightness == Brightness.dark
          ? colorScheme.surface
          : const Color(0xFFFAFBFD),
      body: XBContainer(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back),
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.surfaceContainerLow,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    appLocalizations.createAccount,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: XbFontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          appLocalizations.fillInfoToRegister,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                        ),
                        const SizedBox(height: 24),
                        XBInputField(
                          controller: _emailController,
                          labelText: appLocalizations.emailAddress,
                          hintText:
                              appLocalizations.pleaseEnterYourEmailAddress,
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return appLocalizations.pleaseEnterEmailAddress;
                            }
                            if (!value.contains('@')) {
                              return appLocalizations
                                  .pleaseEnterValidEmailAddress;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        XBInputField(
                          controller: _passwordController,
                          labelText: appLocalizations.password,
                          hintText:
                              appLocalizations.pleaseEnterAtLeast8CharsPassword,
                          prefixIcon: Icons.lock_outlined,
                          obscureText: !_isPasswordVisible,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return appLocalizations.pleaseEnterPassword;
                            }
                            if (value.length < 8) {
                              return appLocalizations.passwordMin8Chars;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        XBInputField(
                          controller: _confirmPasswordController,
                          labelText: appLocalizations.confirmNewPassword,
                          hintText: appLocalizations.pleaseReEnterPassword,
                          prefixIcon: Icons.lock_outlined,
                          obscureText: !_isConfirmPasswordVisible,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isConfirmPasswordVisible
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () {
                              setState(() {
                                _isConfirmPasswordVisible =
                                    !_isConfirmPasswordVisible;
                              });
                            },
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return appLocalizations.pleaseConfirmPassword;
                            }
                            if (value != _passwordController.text) {
                              return appLocalizations.passwordsDoNotMatch;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        // 根据配置决定是否显示邮箱验证码字段
                        if (config?.isEmailVerify == true)
                          Column(
                            children: [
                              XBInputField(
                                controller: _emailCodeController,
                                labelText:
                                    appLocalizations.emailVerificationCode,
                                hintText: appLocalizations
                                    .pleaseEnterEmailVerificationCode,
                                prefixIcon: Icons.verified_user_outlined,
                                keyboardType: TextInputType.number,
                                suffixIcon: _isSendingEmailCode
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : TextButton(
                                        onPressed: _sendEmailCode,
                                        child: Text(appLocalizations
                                            .sendVerificationCode),
                                      ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return appLocalizations
                                        .pleaseEnterEmailVerificationCode;
                                  }
                                  if (value.length != 6) {
                                    return appLocalizations
                                        .verificationCode6Digits;
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        // 邀请码：始终显示，根据配置改变标签（必填 vs 可选）
                        XBInputField(
                          controller: _inviteCodeController,
                          labelText: (config?.isInviteForce ?? false)
                              ? '${appLocalizations.xboardInviteCode} *'
                              : appLocalizations.inviteCodeOptional,
                          hintText: appLocalizations.pleaseEnterInviteCode,
                          prefixIcon: Icons.card_giftcard_outlined,
                          enabled: true,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: _isRegistering
                              ? FilledButton(
                                  onPressed: null,
                                  style: XbUiButton.filledPrimary(
                                    context,
                                    busy: true,
                                  ),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colorScheme.onPrimary,
                                    ),
                                  ),
                                )
                              : FilledButton(
                                  onPressed: _register,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: colorScheme.primary,
                                    foregroundColor: colorScheme.onPrimary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: Text(
                                    appLocalizations.registerAccount,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: XbFontWeight.semibold,
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              appLocalizations.alreadyHaveAccount,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            TextButton(
                              onPressed: () => context.pop(),
                              child: Text(
                                appLocalizations.loginNow,
                                style: TextStyle(
                                  color: colorScheme.primary,
                                  fontWeight: XbFontWeight.semibold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
