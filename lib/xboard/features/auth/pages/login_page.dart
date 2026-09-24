import 'dart:async';

import 'package:fl_clash/xboard/services/services.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/xboard/features/initialization/initialization.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/l10n/l10n.dart';
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
import 'package:fl_clash/xboard/features/auth/widgets/auth_tv_layout.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/widgets.dart';

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
            system.isTV ||
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
  late final FocusNode _languageFocusNode;
  late final FocusNode _themeFocusNode;
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
    _languageFocusNode = FocusNode(debugLabel: 'login-language');
    _themeFocusNode = FocusNode(debugLabel: 'login-theme');
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
    _languageFocusNode.dispose();
    _themeFocusNode.dispose();
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
      case LogicalKeyboardKey.arrowUp:
        _requestTvFocus(_languageFocusNode);
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

  Future<void> _chooseTvLanguage() async {
    final current = ref.read(appSettingProvider).locale ?? '';
    final selected = await showDialog<String>(
      context: context,
      builder: (_) => XbChoiceDialog<String>(
        title: appLocalizations.language,
        options: const ['', 'zh_CN', 'en'],
        selected: current,
        labelBuilder: (value) => switch (value) {
          '' => appLocalizations.system,
          'zh_CN' => '简体中文',
          _ => 'English',
        },
      ),
    );
    if (selected == null) return;
    ref.read(appSettingProvider.notifier).updateState(
          (state) => state.copyWith(locale: selected.isEmpty ? null : selected),
        );
  }

  void _toggleTvTheme() {
    final nextMode = Theme.of(context).brightness == Brightness.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    ref.read(themeSettingProvider.notifier).updateState(
          (state) => state.copyWith(themeMode: nextMode),
        );
  }

  PreferredSizeWidget _buildTvLoginAppBar(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final radius = BorderRadius.circular(XbUiTokens.radiusSm);

    Widget action({
      required FocusNode focusNode,
      required VoidCallback onPressed,
      required IconData icon,
      required String label,
      required KeyEventResult Function(FocusNode, KeyEvent) onKeyEvent,
    }) {
      return TVFocusable(
        focusNode: focusNode,
        borderRadius: radius,
        onPressed: onPressed,
        onKeyEvent: onKeyEvent,
        child: TextButton.icon(
          style: XbUiButton.textChipPrimary(context).copyWith(
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
          onPressed: onPressed,
          icon: Icon(icon, size: 20, color: colorScheme.primary),
          label: Text(
            label,
            style: TextStyle(
              color: colorScheme.primary,
              fontWeight: XbFontWeight.semibold,
            ),
          ),
        ),
      );
    }

    return AppBar(
      key: const Key('login-page-app-bar'),
      automaticallyImplyLeading: false,
      toolbarHeight: AuthTvLayout.toolbarHeight,
      titleSpacing: 20,
      backgroundColor: XbUiTokens.pageBackground(context),
      elevation: 0,
      scrolledUnderElevation: 0,
      title: action(
        focusNode: _languageFocusNode,
        onPressed: _chooseTvLanguage,
        icon: Icons.language_outlined,
        label: appLocalizations.language,
        onKeyEvent: (_, event) => _moveTvFocus(
          event,
          right: _themeFocusNode,
          down: _loginMethodFocusNode,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 20),
          child: action(
            focusNode: _themeFocusNode,
            onPressed: _toggleTvTheme,
            icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            label: appLocalizations.switchTheme,
            onKeyEvent: (_, event) => _moveTvFocus(
              event,
              left: _languageFocusNode,
              down: _loginMethodFocusNode,
            ),
          ),
        ),
      ],
    );
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
    // TV keeps the same brand mark size as the full desktop login page. Only
    // short non-TV windows use the compact logo.
    final size = system.isTV ? 80.0 : (compact ? 64.0 : 80.0);
    final imageSize = system.isTV ? 64.0 : (compact ? 54.0 : 64.0);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.primaryContainer.withAlpha(51)
            : colorScheme.primary.withValues(alpha: 0.10),
        shape: BoxShape.circle,
      ),
      padding: EdgeInsets.all(system.isTV ? 6 : (compact ? 5 : 6)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.asset(
          'assets/images/icon.png',
          width: imageSize,
          height: imageSize,
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
    final verticalPadding = system.isTV ? 8.0 : (isShortViewport ? 12.0 : 20.0);

    final page = LoginResponsiveScaffold(
      appBar: system.isTV
          ? _buildTvLoginAppBar(context)
          : AppBar(
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
                          valueColor:
                              AlwaysStoppedAnimation(colorScheme.primary),
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
                    horizontal:
                        system.isTV ? AuthTvLayout.horizontalPadding : 32,
                    vertical: verticalPadding,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth:
                          system.isTV ? AuthTvLayout.contentMaxWidth : 400,
                    ),
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
                                  localizedAppNameForLocale(
                                    Localizations.localeOf(context)
                                        .toLanguageTag(),
                                  ),
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
                            TVFocusable(
                              focusNode: _loginMethodFocusNode,
                              borderRadius: BorderRadius.circular(
                                AuthTvLayout.controlRadius,
                              ),
                              onPressed: () => _setLoginMethod(!_showQrLogin),
                              onKeyEvent: (_, event) =>
                                  _handleLoginMethodKey(event),
                              child: SegmentedButton<bool>(
                                style: ButtonStyle(
                                  shape: WidgetStatePropertyAll(
                                    RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AuthTvLayout.controlRadius,
                                      ),
                                    ),
                                  ),
                                  overlayColor: const WidgetStatePropertyAll(
                                    Colors.transparent,
                                  ),
                                  side: WidgetStateProperty.resolveWith(
                                    (states) => BorderSide(
                                      color:
                                          states.contains(WidgetState.selected)
                                              ? colorScheme.primary
                                              : colorScheme.outlineVariant,
                                    ),
                                  ),
                                ),
                                segments: [
                                  ButtonSegment(
                                    value: true,
                                    icon: const Icon(Icons.qr_code_2_outlined),
                                    label: Text(appLocalizations.xboardQrLogin),
                                  ),
                                  ButtonSegment(
                                    value: false,
                                    icon: const Icon(Icons.password_outlined),
                                    label: Text(
                                        appLocalizations.xboardAccountLogin),
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
                                  onRefreshKeyEvent: (_, event) => _moveTvFocus(
                                    event,
                                    up: _loginMethodFocusNode,
                                  ),
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
                                          TVFocusable(
                                            focusNode: _rememberFocusNode,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            onKeyEvent: (_, event) =>
                                                _moveTvFocus(
                                              event,
                                              up: _passwordFocusNode,
                                              down: _loginFocusNode,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _rememberPassword =
                                                    !_rememberPassword;
                                              });
                                            },
                                            child: GestureDetector(
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
                                                      focusNode: system.isTV
                                                          ? null
                                                          : _rememberFocusNode,
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
                                    TVFocusable(
                                      focusNode: _loginFocusNode,
                                      borderRadius: BorderRadius.circular(
                                        system.isTV
                                            ? AuthTvLayout.controlRadius
                                            : 14,
                                      ),
                                      onKeyEvent: (_, event) => _moveTvFocus(
                                        event,
                                        up: _rememberFocusNode,
                                        down: _registerFocusNode,
                                      ),
                                      onPressed:
                                          (isIniting || userState.isLoading)
                                              ? null
                                              : _login,
                                      child: FilledButton(
                                        focusNode: system.isTV
                                            ? null
                                            : _loginFocusNode,
                                        onPressed:
                                            (isIniting || userState.isLoading)
                                                ? null
                                                : _login,
                                        style: XbUiButton.filledPrimary(
                                          context,
                                          busy: userState.isLoading,
                                        ).copyWith(
                                          overlayColor:
                                              const WidgetStatePropertyAll(
                                            Colors.transparent,
                                          ),
                                          shape: WidgetStatePropertyAll(
                                            RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                system.isTV
                                                    ? AuthTvLayout.controlRadius
                                                    : 14,
                                              ),
                                            ),
                                          ),
                                          minimumSize: system.isTV
                                              ? const WidgetStatePropertyAll(
                                                  Size.fromHeight(
                                                    AuthTvLayout.buttonHeight,
                                                  ),
                                                )
                                              : null,
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
                                          TVFocusable(
                                            focusNode: _registerFocusNode,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            onKeyEvent: (_, event) =>
                                                _moveTvFocus(
                                              event,
                                              up: _loginFocusNode,
                                              right: _forgotPasswordFocusNode,
                                            ),
                                            onPressed: isIniting
                                                ? null
                                                : _navigateToRegister,
                                            child: TextButton.icon(
                                              focusNode: system.isTV
                                                  ? null
                                                  : _registerFocusNode,
                                              style: const ButtonStyle(
                                                overlayColor:
                                                    WidgetStatePropertyAll(
                                                  Colors.transparent,
                                                ),
                                              ),
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
                                          ),
                                          TVFocusable(
                                            focusNode: _forgotPasswordFocusNode,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            onKeyEvent: (_, event) =>
                                                _moveTvFocus(
                                              event,
                                              up: _loginFocusNode,
                                              left: _registerFocusNode,
                                            ),
                                            onPressed: isIniting
                                                ? null
                                                : _navigateToForgotPassword,
                                            child: TextButton.icon(
                                              focusNode: system.isTV
                                                  ? null
                                                  : _forgotPasswordFocusNode,
                                              style: const ButtonStyle(
                                                overlayColor:
                                                    WidgetStatePropertyAll(
                                                  Colors.transparent,
                                                ),
                                              ),
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
    return AuthTvLayout.apply(context, page);
  }

  Widget _buildLoginFooter(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TVFocusable(
          borderRadius: BorderRadius.circular(16),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const FastCatAboutPage(),
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const FastCatAboutPage(),
              ),
            ),
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
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
    required this.onRefreshKeyEvent,
    required this.onAuthorized,
  });
  final bool enabled;

  final FocusNode refreshFocusNode;
  final FocusOnKeyEventCallback onRefreshKeyEvent;
  final Future<bool> Function(QrLoginResult result) onAuthorized;

  @override
  State<_QrLoginCard> createState() => _QrLoginCardState();
}

class _QrLoginCardState extends State<_QrLoginCard> {
  static const _refreshCooldown = Duration(seconds: 5);

  QrLoginChallenge? _challenge;
  Timer? _pollTimer;
  Timer? _countdownTimer;
  bool _loading = false;
  bool _expired = false;
  Duration _remaining = Duration.zero;
  DateTime? _refreshAvailableAt;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _create());
  }

  @override
  void didUpdateWidget(covariant _QrLoginCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.enabled && widget.enabled) {
      final challenge = _challenge;
      if (challenge == null) {
        _create();
      } else if (_hasExpired(challenge)) {
        _markExpired();
      } else {
        _startTimers(challenge);
      }
    }
    if (oldWidget.enabled && !widget.enabled) _stopTimers();
  }

  @override
  void dispose() {
    _stopTimers();
    super.dispose();
  }

  void _stopTimers() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    _pollTimer = null;
    _countdownTimer = null;
  }

  bool _hasExpired(QrLoginChallenge challenge) {
    return !DateTime.now().toUtc().isBefore(challenge.expiresAt);
  }

  void _startTimers(QrLoginChallenge challenge) {
    _stopTimers();
    _refreshAvailableAt = DateTime.now().add(_refreshCooldown);
    _updateCountdown();
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateCountdown(),
    );
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
  }

  void _updateCountdown() {
    if (!mounted) return;
    final challenge = _challenge;
    if (challenge == null) return;
    final milliseconds =
        challenge.expiresAt.difference(DateTime.now().toUtc()).inMilliseconds;
    final seconds = milliseconds <= 0 ? 0 : (milliseconds + 999) ~/ 1000;
    final expired = seconds == 0;
    setState(() {
      _remaining = Duration(seconds: seconds);
      _expired = expired;
    });
    if (expired) _stopTimers();
  }

  void _markExpired() {
    if (!mounted) return;
    _stopTimers();
    setState(() {
      _remaining = Duration.zero;
      _expired = true;
    });
  }

  Future<void> _create({bool invalidateCurrent = false}) async {
    if (_loading || !widget.enabled) return;
    final previous = _challenge;
    final previousWasExpired = previous != null && _hasExpired(previous);
    var previousInvalidated = previous == null;
    setState(() {
      _loading = true;
      _error = null;
      if (previousWasExpired) {
        _challenge = null;
        _remaining = Duration.zero;
        _expired = false;
      }
    });
    try {
      if (invalidateCurrent && previous != null) {
        await QrLoginService.cancel(previous);
        previousInvalidated = true;
      }
      if (invalidateCurrent && previous != null && previousInvalidated) {
        _stopTimers();
        if (!mounted) return;
        setState(() {
          _challenge = null;
          _remaining = Duration.zero;
          _expired = false;
        });
      }
      final challenge = await QrLoginService.create();
      if (!mounted) return;
      setState(() {
        _challenge = challenge;
        _loading = false;
        _expired = false;
        _error = null;
      });
      _startTimers(challenge);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          if (previousWasExpired) {
            _challenge = previous;
            _remaining = Duration.zero;
            _expired = true;
          } else if (previousInvalidated) {
            _challenge = null;
          }
          _error = invalidateCurrent
              ? AppLocalizations.of(context).xboardQrRefreshFailed
              : AppLocalizations.of(context).xboardQrLoadFailed;
        });
      }
    }
  }

  Future<void> _refresh() async {
    if (_loading || !widget.enabled) return;
    final availableAt = _refreshAvailableAt;
    if (!_expired &&
        availableAt != null &&
        DateTime.now().isBefore(availableAt)) {
      return;
    }
    // Expired challenges are already unusable and do not need a cancellation
    // round-trip. Skipping it prevents a failed cancel request from blocking
    // creation of the replacement QR code.
    await _create(invalidateCurrent: !_expired);
  }

  Future<void> _poll() async {
    final challenge = _challenge;
    if (!widget.enabled || challenge == null || _loading || _expired) return;
    try {
      final result = await QrLoginService.poll(challenge);
      if (result == null) return;
      _stopTimers();
      if (!mounted) return;
      setState(() => _loading = true);
      final success = await widget.onAuthorized(result);
      if (mounted && !success) {
        setState(() {
          _loading = false;
          _error = AppLocalizations.of(context).xboardQrLoginFailed;
          _remaining = Duration.zero;
          _expired = true;
        });
      }
    } on QrLoginExpiredException {
      _markExpired();
    } catch (_) {
      // An expired/consumed challenge is replaced explicitly so transient
      // polling failures do not make the login page flicker.
    }
  }

  String get _countdownText {
    final l10n = AppLocalizations.of(context);
    if (_loading && _challenge == null) return l10n.xboardQrGenerating;
    if (_expired) return _error ?? l10n.xboardQrExpired;
    if (_challenge == null) return _error ?? l10n.xboardQrUnavailable;
    if (_error != null) return _error!;
    final minutes =
        _remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds =
        _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    return l10n.xboardQrExpiresIn('$minutes:$seconds');
  }

  Widget _buildQrSurface(
    BuildContext context,
    ThemeData theme,
    double qrSize,
  ) {
    final challenge = _challenge;
    final canInteract = widget.enabled;
    final radius = BorderRadius.circular(12);
    final l10n = AppLocalizations.of(context);
    final minutes =
        _remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds =
        _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    return Semantics(
      button: true,
      label: _expired
          ? l10n.xboardQrExpiredSemantics
          : l10n.xboardQrReadySemantics('$minutes:$seconds'),
      child: TVFocusable(
        focusNode: widget.refreshFocusNode,
        borderRadius: radius,
        onPressed: canInteract ? _refresh : null,
        onKeyEvent: widget.onRefreshKeyEvent,
        child: SizedBox.square(
          dimension: qrSize,
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (challenge != null)
                  ColoredBox(
                    color: Colors.white,
                    child: QrImageView(
                      data: challenge.qrData,
                      size: qrSize,
                      backgroundColor: Colors.white,
                    ),
                  )
                else
                  ColoredBox(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Center(
                      child: Text(
                        _error ?? l10n.xboardQrUnavailable,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ),
                if (_loading)
                  ColoredBox(
                    color: Colors.black.withValues(alpha: 0.42),
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  )
                else if (_expired && challenge != null)
                  ColoredBox(
                    color: Colors.black.withValues(alpha: 0.52),
                    child: Center(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ).copyWith(
                          overlayColor: const WidgetStatePropertyAll(
                            Colors.transparent,
                          ),
                        ),
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: Text(l10n.xboardQrRefresh),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final qrSize = system.isTV ? 160.0 : 180.0;
    return Container(
      // 与账号密码表单使用同一父级最大宽度，内容高度仍由二维码区域决定。
      width: double.infinity,
      padding: EdgeInsets.all(system.isTV ? 12 : 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      // 卡片按内容收紧，等高差额由外层 IndexedStack 留在边框外。
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(l10n.xboardQrLogin,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
          l10n.xboardQrLoginDescription,
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        _buildQrSurface(context, theme, qrSize),
        const SizedBox(height: 8),
        Text(
          _countdownText,
          style: theme.textTheme.bodySmall?.copyWith(
            color: _expired
                ? theme.colorScheme.error
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: _expired ? XbFontWeight.semibold : FontWeight.normal,
          ),
        ),
      ]),
    );
  }
}
