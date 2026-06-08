import 'dart:async';
import 'dart:convert';
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
        ? const MethodChannel("apex/vpn")
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
      // Read current profile YAML and pass to Swift so it can be written
      // to the App Group shared container before the tunnel starts.
      final profileId = globalState.config.currentProfileId;
      String configYaml = '';
      if (profileId != null) {
        try {
          final profilePath = await appPath.getProfilePath(profileId);
          configYaml = await File(profilePath).readAsString();
        } catch (_) {}
      }
      // This will throw PlatformException if VPN start fails.
      // The caller (handleStart) catches this and shows the error.
      return await methodChannel.invokeMethod<bool>("start", {
        'config': configYaml,
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
      // Disable traffic routing but keep tunnel alive for IPC
      return await methodChannel.invokeMethod<bool>("stop");
    }
    return await methodChannel.invokeMethod<bool>("stopVpn");
  }

  /// iOS only: start the tunnel in idle mode so mihomo runs for IPC
  /// (delay tests, proxy queries) before the user taps "connect".
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
