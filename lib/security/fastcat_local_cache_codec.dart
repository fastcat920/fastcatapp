import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import '../xboard/security/fastcat_subscription_decoder.dart';

/// Authenticated local-cache encryption using the existing rotating FastCat
/// key ring. This is intentionally simpler than a device-key vault: it keeps
/// cached profiles unreadable as plain text without adding Keychain/Keystore
/// availability to the connection path.
class FastCatLocalCacheCodec {
  static const String _purpose = 'fastcat-local-cache';

  static String encode(String plaintext, {required String recordId}) {
    final kid = FastCatSubscriptionDecoder.currentKeyId;
    final encodedKey = FastCatSubscriptionDecoder.currentEncodedKey;
    if (kid.isEmpty || encodedKey.isEmpty) {
      throw const FastCatSubscriptionException(
        '当前客户端未配置 FastCat 缓存加密密钥。',
      );
    }
    return encodeWithKey(
      plaintext,
      recordId: recordId,
      kid: kid,
      encodedKey: encodedKey,
    );
  }

  static String decode(String envelope, {required String recordId}) =>
      decodeWithKeys(
        envelope,
        recordId: recordId,
        keys: FastCatSubscriptionDecoder.configuredKeys,
      );

  static bool isLocalEnvelope(String value) {
    try {
      final decoded = jsonDecode(value);
      return decoded is Map<String, dynamic> && decoded['purpose'] == _purpose;
    } catch (_) {
      return false;
    }
  }

  static String encodeWithKey(
    String plaintext, {
    required String recordId,
    required String kid,
    required String encodedKey,
  }) {
    final key = _decodeBase64(encodedKey);
    if (key.length != 32) {
      throw const FastCatSubscriptionException('FastCat 缓存密钥长度无效。');
    }
    final nonce = _randomBytes(12);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(
          KeyParameter(key),
          128,
          nonce,
          _aad(kid, recordId),
        ),
      );
    final encrypted =
        cipher.process(Uint8List.fromList(utf8.encode(plaintext)));
    final tagOffset = encrypted.length - 16;
    return jsonEncode({
      'v': 1,
      'alg': 'A256GCM',
      'purpose': _purpose,
      'kid': kid,
      'nonce': base64Encode(nonce),
      'data': base64Encode(encrypted.sublist(0, tagOffset)),
      'tag': base64Encode(encrypted.sublist(tagOffset)),
    });
  }

  static String decodeWithKeys(
    String envelope, {
    required String recordId,
    required Map<String, String> keys,
  }) {
    try {
      final decoded = jsonDecode(envelope);
      if (decoded is! Map<String, dynamic> ||
          decoded['v'] != 1 ||
          decoded['alg'] != 'A256GCM' ||
          decoded['purpose'] != _purpose) {
        throw const FormatException('unsupported local cache envelope');
      }
      final kid = _stringField(decoded, 'kid');
      final encodedKey = keys[kid];
      if (encodedKey == null) {
        throw FastCatSubscriptionException(
          '缓存密钥版本 $kid 未包含在当前客户端中，请升级客户端。',
        );
      }
      final key = _decodeBase64(encodedKey);
      final nonce = _decodeBase64(_stringField(decoded, 'nonce'));
      final data = _decodeBase64(_stringField(decoded, 'data'));
      final tag = _decodeBase64(_stringField(decoded, 'tag'));
      if (key.length != 32 || nonce.length != 12 || tag.length != 16) {
        throw const FormatException('invalid cryptographic field length');
      }
      final cipher = GCMBlockCipher(AESEngine())
        ..init(
          false,
          AEADParameters(KeyParameter(key), 128, nonce, _aad(kid, recordId)),
        );
      return utf8.decode(cipher.process(Uint8List.fromList([...data, ...tag])));
    } on FastCatSubscriptionException {
      rethrow;
    } catch (_) {
      throw const FastCatSubscriptionException(
        '本地订阅缓存解密认证失败：缓存已损坏或密钥不匹配。',
      );
    }
  }

  static Uint8List _aad(String kid, String recordId) => Uint8List.fromList(
        utf8.encode('$_purpose|v1|$kid|$recordId'),
      );

  static String _stringField(Map<String, dynamic> envelope, String name) {
    final value = envelope[name];
    if (value is! String || value.isEmpty) throw FormatException(name);
    return value;
  }

  static Uint8List _decodeBase64(String value) {
    final normalized = value.padRight(((value.length + 3) ~/ 4) * 4, '=');
    return base64Decode(normalized);
  }

  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }
}
