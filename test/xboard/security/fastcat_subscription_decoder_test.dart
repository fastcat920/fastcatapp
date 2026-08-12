import 'dart:convert';
import 'dart:typed_data';

import 'package:fl_clash/xboard/security/fastcat_subscription_decoder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/export.dart';

void main() {
  const kid = '2026-01';
  final key = Uint8List.fromList(List<int>.generate(32, (i) => i));
  final encodedKey = base64Encode(key);

  String envelope(String yaml, {String envelopeKid = kid}) {
    const timestamp = 1786500000;
    final nonce = Uint8List.fromList(List<int>.generate(12, (i) => i + 1));
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(
          KeyParameter(key),
          128,
          nonce,
          Uint8List.fromList(utf8.encode(
            'fastcat-subscription|v1|$envelopeKid|$timestamp',
          )),
        ),
      );
    final sealed = cipher.process(Uint8List.fromList(utf8.encode(yaml)));
    final data = sealed.sublist(0, sealed.length - 16);
    final tag = sealed.sublist(sealed.length - 16);
    return jsonEncode({
      'v': 1,
      'alg': 'A256GCM',
      'kid': envelopeKid,
      'ts': timestamp,
      'nonce': base64Encode(nonce),
      'data': base64Encode(data),
      'tag': base64Encode(tag),
    });
  }

  test('decrypts an authenticated v1 envelope by kid', () {
    const yaml = 'proxies:\n  - name: test\nproxy-groups:\n  - name: select\n';
    expect(
      FastCatSubscriptionDecoder.decodeWithKeys(
        envelope(yaml),
        keys: {kid: encodedKey},
      ),
      yaml,
    );
  });

  test('rejects plaintext when encryption is required', () {
    expect(
      () => FastCatSubscriptionDecoder.decodeWithKeys(
        'proxies: []\nproxy-groups: []',
        keys: {kid: encodedKey},
      ),
      throwsA(isA<FastCatSubscriptionException>()),
    );
  });

  test('reports unknown kid as an upgrade requirement', () {
    const yaml = 'proxies: []\nproxy-groups: []';
    expect(
      () => FastCatSubscriptionDecoder.decodeWithKeys(
        envelope(yaml, envelopeKid: '2026-02'),
        keys: {kid: encodedKey},
      ),
      throwsA(predicate((e) => e.toString().contains('升级客户端'))),
    );
  });

  test('rejects a modified authentication tag', () {
    const yaml = 'proxies: []\nproxy-groups: []';
    final value = jsonDecode(envelope(yaml)) as Map<String, dynamic>;
    value['tag'] = base64Encode(List<int>.filled(16, 0));
    expect(
      () => FastCatSubscriptionDecoder.decodeWithKeys(
        jsonEncode(value),
        keys: {kid: encodedKey},
      ),
      throwsA(isA<FastCatSubscriptionException>()),
    );
  });
}
