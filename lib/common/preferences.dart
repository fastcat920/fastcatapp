import 'dart:async';
import 'dart:convert';

import 'package:fl_clash/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'constant.dart';

class Preferences {
  static Preferences? _instance;
  Completer<SharedPreferences?> sharedPreferencesCompleter = Completer();

  Future<bool> get isInit async =>
      await sharedPreferencesCompleter.future != null;

  Preferences._internal() {
    SharedPreferences.getInstance()
        .then((value) => sharedPreferencesCompleter.complete(value))
        .onError((_, __) => sharedPreferencesCompleter.complete(null));
  }

  factory Preferences() {
    _instance ??= Preferences._internal();
    return _instance!;
  }

  Future<ClashConfig?> getClashConfig() async {
    final preferences = await sharedPreferencesCompleter.future;
    final clashConfigString = preferences?.getString(clashConfigKey);
    if (clashConfigString == null) return null;
    final clashConfigMap = json.decode(clashConfigString);
    return ClashConfig.fromJson(clashConfigMap);
  }

  Future<Config?> getConfig() async {
    final preferences = await sharedPreferencesCompleter.future;
    final configString = preferences?.getString(configKey);
    if (configString == null) {
      await preferences?.setBool(closeConnectionsDefaultMigratedKey, true);
      return null;
    }
    final configMap = json.decode(configString) as Map<String, dynamic>;
    await _migrateCloseConnectionsDefault(preferences, configMap);
    await _migrateDnsDefaults(preferences, configMap);
    return Config.compatibleFromJson(configMap);
  }

  Future<void> _migrateCloseConnectionsDefault(
    SharedPreferences? preferences,
    Map<String, dynamic> configMap,
  ) async {
    if (preferences == null) return;
    if (preferences.getBool(closeConnectionsDefaultMigratedKey) == true) {
      return;
    }
    final appSetting = configMap['appSetting'];
    if (appSetting is Map) {
      appSetting['closeConnections'] = false;
    }
    await preferences.setBool(closeConnectionsDefaultMigratedKey, true);
    await preferences.setString(configKey, json.encode(configMap));
  }

  Future<void> _migrateDnsDefaults(
    SharedPreferences? preferences,
    Map<String, dynamic> configMap,
  ) async {
    if (preferences == null ||
        preferences.getBool(dnsDefaultsMigratedKey) == true) {
      return;
    }

    final patchConfig = configMap['patchClashConfig'];
    final dns = patchConfig is Map ? patchConfig['dns'] : null;
    if (dns is Map) {
      final defaultNameserver = dns['default-nameserver'];
      if (defaultNameserver is List &&
          (defaultNameserver.length == 1 || defaultNameserver.length == 2) &&
          defaultNameserver.first == '223.5.5.5' &&
          (defaultNameserver.length == 1 ||
              defaultNameserver[1] == '119.29.29.29')) {
        for (final server in const [
          '119.29.29.29',
          '180.76.76.76',
          '1.1.1.1',
        ]) {
          if (!defaultNameserver.contains(server)) {
            defaultNameserver.add(server);
          }
        }
      }

      final proxyNameserver = dns['proxy-server-nameserver'];
      if (proxyNameserver is List &&
          proxyNameserver.length == 1 &&
          proxyNameserver.first == 'https://doh.pub/dns-query') {
        proxyNameserver.insert(0, 'https://dns.alidns.com/dns-query');
      }
    }

    await preferences.setBool(dnsDefaultsMigratedKey, true);
    await preferences.setString(configKey, json.encode(configMap));
  }

  Future<bool> saveConfig(Config config) async {
    final preferences = await sharedPreferencesCompleter.future;
    return await preferences?.setString(
          configKey,
          json.encode(config),
        ) ??
        false;
  }

  clearClashConfig() async {
    final preferences = await sharedPreferencesCompleter.future;
    preferences?.remove(clashConfigKey);
  }

  clearPreferences() async {
    final sharedPreferencesIns = await sharedPreferencesCompleter.future;
    sharedPreferencesIns?.clear();
  }
}

final preferences = Preferences();
