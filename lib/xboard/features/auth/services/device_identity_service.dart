import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class XBoardDeviceIdentityService {
  XBoardDeviceIdentityService._();

  static const _deviceIdKey = 'xboard_device_id';
  static const _uuid = Uuid();
  static final _deviceInfo = DeviceInfoPlugin();

  static Future<Map<String, dynamic>> buildLoginPayload() async {
    final deviceId = await _getOrCreateDeviceId();
    final packageInfo = await PackageInfo.fromPlatform();
    final platform = Platform.operatingSystem;

    final payload = <String, dynamic>{
      'device_id': deviceId,
      'device_name': await _deviceName(platform),
      'platform': platform,
      'app_version': packageInfo.version,
      'build_number': packageInfo.buildNumber,
    };

    final osVersion = await _osVersion(platform);
    if (osVersion != null && osVersion.isNotEmpty) {
      payload['os_version'] = osVersion;
    }

    return payload;
  }

  static Future<String> _getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final deviceId = 'apex-${_uuid.v4()}';
    await prefs.setString(_deviceIdKey, deviceId);
    return deviceId;
  }

  static Future<String> _deviceName(String platform) async {
    try {
      if (Platform.isMacOS) {
        final info = await _deviceInfo.macOsInfo;
        return _firstNonEmpty([
          info.computerName,
          info.hostName,
          info.model,
          'Mac',
        ]);
      }
      if (Platform.isWindows) {
        final info = await _deviceInfo.windowsInfo;
        return _firstNonEmpty([info.computerName, 'Windows PC']);
      }
      if (Platform.isLinux) {
        final info = await _deviceInfo.linuxInfo;
        return _firstNonEmpty([info.prettyName, info.name, 'Linux PC']);
      }
      if (Platform.isIOS) {
        final info = await _deviceInfo.iosInfo;
        return _firstNonEmpty([info.name, info.model, 'iPhone']);
      }
      if (Platform.isAndroid) {
        final info = await _deviceInfo.androidInfo;
        return _firstNonEmpty([
          '${info.manufacturer} ${info.model}'.trim(),
          info.model,
          'Android Device',
        ]);
      }
    } catch (_) {}

    return platform.isNotEmpty ? platform : 'Unknown Device';
  }

  static Future<String?> _osVersion(String platform) async {
    try {
      if (Platform.isMacOS) {
        final info = await _deviceInfo.macOsInfo;
        return '${info.majorVersion}.${info.minorVersion}.${info.patchVersion}';
      }
      if (Platform.isWindows) {
        final info = await _deviceInfo.windowsInfo;
        return '${info.majorVersion}.${info.minorVersion}.${info.buildNumber}';
      }
      if (Platform.isLinux) {
        final info = await _deviceInfo.linuxInfo;
        return _firstNonEmpty([info.version, info.versionId]);
      }
      if (Platform.isIOS) {
        final info = await _deviceInfo.iosInfo;
        return info.systemVersion;
      }
      if (Platform.isAndroid) {
        final info = await _deviceInfo.androidInfo;
        return info.version.release;
      }
    } catch (_) {}

    return null;
  }

  static String _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final text = value?.trim();
      if (text != null && text.isNotEmpty) {
        return text;
      }
    }
    return 'Unknown Device';
  }
}
