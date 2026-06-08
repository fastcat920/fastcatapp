import 'dart:async';
import 'dart:io';

import 'package:fl_clash/clash/interface.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:flutter/services.dart';

/// iOS implementation of [ClashHandlerInterface].
///
/// All clash operations are routed via MethodChannel "apex/clash" to the Swift
/// layer in AppDelegate, which forwards them to the PacketTunnel extension via
/// [NETunnelProviderSession.sendProviderMessage]. The extension executes the
/// request against the embedded libclash.a and returns the result.
///
/// When the VPN tunnel is not running, operations return safe empty/default
/// values rather than throwing.
class ClashIOS extends ClashHandlerInterface {
  static const MethodChannel _channel = MethodChannel("apex/clash");

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
      if (result == null) return _default<T>(defaultValue);
      if (result is T) return result;
      // Common safe coercions
      if (T == String) return (result.toString()) as T;
      if (T == bool) return (result as bool) as T;
      if (T == Map) return (result as Map) as T;
      return result as T;
    } catch (_) {
      if (onTimeout != null) return onTimeout();
      return _default<T>(defaultValue);
    }
  }

  T _default<T>(T? provided) {
    if (provided != null) return provided;
    if (T == bool) return false as T;
    if (T == String) return '' as T;
    if (T == Map) return <String, dynamic>{} as T;
    return provided as T;
  }
}

ClashIOS? get clashIOS => Platform.isIOS ? ClashIOS() : null;
