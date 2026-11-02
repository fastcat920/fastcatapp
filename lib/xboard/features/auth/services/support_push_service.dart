import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:fastcat_support/fastcat_support.dart';
import 'package:fl_clash/xboard/core/core.dart';

/// Mobile only: tokens come from platform APNs/FCM, never the chat payload.
class SupportPushService {
  static const _channel = MethodChannel('fastcat/support_push');
  static const _logger = FileLogger('support_push_service.dart');
  Timer? _timer;
  AppLifecycleListener? _lifecycle;
  bool _busy = false, _closed = false;
  String? _registered;
  Future<void> attach(FastCatClient client, String deviceId, String language,
      bool Function() visible,
      {Future<void> Function()? onNotification}) async {
    if (!(Platform.isIOS || Platform.isAndroid)) return;
    final seenMessages = <String>{};
    Future<void> sync() async {
      if (_closed || _busy || !client.hasSession) return;
      _busy = true;
      try {
        final notification =
            await _channel.invokeMapMethod<String, dynamic>('notification');
        if (!_closed &&
            notification?['type'] == 'support.reply' &&
            notification?['conversationId'] == client.conversationId &&
            notification?['messageId'] is String &&
            seenMessages.add(notification!['messageId'] as String)) {
          await onNotification?.call();
        }
        final token = await _channel.invokeMethod<String>('token');
        if (_closed || token == null || token.isEmpty) return;
        if (_registered != token) {
          await client.registerPushDevice(
              deviceId: deviceId,
              token: token,
              provider: Platform.isIOS ? 'apns' : 'fcm',
              environment: const String.fromEnvironment('APNS_ENVIRONMENT',
                  defaultValue: kDebugMode ? 'sandbox' : 'production'),
              language: language.startsWith('zh') ? 'zh' : 'en');
          _registered = token;
        }
        await client.setPushChatVisible(visible());
      } catch (error) {
        _logger.debug('Push registration pending: ${error.runtimeType}');
      } finally {
        _busy = false;
      }
    }

    _lifecycle = AppLifecycleListener(onResume: () => unawaited(sync()));
    await sync();
    if (!_closed)
      _timer =
          Timer.periodic(const Duration(seconds: 30), (_) => unawaited(sync()));
  }

  void close() {
    _closed = true;
    _timer?.cancel();
    _lifecycle?.dispose();
  }
}
