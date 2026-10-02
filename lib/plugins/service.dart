import 'dart:async';
import 'dart:convert';
import 'package:fl_clash/security/ios_profile_config.dart';
import 'dart:io';
import 'dart:isolate';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/services.dart';

import '../clash/lib.dart';

class Service {
  static Service? _instance;
  late MethodChannel methodChannel;
  ReceivePort? receiver;

  Service._internal() {
    // iOS uses a dedicated VPN channel; Android uses the legacy "service" channel
    methodChannel = Platform.isIOS
        ? const MethodChannel("fastcat/vpn")
        : const MethodChannel("service");
  }

  factory Service() {
    _instance ??= Service._internal();
    return _instance!;
  }

  Future<bool?> init() async {
    if (Platform.isIOS) return true;
    return await methodChannel.invokeMethod<bool>("init");
  }

  Future<bool?> requestNotificationsPermission() async {
    if (!Platform.isAndroid) return true;
    return await methodChannel
        .invokeMethod<bool>("requestNotificationsPermission");
  }

  Future<bool?> destroy() async {
    if (Platform.isIOS) return true;
    return await methodChannel.invokeMethod<bool>("destroy");
  }

  /// Starts the VPN. On iOS, throws [PlatformException] with error details
  /// if the VPN tunnel fails to start.
  Future<bool?> startVpn() async {
    if (Platform.isIOS) {
      if (globalState.config.currentProfileId == null) {
        throw StateError('No subscription configuration is selected');
      }
      final config = iosProfileConfig(await globalState.patchRawConfig(
        patchConfig: globalState.config.patchClashConfig,
      ));
      // JSON is valid YAML; the startup path expects a raw profile, not SetupParams.
      config['rules'] = config.remove('rule') ?? config['rules'] ?? [];
      // This will throw PlatformException if VPN start fails.
      // The caller (handleStart) catches this and shows the error.
      return await methodChannel.invokeMethod<bool>("start", {
        'config': json.encode(config),
      });
    }
    final options = await clashLib?.getAndroidVpnOptions();
    await requestNotificationsPermission();
    return await methodChannel.invokeMethod<bool>("startVpn", {
      'data': json.encode(options),
    });
  }

  Future<bool?> stopVpn() async {
    if (Platform.isIOS) {
      // Fully stop the user-initiated tunnel when disconnecting.
      return await methodChannel.invokeMethod<bool>("stop");
    }
    return await methodChannel.invokeMethod<bool>("stopVpn");
  }

  Future<void> reloadConfiguration(String config) async {
    if (!Platform.isIOS) throw UnsupportedError('iOS tunnel reload');
    final payload = json.decode(config) as Map<String, dynamic>;
    final profile = iosProfileConfig(payload['config'] as Map<String, dynamic>);
    payload['config'] = profile;
    (profile['tun'] as Map<String, dynamic>)['enable'] = false;
    profile['allow-lan'] = true;
    profile['bind-address'] = '*';
    final dns = profile['dns'] as Map<String, dynamic>;
    dns['enable'] = true;
    dns['listen'] = '127.0.0.1:6053';
    final result = await const MethodChannel('fastcat/clash')
        .invokeMethod<String>('_updateConfig', json.encode(payload))
        .timeout(const Duration(seconds: 30));
    if (result == null || (result.isNotEmpty && result != 'ok')) {
      throw StateError('Tunnel configuration was not applied');
    }
  }

  Future<bool> isVpnActuallyRunning() async {
    if (Platform.isIOS) return globalState.isStart;
    return await methodChannel.invokeMethod<bool>('status') ?? false;
  }

  Future<String> getVpnConnectionState() async {
    if (Platform.isIOS) {
      return globalState.isStart ? 'connected' : 'disconnected';
    }
    return await methodChannel.invokeMethod<String>('connectionState') ??
        'disconnected';
  }

  /// iOS only: start the tunnel in idle mode after an explicit, disclosed use.
  Future<bool?> ensureTunnelRunning(String config) async {
    if (!Platform.isIOS) return true;
    try {
      return await methodChannel.invokeMethod<bool>("ensureRunning", {
        'config': config,
      });
    } catch (e) {
      commonPrint.log("ensureTunnelRunning failed: $e");
      return false;
    }
  }

  /// iOS only: fully stop the tunnel (kills mihomo).
  Future<bool?> stopTunnel() async {
    if (!Platform.isIOS) return true;
    return await methodChannel.invokeMethod<bool>("stopTunnel");
  }

  /// iOS only: check if the tunnel process is running.
  Future<bool> isTunnelRunning() async {
    if (!Platform.isIOS) return false;
    try {
      return await methodChannel.invokeMethod<bool>("isTunnelRunning") ?? false;
    } catch (_) {
      return false;
    }
  }
}

Service? get service {
  if (Platform.isAndroid && !globalState.isService) return Service();
  if (Platform.isIOS) return Service();
  return null;
}
