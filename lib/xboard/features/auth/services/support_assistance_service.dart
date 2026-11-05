import 'dart:async';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:fl_clash/common/sensitive_masker.dart';

/// Local boundary for SDK assistance adapters. No grant is created from chat text.
enum SupportDiagnosticScope {
  basicInfo,
  runtimeStatus,
  networkDiagnostics,
  recentLogs
}

typedef SupportDiagnosticCallback = Future<Map<String, dynamic>> Function();

class SupportAssistanceService {
  SupportAssistanceService._();
  static final instance = SupportAssistanceService._();
  final _callbacks = <SupportDiagnosticScope, SupportDiagnosticCallback>{};
  final _requests = <String>{};
  String? _account, _device, _grant;
  DateTime? _expires;
  Set<SupportDiagnosticScope> _scopes = {};
  Timer? _expiry;
  int _generation = 0;
  bool _busy = false;

  /// Bind only authenticated business identity and this installation's device ID.
  void bind(
      {required String accountId,
      required String deviceId,
      required Map<SupportDiagnosticScope, SupportDiagnosticCallback>
          callbacks}) {
    if (accountId.isEmpty || deviceId.isEmpty)
      throw ArgumentError('Missing identity');
    clear();
    _account = accountId;
    _device = deviceId;
    _callbacks.addAll(callbacks);
  }

  /// Called by the host only after the SDK's explicit consent button is confirmed.
  String grantAfterConfirmation(Set<SupportDiagnosticScope> scopes,
      {Duration duration = const Duration(minutes: 20)}) {
    if (_account == null ||
        scopes.isEmpty ||
        duration <= Duration.zero ||
        duration > const Duration(minutes: 20) ||
        !scopes.every(_callbacks.containsKey)) {
      throw StateError('Invalid assistance authorization');
    }
    revoke();
    _grant = const Uuid().v4();
    _scopes = Set.of(scopes);
    _expires = DateTime.now().toUtc().add(duration);
    _expiry = Timer(duration, revoke);
    return _grant!;
  }

  void revoke() {
    _generation++;
    _expiry?.cancel();
    _expiry = null;
    _grant = null;
    _expires = null;
    _scopes.clear();
    _requests.clear();
  }

  void clear() {
    revoke();
    _account = null;
    _device = null;
    _callbacks.clear();
  }

  /// SDK must authenticate the server request before entering this local gate.
  Future<Map<String, dynamic>> execute(
      {required String requestId,
      required String accountId,
      required String deviceId,
      required String grantId,
      required DateTime expiresAt,
      required SupportDiagnosticScope scope}) async {
    final now = DateTime.now().toUtc();
    bool authorized() =>
        _grant != null &&
        grantId == _grant &&
        accountId == _account &&
        deviceId == _device &&
        _scopes.contains(scope) &&
        _expires != null &&
        now.isBefore(_expires!) &&
        now.isBefore(expiresAt.toUtc());
    if (!authorized() || requestId.isEmpty || requestId.length > 128) {
      throw StateError('Assistance request unauthorized or expired');
    }
    if (_busy || _requests.contains(requestId) || _requests.length >= 100) {
      throw StateError('Assistance request busy, duplicate or limit reached');
    }
    final callback = _callbacks[scope];
    if (callback == null) throw StateError('Unsupported diagnostic');
    _requests.add(requestId);
    final generation = _generation;
    _busy = true;
    try {
      final data = await callback().timeout(const Duration(seconds: 45));
      if (generation != _generation ||
          !DateTime.now().toUtc().isBefore(_expires!) ||
          !DateTime.now().toUtc().isBefore(expiresAt.toUtc())) {
        throw StateError('Assistance authorization ended');
      }
      // Apply the existing export masker at the final egress boundary as well.
      final masked = SensitiveMasker.maskText(jsonEncode(data));
      if (utf8.encode(masked).length > 128 * 1024) {
        throw StateError('Diagnostic result exceeds limit');
      }
      return {
        'schemaVersion': 1,
        'requestId': requestId,
        'scope': scope.name,
        'capturedAt': DateTime.now().toUtc().toIso8601String(),
        'report': masked
      };
    } finally {
      _busy = false;
    }
  }
}
