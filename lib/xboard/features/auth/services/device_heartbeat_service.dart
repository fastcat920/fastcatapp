import 'dart:async';
import 'dart:math';

import 'package:fl_clash/xboard/core/logger/file_logger.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';

const _logger = FileLogger('device_heartbeat_service.dart');

class XBoardDeviceHeartbeatService {
  XBoardDeviceHeartbeatService._();

  static const Duration _defaultMinInterval = Duration(minutes: 1);
  static const String _strictPolicy = 'strict';
  static const String _kickOldestPolicy = 'kick_oldest';
  static final Random _random = Random();
  static DateTime? _lastAttemptAt;
  static DateTime? _lastSuccessAt;
  static String? _lastReason;
  static bool _inFlight = false;
  static bool _periodicRunning = false;
  static Timer? _periodicTimer;
  static int _consecutiveFailures = 0;
  static String _devicePolicy = _kickOldestPolicy;

  static DateTime? get lastAttemptAt => _lastAttemptAt;
  static DateTime? get lastSuccessAt => _lastSuccessAt;
  static String? get lastReason => _lastReason;
  static bool get isInFlight => _inFlight;
  static bool get isPeriodicRunning => _periodicRunning;
  static int get consecutiveFailures => _consecutiveFailures;

  static void startPeriodic() {
    if (_periodicRunning) return;
    _periodicRunning = true;
    _consecutiveFailures = 0;
    unawaited(markActive(reason: 'connection_lease_start', force: true));
    _scheduleNextHeartbeat();
  }

  static void stopPeriodic() {
    _periodicRunning = false;
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  static void _scheduleNextHeartbeat() {
    if (!_periodicRunning) return;
    _periodicTimer?.cancel();
    _periodicTimer = Timer(_nextHeartbeatDelay(), () async {
      await markActive(reason: 'connection_lease', force: true);
      _scheduleNextHeartbeat();
    });
  }

  static Duration _nextHeartbeatDelay() {
    if (_devicePolicy == _strictPolicy) {
      return switch (_consecutiveFailures) {
        0 => Duration(seconds: 120 + _random.nextInt(181)),
        1 => Duration(seconds: 300 + _random.nextInt(61)),
        _ => Duration(seconds: 600 + _random.nextInt(121)),
      };
    }
    return switch (_consecutiveFailures) {
      0 => Duration(seconds: 20 + _random.nextInt(11)),
      1 => Duration(seconds: 55 + _random.nextInt(11)),
      _ => Duration(seconds: 115 + _random.nextInt(11)),
    };
  }

  static void _updateDevicePolicy(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! Map) return;
    final policy = data['device_policy']?.toString();
    if (policy != _strictPolicy && policy != _kickOldestPolicy) return;
    if (_devicePolicy == policy) return;
    _devicePolicy = policy!;
    if (_periodicRunning) _scheduleNextHeartbeat();
  }

  static Future<void> markActive({
    String reason = 'activity',
    bool force = false,
    Duration minInterval = _defaultMinInterval,
  }) async {
    final now = DateTime.now();
    final lastAttemptAt = _lastAttemptAt;
    final effectiveMinInterval = _devicePolicy == _strictPolicy &&
            minInterval < const Duration(minutes: 2)
        ? const Duration(minutes: 2)
        : minInterval;
    if (!force &&
        lastAttemptAt != null &&
        now.difference(lastAttemptAt) < effectiveMinInterval) {
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
        stopPeriodic();
        return;
      }
      final response = await sdk.httpService.postRequest(
        '/user/devices/heartbeat',
        <String, dynamic>{},
        headers: {'Authorization': token},
      ).timeout(const Duration(seconds: 8));
      _lastSuccessAt = DateTime.now();
      _consecutiveFailures = 0;
      _updateDevicePolicy(response);
      _logger.debug('设备心跳已刷新: $reason');
    } catch (e) {
      _consecutiveFailures++;
      _logger.debug('设备心跳刷新跳过: $reason, $e');
    } finally {
      _inFlight = false;
    }
  }
}
