import 'dart:convert';
import 'dart:typed_data';

import 'package:fl_clash/security/fastcat_local_cache_codec.dart';
import 'package:fl_clash/xboard/security/fastcat_subscription_decoder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const kid = '2026-01';
  final encodedKey = base64Encode(
    Uint8List.fromList(List<int>.generate(32, (index) => index)),
  );

  test('encrypts arbitrary cached content and authenticates its record id', () {
    const plaintext = 'proxies:\n  - name: hidden.example:443\n';
    final envelope = FastCatLocalCacheCodec.encodeWithKey(
      plaintext,
      recordId: 'profile|42',
      kid: kid,
      encodedKey: encodedKey,
    );

    expect(envelope, isNot(contains('hidden.example')));
    expect(FastCatLocalCacheCodec.isLocalEnvelope(envelope), isTrue);
    expect(
      FastCatLocalCacheCodec.decodeWithKeys(
        envelope,
        recordId: 'profile|42',
        keys: {kid: encodedKey},
      ),
      plaintext,
    );
    expect(
      () => FastCatLocalCacheCodec.decodeWithKeys(
        envelope,
        recordId: 'profile|different',
        keys: {kid: encodedKey},
      ),
      throwsA(isA<FastCatSubscriptionException>()),
    );
  });

  test('rejects a modified ciphertext', () {
    final envelope = FastCatLocalCacheCodec.encodeWithKey(
      'provider bytes',
      recordId: 'provider|42|one',
      kid: kid,
      encodedKey: encodedKey,
    );
    final value = jsonDecode(envelope) as Map<String, dynamic>;
    final ciphertext = base64Decode(value['data'] as String);
    ciphertext[0] ^= 1;
    value['data'] = base64Encode(ciphertext);

    expect(
      () => FastCatLocalCacheCodec.decodeWithKeys(
        jsonEncode(value),
        recordId: 'provider|42|one',
        keys: {kid: encodedKey},
      ),
      throwsA(isA<FastCatSubscriptionException>()),
    );
  });
}
