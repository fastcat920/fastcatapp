import 'package:fl_clash/xboard/services/services.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/xboard/features/initialization/initialization.dart';
import 'package:fl_clash/common/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'register_page.dart';
import 'forgot_password_page.dart';
import 'package:fl_clash/xboard/features/auth/utils/customer_service_helper.dart';
import 'package:fl_clash/xboard/features/shared/shared.dart';
import 'package:fl_clash/xboard/config/xboard_config.dart';
import 'package:fl_clash/xboard/config/utils/website_url_resolver.dart';
import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';

const _gatewayOverrideUrl = String.fromEnvironment('XBOARD_GATEWAY_URL');

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberPassword = true;
  bool _isPasswordVisible = false;
  bool _isCheckingWebsite = false;
  late XBoardStorageService _storageService;

  static const String _appWebsite = '';

  @override
  void initState() {
    super.initState();
    _storageService = ref.read(storageServiceProvider);
    _loadSavedCredentials();
    // 根 Application 已在首帧后预热初始化；这里仅在非网关调试模式下兜底。
    if (_gatewayOverrideUrl.trim().isEmpty) {
      _initializeXBoard();
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// 初始化 XBoard（统一入口）
  Future<void> _initializeXBoard() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref.read(initializationProvider.notifier).initialize();
      } catch (e) {
        // 初始化失败，UI 会显示错误状态
      }
    });
  }

  void refreshCredentials() {
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final savedEmail = await _storageService.getSavedEmail();
      final savedPassword = await _storageService.getSavedPassword();
      final rememberPassword = await _storageService.getRememberPassword();
      final hasRememberPasswordSetting =
          await _storageService.hasRememberPasswordSetting();
      if (savedEmail != null && savedEmail.isNotEmpty) {
        _emailController.text = savedEmail;
      }
      if (savedPassword != null &&
          savedPassword.isNotEmpty &&
          rememberPassword) {
        _passwordController.text = savedPassword;
      }
      _rememberPassword = hasRememberPasswordSetting ? rememberPassword : true;
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      // 忽略加载凭据失败,继续正常流程
    }
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final rememberPassword = _rememberPassword;
      final userNotifier = ref.read(xboardUserProvider.notifier);
      final success = await userNotifier.login(
        email,
        password,
      );
      if (success) {
        if (rememberPassword) {
          await _storageService.saveCredentials(
            email,
            password,
            true,
          );
        } else {
          await _storageService.saveCredentials(
            email,
            '',
            false,
          );
        }
        await _storageService.saveAutoLogin(false);
      }
      if (mounted) {
        if (success) {
          XBoardNotification.showSuccess(appLocalizations.xboardLoginSuccess);
          // 无需手动导航：auth 状态变化后 GoRouter redirect 自动跳转到 '/'
        } else {
          final userState = ref.read(xboardUserProvider);
          if (userState.errorMessage != null) {
            // 使用原生 Toast 通知（自动消失）
            XBoardNotification.showError(
              _normalizeLoginError(userState.errorMessage!),
            );
          }
        }
      }
    }
  }

  String _normalizeLoginError(String message) {
    final al = appLocalizations;
    // Provider 侧带 [CODE] 前缀的精确匹配
    if (message.startsWith('[NETWORK_ERROR]')) {
      return al.xboardLoginErrorNetwork;
    }
    if (message.startsWith('[CONFIG_LOAD_FAILED]') ||
        message.startsWith('[BACKEND_UNREACHABLE]') ||
        message.startsWith('[BUSINESS_LOGIN_FAILED]')) {
      return al.xboardLoginErrorConfigLoad;
    }
    if (message.startsWith('[CREDENTIALS_ERROR]') ||
        message.startsWith('[CREDENTIALS_REQUIRED]') ||
        message.startsWith('[DEVICE_ID_REQUIRED]')) {
      return al.xboardLoginErrorCredentials;
    }
    // 降级：旧格式文本匹配
    final lower = message.toLowerCase();
    if (message.contains('SocketException') ||
        message.contains('TimeoutException') ||
        message.contains('HandshakeException') ||
        lower.contains('connection refused') ||
        lower.contains('no address associated') ||
        lower.contains('network is unreachable')) {
      return al.xboardLoginErrorNetwork;
    }
    final trimmed = message.trim();
    if (trimmed == '登录失败' ||
        trimmed == '登陆失败' ||
        lower.contains('invalid credentials') ||
        lower.contains('unauthorized') ||
        lower.contains('email or password')) {
      return al.xboardLoginErrorCredentials;
    }
    if (message.contains('DEVICE_LIMIT_EXCEEDED') ||
        lower.contains('device limit exceeded')) {
      return message;
    }
    // 后端业务错误保留 API 返回的真实提示，例如登录限制、账号状态等。
    return message;
  }

  Future<void> _openOfficialWebsite(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isCheckingWebsite = true);

    final success = await WebsiteUrlResolver.openWithFallback(
      primaryUrls: XBoardConfig.websiteUrls,
      fallbackLocalUrl: () => ConfigFileLoaderHelper.getFallbackWebsiteUrl(),
      fallbackApiUrl: () async {
        try {
          final sdk = await ref.read(xboardSdkProvider.future);
          final resp = await sdk.httpService.getRequest('/guest/comm/config');
          final data = resp['data'] as Map<String, dynamic>?;
          return data?['app_url'] as String? ?? '';
        } catch (_) {
          return '';
        }
      },
    );

    setState(() => _isCheckingWebsite = false);

    if (!success && mounted) {
      messenger.showSnackBar(const SnackBar(content: Text('未配置官方网站')));
    }
  }

  Widget _buildLogo(ColorScheme colorScheme) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.primaryContainer.withAlpha(51)
            : colorScheme.primary.withValues(alpha: 0.10),
        shape: BoxShape.circle,
      ),
      padding: const EdgeInsets.all(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.asset(
          'assets/images/icon.png',
          width: 64,
          height: 64,
        ),
      ),
    );
  }

  void _navigateToRegister() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const RegisterPage()),
    );
    _loadSavedCredentials();
    _initializeXBoard(); // 重新初始化
  }

  void _navigateToForgotPassword() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const ForgotPasswordPage()),
    );
    _initializeXBoard(); // 重新初始化
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final initState = ref.watch(initializationProvider);
    final userState = ref.watch(xboardUserProvider);

    // 初始化中：直接显示登录表单，按钮禁用 + 右上角转圈，无需全屏加载画面
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isIniting = !initState.isReady && !initState.isFailed;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDark ? null : Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(
          children: [
            TextButton.icon(
              onPressed: _isCheckingWebsite
                  ? null
                  : () => _openOfficialWebsite(context),
              icon: _isCheckingWebsite
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.language_outlined, size: 18),
              label: Text(_isCheckingWebsite
                  ? appLocalizations.checking
                  : appLocalizations.officialWebsite),
              style: XbUiButton.textChipPrimary(context),
            ),
            const Spacer(),
            // 初始化时：右上角显示小转圈
            if (isIniting)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                  ),
                ),
              )
            else ...[
              // 客服按钮固定显示（远程 Crisp 优先，本地 Crisp 兜底）
              TextButton.icon(
                style: XbUiButton.textChipPrimary(context),
                icon: const Icon(Icons.support_agent_outlined, size: 18),
                label: Text(appLocalizations.contactSupport),
                onPressed: () => CustomerServiceHelper.open(context),
              ),
            ],
            const SizedBox(width: 8),
          ],
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        color: isDark ? colorScheme.surface : const Color(0xFFFAFBFD),
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Column(
                        children: [
                          _buildLogo(colorScheme),
                          const SizedBox(height: 12),
                          Text(
                            appName,
                            style: textTheme.headlineMedium?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_appWebsite.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              _appWebsite,
                              style: textTheme.titleSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    XBInputField(
                      controller: _emailController,
                      labelText: appLocalizations.xboardEmail,
                      hintText: appLocalizations.xboardEmail,
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return appLocalizations.xboardEmail;
                        }
                        if (!value.contains('@')) {
                          return appLocalizations.xboardEmail;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    XBInputField(
                      controller: _passwordController,
                      labelText: appLocalizations.xboardPassword,
                      hintText: appLocalizations.xboardPassword,
                      prefixIcon: Icons.lock_outlined,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) {
                        if (!(isIniting || userState.isLoading)) {
                          _login();
                        }
                      },
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
                          return appLocalizations.xboardPassword;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // 记住密码
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _rememberPassword = !_rememberPassword;
                              });
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: _rememberPassword,
                                    onChanged: (value) {
                                      setState(() {
                                        _rememberPassword = value ?? false;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  appLocalizations.xboardRememberPassword,
                                  style: textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // 初始化失败或重试中显示提示条
                    if (initState.isFailed || isIniting) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: initState.isFailed
                              ? colorScheme.errorContainer
                              : colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            if (initState.isFailed)
                              Icon(Icons.warning_outlined,
                                  size: 16, color: colorScheme.onErrorContainer)
                            else
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                initState.isFailed
                                    ? (initState.errorMessage ??
                                        appLocalizations.checkNetwork)
                                    : (initState.currentStepDescription ??
                                        '正在重试...'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: initState.isFailed
                                      ? colorScheme.onErrorContainer
                                      : colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            if (initState.isFailed)
                              TextButton(
                                onPressed: () {
                                  ref
                                      .read(initializationProvider.notifier)
                                      .refresh();
                                },
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(40, 28),
                                ),
                                child: Text(
                                  appLocalizations.xboardRetry,
                                  style: TextStyle(
                                      fontSize: 12, color: colorScheme.error),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    SizedBox(
                      height: 50,
                      child: FilledButton(
                        onPressed:
                            (isIniting || userState.isLoading) ? null : _login,
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: const Color(0xFFFAFBFD),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: isIniting
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colorScheme.onSurface
                                          .withValues(alpha: 0.4),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Text('正在加载配置...'),
                                ],
                              )
                            : userState.isLoading
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: colorScheme.onPrimary,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        '登录中...',
                                        style: TextStyle(
                                            color: colorScheme.onPrimary),
                                      ),
                                    ],
                                  )
                                : Text(appLocalizations.xboardLogin),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // 注册 + 忘记密码 并排
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          onPressed: _navigateToRegister,
                          icon: Icon(Icons.person_add_outlined,
                              size: 18, color: colorScheme.primary),
                          label: Text(
                            appLocalizations.xboardRegister,
                            style: TextStyle(
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _navigateToForgotPassword,
                          icon: Icon(Icons.help_outline,
                              size: 18, color: colorScheme.primary),
                          label: Text(
                            appLocalizations.xboardForgotPassword,
                            style: TextStyle(
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
