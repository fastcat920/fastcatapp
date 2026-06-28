import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/common/path.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

class BrandedDesktopSharedPreferencesStore
    extends SharedPreferencesStorePlatform {
  BrandedDesktopSharedPreferencesStore();

  static const _defaultPrefix = 'flutter.';

  Map<String, Object>? _cache;

  static void registerIfNeeded() {
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) {
      return;
    }
    SharedPreferencesStorePlatform.instance =
        BrandedDesktopSharedPreferencesStore();
  }

  @override
  Future<bool> remove(String key) async {
    final data = await _read();
    data.remove(key);
    return _write(data);
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    final normalized = _normalizeValue(value);
    if (normalized == null) return false;
    final data = await _read();
    data[key] = normalized;
    return _write(data);
  }

  @override
  Future<bool> clear() {
    return clearWithParameters(
      ClearParameters(filter: PreferencesFilter(prefix: _defaultPrefix)),
    );
  }

  @override
  Future<bool> clearWithPrefix(String prefix) {
    return clearWithParameters(
      ClearParameters(filter: PreferencesFilter(prefix: prefix)),
    );
  }

  @override
  Future<bool> clearWithParameters(ClearParameters parameters) async {
    final data = await _read();
    final filter = parameters.filter;
    data.removeWhere((key, _) {
      if (!key.startsWith(filter.prefix)) return false;
      return filter.allowList == null || filter.allowList!.contains(key);
    });
    return _write(data);
  }

  @override
  Future<Map<String, Object>> getAll() {
    return getAllWithParameters(
      GetAllParameters(filter: PreferencesFilter(prefix: _defaultPrefix)),
    );
  }

  @override
  Future<Map<String, Object>> getAllWithPrefix(String prefix) {
    return getAllWithParameters(
      GetAllParameters(filter: PreferencesFilter(prefix: prefix)),
    );
  }

  @override
  Future<Map<String, Object>> getAllWithParameters(
    GetAllParameters parameters,
  ) async {
    final data = await _read();
    final filter = parameters.filter;
    return Map<String, Object>.fromEntries(
      data.entries.where((entry) {
        if (!entry.key.startsWith(filter.prefix)) return false;
        return filter.allowList == null ||
            filter.allowList!.contains(entry.key);
      }),
    );
  }

  Future<Map<String, Object>> _read() async {
    if (_cache != null) return _cache!;
    await appPath.migrateLegacyDesktopData();
    final file = File(await appPath.sharedPreferencesPath);
    if (!await file.exists()) {
      _cache = <String, Object>{};
      return _cache!;
    }
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) {
        _cache = <String, Object>{};
        return _cache!;
      }
      final result = <String, Object>{};
      for (final entry in decoded.entries) {
        final value = _normalizeValue(entry.value);
        if (value != null) {
          result[entry.key.toString()] = value;
        }
      }
      _cache = result;
      return _cache!;
    } catch (_) {
      _cache = <String, Object>{};
      return _cache!;
    }
  }

  Future<bool> _write(Map<String, Object> data) async {
    final file = File(await appPath.sharedPreferencesPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
      flush: true,
    );
    _cache = Map<String, Object>.from(data);
    return true;
  }

  Object? _normalizeValue(Object? value) {
    if (value is bool || value is int || value is double || value is String) {
      return value;
    }
    if (value is List) {
      return value.map((item) => item.toString()).toList(growable: false);
    }
    return null;
  }
}
