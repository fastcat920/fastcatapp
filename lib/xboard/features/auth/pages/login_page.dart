import 'dart:async';

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
import 'package:fl_clash/xboard/utils/backend_message_mapper.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:fl_clash/xboard/features/auth/utils/login_validation.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/xboard/features/about/pages/fastcat_about_page.dart';
import 'package:fl_clash/xboard/features/shared/widgets/legal_footer.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:fl_clash/xboard/features/auth/services/qr_login_service.dart';

const _gatewayOverrideUrl = String.fromEnvironment('XBOARD_GATEWAY_URL');

class LoginResponsiveScaffold extends StatelessWidget {
  const LoginResponsiveScaffold({
    super.key,
    required this.appBar,
    required this.body,
    this.isDesktop,
  });

  static const fullLayoutMinHeight = 640.0;

  final PreferredSizeWidget appBar;
  final Widget body;
  final bool? isDesktop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showPageActions = (isDesktop ?? system.isDesktop) ||
            constraints.maxHeight >= fullLayoutMinHeight;

        return Scaffold(
          resizeToAvoidBottomInset: true,
          appBar: showPageActions ? appBar : null,
          // 登录内容不再绘制到桌面端顶部工具栏下方，避免品牌图标被
          // 半透明 AppBar 裁切；空间不足时由表单区域自行滚动。
          extendBodyBehindAppBar: false,
          body: SafeArea(
            top: !showPageActions,
            child: body,
          ),
        );
      },
    );
  }
}

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late final FocusNode _emailFocusNode;
  late final FocusNode _passwordFocusNode;
  late final FocusNode _rememberFocusNode;
  late final FocusNode _loginFocusNode;
  late final FocusNode _registerFocusNode;
  late final FocusNode _forgotPasswordFocusNode;
  late final FocusNode _loginMethodFocusNode;
  late final FocusNode _refreshQrFocusNode;
  final _loginScrollController = ScrollController();
  bool _rememberPassword = true;
  bool _isPasswordVisible = false;
  bool _isCheckingWebsite = false;
  bool _hasAttemptedLogin = false;
  late bool _showQrLogin;
  late XBoardStorageService _storageService;

  static const String _appWebsite = '';

  @override
  void initState() {
    super.initState();
    _showQrLogin = system.isTV;
    _emailFocusNode = FocusNode(debugLabel: 'login-email');
    _passwordFocusNode = FocusNode(debugLabel: 'login-password');
    _rememberFocusNode = FocusNode(debugLabel: 'login-remember-password');
    _loginFocusNode = FocusNode(debugLabel: 'login-submit');
    _registerFocusNode = FocusNode(debugLabel: 'login-register');
    _forgotPasswordFocusNode = FocusNode(debugLabel: 'login-forgot-password');
    _loginMethodFocusNode = FocusNode(debugLabel: 'login-method');
    _refreshQrFocusNode = FocusNode(debugLabel: 'login-refresh-qr');
    _loginMethodFocusNode.onKeyEvent =
        (_, event) => _handleLoginMethodKey(event);
    _refreshQrFocusNode.onKeyEvent = (_, event) => _moveTvFocus(
          event,
          up: _loginMethodFocusNode,
        );
    _rememberFocusNode.onKeyEvent = (_, event) => _moveTvFocus(
          event,
          up: _passwordFocusNode,
          down: _loginFocusNode,
        );
    _loginFocusNode.onKeyEvent = (_, event) => _moveTvFocus(
          event,
          up: _rememberFocusNode,
          down: _registerFocusNode,
        );
    _registerFocusNode.onKeyEvent = (_, event) => _moveTvFocus(
          event,
          up: _loginFocusNode,
          right: _forgotPasswordFocusNode,
        );
    _forgotPasswordFocusNode.onKeyEvent = (_, event) => _moveTvFocus(
          event,
          up: _loginFocusNode,
          left: _registerFocusNode,
        );
    _storageService = ref.read(storageServiceProvider);
    _loadSavedCredentials();
    // 根 Application 已在首帧后预热初始化；这里仅在非网关调试模式下兜底。
    if (_gatewayOverrideUrl.trim().isEmpty) {
      _initializeXBoard();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      CustomerServiceHelper.prewarm();
      if (system.isTV && _loginMethodFocusNode.canRequestFocus) {
        _requestTvFocus(_loginMethodFocusNode);
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _rememberFocusNode.dispose();
    _loginFocusNode.dispose();
    _registerFocusNode.dispose();
    _forgotPasswordFocusNode.dispose();
    _loginMethodFocusNode.dispose();
    _refreshQrFocusNode.dispose();
    _loginScrollController.dispose();
    super.dispose();
  }

  void _requestTvFocus(FocusNode node) {
    node.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !node.hasFocus || node.context == null) return;
      Scrollable.ensureVisible(
        node.context!,
        alignment: 0.35,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  KeyEventResult _moveTvFocus(
    KeyEvent event, {
    FocusNode? up,
    FocusNode? down,
    FocusNode? left,
    FocusNode? right,
  }) {
    if (!system.isTV || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final target = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowUp => up,
      LogicalKeyboardKey.arrowDown => down,
      LogicalKeyboardKey.arrowLeft => left,
      LogicalKeyboardKey.arrowRight => right,
      _ => null,
    };
    if (target == null || !target.canRequestFocus) {
      return KeyEventResult.ignored;
    }
    _requestTvFocus(target);
    return KeyEventResult.handled;
  }

  KeyEventResult _handleLoginMethodKey(KeyEvent event) {
    if (!system.isTV || event is! KeyDownEvent) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
        _setLoginMethod(true);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        _setLoginMethod(false);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        _requestTvFocus(
          _showQrLogin ? _refreshQrFocusNode : _emailFocusNode,
        );
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  void _setLoginMethod(bool showQr) {
    if (_showQrLogin == showQr) return;
    setState(() => _showQrLogin = showQr);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !system.isTV) return;
      _requestTvFocus(_loginMethodFocusNode);
    });
  }

  /// 初始化 XBoard（统一入口）
  Future<void> _initializeXBoard() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref.read(initializationProvider.notifier).initialize();
      } catch (e) {
        // 初始化失败，UI 会显示错误状态
      } finally {
        CustomerServiceHelper.prewarm();
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
      _rememberPassword = hasRememberPasswordSetting ? rememberPassword : false;
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      // 忽略加载凭据失败,继续正常流程
    }
  }

  Future<void> _login() async {
    if (!_hasAttemptedLogin) {
      setState(() => _hasAttemptedLogin = true);
    }
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
        message.startsWith('[BACKEND_UNAVAILABLE]') ||
        message.startsWith('[BUSINESS_LOGIN_FAILED]')) {
      return al.xboardLoginErrorConfigLoad;
    }
    if (message.startsWith('[ACCOUNT_DISABLED]')) {
      return al.xboardAccountBannedDetail;
    }
    // 账号禁用/封禁优先于密码错误：即使 Provider 误包 [CREDENTIALS_ERROR]，
    // 只要原始消息包含禁用关键词，都应展示账号状态而非密码错误。
    final lower = message.toLowerCase();
    if (lower.contains('disabled') ||
        lower.contains('banned') ||
        lower.contains('suspended') ||
        lower.contains('frozen') ||
        message.contains('禁用') ||
        message.contains('封禁') ||
        message.contains('停用') ||
        message.contains('停止使用') ||
        message.contains('冻结')) {
      return al.xboardAccountBannedDetail;
    }
    if (message.startsWith('[CREDENTIALS_ERROR]') ||
        message.startsWith('[CREDENTIALS_REQUIRED]') ||
        message.startsWith('[DEVICE_ID_REQUIRED]')) {
      return al.xboardLoginErrorCredentials;
    }
    // 降级：旧格式文本匹配
    if (message.contains('SocketException') ||
        message.contains('TimeoutException') ||
        message.contains('HandshakeException') ||
        lower.contains('connection refused') ||
        lower.contains('no address associated') ||
        lower.contains('network is unreachable')) {
      return al.xboardLoginErrorNetwork;
    }
    if (lower.contains("invalid credentials") ||
        lower.contains('unauthorized') ||
        lower.contains('email or password') ||
        lower.contains('password error') ||
        lower.contains('wrong password') ||
        lower.contains('user not found') ||
        lower.contains('account not found') ||
        message.contains('密码错误') ||
        message.contains('账号或密码') ||
        message.contains('用户不存在') ||
        message.contains('邮箱不存在')) {
      return BackendMessageMapper.map(
        message,
        context: BackendMessageContext.login,
        fallback: message,
      );
    }
    if (lower.contains('too many') ||
        lower.contains('rate limit') ||
        lower.contains('login limit') ||
        lower.contains('temporarily locked') ||
        message.contains('频繁') ||
        message.contains('限制') ||
        message.contains('稍后再试')) {
      return al.xboardLoginErrorLimited;
    }
    if (message.contains('DEVICE_LIMIT_EXCEEDED') ||
        lower.contains('device limit exceeded')) {
      return al.xboardLoginErrorDeviceLimit;
    }
    // 后端业务错误优先映射为本地化提示，未命中时保留 API 原始提示。
    return BackendMessageMapper.map(
      message,
      context: BackendMessageContext.login,
      fallback: message,
    );
  }

  Future<void> _openOfficialWebsite(BuildContext context) async {
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
      XBoardNotification.showError('未配置官方网站');
    }
  }

  Widget _buildLogo(ColorScheme colorScheme, {bool compact = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = compact ? 64.0 : 80.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.primaryContainer.withAlpha(51)
            : colorScheme.primary.withValues(alpha: 0.10),
        shape: BoxShape.circle,
      ),
      padding: EdgeInsets.all(compact ? 5 : 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.asset(
          'assets/images/icon.png',
          width: compact ? 54 : 64,
          height: compact ? 54 : 64,
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
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final isShortViewport = viewportHeight < 760;
    final compactBrand = isShortViewport || system.isTV;
    final showCopyright = !system.isTV && !isShortViewport;
    final verticalPadding = isShortViewport ? 12.0 : 20.0;

    return LoginResponsiveScaffold(
      appBar: AppBar(
        key: const Key('login-page-app-bar'),
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
      body: Container(
        color: isDark ? colorScheme.surface : const Color(0xFFFAFBFD),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  controller: _loginScrollController,
                  // 桌面和 TV 不显示 iOS 式回弹：内容未溢出时页面保持固定，
                  // 仅在窗口确实不足以显示登录控件时才允许滚动。
                  physics: (system.isDesktop || system.isTV)
                      ? const ClampingScrollPhysics()
                      : null,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: verticalPadding,
                  ),
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
                                _buildLogo(colorScheme, compact: compactBrand),
                                SizedBox(height: compactBrand ? 8 : 12),
                                Text(
                                  localizedAppName,
                                  style: textTheme.headlineMedium?.copyWith(
                                    color: colorScheme.onSurface,
                                    fontWeight: XbFontWeight.bold,
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
                          if (system.isTV || system.isDesktop) ...[
                            SizedBox(height: compactBrand ? 16 : 20),
                            Focus(
                              focusNode: _loginMethodFocusNode,
                              child: SegmentedButton<bool>(
                                segments: const [
                                  ButtonSegment(
                                    value: true,
                                    icon: Icon(Icons.qr_code_2_outlined),
                                    label: Text('扫码登录'),
                                  ),
                                  ButtonSegment(
                                    value: false,
                                    icon: Icon(Icons.password_outlined),
                                    label: Text('账号登录'),
                                  ),
                                ],
                                selected: {_showQrLogin},
                                showSelectedIcon: false,
                                onSelectionChanged: (selected) =>
                                    _setLoginMethod(selected.first),
                              ),
                            ),
                            SizedBox(height: compactBrand ? 10 : 12),
                          ],
                          IndexedStack(
                            index: (system.isTV || system.isDesktop) &&
                                    _showQrLogin
                                ? 0
                                : 1,
                            alignment: Alignment.topCenter,
                            sizing: StackFit.loose,
                            children: [
                              if (system.isTV || system.isDesktop)
                                _QrLoginCard(
                                  enabled: _showQrLogin &&
                                      !isIniting &&
                                      !userState.isLoading,
                                  refreshFocusNode: _refreshQrFocusNode,
                                  onAuthorized: (result) => ref
                                      .read(xboardUserProvider.notifier)
                                      .loginWithQrToken(result.token,
                                          email: result.email),
                                )
                              else
                                const SizedBox.shrink(),
                              ExcludeFocus(
                                excluding: (system.isTV || system.isDesktop) &&
                                    _showQrLogin,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    SizedBox(height: compactBrand ? 16 : 24),
                                    XBInputField(
                                      focusNode: _emailFocusNode,
                                      onKeyEvent: (_, event) => _moveTvFocus(
                                        event,
                                        up: (system.isTV || system.isDesktop)
                                            ? _loginMethodFocusNode
                                            : null,
                                        down: _passwordFocusNode,
                                      ),
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
                                    SizedBox(height: compactBrand ? 12 : 16),
                                    XBInputField(
                                      focusNode: _passwordFocusNode,
                                      onKeyEvent: (_, event) => _moveTvFocus(
                                        event,
                                        up: _emailFocusNode,
                                        down: _rememberFocusNode,
                                      ),
                                      controller: _passwordController,
                                      labelText:
                                          appLocalizations.xboardPassword,
                                      hintText: appLocalizations.xboardPassword,
                                      prefixIcon: Icons.lock_outlined,
                                      textInputAction: TextInputAction.done,
                                      onFieldSubmitted: (_) {
                                        if (!(isIniting ||
                                            userState.isLoading)) {
                                          _login();
                                        }
                                      },
                                      obscureText: !_isPasswordVisible,
                                      autovalidateMode: _hasAttemptedLogin
                                          ? AutovalidateMode.onUserInteraction
                                          : AutovalidateMode.disabled,
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _isPasswordVisible
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _isPasswordVisible =
                                                !_isPasswordVisible;
                                          });
                                        },
                                      ),
                                      validator: (value) {
                                        return switch (
                                            validateLoginPassword(value)) {
                                          LoginPasswordIssue.empty =>
                                            appLocalizations.xboardPassword,
                                          LoginPasswordIssue.tooShort =>
                                            appLocalizations.passwordMin8Chars,
                                          null => null,
                                        };
                                      },
                                    ),
                                    SizedBox(height: compactBrand ? 12 : 16),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          // 记住密码
                                          GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _rememberPassword =
                                                    !_rememberPassword;
                                              });
                                            },
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                  child: Checkbox(
                                                    focusNode:
                                                        _rememberFocusNode,
                                                    value: _rememberPassword,
                                                    onChanged: (value) {
                                                      setState(() {
                                                        _rememberPassword =
                                                            value ?? false;
                                                      });
                                                    },
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  appLocalizations
                                                      .xboardRememberPassword,
                                                  style: textTheme.bodyMedium,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(height: compactBrand ? 16 : 20),
                                    // 初始化失败或重试中显示提示条
                                    if (initState.isFailed || isIniting) ...[
                                      Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 12),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: initState.isFailed
                                              ? colorScheme.errorContainer
                                              : colorScheme
                                                  .surfaceContainerHighest,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            if (initState.isFailed)
                                              Icon(Icons.warning_outlined,
                                                  size: 16,
                                                  color: colorScheme
                                                      .onErrorContainer)
                                            else
                                              SizedBox(
                                                width: 14,
                                                height: 14,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                              ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                initState.isFailed
                                                    ? (initState.errorMessage ??
                                                        appLocalizations
                                                            .checkNetwork)
                                                    : (initState
                                                            .currentStepDescription ??
                                                        '正在重试...'),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: initState.isFailed
                                                      ? colorScheme
                                                          .onErrorContainer
                                                      : colorScheme
                                                          .onSurfaceVariant,
                                                ),
                                              ),
                                            ),
                                            if (initState.isFailed)
                                              TextButton(
                                                onPressed: () {
                                                  ref
                                                      .read(
                                                          initializationProvider
                                                              .notifier)
                                                      .refresh();
                                                },
                                                style: TextButton.styleFrom(
                                                  padding: EdgeInsets.zero,
                                                  minimumSize:
                                                      const Size(40, 28),
                                                ),
                                                child: Text(
                                                  appLocalizations.xboardRetry,
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: colorScheme.error),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    SizedBox(
                                      child: FilledButton(
                                        focusNode: _loginFocusNode,
                                        onPressed:
                                            (isIniting || userState.isLoading)
                                                ? null
                                                : _login,
                                        style: XbUiButton.filledPrimary(
                                          context,
                                          busy: userState.isLoading,
                                        ).copyWith(
                                          shape: WidgetStatePropertyAll(
                                            RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                          ),
                                        ),
                                        child: isIniting
                                            ? Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: colorScheme
                                                          .onSurface
                                                          .withValues(
                                                              alpha: 0.4),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Text(appLocalizations
                                                      .xboardLoadingConfiguration),
                                                ],
                                              )
                                            : userState.isLoading
                                                ? Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      SizedBox(
                                                        width: 18,
                                                        height: 18,
                                                        child:
                                                            CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: colorScheme
                                                              .onPrimary,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 10),
                                                      Text(
                                                        appLocalizations
                                                            .xboardLoggingIn,
                                                        style: TextStyle(
                                                            color: colorScheme
                                                                .onPrimary),
                                                      ),
                                                    ],
                                                  )
                                                : Text(appLocalizations
                                                    .xboardLogin),
                                      ),
                                    ),
                                    SizedBox(height: compactBrand ? 10 : 14),
                                    // 保持左右分布，并相对登录按钮边缘略微内收
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          TextButton.icon(
                                            focusNode: _registerFocusNode,
                                            onPressed: isIniting
                                                ? null
                                                : _navigateToRegister,
                                            icon: const Icon(
                                              Icons.person_add_outlined,
                                              size: 18,
                                            ),
                                            label: Text(appLocalizations
                                                .xboardRegister),
                                          ),
                                          TextButton.icon(
                                            focusNode: _forgotPasswordFocusNode,
                                            onPressed: isIniting
                                                ? null
                                                : _navigateToForgotPassword,
                                            icon: const Icon(
                                              Icons.help_outline,
                                              size: 18,
                                            ),
                                            label: Text(appLocalizations
                                                .xboardForgotPassword),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (system.isDesktop || system.isTV) ...[
                                      const SizedBox(height: 12),
                                      _buildLoginFooter(context),
                                    ],
                                  ],
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
            if (showCopyright && !system.isDesktop && !system.isTV)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildLoginFooter(context),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginFooter(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const FastCatAboutPage(),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            child: Text(
              appLocalizations.updateCheckCurrentVersion(
                'V${globalState.packageInfo.version}',
              ),
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        const FastCatCopyrightNotice(compact: true),
      ],
    );
  }
}

class _QrLoginCard extends StatefulWidget {
  const _QrLoginCard({
    required this.enabled,
    required this.refreshFocusNode,
    required this.onAuthorized,
  });
  final bool enabled;

  final FocusNode refreshFocusNode;
  final Future<bool> Function(QrLoginResult result) onAuthorized;

  @override
  State<_QrLoginCard> createState() => _QrLoginCardState();
}

class _QrLoginCardState extends State<_QrLoginCard> {
  QrLoginChallenge? _challenge;
  Timer? _pollTimer;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _create());
  }

  @override
  void didUpdateWidget(covariant _QrLoginCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.enabled && widget.enabled && _challenge == null) _create();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _create() async {
    if (_loading || !widget.enabled) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final challenge = await QrLoginService.create();
      if (!mounted) return;
      setState(() {
        _challenge = challenge;
        _loading = false;
      });
      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '二维码加载失败';
        });
      }
    }
  }

  Future<void> _poll() async {
    final challenge = _challenge;
    if (!widget.enabled || challenge == null || _loading) return;
    try {
      final result = await QrLoginService.poll(challenge);
      if (result == null) return;
      _pollTimer?.cancel();
      if (!mounted) return;
      setState(() => _loading = true);
      final success = await widget.onAuthorized(result);
      if (mounted && !success) {
        setState(() {
          _loading = false;
          _error = '登录失败，请刷新二维码';
        });
      }
    } catch (_) {
      // An expired/consumed challenge is replaced explicitly so transient
      // polling failures do not make the login page flicker.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final challenge = _challenge;
    return Container(
      // 与账号密码表单使用同一父级最大宽度，内容高度仍由二维码区域决定。
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      // 卡片按内容收紧，等高差额由外层 IndexedStack 留在边框外。
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('扫码登录',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('使用已登录快猫的手机扫描并确认', style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),
        if (_loading && challenge == null)
          const SizedBox(
              width: 180,
              height: 180,
              child: Center(child: CircularProgressIndicator()))
        else if (challenge != null)
          QrImageView(
              data: challenge.qrData, size: 180, backgroundColor: Colors.white)
        else
          SizedBox(height: 180, child: Center(child: Text(_error ?? '二维码不可用'))),
        const SizedBox(height: 8),
        TextButton.icon(
            focusNode: widget.refreshFocusNode,
            onPressed: _loading ? null : _create,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('刷新二维码')),
      ]),
    );
  }
}
