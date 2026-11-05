import 'dart:async';
import 'dart:convert';

import 'package:fl_clash/security/ios_profile_config.dart';
import 'package:flutter/services.dart';

/// Reload the running extension with SetupParams, not a raw startup profile.
/// Keeping this boundary independent of Platform permits offline channel tests.
Future<void> reloadIosTunnelConfiguration(
  String config, {
  MethodChannel channel = const MethodChannel('fastcat/clash'),
  Duration timeout = const Duration(seconds: 30),
}) async {
  final decoded = json.decode(config);
  if (decoded is! Map<String, dynamic> ||
      decoded['config'] is! Map<String, dynamic> ||
      (decoded['config'] as Map).isEmpty) {
    throw const FormatException('Expected a nonempty iOS SetupParams config');
  }
  final payload = Map<String, dynamic>.from(decoded);
  final profile = iosProfileConfig(payload['config'] as Map<String, dynamic>);
  for (final key in ['tun', 'dns']) {
    if (profile[key] != null && profile[key] is! Map) {
      throw FormatException('Invalid iOS configuration section: $key');
    }
    profile[key] = Map<String, dynamic>.from(profile[key] as Map? ?? {});
  }
  payload['config'] = profile;
  (profile['tun'] as Map<String, dynamic>)['enable'] = false;
  profile['allow-lan'] = true;
  profile['bind-address'] = '*';
  final dns = profile['dns'] as Map<String, dynamic>;
  dns['enable'] = true;
  dns['listen'] = '127.0.0.1:6053';
  // A request whose UI deadline elapsed must not apply later behind rollback.
  payload['deadlineUnixMs'] =
      DateTime.now().add(timeout).millisecondsSinceEpoch;
  final result = await channel
      .invokeMethod<String>('_updateConfig', json.encode(payload))
      .timeout(timeout);
  if (result == null || (result.isNotEmpty && result != 'ok')) {
    throw StateError('Tunnel configuration was not applied');
  }
}
