import 'dart:convert';

import 'package:fl_clash/security/fastcat_local_cache_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native provider envelope is compatible with the Dart vault', () {
    // Independent AES-GCM fixture, also verified by the native resource tests.
    const envelope = '{"v":1,"alg":"A256GCM","purpose":"fastcat-local-cache",'
        '"kid":"test","nonce":"AwMDAwMDAwMDAwMD",'
        '"data":"/vXgYsce6Q/bRn/Na0O1cg==","tag":"5UCjPuVqMjvstS1/Pq2LrQ=="}';
    final decoded = FastCatLocalCacheCodec.decodeWithKeys(envelope,
        recordId: 'provider|p1|proxies/fixture',
        keys: {'test': base64Encode(List.filled(32, 42))});
    expect(utf8.decode(base64Decode(decoded)), 'proxies: []\n');
    expect(
        () => FastCatLocalCacheCodec.decodeWithKeys(envelope,
            recordId: 'provider|other|proxies/fixture',
            keys: {'test': base64Encode(List.filled(32, 42))}),
        throwsException);
  });
}
