import 'package:flutter/material.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/xboard/features/shared/shared.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/utils/backend_message_mapper.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/xboard/features/auth/widgets/auth_tv_layout.dart';
import 'package:fl_clash/widgets/widgets.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});
  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

enum ResetPasswordStep {
  sendCode, // 发送验证码步骤
  resetPassword // 重置密码步骤
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  ResetPasswordStep _currentStep = ResetPasswordStep.sendCode;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _sendVerificationCode() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 使用 SDK 发送验证码
      await XBoardSDK.instance.auth.sendEmailVerifyCode(_emailController.text);

      if (mounted) {
        setState(() {
          _currentStep = ResetPasswordStep.resetPassword;
        });
        XBoardNotification.showSuccess(
            AppLocalizations.of(context).verificationCodeSent);
      }
    } catch (e) {
      if (mounted) {
        XBoardNotification.showError(
          '${AppLocalizations.of(context).sendCodeFailed}: ${BackendMessageMapper.mapError(
            e,
            context: BackendMessageContext.emailVerify,
          )}',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      XBoardNotification.showError(
          AppLocalizations.of(context).passwordMismatch);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 使用 AuthRepository 重置密码
      // 使用 SDK 重置密码
      final success = await XBoardSDK.instance.auth.forgotPassword(
        _emailController.text,
        _codeController.text,
        _passwordController.text,
      );

      if (!success) {
        throw Exception('重置密码失败');
      }

      if (mounted) {
        XBoardNotification.showSuccess(
            AppLocalizations.of(context).passwordResetSuccessful);
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        XBoardNotification.showError(
          '${AppLocalizations.of(context).passwordResetFailed}: ${BackendMessageMapper.mapError(
            e,
            context: BackendMessageContext.password,
          )}',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _goBackToSendCode() {
    setState(() {
      _currentStep = ResetPasswordStep.sendCode;
      _codeController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
    });
  }

  Widget _buildSendCodeStep() {
    final sectionGap = system.isTV ? AuthTvLayout.sectionGap : 32.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppLocalizations.of(context).enterEmailForReset,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        SizedBox(height: sectionGap),
        XBInputField(
          controller: _emailController,
          labelText: AppLocalizations.of(context).emailAddress,
          hintText: AppLocalizations.of(context).pleaseEnterEmail,
          prefixIcon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          enabled: !_isLoading,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return AppLocalizations.of(context).pleaseEnterEmail;
            }
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
              return AppLocalizations.of(context).pleaseEnterValidEmail;
            }
            return null;
          },
        ),
        SizedBox(height: sectionGap),
        TVFocusable(
          borderRadius: BorderRadius.circular(14),
          onPressed: _isLoading ? null : _sendVerificationCode,
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: _isLoading
                ? FilledButton(
                    onPressed: null,
                    style: XbUiButton.filledPrimary(context, busy: true),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  )
                : FilledButton(
                    onPressed: _sendVerificationCode,
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ).copyWith(
                      overlayColor:
                          const WidgetStatePropertyAll(Colors.transparent),
                    ),
                    child: Text(
                      AppLocalizations.of(context).sendVerificationCode,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: XbFontWeight.semibold,
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildResetPasswordStep() {
    final sectionGap = system.isTV ? AuthTvLayout.sectionGap : 32.0;
    final fieldGap = system.isTV ? AuthTvLayout.compactGap : 16.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppLocalizations.of(context)
              .verificationCodeSentTo(_emailController.text),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        SizedBox(height: sectionGap),
        XBInputField(
          controller: _codeController,
          labelText: AppLocalizations.of(context).verificationCode,
          hintText: AppLocalizations.of(context).pleaseEnterVerificationCode,
          prefixIcon: Icons.verified_user_outlined,
          keyboardType: TextInputType.number,
          enabled: !_isLoading,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return AppLocalizations.of(context).pleaseEnterVerificationCode;
            }
            if (value.length < 4) {
              return AppLocalizations.of(context)
                  .pleaseEnterValidVerificationCode;
            }
            return null;
          },
        ),
        SizedBox(height: fieldGap),
        XBInputField(
          controller: _passwordController,
          labelText: AppLocalizations.of(context).newPassword,
          hintText: AppLocalizations.of(context).pleaseEnterNewPassword,
          prefixIcon: Icons.lock_outlined,
          obscureText: _obscurePassword,
          enabled: !_isLoading,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
            onPressed: () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
            },
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return AppLocalizations.of(context).pleaseEnterNewPassword;
            }
            if (value.length < 6) {
              return AppLocalizations.of(context).passwordMinLength;
            }
            return null;
          },
        ),
        SizedBox(height: fieldGap),
        XBInputField(
          controller: _confirmPasswordController,
          labelText: AppLocalizations.of(context).confirmNewPassword,
          hintText: AppLocalizations.of(context).pleaseConfirmNewPassword,
          prefixIcon: Icons.lock_outlined,
          obscureText: _obscureConfirmPassword,
          enabled: !_isLoading,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureConfirmPassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
            onPressed: () {
              setState(() {
                _obscureConfirmPassword = !_obscureConfirmPassword;
              });
            },
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return AppLocalizations.of(context).pleaseConfirmNewPassword;
            }
            if (value != _passwordController.text) {
              return AppLocalizations.of(context).passwordMismatch;
            }
            return null;
          },
        ),
        SizedBox(height: sectionGap),
        TVFocusable(
          borderRadius: BorderRadius.circular(14),
          onPressed: _isLoading ? null : _resetPassword,
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: _isLoading
                ? FilledButton(
                    onPressed: null,
                    style: XbUiButton.filledPrimary(context, busy: true),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  )
                : FilledButton(
                    onPressed: _resetPassword,
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ).copyWith(
                      overlayColor:
                          const WidgetStatePropertyAll(Colors.transparent),
                    ),
                    child: Text(
                      AppLocalizations.of(context).resetPassword,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: XbFontWeight.semibold,
                      ),
                    ),
                  ),
          ),
        ),
        SizedBox(height: fieldGap),
        TVFocusable(
          borderRadius: BorderRadius.circular(10),
          onPressed: _isLoading ? null : _goBackToSendCode,
          child: TextButton(
            style: const ButtonStyle(
              overlayColor: WidgetStatePropertyAll(Colors.transparent),
            ),
            onPressed: _isLoading ? null : _goBackToSendCode,
            child: Text(
              AppLocalizations.of(context).resendVerificationCode,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: XbFontWeight.semibold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isTv = system.isTV;
    final page = Scaffold(
      backgroundColor: colorScheme.brightness == Brightness.dark
          ? colorScheme.surface
          : const Color(0xFFFAFBFD),
      body: XBContainer(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(isTv ? 10 : 16),
              child: Row(
                children: [
                  TVFocusable(
                    borderRadius: BorderRadius.circular(14),
                    onPressed: () {
                      if (_currentStep == ResetPasswordStep.resetPassword) {
                        _goBackToSendCode();
                      } else {
                        context.pop();
                      }
                    },
                    child: IconButton(
                      onPressed: () {
                        if (_currentStep == ResetPasswordStep.resetPassword) {
                          _goBackToSendCode();
                        } else {
                          context.pop();
                        }
                      },
                      icon: const Icon(Icons.arrow_back),
                      style: IconButton.styleFrom(
                        backgroundColor: colorScheme.surfaceContainerLow,
                      ).copyWith(
                        overlayColor: const WidgetStatePropertyAll(
                          Colors.transparent,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: isTv ? 12 : 16),
                  Text(
                    _currentStep == ResetPasswordStep.sendCode
                        ? AppLocalizations.of(context).resetPassword
                        : AppLocalizations.of(context).setNewPassword,
                    style: (isTv
                            ? Theme.of(context).textTheme.titleLarge
                            : Theme.of(context).textTheme.headlineMedium)
                        ?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: XbFontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isTv ? AuthTvLayout.horizontalPadding : 24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isTv ? AuthTvLayout.contentMaxWidth : 400,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: _currentStep == ResetPasswordStep.sendCode
                                ? KeyedSubtree(
                                    key: const ValueKey('send'),
                                    child: _buildSendCodeStep(),
                                  )
                                : KeyedSubtree(
                                    key: const ValueKey('reset'),
                                    child: _buildResetPasswordStep(),
                                  ),
                          ),
                          SizedBox(height: isTv ? 12 : 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                AppLocalizations.of(context).rememberPassword,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                              ),
                              TVFocusable(
                                borderRadius: BorderRadius.circular(10),
                                onPressed: () => context.pop(),
                                child: TextButton(
                                  style: const ButtonStyle(
                                    overlayColor: WidgetStatePropertyAll(
                                      Colors.transparent,
                                    ),
                                  ),
                                  onPressed: () => context.pop(),
                                  child: Text(
                                    AppLocalizations.of(context).backToLogin,
                                    style: TextStyle(
                                      color: colorScheme.primary,
                                      fontWeight: XbFontWeight.semibold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: isTv ? 12 : 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return AuthTvLayout.apply(context, page);
  }
}
