import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
/// Supabase REST API 服务
///
/// 用于双 OSS 切换：查全局开关、查用户 is_builtin、注册后写入
/// 不引入 Supabase SDK，直接用 Dio 调 REST API
class SupabaseService {
  SupabaseService._();

  // ── 混淆存储（XOR + Base64）──
  // 运行时解密，防止反编译直接看到明文
  static const _obfuscatedUrl =
      'CQQRCCxJWl8NGAYSFD5FUlpFFQgAHTwWDxERDE8AEC9TUlNHBF4GFw==';
  static const _obfuscatedKey =
      'EhI6CCoRGRkSCgARCTptA3x+DAYoHCgKIChWJCQ5VCZdX3kBBi8HKGw0TCovAw==';
  static const _obfKey = 'apex_supabase_2024';

  static String get _url => _deobfuscate(_obfuscatedUrl, _obfKey);
  static String get _apiKey => _deobfuscate(_obfuscatedKey, _obfKey);

  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));

  /// XOR + Base64 解混淆
  static String _deobfuscate(String encoded, String key) {
    final encBytes = base64.decode(encoded);
    final keyBytes = utf8.encode(key);
    final result = Uint8List(encBytes.length);
    for (var i = 0; i < encBytes.length; i++) {
      result[i] = encBytes[i] ^ keyBytes[i % keyBytes.length];
    }
    return utf8.decode(result);
  }

  /// XOR + Base64 混淆（用于生成混淆值，开发时使用）
  static String obfuscate(String plaintext, String key) {
    final textBytes = utf8.encode(plaintext);
    final keyBytes = utf8.encode(key);
    final result = Uint8List(textBytes.length);
    for (var i = 0; i < textBytes.length; i++) {
      result[i] = textBytes[i] ^ keyBytes[i % keyBytes.length];
    }
    return base64.encode(result);
  }

  /// 查询全局开关 dual_oss_enabled
  ///
  /// 返回 true/false，不可达时返回 false（降级走打包 OSS）
  static Future<bool> isDualOssEnabled() async {
    try {
      final resp = await _dio.get(
        '${_url}/rest/v1/app_config',
        queryParameters: {
          'key': 'eq.dual_oss_enabled',
          'select': 'value',
        },
        options: Options(headers: _headers()),
      );
      final data = resp.data as List?;
      if (data == null || data.isEmpty) return false;
      return data.first['value'] == 'true';
    } catch (_) {
      return false;
    }
  }

  /// 查询邮箱的 is_builtin 值
  ///
  /// 返回 1（内置 OSS）或 0（打包 OSS），不存在返回 null
  static Future<int?> queryUserBuiltin(String email) async {
    try {
      final resp = await _dio.get(
        '${_url}/rest/v1/app_users',
        queryParameters: {
          'email': 'eq.$email',
          'select': 'is_builtin',
        },
        options: Options(headers: _headers()),
      );
      final data = resp.data as List?;
      if (data == null || data.isEmpty) return null;
      return data.first['is_builtin'] as int?;
    } catch (_) {
      return null;
    }
  }

  /// 注册成功后写入用户记录
  ///
  /// 使用 upsert（ON CONFLICT DO UPDATE）避免重复插入
  static Future<void> syncUser(String email, int isBuiltin) async {
    try {
      await _dio.post(
        '${_url}/rest/v1/app_users?on_conflict=email',
        data: {'email': email, 'is_builtin': isBuiltin},
        options: Options(headers: {
          ..._headers(),
          'Prefer': 'resolution=merge-duplicates',
        }),
      );
    } catch (_) {}
  }

  static Map<String, String> _headers() => {
        'apikey': _apiKey,
        'Authorization': 'Bearer ${_apiKey}',
        'Content-Type': 'application/json',
      };
}
