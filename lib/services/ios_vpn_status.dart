import 'package:flutter/services.dart';

/// Query the OS-backed manager; never infer VPN status from UI runtime state.
class IosVpnStatusReader {
  const IosVpnStatusReader({
    this.channel = const MethodChannel('fastcat/vpn'),
    this.timeout = const Duration(seconds: 3),
  });

  final MethodChannel channel;
  final Duration timeout;

  Future<Map<String, dynamic>> restore() async {
    final snapshot = await channel.invokeMapMethod<String, dynamic>('restoreState')
        .timeout(const Duration(seconds: 15));
    if (snapshot == null) throw StateError('系统 VPN 状态读取失败');
    return snapshot;
  }

  Future<bool> isConnected() async =>
      await channel.invokeMethod<bool>('isConnected').timeout(timeout) ?? false;

  Future<String> state() async =>
      await channel.invokeMethod<String>('getStatus').timeout(timeout) ??
      'disconnected';
}
