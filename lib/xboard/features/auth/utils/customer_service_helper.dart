import 'package:fl_clash/common/cached_cupertino_page.dart';
import 'package:fl_clash/xboard/features/auth/widgets/customer_service_viewport.dart';
import 'package:fl_clash/xboard/features/auth/services/support_push_service.dart';
import 'package:fl_clash/xboard/features/auth/services/desktop_support_notifications.dart';
import 'package:fl_clash/xboard/widgets/navigation/mobile_navigation_bar.dart';
import 'package:http/io_client.dart';
import 'package:fl_clash/xboard/features/auth/services/support_proxy_repairs.dart';
import 'package:fl_clash/xboard/features/auth/services/support_connection_repairs.dart';
import 'package:fl_clash/common/sensitive_masker.dart';
import 'package:fl_clash/xboard/features/auth/services/support_assistance_service.dart';
import 'package:fl_clash/common/picker.dart' as app_picker;
import 'package:fastcat_support/fastcat_support.dart' as fc;
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/common/common.dart' show system;
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/xboard/config/xboard_config.dart';
import 'package:fl_clash/xboard/features/auth/auth.dart';
import 'package:fl_clash/xboard/domain/domain.dart';
import 'package:flutter/foundation.dart';
import 'package:fl_clash/xboard/core/core.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:tgo_widget/tgo_widget.dart';
import 'package:fl_clash/xboard/config/utils/config_file_loader.dart'
    as local_config;

const _logger = FileLogger('customer_service_helper.dart');
const _customerServiceHiddenTtl = Duration(minutes: 10);
const _desktopRootMenuWidth = 96.0;
const _mobileRootMenuHeight = 68.0;

@immutable
class CustomerServiceSessionState {
  const CustomerServiceSessionState({
    required this.isVisible,
    required this.restoreToken,
    required this.brightness,
    required this.localeTag,
  });

  final bool isVisible;
  final int restoreToken;
  final Brightness brightness;
  final String localeTag;

  CustomerServiceSessionState copyWith({
    bool? isVisible,
    int? restoreToken,
    Brightness? brightness,
    String? localeTag,
  }) {
    return CustomerServiceSessionState(
      isVisible: isVisible ?? this.isVisible,
      restoreToken: restoreToken ?? this.restoreToken,
      brightness: brightness ?? this.brightness,
      localeTag: localeTag ?? this.localeTag,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CustomerServiceSessionState &&
        other.isVisible == isVisible &&
        other.restoreToken == restoreToken &&
        other.brightness == brightness &&
        other.localeTag == localeTag;
  }

  @override
  int get hashCode => Object.hash(
        isVisible,
        restoreToken,
        brightness,
        localeTag,
      );
}

/// Unified FastCat Support entry for Flutter clients.
class CustomerServiceHelper {
  static final _unreadEvents = StreamController<int>.broadcast();
  static int supportUnreadCount = 0;
  static Stream<int> get supportUnreadCountStream => _unreadEvents.stream;
  static fc.FastCatSupport? _support;
  static Future<void> Function(BuildContext)? _openSupportView;
  static bool _initializingSupport = false;
  static SupportPushService? _pushService;
  static StreamSubscription<int>? _supportUnread;
  static StreamSubscription<Map<String, dynamic>>? _supportIncoming;
  static StreamSubscription<Map<String, dynamic>>? _supportMessageFeed;
  static fc.SupportNotificationSound? _supportTone;
  static DesktopSupportNotifications? _desktopNotifications;
  static StreamSubscription<fc.FastCatConnectionStatus>? _supportMonitor;
  static int _actualSupportUnread = 0;
  static AppLifecycleListener? _badgeLifecycle;
  static void _refreshSupportBadge() {
    // Desktop windows may be inactive while their conversation stays visible.
    // Only hiding the support view should expose its unread badge.
    final visibleCount = _actualSupportUnread;
    if (supportUnreadCount == visibleCount) return;
    supportUnreadCount = visibleCount;
    _unreadEvents.add(visibleCount);
  }

  static void _publishUnread(int count) {
    _actualSupportUnread = count;
    _desktopNotifications?.unread(count);
    if (Platform.isIOS || Platform.isAndroid) {
      unawaited(const MethodChannel('fastcat/support_push')
          .invokeMethod<void>('badge', count)
          .catchError((Object _) {}));
    }
    _badgeLifecycle ??= AppLifecycleListener(
        onStateChange: (_) => _refreshSupportBadge(),
        onResume: () {
          unawaited(_support?.client.refreshMessages());
        });
    _refreshSupportBadge();
  }

  static Future<void> disposeSupport() async {
    try {
      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          await _support?.client.unregisterPushDevice();
          break;
        } catch (_) {
          if (attempt == 2) rethrow;
          await Future<void>.delayed(Duration(seconds: attempt + 1));
        }
      }
    } finally {
      _closeEmbeddedCustomerService();
    }
  }

  static void _releaseSupport() {
    unawaited(_desktopNotifications?.close().catchError((Object error) {
      _logger.debug('Desktop notification cleanup failed: ${error.runtimeType}');
    }));
    _desktopNotifications = null;
    _openSupportView = null;
    _pushService?.close();
    _pushService = null;
    SupportAssistanceService.instance.clear();
    unawaited(_supportIncoming?.cancel());
    _supportIncoming = null;
    unawaited(_supportMessageFeed?.cancel());
    _supportMessageFeed = null;
    _supportTone?.dispose();
    _supportTone = null;
    unawaited(_supportUnread?.cancel());
    unawaited(_supportMonitor?.cancel());
    _supportUnread = null;
    _supportMonitor = null;
    _support?.close();
    _support = null;
    _publishUnread(0);
    _badgeLifecycle?.dispose();
    _badgeLifecycle = null;
  }

  CustomerServiceHelper._();

  static const MethodChannel _androidBackChannel =
      MethodChannel('fastcat/customer_service_back');

  static bool _androidBackHandlerRegistered = false;
  static OverlayEntry? _embeddedCustomerServiceEntry;
  static CachedCupertinoPage? _iosCustomerServicePage;
  static ValueNotifier<CustomerServiceSessionState>?
      _embeddedCustomerServiceState;
  static Timer? _embeddedCustomerServiceCloseTimer;
  static String? _embeddedCustomerServiceSignature;
  static DateTime? _embeddedCustomerServiceHiddenAt;
  static _FastCatSupportConfig? _fastCatSupportConfig;

  /// FastCat Support is the sole support platform; no WebView fallback.
  static bool get isAvailable => XBoardConfig.fastCatSupportConfigured
      ? XBoardConfig.fastCatSupportEnabled
      : _fastCatSupportConfig != null;

  static void prewarm() {
    unawaited(() async {
      if (_initializingSupport || _support != null) return;
      final context = globalState.navigatorKey.currentContext;
      if (context == null || !context.mounted) return;
      _initializingSupport = true;
      try {
        await _openFastCatSupport(context, showView: false);
      } finally {
        _initializingSupport = false;
      }
    }());
  }

  static void syncDesktopTheme(Brightness brightness, {Color? accentColor}) =>
      syncDesktopWindowState(brightness, accentColor: accentColor);

  static void syncDesktopWindowState(Brightness brightness,
      {Color? accentColor, String? localeTag, String? loadingText}) {
    final session = _embeddedCustomerServiceState;
    if (session != null) {
      session.value =
          session.value.copyWith(brightness: brightness, localeTag: localeTag);
    }
  }

  static bool get isEmbeddedCustomerServiceVisible {
    return _embeddedCustomerServiceState?.value.isVisible ?? false;
  }

  static void ensureAndroidBackHandlerRegistered() {
    if (!Platform.isAndroid || _androidBackHandlerRegistered) return;
    _androidBackChannel.setMethodCallHandler((call) async {
      if (call.method == 'hideIfVisible') {
        return hideEmbeddedCustomerServiceIfVisible();
      }
      throw MissingPluginException('No method ${call.method}');
    });
    _androidBackHandlerRegistered = true;
  }

  static bool hideEmbeddedCustomerServiceIfVisible() {
    if (!isEmbeddedCustomerServiceVisible) return false;
    _hideEmbeddedCustomerService();
    return true;
  }

  static String _embeddedCustomerServiceSessionSignature({
    required String channel,
    required String websiteId,
  }) {
    return [
      Platform.operatingSystem,
      channel,
      websiteId.trim(),
    ].join('|');
  }

  static CustomerServiceSessionState _embeddedCustomerServiceStateFor(
    BuildContext context, {
    required bool isVisible,
    required int restoreToken,
  }) {
    Brightness brightness;
    String localeTag;
    try {
      brightness = Theme.of(context).brightness;
    } catch (_) {
      brightness =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
    }
    try {
      localeTag = Localizations.localeOf(context).toLanguageTag();
    } catch (_) {
      localeTag = 'en';
    }
    return CustomerServiceSessionState(
      isVisible: isVisible,
      restoreToken: restoreToken,
      brightness: brightness,
      localeTag: localeTag,
    );
  }

  static String? _currentRoutePath(BuildContext context) {
    try {
      return GoRouterState.of(context).uri.path;
    } catch (_) {
      return null;
    }
  }

  static bool _showExistingEmbeddedCustomerService(
    BuildContext context,
    String signature,
  ) {
    final entry = _embeddedCustomerServiceEntry;
    final state = _embeddedCustomerServiceState;
    if ((entry == null && _iosCustomerServicePage == null) ||
        state == null ||
        _embeddedCustomerServiceSignature != signature) {
      return false;
    }

    final hiddenAt = _embeddedCustomerServiceHiddenAt;
    if (hiddenAt != null &&
        DateTime.now().difference(hiddenAt) >= _customerServiceHiddenTtl) {
      _closeEmbeddedCustomerService(preserveMessaging: true);
      return false;
    }

    _embeddedCustomerServiceCloseTimer?.cancel();
    _embeddedCustomerServiceCloseTimer = null;
    _embeddedCustomerServiceHiddenAt = null;
    state.value = _embeddedCustomerServiceStateFor(
      context,
      isVisible: true,
      restoreToken: state.value.restoreToken + 1,
    );
    _iosCustomerServicePage?.show(context);
    return true;
  }

  static Future<void> _openEmbeddedCustomerService(
    BuildContext context, {
    required String signature,
    required Widget Function(
      VoidCallback hide,
      ValueListenable<CustomerServiceSessionState> session,
    ) builder,
  }) async {
    if (_showExistingEmbeddedCustomerService(context, signature)) return;
    _closeEmbeddedCustomerService(preserveMessaging: true);

    final session = ValueNotifier<CustomerServiceSessionState>(
      _embeddedCustomerServiceStateFor(
        context,
        isVisible: true,
        restoreToken: 0,
      ),
    );
    if (Platform.isIOS) {
      final path = _currentRoutePath(context) ?? '/';
      final router = GoRouter.of(context);
      final page = CachedCupertinoPage(
        child: ValueListenableBuilder<CustomerServiceSessionState>(
          valueListenable: session,
          builder: (_, current, child) =>
              TickerMode(enabled: current.isVisible, child: child!),
          child: _IosCustomerServiceFrame(
            initialPath: path,
            onDestination: (index) {
              FocusManager.instance.primaryFocus?.unfocus();
              _hideEmbeddedCustomerService();
              router.go(const ['/', '/plans', '/invite', '/mine'][index]);
            },
            child: builder(_hideEmbeddedCustomerService, session)),
        ),
        onHidden: _markEmbeddedCustomerServiceHidden,
      );
      _iosCustomerServicePage = page;
      _embeddedCustomerServiceState = session;
      session.addListener(_refreshSupportBadge);
      _embeddedCustomerServiceSignature = signature;
      _embeddedCustomerServiceHiddenAt = null;
      _refreshSupportBadge();
      page.show(context);
      return;
    }
    final showRootMenu = _shouldKeepRootMenuVisible(context);
    final overlay = Overlay.of(context, rootOverlay: true);
    final initialRoutePath = _currentRoutePath(context);
    late final OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => _EmbeddedCustomerServiceFrame(
        showRootMenu: showRootMenu,
        initialRoutePath: initialRoutePath,
        child: ValueListenableBuilder<CustomerServiceSessionState>(
          valueListenable: session,
          builder: (_, currentSession, child) {
            return Offstage(
              offstage: !currentSession.isVisible,
              child: IgnorePointer(
                ignoring: !currentSession.isVisible,
                child: child,
              ),
            );
          },
          child: BackButtonListener(
            onBackButtonPressed: () async {
              if (!isEmbeddedCustomerServiceVisible) return false;
              _hideEmbeddedCustomerService();
              return true;
            },
            child: Material(
              type: MaterialType.transparency,
              child: Navigator(
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (_) =>
                      builder(_hideEmbeddedCustomerService, session),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    _embeddedCustomerServiceEntry = entry;
    _embeddedCustomerServiceState = session;
    session.addListener(_refreshSupportBadge);
    _refreshSupportBadge();
    _embeddedCustomerServiceSignature = signature;
    _embeddedCustomerServiceHiddenAt = null;
    _embeddedCustomerServiceCloseTimer?.cancel();
    _embeddedCustomerServiceCloseTimer = null;
    overlay.insert(entry);
  }

  static bool _shouldKeepRootMenuVisible(BuildContext context) {
    try {
      final path = GoRouterState.of(context).uri.path;
      return path == '/' ||
          path.startsWith('/plans') ||
          path.startsWith('/invite') ||
          path.startsWith('/mine') ||
          path.startsWith('/logs');
    } catch (_) {
      return false;
    }
  }

  static void _hideEmbeddedCustomerService() {
    if (_iosCustomerServicePage != null) {
      _iosCustomerServicePage!.hide();
      return;
    }
    _markEmbeddedCustomerServiceHidden();
  }

  static void _markEmbeddedCustomerServiceHidden() {
    unawaited(
        _support?.client.setPushChatVisible(false).catchError((Object _) {}));
    final state = _embeddedCustomerServiceState;
    if (state == null) return;
    if (!state.value.isVisible) return;
    // Messages received while the chat is open are already seen by the user.
    // Clear their badge when the embedded chat is dismissed.
    if (_embeddedCustomerServiceSignature?.contains('|fastcat-support|') ==
        true) {
      TgoWidget.clearUnreadCount();
    }
    state.value = state.value.copyWith(isVisible: false);
    _embeddedCustomerServiceHiddenAt = DateTime.now();
    _embeddedCustomerServiceCloseTimer?.cancel();
    _embeddedCustomerServiceCloseTimer = Timer(_customerServiceHiddenTtl, () {
      final hiddenAt = _embeddedCustomerServiceHiddenAt;
      if (hiddenAt == null) return;
      if (DateTime.now().difference(hiddenAt) >= _customerServiceHiddenTtl) {
        _closeEmbeddedCustomerService(preserveMessaging: true);
      }
    });
  }

  static void _closeEmbeddedCustomerService({bool preserveMessaging = false}) {
    if (!preserveMessaging) _releaseSupport();
    _embeddedCustomerServiceCloseTimer?.cancel();
    _embeddedCustomerServiceCloseTimer = null;
    _embeddedCustomerServiceHiddenAt = null;
    _embeddedCustomerServiceSignature = null;
    _embeddedCustomerServiceState?.removeListener(_refreshSupportBadge);
    _embeddedCustomerServiceState?.dispose();
    _embeddedCustomerServiceState = null;
    _iosCustomerServicePage?.dispose();
    _iosCustomerServicePage = null;
    _embeddedCustomerServiceEntry?.remove();
    _embeddedCustomerServiceEntry = null;
  }

  static Future<void> open(BuildContext context) async {
    final config = await _resolveFastCatSupportConfig();
    if (!context.mounted) return;
    if (config == null) {
      XBoardNotification.showError(
          AppLocalizations.of(context).xboardCustomerServiceNotConfigured);
      return;
    }
    if (await _openFastCatSupport(context) || !context.mounted) return;
    XBoardNotification.showError(
        Localizations.localeOf(context).languageCode == 'zh'
            ? '客服暂时无法打开，请稍后重试。'
            : 'Support could not be opened. Please try again later.');
  }

  static Future<bool> _openFastCatSupport(BuildContext context,
      {bool showView = true}) async {
    fc.FastCatSupport? pendingSupport;
    try {
      final config = await _resolveFastCatSupportConfig();
      if (config == null || !context.mounted) return false;

      final signature = _embeddedCustomerServiceSessionSignature(
        channel: 'fastcat-support-v019',
        websiteId: '${config.baseUrl}|${config.appKey}',
      );
      if (_showExistingEmbeddedCustomerService(context, signature)) return true;
      if (showView && _support != null && _openSupportView != null) {
        await _openSupportView!(context);
        return true;
      }
      final visitor = _buildFastCatSupportVisitor(context);
      final deviceIdentity =
          await XBoardDeviceIdentityService.buildLoginPayload();
      if (!context.mounted) return true;
      final diagnosticRequests = <String>{};
      final diagnosticContainer =
          ProviderScope.containerOf(context, listen: false);
      final support = fc.FastCatSupport(
        repairHandlers: visitor?.platformOpenId == null
            ? {}
            : supportConnectionRepairs(
                accountId: visitor!.platformOpenId!,
                deviceId: deviceIdentity['device_id'] as String,
                identityValid: () =>
                    context.mounted &&
                    _buildFastCatSupportVisitor(context)?.platformOpenId ==
                        visitor.platformOpenId,
                proxyPort: () =>
                    diagnosticContainer.read(proxyStateProvider).port,
              ),
        diagnosticHandlers: {
          for (final capability in ['basic', 'status', 'network', 'logs'])
            capability: (request) async {
              void check() {
                request.throwIfCancelled();
                if (!context.mounted ||
                    _buildFastCatSupportVisitor(context)?.platformOpenId !=
                        visitor?.platformOpenId) {
                  throw StateError('Support identity changed');
                }
              }

              check();
              if (diagnosticRequests.length >= 100 ||
                  !diagnosticRequests.add(request.id)) {
                throw StateError(
                    'Duplicate diagnostic request or session limit');
              }
              Map<String, dynamic> report;
              switch (capability) {
                case 'basic':
                  report = {
                    'appVersion':
                        '${globalState.packageInfo.version}+${globalState.packageInfo.buildNumber}',
                    'osVersion': Platform.operatingSystemVersion,
                    'platform': Platform.operatingSystem
                  };
                case 'status':
                  final proxy = diagnosticContainer.read(proxyStateProvider);
                  report = {
                    'connection': {'connected': globalState.isStart},
                    'kernel': {'running': globalState.appState.runTime != null},
                    'proxy': {
                      'systemProxy': proxy.systemProxy,
                      'isStart': proxy.isStart,
                      'port': proxy.port
                    },
                    'tun': {
                      'enabled': diagnosticContainer.read(realTunEnableProvider)
                    }
                  };
                case 'network':
                  final timer = Stopwatch()..start();
                  final addresses =
                      await InternetAddress.lookup('www.gstatic.com')
                          .timeout(const Duration(seconds: 8));
                  check();
                  report = {
                    'checks': [
                      {
                        'type': 'system_dns',
                        'success': addresses.isNotEmpty,
                        'elapsedMs': timer.elapsedMilliseconds
                      }
                    ],
                    'summary':
                        'System DNS check only; does not verify the proxy route'
                  };
                default:
                  final logs = globalState.appState.logs.list;
                  final recent =
                      logs.skip(logs.length > 60 ? logs.length - 60 : 0);
                  var budget = 14000;
                  final rows = <String>[];
                  for (final log in recent.toList().reversed) {
                    final text = SensitiveMasker.maskText(log.payload);
                    final bounded =
                        text.length > 1000 ? text.substring(0, 1000) : text;
                    if (bounded.length > budget) break;
                    rows.insert(0, bounded);
                    budget -= bounded.length;
                  }
                  report = {'logs': rows};
              }
              check();
              return jsonDecode(SensitiveMasker.maskText(jsonEncode(report)))
                  as Map<String, dynamic>;
            },
        },
        httpClient: IOClient(HttpClient()..findProxy = (_) => 'DIRECT'),
        store: _ResilientSupportSessionStore.instance,
        baseUrl: Uri.parse(config.baseUrl),
        appKey: config.appKey,
        user: visitor == null
            ? null
            : fc.FastCatUser(
                id: visitor.platformOpenId ?? visitor.email ?? 'anonymous',
                email: visitor.email,
                name: visitor.name,
                profile: {'custom': visitor.customAttributes},
              ),
      );
      pendingSupport = support;
      if (visitor?.platformOpenId != null) {
        support.client.repairHandlers.addAll(supportProxyRepairs(
          accountId: visitor!.platformOpenId!,
          deviceId: deviceIdentity['device_id'] as String,
          identityValid: () =>
              context.mounted &&
              _buildFastCatSupportVisitor(context)?.platformOpenId ==
                  visitor.platformOpenId,
          port: () => diagnosticContainer.read(proxyStateProvider).port,
          bypass: () => diagnosticContainer.read(proxyStateProvider).bassDomain,
        ));
      }
      {
        if (!await support.client.restore()) {
          final email = visitor?.email;
          if (email == null || email.isEmpty) {
            support.close();
            return false;
          }
          await support.client.start(
              email: email,
              profile: {'custom': visitor?.customAttributes ?? {}});
        }
      }
      if (!context.mounted) {
        support.close();
        return true;
      }
      final supportLocaleTag = Localizations.localeOf(context).toLanguageTag();
      Future<void> openView(BuildContext viewContext) async =>
          _openEmbeddedCustomerService(viewContext,
              signature: signature,
              builder: (hide, session) => Scaffold(
                    appBar: AppBar(
                        title: Text(
                            AppLocalizations.of(context).onlineSupportTitle),
                        leading: BackButton(onPressed: hide)),
                    body: ValueListenableBuilder<CustomerServiceSessionState>(
                      valueListenable: session,
                      builder: (context, state, child) =>
                          TickerMode(enabled: state.isVisible, child: child!),
                      child: fc.FastCatSupportView(
                        support: support,
                        showHeader: true,
                        pickAttachment: () async {
                          final file = await app_picker.picker.pickerFile();
                          if (file == null) return null;
                          if (file.size > 8 * 1024 * 1024) {
                            throw StateError('Attachment exceeds 8 MB');
                          }
                          final bytes = file.bytes ??
                              (file.path == null
                                  ? null
                                  : await File(file.path!).readAsBytes());
                          if (bytes == null) {
                            throw StateError('Cannot read attachment');
                          }
                          return fc.FastCatAttachment(
                              filename: file.name, bytes: bytes);
                        },
                        onAttachment: (filename, bytes) async {
                          await app_picker.picker.saveFile(
                              filename.replaceAll('\\', '/').split('/').last,
                              bytes);
                        },
                      ),
                    ),
                  ));
      _openSupportView = openView;
      if (showView) await openView(context);
      _support = support;
      _pushService = SupportPushService();
      unawaited(_pushService!.attach(
          support.client,
          deviceIdentity['device_id'] as String,
          supportLocaleTag,
          () =>
              isEmbeddedCustomerServiceVisible &&
              WidgetsBinding.instance.lifecycleState ==
                  AppLifecycleState.resumed,
          onUnread: _publishUnread, onNotification: () async {
        final activeContext =
            globalState.navigatorKey.currentState?.overlay?.context;
        if (activeContext != null &&
            activeContext.mounted &&
            _support == support) {
          if (!_showExistingEmbeddedCustomerService(activeContext, signature)) {
            await _openSupportView?.call(activeContext);
          }
        }
      }));
      _supportTone = fc.SupportNotificationSound();
      if (DesktopSupportNotifications.supported) {
        _desktopNotifications = DesktopSupportNotifications(
          chatVisible: () => isEmbeddedCustomerServiceVisible,
          soundEnabled: () => support.client.notificationSoundEnabled,
          playSound: () async { await _supportTone?.play(); },
          openConversation: () async {
            final activeContext = globalState.navigatorKey.currentState?.overlay?.context;
            if (_support != support || activeContext == null || !activeContext.mounted) return;
            if (!_showExistingEmbeddedCustomerService(activeContext, signature)) {
              await _openSupportView?.call(activeContext);
            }
          });
      }
      _supportIncoming = support.client.incomingMessageStream.listen((message) {
        if (DesktopSupportNotifications.supported) {
          _desktopNotifications?.incoming(message);
          return;
        }
        final foreground = WidgetsBinding.instance.lifecycleState == null ||
            WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
        if (!foreground) {
          if (Platform.isAndroid &&
              support.client.conversationId != null && message['id'] is String) {
            unawaited(SupportPushService.notifyReply(
                support.client.conversationId!, message['id'] as String,
                unreadCount: support.client.unreadCount));
          }
        } else if (!isEmbeddedCustomerServiceVisible &&
            support.client.notificationSoundEnabled) {
          unawaited(_supportTone?.play());
        }
      });
      _supportUnread = support.client.unreadCountStream.listen(_publishUnread);
      _publishUnread(support.client.unreadCount);
      // The application owns message delivery; mounting the chat is optional.
      // Subscribe to sound/unread events first so startup synchronization cannot
      // race their listeners. The client deduplicates messages across watchers.
      _supportMessageFeed = support.client.watch(onError: (error) {
        _logger.warning(
            '[FastCatSupport] 应用消息连接异常: ${error.runtimeType}');
      }).listen((_) {}, onError: (Object error) {
        _logger.warning(
            '[FastCatSupport] 应用消息连接已停止: ${error.runtimeType}');
      });
      var reconnecting = false;
      _supportMonitor = support.client.connectionStatusStream.listen((status) {
        if (status == fc.FastCatConnectionStatus.reconnecting &&
            !reconnecting) {
          reconnecting = true;
          _logger.warning('[FastCatSupport] 消息连接异常，正在重连');
        } else if (status == fc.FastCatConnectionStatus.connected &&
            reconnecting) {
          reconnecting = false;
          _logger.info('[FastCatSupport] 消息连接已恢复');
        }
      });
      return true;
    } catch (error, stackTrace) {
      _logger.warning(
        '[FastCatSupport] 打开失败: $error',
        stackTrace,
      );
      if (pendingSupport != null) {
        if (_support == null || identical(_support, pendingSupport)) {
          _closeEmbeddedCustomerService();
        }
        pendingSupport.close();
      }
      try {
        await TgoWidget.dispose();
      } catch (_) {}
      return false;
    }
  }

  static Future<_FastCatSupportConfig?> _resolveFastCatSupportConfig() async {
    final remoteBaseUrl = XBoardConfig.fastCatSupportBaseUrl.trim();
    final remoteAppKey = XBoardConfig.fastCatSupportAppKey.trim();
    if (XBoardConfig.fastCatSupportEnabled &&
        remoteBaseUrl.isNotEmpty &&
        remoteAppKey.isNotEmpty) {
      return _fastCatSupportConfig = _FastCatSupportConfig(
        baseUrl: remoteBaseUrl,
        appKey: remoteAppKey,
      );
    }
    // A remote entry is authoritative, including an explicit disable. Only
    // use the bundled fallback while older OSS configurations omit the key.
    if (XBoardConfig.fastCatSupportConfigured) return null;

    final cached = _fastCatSupportConfig;
    if (cached != null) return cached;
    final contact =
        await local_config.ConfigFileLoaderHelper.getContactFallbackConfig();
    final rawLocal = contact['fastcat_support'];
    final local = rawLocal is Map
        ? rawLocal.map((key, value) => MapEntry(key.toString(), value))
        : const <String, dynamic>{};
    final enabled = local['enabled'] != false;
    final baseUrl = local['base_url']?.toString().trim() ?? '';
    final appKey = local['app_key']?.toString().trim() ?? '';
    if (!enabled || baseUrl.isEmpty || appKey.isEmpty) return null;
    return _fastCatSupportConfig = _FastCatSupportConfig(
      baseUrl: baseUrl,
      appKey: appKey,
    );
  }

  static VisitorInfo? _buildFastCatSupportVisitor(BuildContext context) {
    final container = ProviderScope.containerOf(context, listen: false);
    final userState = container.read(xboardUserProvider);
    final userInfo = container.read(userInfoProvider);
    final subscriptionInfo = container.read(subscriptionInfoProvider);
    final email = (userInfo?.email ?? userState.email ?? '').trim();
    final openId = _firstNonEmpty(
      userInfo?.uuid,
      subscriptionInfo?.uuid,
    );
    if (email.isEmpty && openId.isEmpty) return null;

    final supportData = _buildSupportUserData(context);
    final attributes = <String, String?>{};
    for (final entry in supportData['sessionData'] as List<List<String>>) {
      if (entry.length == 2 && entry[0].isNotEmpty && entry[1].isNotEmpty) {
        attributes[entry[0]] = entry[1];
      }
    }
    return VisitorInfo(
      platformOpenId: openId.isNotEmpty ? openId : email,
      name: email.isEmpty ? null : email.split('@').first,
      nickname: email.isEmpty ? null : email.split('@').first,
      email: email.isEmpty ? null : email,
      avatarUrl:
          userInfo?.avatarUrl.isNotEmpty == true ? userInfo!.avatarUrl : null,
      customAttributes: attributes,
    );
  }

  static Map<String, Object?> _buildSupportUserData(
    BuildContext context,
  ) {
    final container = ProviderScope.containerOf(context, listen: false);
    final userState = container.read(xboardUserProvider);
    final userInfo = container.read(userInfoProvider);
    final subscriptionInfo = container.read(subscriptionInfoProvider);
    final profileSubscriptionInfo =
        container.read(currentProfileProvider)?.subscriptionInfo;

    final email = (userInfo?.email ?? userState.email ?? '').trim();
    final appVersion = _getAppVersionText();
    final osText = Platform.operatingSystem;
    final usedTraffic = profileSubscriptionInfo != null
        ? profileSubscriptionInfo.upload + profileSubscriptionInfo.download
        : (subscriptionInfo?.uploadedBytes ?? 0) +
            (subscriptionInfo?.downloadedBytes ?? 0);
    final totalTraffic =
        profileSubscriptionInfo?.total ?? subscriptionInfo?.transferLimit ?? 0;
    final expiredAt = subscriptionInfo?.expiredAt;
    final planName = subscriptionInfo?.planName ?? '';
    final resetDaysLeft = _resolveResetDaysLeft(subscriptionInfo);
    final userIP = userInfo?.ip ?? '';
    final userIPRegion = userInfo?.ipRegion ?? '';
    final userIPISP = userInfo?.ipIsp ?? '';
    final walletBalanceInCents = userInfo?.balanceInCents;
    final commissionBalanceInCents = userInfo?.commissionBalanceInCents;

    return {
      'email': email,
      'nickname': email.isEmpty ? null : email.split('@').first,
      'sessionData': <List<String>>[
        ['os', osText],
        ['client_version', appVersion],
        ['plan_name', planName],
        ['plan_expired_at', expiredAt?.toIso8601String() ?? ''],
        ['traffic_used', _formatTraffic(usedTraffic)],
        ['traffic_total', _formatTraffic(totalTraffic)],
        ['traffic_reset_days_left', resetDaysLeft?.toString() ?? 'unknown'],
        [
          'wallet_balance',
          walletBalanceInCents != null
              ? '¥${(walletBalanceInCents / 100).toStringAsFixed(2)}'
              : '0.00'
        ],
        [
          'commission_balance',
          commissionBalanceInCents != null
              ? '¥${(commissionBalanceInCents / 100).toStringAsFixed(2)}'
              : '0.00'
        ],
        ['user_ip', userIP],
        ['user_ip_region', userIPRegion],
        ['user_ip_isp', userIPISP],
      ],
    };
  }

  static String _firstNonEmpty(String? primary, String? fallback) {
    final first = primary?.trim() ?? '';
    if (first.isNotEmpty) return first;
    return fallback?.trim() ?? '';
  }

  static int? _resolveResetDaysLeft(DomainSubscription? subscriptionInfo) {
    if (subscriptionInfo == null) return null;
    final fromNextReset = _calcResetDaysLeft(subscriptionInfo.nextResetAt);
    if (fromNextReset != null) return fromNextReset;
    final metadataValue = subscriptionInfo.metadata['resetDay'];
    if (metadataValue is num) return metadataValue.toInt();
    if (metadataValue is String) return int.tryParse(metadataValue);
    return null;
  }

  static int? _calcResetDaysLeft(DateTime? nextResetAt) {
    if (nextResetAt == null) return null;
    final now = DateTime.now();
    if (!nextResetAt.isAfter(now)) return 0;
    final nowDate = DateTime(now.year, now.month, now.day);
    final resetDate = DateTime(
      nextResetAt.year,
      nextResetAt.month,
      nextResetAt.day,
    );
    final days = resetDate.difference(nowDate).inDays;
    return days < 0 ? 0 : days;
  }

  static String _getAppVersionText() {
    try {
      final info = globalState.packageInfo;
      final buildNumber = info.buildNumber.trim();
      return buildNumber.isEmpty
          ? info.version
          : '${info.version}+$buildNumber';
    } catch (_) {
      return '';
    }
  }

  static String _formatTraffic(num bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var unitIndex = 0;
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    final precision = size >= 100
        ? 0
        : size >= 10
            ? 1
            : 2;
    return '${size.toStringAsFixed(precision)} ${units[unitIndex]}';
  }
}

class _FastCatSupportConfig {
  const _FastCatSupportConfig({required this.baseUrl, required this.appKey});

  final String baseUrl;
  final String appKey;
}

class _EmbeddedCustomerServiceFrame extends StatefulWidget {
  const _EmbeddedCustomerServiceFrame({
    required this.showRootMenu,
    required this.initialRoutePath,
    required this.child,
  });

  final bool showRootMenu;
  final String? initialRoutePath;
  final Widget child;

  @override
  State<_EmbeddedCustomerServiceFrame> createState() =>
      _EmbeddedCustomerServiceFrameState();
}

class _EmbeddedCustomerServiceFrameState
    extends State<_EmbeddedCustomerServiceFrame> {
  GoRouter? _router;
  String? _currentRoutePath;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextRouter = _readRouter(context);
    if (!identical(_router, nextRouter)) {
      _router?.routerDelegate.removeListener(_handleRouteChanged);
      _router = nextRouter;
      _router?.routerDelegate.addListener(_handleRouteChanged);
      _currentRoutePath ??=
          widget.initialRoutePath ?? _readRoutePath(nextRouter);
    }
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_handleRouteChanged);
    super.dispose();
  }

  GoRouter? _readRouter(BuildContext context) {
    try {
      return GoRouter.of(context);
    } catch (_) {
      return null;
    }
  }

  String? _readRoutePath(GoRouter? router) {
    try {
      return router?.routeInformationProvider.value.uri.path;
    } catch (_) {
      return null;
    }
  }

  void _handleRouteChanged() {
    if (!mounted || !widget.showRootMenu) return;
    final nextRoutePath = _readRoutePath(_router) ?? widget.initialRoutePath;
    if (nextRoutePath != _currentRoutePath) {
      setState(() {
        _currentRoutePath = nextRoutePath;
      });
    }
  }

  String? _rootRouteKey(String? routePath) {
    if (routePath == null || routePath.isEmpty) return null;
    if (routePath == '/') return '/';
    final segments = routePath.split('/').where((part) => part.isNotEmpty);
    final first = segments.isEmpty ? '' : segments.first;
    return switch (first) {
      'plans' => '/plans',
      'invite' => '/invite',
      'mine' => '/mine',
      'logs' => '/logs',
      _ => '/',
    };
  }

  bool get _isCurrentRootRoute {
    if (!widget.showRootMenu) return true;
    final initialKey = _rootRouteKey(widget.initialRoutePath);
    final currentKey = _rootRouteKey(_currentRoutePath);
    return initialKey == null || currentKey == null || initialKey == currentKey;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showRootMenu) {
      return Positioned.fill(child: widget.child);
    }

    final framedChild = Offstage(
      offstage: !_isCurrentRootRoute,
      child: IgnorePointer(
        ignoring: !_isCurrentRootRoute,
        child: widget.child,
      ),
    );
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;
    final useSideNavigation = size.width > size.height || system.isTV;

    if (useSideNavigation) {
      return Positioned(
        left: _desktopRootMenuWidth,
        top: 0,
        right: 0,
        bottom: 0,
        child: CustomerServiceViewport(
          consumed: const EdgeInsets.only(left: _desktopRootMenuWidth),
          child: framedChild,
        ),
      );
    }

    final bottom = _mobileRootMenuHeight + mediaQuery.padding.bottom;
    return Positioned(
      left: 0,
      top: 0,
      right: 0,
      bottom: bottom,
      child: CustomerServiceViewport(
        consumed: EdgeInsets.only(bottom: bottom),
        child: framedChild,
      ),
    );
  }
}

class _IosCustomerServiceFrame extends StatelessWidget {
  const _IosCustomerServiceFrame({required this.initialPath,
    required this.onDestination, required this.child});
  final String initialPath;
  final ValueChanged<int> onDestination;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottom = _mobileRootMenuHeight + MediaQuery.paddingOf(context).bottom;
    final router = GoRouter.of(context);
    return Scaffold(resizeToAvoidBottomInset: false,
      body: CustomerServiceViewport(consumed: EdgeInsets.only(bottom: bottom), child: child),
      bottomNavigationBar: ListenableBuilder(listenable: router.routerDelegate,
        builder: (context, _) {
          final path = router.routerDelegate.currentConfiguration.uri.path;
          final current = path.isEmpty ? initialPath : path;
          final selected = current.startsWith('/plans') ? 1 :
              current.startsWith('/invite') ? 2 : current.startsWith('/mine') ? 3 : 0;
          return MobileNavigationBar(selectedIndex: selected,
            onDestinationSelected: onDestination);
        }));
  }
}

/// Keep the current process usable when platform credential storage is unavailable.
/// Keys supplied by the SDK include server, platform and account scope.
class _ResilientSupportSessionStore implements fc.FastCatSessionStore {
  static final instance = _ResilientSupportSessionStore();
  final fc.FastCatSecureSessionStore _secure =
      const fc.FastCatSecureSessionStore();
  final Map<String, String> _memory = {};
  final Set<String> _deleted = {};
  bool _unavailable = false;

  void _failed(Object error) {
    if (!_unavailable) {
      _logger.warning(
          '[FastCatSupport] 安全存储不可用，当前运行使用内存会话；重启后可能无法恢复历史会话。错误类型: ${error.runtimeType}');
    }
    _unavailable = true;
  }

  @override
  Future<String?> read(String key) async {
    if (_deleted.contains(key)) return null;
    if (_memory.containsKey(key)) return _memory[key];
    if (!_unavailable) {
      try {
        final value = await _secure.read(key);
        if (value != null) {
          _memory[key] = value;
        }
        return value;
      } catch (error) {
        _failed(error);
      }
    }
    return null;
  }

  @override
  Future<void> write(String key, String value) async {
    _deleted.remove(key);
    _memory[key] = value;
    if (!_unavailable) {
      try {
        await _secure.write(key, value);
      } catch (error) {
        _failed(error);
      }
    }
  }

  @override
  Future<void> delete(String key) async {
    _memory.remove(key);
    _deleted.add(key);
    // Attempt deletion even after a previous failure; never restore a removed
    // identity from persistent storage during this process.
    try {
      await _secure.delete(key);
    } catch (error) {
      _failed(error);
    }
  }
}
