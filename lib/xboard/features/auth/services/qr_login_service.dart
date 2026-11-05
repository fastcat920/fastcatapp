import 'dart:async';

import 'package:fl_clash/xboard/features/auth/services/device_identity_service.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';

/// Gateway-backed, one-time QR authorization.  The QR has no account token;
/// the target keeps [pollToken] and the signed-in phone approves the challenge.
class QrLoginChallenge {
  const QrLoginChallenge({
    required this.id,
    required this.pollToken,
    required this.qrData,
    required this.expiresAt,
    this.deliveryAck = false,
  });

  final String id;
  final String pollToken;
  final String qrData;
  final DateTime expiresAt;

  /// Only negotiated gateways retain approval until the target confirms login.
  final bool deliveryAck;
}

class QrLoginResult {
  const QrLoginResult({
    required this.token,
    required this.email,
    this.deliveryId,
  });
  final String token;
  final String email;
  final String? deliveryId;
}

class QrLoginExpiredException implements Exception {
  const QrLoginExpiredException();
}

class QrLoginService {
  QrLoginService._();

  static Future<QrLoginChallenge> create() async {
    final sdk = XBoardSDK.instance;
    final payload = await XBoardDeviceIdentityService.buildLoginPayload();
    final response = await sdk.httpService.postRequest(
      '/auth/qr/sessions',
      {...payload, 'delivery_ack': true},
    );
    return decodeChallenge(response);
  }

  static QrLoginChallenge decodeChallenge(Map<String, dynamic> response) {
    final data = Map<String, dynamic>.from(response['data'] as Map);
    final expiresAt = DateTime.tryParse((data['expires_at'] ?? '').toString());
    final id = data['id'];
    final pollToken = data['poll_token'];
    final qrData = data['qr_data'];
    if (id is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(id) ||
        pollToken is! String ||
        pollToken.isEmpty ||
        qrData is! String ||
        parse(qrData).id != id ||
        expiresAt == null) {
      throw const FormatException('Invalid QR login challenge');
    }
    return QrLoginChallenge(
      id: id,
      pollToken: pollToken,
      qrData: qrData,
      expiresAt: expiresAt.toUtc(),
      deliveryAck: data['delivery_ack'] == true,
    );
  }

  static Future<void> cancel(QrLoginChallenge challenge) async {
    await XBoardSDK.instance.httpService.deleteRequest(
      '/auth/qr/sessions/${challenge.id}?poll_token=${Uri.encodeQueryComponent(challenge.pollToken)}',
    );
  }

  static Future<QrLoginResult?> poll(QrLoginChallenge challenge) async {
    final response = await XBoardSDK.instance.httpService.getRequest(
      '/auth/qr/sessions/${challenge.id}?poll_token=${Uri.encodeQueryComponent(challenge.pollToken)}',
    );
    return decodePoll(response, deliveryAck: challenge.deliveryAck);
  }

  static QrLoginResult? decodePoll(Map<String, dynamic> response,
      {bool deliveryAck = false}) {
    final data = Map<String, dynamic>.from(response['data'] as Map);
    if (const {'expired', 'consumed', 'cancelled', 'failed'}
        .contains(data['status'])) {
      throw const QrLoginExpiredException();
    }
    if (data['status'] != 'approved') return null;
    final login = Map<String, dynamic>.from(data['login'] as Map);
    final token = login['auth_data'] ?? login['token'];
    if (token is! String || token.trim().isEmpty) {
      throw StateError('扫码登录响应缺少登录凭证');
    }
    final deliveryId = data['delivery_id'];
    if (deliveryAck && (deliveryId is! String || deliveryId.trim().isEmpty)) {
      throw const FormatException('Invalid QR login delivery');
    }
    return QrLoginResult(
      token: token,
      email: (login['email'] ?? '').toString(),
      deliveryId: deliveryId is String ? deliveryId : null,
    );
  }

  static Future<void> acknowledge(
      QrLoginChallenge challenge, QrLoginResult result) async {
    if (!challenge.deliveryAck) return;
    final deliveryId = result.deliveryId;
    if (deliveryId == null || deliveryId.trim().isEmpty) {
      throw const FormatException('Invalid QR login delivery');
    }
    final response = await XBoardSDK.instance.httpService.postRequest(
      '/auth/qr/sessions/${challenge.id}/ack',
      {'poll_token': challenge.pollToken, 'delivery_id': deliveryId},
    );
    if ((response['data'] as Map?)?['status'] != 'consumed') {
      throw const FormatException('Invalid QR login acknowledgement');
    }
  }

  static ScannedQrLoginChallenge parse(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null ||
        uri.scheme != 'fastcat' ||
        uri.host != 'login' ||
        uri.path != '/qr') {
      throw const FormatException('请扫描快猫电脑或电视上的登录二维码');
    }
    final id = uri.queryParameters['challenge']?.trim() ?? '';
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(id)) {
      throw const FormatException('登录二维码无效');
    }
    return ScannedQrLoginChallenge(id);
  }

  static Future<Map<String, dynamic>> approve(String challengeID) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(challengeID)) {
      throw const FormatException('Invalid challenge');
    }
    final token = await XBoardSDK.instance.getToken();
    if (token == null || token.isEmpty) throw StateError('请先登录账号');
    return XBoardSDK.instance.httpService.postRequest(
      '/auth/qr/sessions/$challengeID',
      const {},
      headers: {'Authorization': token},
    );
  }
}

/// Owns one displayed challenge. Refresh/hide/dispose revoke pending work's
/// authority to deliver credentials, even when its HTTP request finishes late.
/// Only one poll is issued at a time and one result can be delivered per QR.
class QrLoginAttemptController {
  QrLoginAttemptController({
    Future<QrLoginChallenge> Function()? create,
    Future<void> Function(QrLoginChallenge)? cancel,
    Future<QrLoginResult?> Function(QrLoginChallenge)? poll,
    Future<void> Function(QrLoginChallenge, QrLoginResult)? acknowledge,
    DateTime Function()? now,
    this.requestTimeout = const Duration(seconds: 15),
    this.cancelTimeout = const Duration(seconds: 3),
    this.acknowledgementTimeout = const Duration(seconds: 3),
  })  : _create = create ?? QrLoginService.create,
        _cancel = cancel ?? QrLoginService.cancel,
        _poll = poll ?? QrLoginService.poll,
        _acknowledge = acknowledge ?? QrLoginService.acknowledge,
        _now = now ?? DateTime.now;

  final Future<QrLoginChallenge> Function() _create;
  final Future<void> Function(QrLoginChallenge) _cancel;
  final Future<QrLoginResult?> Function(QrLoginChallenge) _poll;
  final Future<void> Function(QrLoginChallenge, QrLoginResult) _acknowledge;
  final DateTime Function() _now;
  final Duration requestTimeout;
  final Duration cancelTimeout;
  final Duration acknowledgementTimeout;
  int _generation = 0;
  bool _enabled = true;
  bool _disposed = false;
  bool _polling = false;
  bool _delivered = false;
  QrLoginResult? _deliveredResult;
  QrLoginChallenge? _challenge;
  ({int generation, Future<QrLoginChallenge?> operation})? _creation;

  QrLoginChallenge? get challenge => _challenge;

  bool _isCurrent(int generation) =>
      !_disposed && _enabled && generation == _generation;

  bool _hasExpired(QrLoginChallenge challenge) =>
      !_now().toUtc().isBefore(challenge.expiresAt);

  void setEnabled(bool enabled) {
    if (_disposed || _enabled == enabled) return;
    _enabled = enabled;
    if (!enabled) invalidate();
  }

  void invalidate() {
    _generation++;
    _challenge = null;
    _delivered = false;
    _deliveredResult = null;
  }

  Future<QrLoginChallenge?> create({bool invalidateCurrent = false}) {
    if (_disposed || !_enabled) return Future.value();
    final pending = _creation;
    if (pending != null && pending.generation == _generation) {
      return pending.operation;
    }
    final previous = _challenge;
    invalidate();
    final generation = _generation;
    final operation =
        _replace(generation, previous: invalidateCurrent ? previous : null)
            .whenComplete(() {
      if (_creation?.generation == generation) _creation = null;
    });
    _creation = (generation: generation, operation: operation);
    return operation;
  }

  Future<QrLoginChallenge?> _replace(int generation,
      {QrLoginChallenge? previous}) async {
    try {
      if (previous != null && !_hasExpired(previous)) {
        try {
          await _cancel(previous).timeout(cancelTimeout);
        } catch (_) {
          // The old challenge is locally invalid immediately. A consumed,
          // already-cancelled or unreachable old session must not trap refresh.
          // Its server-side TTL still applies; no old result can be accepted.
        }
      }
      if (!_isCurrent(generation)) return null;
      final next = await _create().timeout(requestTimeout);
      if (!_isCurrent(generation)) return null;
      if (_hasExpired(next)) throw const QrLoginExpiredException();
      _challenge = next;
      return next;
    } catch (_) {
      if (_isCurrent(generation)) rethrow;
      return null;
    }
  }

  Future<QrLoginResult?> poll() async {
    final current = _challenge;
    final generation = _generation;
    if (!_isCurrent(generation) || current == null || _polling || _delivered) {
      return null;
    }
    if (_hasExpired(current)) throw const QrLoginExpiredException();
    _polling = true;
    try {
      final result = await _poll(current).timeout(requestTimeout);
      if (!_isCurrent(generation) || !identical(current, _challenge)) {
        return null;
      }
      if (_hasExpired(current)) throw const QrLoginExpiredException();
      if (result != null) {
        _delivered = true;
        _deliveredResult = result;
      }
      return result;
    } catch (_) {
      if (_isCurrent(generation) && identical(current, _challenge)) rethrow;
      return null;
    } finally {
      _polling = false;
    }
  }

  /// Take the current delivery once, then acknowledge only a successful login.
  /// Login itself can hide/dispose this view, so the acknowledgement deliberately
  /// keeps the original immutable challenge instead of consulting new UI state.
  Future<bool> authorize(QrLoginResult result,
      Future<bool> Function(QrLoginResult) onAuthorized) async {
    final current = _challenge;
    if (!_isCurrent(_generation) ||
        current == null ||
        !identical(result, _deliveredResult) ||
        _hasExpired(current)) {
      return false;
    }
    _deliveredResult = null;
    final success = await onAuthorized(result);
    if (success && current.deliveryAck) {
      // A gateway failure must not undo an already established local session.
      unawaited(_acknowledgeBestEffort(current, result));
    }
    return success;
  }

  Future<void> _acknowledgeBestEffort(
      QrLoginChallenge challenge, QrLoginResult result) async {
    final timer = Stopwatch()..start();
    for (var attempt = 0; attempt < 2; attempt++) {
      final remaining = acknowledgementTimeout - timer.elapsed;
      if (remaining <= Duration.zero) return;
      // Reserve time for one idempotent retry if the first response is lost.
      final timeout =
          Duration(microseconds: remaining.inMicroseconds ~/ (2 - attempt));
      try {
        await _acknowledge(challenge, result).timeout(timeout);
        return;
      } catch (_) {
        // The gateway TTL will reclaim an unacknowledged delivery. Never log
        // its poll secret, delivery ID or credentials, or alter login state.
      }
    }
  }

  void dispose() {
    _disposed = true;
    invalidate();
  }
}

class ScannedQrLoginChallenge {
  const ScannedQrLoginChallenge(this.id);
  final String id;
}
