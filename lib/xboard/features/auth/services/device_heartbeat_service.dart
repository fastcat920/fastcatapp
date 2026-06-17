import 'dart:async';

import 'package:fl_clash/xboard/core/logger/file_logger.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';

const _logger = FileLogger('device_heartbeat_service.dart');

class XBoardDeviceHeartbeatService {
  XBoardDeviceHeartbeatService._();

  static const Duration _defaultMinInterval = Duration(minutes: 1);
  static DateTime? _lastAttemptAt;
  static DateTime? _lastSuccessAt;
  static String? _lastReason;
  static bool _inFlight = false;

  static DateTime? get lastAttemptAt => _lastAttemptAt;
  static DateTime? get lastSuccessAt => _lastSuccessAt;
  static String? get lastReason => _lastReason;
  static bool get isInFlight => _inFlight;

  static Future<void> markActive({
    String reason = 'activity',
    bool force = false,
    Duration minInterval = _defaultMinInterval,
  }) async {
    final now = DateTime.now();
    final lastAttemptAt = _lastAttemptAt;
    if (!force &&
        lastAttemptAt != null &&
        now.difference(lastAttemptAt) < minInterval) {
      return;
    }
    if (_inFlight) return;

    _lastAttemptAt = now;
    _lastReason = reason;
    _inFlight = true;
    try {
      final sdk = XBoardSDK.instance;
      final token = await sdk.getToken();
      if (token == null || token.isEmpty || !token.contains('dg_')) {
        return;
      }
      await sdk.httpService.postRequest(
        '/user/devices/heartbeat',
        <String, dynamic>{},
        headers: {'Authorization': token},
      ).timeout(const Duration(seconds: 8));
      _lastSuccessAt = DateTime.now();
      _logger.debug('设备心跳已刷新: $reason');
    } catch (e) {
      _logger.debug('设备心跳刷新跳过: $reason, $e');
    } finally {
      _inFlight = false;
    }
  }
}
