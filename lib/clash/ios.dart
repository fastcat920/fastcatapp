import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/clash/interface.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter/services.dart';

/// iOS implementation of [ClashHandlerInterface].
///
/// All clash operations are routed via MethodChannel "fastcat/clash" to the Swift
/// layer in AppDelegate, which forwards them to the PacketTunnel extension via
/// [NETunnelProviderSession.sendProviderMessage]. The extension executes the
/// request against the embedded libclash.a and returns the result.
///
/// When the VPN tunnel is not running, operations return safe empty/default
/// values rather than throwing.
class ClashIOS extends ClashHandlerInterface {
  static const MethodChannel _channel = MethodChannel("fastcat/clash");

  // ── ClashHandlerInterface stubs ─────────────────────────────────────────

  @override
  void sendMessage(String message) {
    // Not used — invoke<T> is overridden to call MethodChannel directly.
  }

  @override
  void reStart() {}

  @override
  FutureOr<bool> destroy() async => true;

  @override
  Future<bool> preload() async => true;

  // ── Core invoke override ─────────────────────────────────────────────────

  /// Routes every [ClashInterface] call through MethodChannel → Swift →
  /// PacketTunnel (when connected) or returns a safe default otherwise.
  @override
  Future<T> invoke<T>({
    required ActionMethod method,
    dynamic data,
    Duration? timeout,
    FutureOr<T> Function()? onTimeout,
    T? defaultValue,
  }) async {
    final effectiveTimeout = timeout ?? const Duration(seconds: 30);
    try {
      final result = await _channel
          .invokeMethod<dynamic>(method.name, data)
          .timeout(effectiveTimeout);
      if (result == null) {
        if (ClashHandlerInterface.requiresAcknowledgement(method)) {
          throw StateError('Core ${method.name} returned no acknowledgement');
        }
        return _default<T>(defaultValue, method);
      }
      return _decode<T>(result);
    } on TimeoutException {
      if (onTimeout != null) return onTimeout();
      if (ClashHandlerInterface.requiresAcknowledgement(method)) rethrow;
      return _default<T>(defaultValue, method);
    } catch (_) {
      if (ClashHandlerInterface.requiresAcknowledgement(method)) rethrow;
      return _default<T>(defaultValue, method);
    }
  }

  T _decode<T>(Object result) {
    if (result is T) return result as T;
    // The Go bridge returns JSON as UTF-8 strings, not StandardMessageCodec
    // maps/bools. Keep String replies verbatim: an explicit empty string is a
    // valid acknowledgement, and provider/probe callers decode their own JSON.
    final decoded = result is String && (T == Map || T == bool || T == Result)
        ? json.decode(result)
        : result;
    if (decoded is T) return decoded;
    if (T == Result && decoded is Map) {
      // getConfig/getConfigContent return the raw configuration object on iOS,
      // unlike the ActionResult envelope used by the desktop transport.
      return Result.success(Map<String, dynamic>.from(decoded)) as T;
    }
    throw FormatException('Unexpected iOS core response type for $T');
  }

  T _default<T>(T? provided, ActionMethod method) {
    if (provided != null) return provided;
    if (T == bool) return false as T;
    if (T == String) return '' as T;
    if (T == Map) return <String, dynamic>{} as T;
    if (T == Result) {
      return Result.error('CORE_METHOD_UNAVAILABLE:${method.name}') as T;
    }
    return provided as T;
  }
}

ClashIOS? get clashIOS => Platform.isIOS ? ClashIOS() : null;
