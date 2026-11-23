import 'package:fl_clash/security/local_test_profile_scope.dart';
import 'package:fl_clash/models/models.dart';
import 'dart:async';
import 'dart:convert';
import 'package:fl_clash/security/ios_profile_config.dart';
import 'package:fl_clash/services/ios_configuration_reload.dart';
import 'dart:io';
import 'dart:isolate';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/services.dart';

import '../clash/lib.dart';
import '../services/core_switch_status.dart';
import '../services/ios_vpn_status.dart';

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
      final attempt = DateTime.now().millisecondsSinceEpoch;
      final elapsed = Stopwatch()..start();
      commonPrint.log('[IOSVPN:$attempt] preparing configuration');
      globalState.updateCoreSwitchStatus(CoreSwitchStage.coreConnecting,
          message: '正在准备 VPN 配置');
      final config = iosProfileConfig(await globalState
          .patchRawConfig(
            patchConfig: globalState.config.patchClashConfig,
          )
          .timeout(const Duration(seconds: 20)));
      globalState.updateCoreSwitchStatus(CoreSwitchStage.tunApplying,
          message: '正在启动系统 VPN');
      // JSON is valid YAML; the startup path expects a raw profile, not SetupParams.
      config['rules'] = config.remove('rule') ?? config['rules'] ?? [];
      config['fastcat-selected-map'] = scopedProfileSelections(
          globalState.config.currentProfileId,
          globalState.config.currentProfile?.selectedMap ?? <String, String>{});
      // This will throw PlatformException if VPN start fails.
      // The caller (handleStart) catches this and shows the error.
      commonPrint.log(
          '[IOSVPN:$attempt] requesting tunnel at ${elapsed.elapsedMilliseconds}ms');
      try {
        final started = await methodChannel.invokeMethod<bool>("start", {
          'config': json.encode(config),
        });
        commonPrint.log(
            '[IOSVPN:$attempt] tunnel result=$started at ${elapsed.elapsedMilliseconds}ms');
        return started;
      } catch (error) {
        commonPrint.log(
            '[IOSVPN:$attempt] tunnel failed at ${elapsed.elapsedMilliseconds}ms: $error');
        rethrow;
      }
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
    await reloadIosTunnelConfiguration(config);
  }

  Future<Map<String, dynamic>> restoreIosVpnState() =>
      const IosVpnStatusReader().restore();

  Future<bool> isVpnActuallyRunning() async {
    if (Platform.isIOS) {
      return const IosVpnStatusReader().isConnected();
    }
    return await methodChannel.invokeMethod<bool>('status') ?? false;
  }

  Future<String> getVpnConnectionState() async {
    if (Platform.isIOS) {
      return const IosVpnStatusReader().state();
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
