import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

class FastCatSubscriptionException implements Exception {
  final String message;
  const FastCatSubscriptionException(this.message);

  @override
  String toString() => message;
}

/// Decodes the authenticated FastCat subscription envelope returned by catboard.
class FastCatSubscriptionDecoder {
  static const String subscriptionFlag = String.fromEnvironment(
    'FASTCAT_SUBSCRIPTION_FLAG',
    defaultValue: 'fastcat-v1',
  );
  static const bool requireEncryption = bool.fromEnvironment(
    'FASTCAT_REQUIRE_ENCRYPTION',
    defaultValue: true,
  );
  static const String _currentKid =
      String.fromEnvironment('FASTCAT_KEY_CURRENT_ID', defaultValue: '');
  static const String _currentKey =
      String.fromEnvironment('FASTCAT_KEY_CURRENT', defaultValue: '');
  static const String _nextKid =
      String.fromEnvironment('FASTCAT_KEY_NEXT_ID', defaultValue: '');
  static const String _nextKey =
      String.fromEnvironment('FASTCAT_KEY_NEXT', defaultValue: '');

  static String decode(String responseBody) => decodeWithKeys(
        responseBody,
        keys: {
          if (_currentKid.isNotEmpty) _currentKid: _currentKey,
          if (_nextKid.isNotEmpty) _nextKid: _nextKey,
        },
        requireEncrypted: requireEncryption,
      );

  /// Public for deterministic protocol tests; production callers use [decode].
  static String decodeWithKeys(
    String responseBody, {
    required Map<String, String> keys,
    bool requireEncrypted = true,
  }) {
    final trimmed = responseBody.trim();
    Map<String, dynamic> envelope;
    try {
      final value = jsonDecode(trimmed);
      if (value is! Map<String, dynamic>) throw const FormatException();
      envelope = value;
    } catch (_) {
      if (!requireEncrypted && _looksLikeClashYaml(responseBody)) {
        return responseBody;
      }
      throw const FastCatSubscriptionException(
        '服务端未返回 FastCat 加密订阅，已拒绝明文降级。',
      );
    }

    if (envelope['v'] != 1 || envelope['alg'] != 'A256GCM') {
      throw const FastCatSubscriptionException('不支持的 FastCat 订阅协议版本或算法。');
    }
    final kid = envelope['kid'];
    final timestamp = envelope['ts'];
    if (kid is! String || kid.isEmpty || timestamp is! int) {
      throw const FastCatSubscriptionException('FastCat 加密信封缺少有效的 kid 或时间戳。');
    }

    final encodedKey = keys[kid];
    if (encodedKey == null) {
      throw FastCatSubscriptionException(
        '订阅密钥版本 $kid 未包含在当前客户端中，请升级客户端。',
      );
    }

    try {
      final key = base64Decode(encodedKey);
      final nonce = base64Decode(_stringField(envelope, 'nonce'));
      final data = base64Decode(_stringField(envelope, 'data'));
      final tag = base64Decode(_stringField(envelope, 'tag'));
      if (key.length != 32 || nonce.length != 12 || tag.length != 16) {
        throw const FormatException('invalid cryptographic field length');
      }

      final cipher = GCMBlockCipher(AESEngine())
        ..init(
          false,
          AEADParameters(
            KeyParameter(Uint8List.fromList(key)),
            128,
            Uint8List.fromList(nonce),
            Uint8List.fromList(
              utf8.encode('fastcat-subscription|v1|$kid|$timestamp'),
            ),
          ),
        );
      final input = Uint8List.fromList([...data, ...tag]);
      final plaintext = utf8.decode(cipher.process(input));
      if (!_looksLikeClashYaml(plaintext)) {
        throw const FormatException('decrypted payload is not Clash YAML');
      }
      return plaintext;
    } catch (error) {
      if (error is FastCatSubscriptionException) rethrow;
      throw const FastCatSubscriptionException(
        '订阅解密认证失败：密钥不匹配或响应已损坏。',
      );
    }
  }

  static String _stringField(Map<String, dynamic> envelope, String name) {
    final value = envelope[name];
    if (value is! String || value.isEmpty) throw FormatException(name);
    return value;
  }

  static bool _looksLikeClashYaml(String content) {
    return content.contains('proxies:') && content.contains('proxy-groups:');
  }
}
