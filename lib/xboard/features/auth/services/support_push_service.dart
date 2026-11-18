import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:fastcat_support/fastcat_support.dart';
import 'package:fl_clash/xboard/core/core.dart';

/// Mobile only: tokens come from platform APNs/FCM, never the chat payload.
class SupportPushService {
  static const _channel = MethodChannel('fastcat/support_push');
  static const _logger = FileLogger('support_push_service.dart');
  Timer? _timer;
  Timer? _visibilityTimer;
  DateTime? _nextRegistrationRefresh;
  AppLifecycleListener? _lifecycle;
  bool _busy = false, _closed = false;
  String? _registered;
  DateTime? _nextTokenAttempt;
  static Future<void> notifyReply(
      String conversationId, String messageId, {int? unreadCount}) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('showReply', {
        'conversationId': conversationId,
        'messageId': messageId,
        if (unreadCount != null) 'unreadCount': unreadCount,
      });
    } catch (error) {
      _logger.debug('Local notification unavailable: ${error.runtimeType}');
    }
  }

  Future<void> attach(FastCatClient client, String deviceId, String language,
      bool Function() visible,
      {Future<void> Function()? onNotification,
      void Function(int)? onUnread}) async {
    if (!(Platform.isIOS || Platform.isAndroid)) return;
    final seenMessages = <String>{};
    Future<void> sync() async {
      if (_closed || _busy || !client.hasSession) return;
      _busy = true;
      try {
        final status = await client.pushStatus();
        if (!_closed && status['unreadCount'] is num) {
          onUnread?.call(client.unreadCount);
        }
        final notification =
            await _channel.invokeMapMethod<String, dynamic>('notification');
        if (!_closed &&
            notification?['type'] == 'support.reply' &&
            notification?['conversationId'] == client.conversationId &&
            notification?['messageId'] is String &&
            seenMessages.add(notification!['messageId'] as String)) {
          await onNotification?.call();
        }
        if (_nextTokenAttempt != null &&
            DateTime.now().isBefore(_nextTokenAttempt!)) return;
        _nextTokenAttempt = DateTime.now().add(const Duration(seconds: 30));
        final token = await _channel.invokeMethod<String>('token');
        if (_closed || token == null || token.isEmpty) return;
        final environment = Platform.isIOS
            ? await _channel.invokeMethod<String>('environment')
            : 'production';
        if (_closed || environment == null) {
          _logger.warning(
              'Push registration deferred: signing environment unavailable');
          return;
        }
        if (_registered != token ||
            _nextRegistrationRefresh == null ||
            DateTime.now().isAfter(_nextRegistrationRefresh!)) {
          await client.registerPushDevice(
              deviceId: deviceId,
              token: token,
              provider: Platform.isIOS ? 'apns' : 'fcm',
              environment: environment,
              language: language.startsWith('zh') ? 'zh' : 'en');
          _registered = token;
          _nextRegistrationRefresh =
              DateTime.now().add(const Duration(hours: 6));
          _logger.info('Push device registered: $environment');
        }
        _nextTokenAttempt = DateTime.now().add(const Duration(minutes: 5));
        // Chat owns visibility transitions and its single presence heartbeat.
      } catch (error) {
        _logger.debug('Push registration pending: ${error.runtimeType}');
      } finally {
        _busy = false;
      }
    }

    Future<void> syncVisibility() async {
      if (_closed || !Platform.isIOS) return;
      try {
        await _channel.invokeMethod<void>('visibility', {
          'conversationId': client.conversationId,
          'visible': visible() &&
              WidgetsBinding.instance.lifecycleState ==
                  AppLifecycleState.resumed,
        });
      } catch (error) {
        _logger
            .debug('Notification visibility sync failed: ${error.runtimeType}');
      }
    }

    _lifecycle = AppLifecycleListener(
        onStateChange: (_) => unawaited(syncVisibility()),
        onResume: () {
          _nextTokenAttempt = null;
          unawaited(sync());
        });
    await sync();
    await syncVisibility();
    _visibilityTimer = Timer.periodic(
        const Duration(seconds: 1), (_) => unawaited(syncVisibility()));
    if (!_closed)
      _timer =
          Timer.periodic(const Duration(seconds: 30), (_) => unawaited(sync()));
  }

  void close() {
    _closed = true;
    _timer?.cancel();
    _visibilityTimer?.cancel();
    if (Platform.isIOS) {
      unawaited(_channel.invokeMethod<void>(
          'visibility', {'visible': false}).catchError((Object _) {}));
    }
    _lifecycle?.dispose();
  }
}
