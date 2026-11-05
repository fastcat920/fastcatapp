import 'package:fl_clash/xboard/config/fetchers/remote_config_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cryptography/cryptography.dart';
import 'dart:convert';
import 'dart:typed_data';

class _FakeHttpClient implements IHttpClient {
  _FakeHttpClient(this.body);
  final String body;

  @override
  Future<String?> getString(String url, {Duration? timeout}) async => body;
}

String _xorEncode(String plain, String key) {
  final source = utf8.encode(plain);
  final keyBytes = utf8.encode(key);
  final encrypted = Uint8List(source.length);
  for (var i = 0; i < source.length; i++) {
    encrypted[i] = source[i] ^ keyBytes[i % keyBytes.length];
  }
  return base64Encode(encrypted);
}

class _FakeConfigSource implements ConfigSource {
  _FakeConfigSource({
    required this.sourceName,
    required this.data,
    required this.delay,
    this.isEmergency = false,
    this.onFetch,
  });

  @override
  final String sourceName;
  final Map<String, dynamic> data;
  final Duration delay;
  final void Function(String source)? onFetch;

  @override
  final bool isEmergency;

  @override
  int get priority => 1;

  @override
  Future<ConfigResult<Map<String, dynamic>>> fetchConfig() async {
    onFetch?.call(sourceName);
    await Future<void>.delayed(delay);
    return ConfigResult.success(data, sourceName);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SimpleKeyPair testSigningKey;
  late String testPublicKey;
  final signedFixtures = <String, String>{};
  Future<String> signPlain(Map<String, dynamic> data) async {
    final payload =
        _xorEncode(jsonEncode(data), 'CHANGE_ME_TO_YOUR_SECRET_KEY_32C');
    final signature =
        await Ed25519().sign(utf8.encode(payload), keyPair: testSigningKey);
    return jsonEncode({
      '_format': 'fastcat-config-v2',
      'algorithm': 'Ed25519',
      'encoding': 'xor+base64',
      'payload': payload,
      'signature': base64Encode(signature.bytes),
    });
  }

  setUpAll(() async {
    testSigningKey = await Ed25519().newKeyPair();
    testPublicKey =
        base64Encode((await testSigningKey.extractPublicKey()).bytes);
    for (final version in ['1', '2', '3', '7', '8', '9', '99']) {
      signedFixtures[version] = await signPlain({
        'config_version': version,
        'domains': ['https://api.invalid'],
        'gateway_urls': ['https://gateway.invalid'],
      });
    }
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('signed v2 envelope is verified before XOR decryption', () async {
    const plain =
        '{"config_version":"2","domains":["https://api.example.com"]}';
    const testKey = 'CHANGE_ME_TO_YOUR_SECRET_KEY_32C';
    final payload = _xorEncode(plain, testKey);
    final algorithm = Ed25519();
    final keyPair = await algorithm.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final signature = await algorithm.sign(
      utf8.encode(payload),
      keyPair: keyPair,
    );
    final envelope = jsonEncode({
      '_format': 'fastcat-config-v2',
      'algorithm': 'Ed25519',
      'encoding': 'xor+base64',
      'payload': payload,
      'signature': base64Encode(signature.bytes),
    });
    final source = OssConfigSource(
      httpClient: _FakeHttpClient(envelope),
      url: 'https://config.example.com/config.json',
      name: 'signed',
      verificationPublicKey: base64Encode(publicKey.bytes),
    );

    final result = await source.fetchConfig();

    expect(result.isSuccess, isTrue);
    expect(result.data?['config_version'], '2');
  });

  test('signed v2 envelope rejects a modified payload', () async {
    const plain =
        '{"config_version":"2","domains":["https://api.example.com"]}';
    const testKey = 'CHANGE_ME_TO_YOUR_SECRET_KEY_32C';
    final payload = _xorEncode(plain, testKey);
    final algorithm = Ed25519();
    final keyPair = await algorithm.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final signature = await algorithm.sign(
      utf8.encode(payload),
      keyPair: keyPair,
    );
    final envelope = jsonEncode({
      '_format': 'fastcat-config-v2',
      'algorithm': 'Ed25519',
      'encoding': 'xor+base64',
      'payload': '${payload}A',
      'signature': base64Encode(signature.bytes),
    });
    final source = OssConfigSource(
      httpClient: _FakeHttpClient(envelope),
      url: 'https://config.example.com/config.json',
      name: 'tampered',
      verificationPublicKey: base64Encode(publicKey.bytes),
    );

    final result = await source.fetchConfig();

    expect(result.isSuccess, isFalse);
    expect(result.error, contains('解密/解析失败'));
  });

  test('usable backup takes over when faster primary content is invalid',
      () async {
    final manager = RemoteConfigManager(
      sources: [
        _FakeConfigSource(
          sourceName: 'primary',
          data: const {'broken': true},
          delay: const Duration(milliseconds: 1),
        ),
        _FakeConfigSource(
          sourceName: 'backup',
          data: const {
            'domains': ['https://example.com'],
          },
          delay: const Duration(milliseconds: 5),
        ),
      ],
      maxRetries: 0,
    );

    final result = await manager.fetchFirstUsableConfig(
      (data) => data['domains'] is List,
    );

    expect(result.isSuccess, isTrue);
    expect(result.source, 'backup');
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('xboard_remote_config_last_successful_source'),
      'backup',
    );
  });

  test('last successful source is started first on the next launch', () async {
    SharedPreferences.setMockInitialValues({
      'xboard_remote_config_last_successful_source': 'backup',
    });
    final started = <String>[];
    final manager = RemoteConfigManager(
      sources: [
        _FakeConfigSource(
          sourceName: 'primary',
          data: const {
            'domains': ['https://primary.example.com']
          },
          delay: const Duration(milliseconds: 10),
          onFetch: started.add,
        ),
        _FakeConfigSource(
          sourceName: 'backup',
          data: const {
            'domains': ['https://backup.example.com']
          },
          delay: const Duration(milliseconds: 1),
          onFetch: started.add,
        ),
      ],
      maxRetries: 0,
    );

    final result = await manager.fetchFirstUsableConfig((_) => true);

    expect(started.first, 'backup');
    expect(result.source, 'backup');
  });

  test('emergency source is used only after normal sources are unusable',
      () async {
    final started = <String>[];
    final manager = RemoteConfigManager(
      sources: [
        _FakeConfigSource(
          sourceName: 'normal',
          data: const {'broken': true},
          delay: Duration.zero,
          onFetch: started.add,
        ),
        _FakeConfigSource(
          sourceName: 'emergency_builtin',
          data: const {
            'domains': ['https://emergency.example.com'],
          },
          delay: Duration.zero,
          isEmergency: true,
          onFetch: started.add,
        ),
      ],
      maxRetries: 0,
    );

    final result = await manager.fetchFirstUsableConfig(
      (data) => data['domains'] is List,
    );

    expect(result.source, 'emergency_builtin');
    expect(started.first, 'normal');
    expect(started.last, 'emergency_builtin');
  });

  test('higher config_version wins inside the settlement window', () async {
    final manager = RemoteConfigManager(
      sources: [
        _FakeConfigSource(
          sourceName: 'old-fast',
          data: const {
            'config_version': '2',
            'domains': ['https://old.example.com'],
          },
          delay: const Duration(milliseconds: 1),
        ),
        _FakeConfigSource(
          sourceName: 'new-slow',
          data: const {
            'config_version': '3',
            'domains': ['https://new.example.com'],
          },
          delay: const Duration(milliseconds: 20),
        ),
      ],
      maxRetries: 0,
    );

    final result = await manager.fetchFirstUsableConfig((_) => true);

    expect(result.source, 'new-slow');
    expect(result.data?['config_version'], '3');
  });

  test('one healthy normal source is enough and emergency is not requested',
      () async {
    final started = <String>[];
    final manager = RemoteConfigManager(
      sources: [
        _FakeConfigSource(
          sourceName: 'only-working-normal',
          data: const {
            'config_version': '4',
            'domains': ['https://api.example.com'],
            'gateway_urls': ['https://gateway.example.com'],
          },
          delay: Duration.zero,
          onFetch: started.add,
        ),
        _FakeConfigSource(
          sourceName: 'emergency_builtin',
          data: const {
            'config_version': '4',
            'domains': ['https://emergency-api.example.com'],
            'gateway_urls': ['https://emergency-gateway.example.com'],
          },
          delay: Duration.zero,
          isEmergency: true,
          onFetch: started.add,
        ),
      ],
      maxRetries: 0,
    );

    final result = await manager.fetchFirstUsableConfig((_) => true);

    expect(result.source, 'only-working-normal');
    expect(started, ['only-working-normal']);
  });

  test('complete cache preserves routes and update config during outage',
      () async {
    final cachedData = {
      'config_version': '8',
      'domains': ['https://api.example.com'],
      'gateway_urls': ['https://gateway.example.com'],
      'update': {
        'latest': {
          'windows': {
            'version': '3.5.9',
            'url': 'https://download.example.com/windows',
          },
        },
      },
    };
    SharedPreferences.setMockInitialValues({
      RemoteConfigManager.rawCacheKey: jsonEncode({
        'current': {
          'source': 'working-before-outage',
          'verified_at': DateTime.now().toUtc().toIso8601String(),
          'raw_content': await signPlain(cachedData),
        },
      }),
    });
    final manager = RemoteConfigManager(
      verificationPublicKey: testPublicKey,
      sources: [
        _FakeConfigSource(
          sourceName: 'broken-live',
          data: const {'broken': true},
          delay: Duration.zero,
        ),
      ],
      maxRetries: 0,
    );

    final result = await manager.fetchFirstUsableConfig(
      (data) => data['domains'] is List && data['gateway_urls'] is List,
    );

    expect(result.source, 'local_cache');
    expect(result.data?['config_version'], '8');
    expect(
      ((result.data?['update'] as Map)['latest'] as Map)['windows'],
      isNotNull,
    );
  });

  final clock = DateTime.utc(2026, 10, 5);
  String wire(String version) => signedFixtures[version]!;
  Map<String, dynamic> record(String raw, {int days = 0}) => {
        'raw_content': raw,
        'verified_at': clock.subtract(Duration(days: days)).toIso8601String(),
        'source': 'test',
      };
  Future<void> seed(Map<String, dynamic> entries) async {
    SharedPreferences.setMockInitialValues(
        {RemoteConfigManager.rawCacheKey: jsonEncode(entries)});
  }

  RemoteConfigManager manager({String? live, String? publicKey}) =>
      RemoteConfigManager(
        sources: live == null
            ? []
            : [
                OssConfigSource(
                  httpClient: _FakeHttpClient(live),
                  url: 'https://config.invalid',
                  name: 'live',
                  verificationPublicKey: publicKey ?? testPublicKey,
                )
              ],
        now: () => clock,
        verificationPublicKey: publicKey ?? testPublicKey,
      );
  Future<ConfigResult<Map<String, dynamic>>> read(RemoteConfigManager value) =>
      value.fetchFirstUsableConfig(
          (data) => data['domains'] is List && data['gateway_urls'] is List);

  test('cache is original wire only and rotates two snapshots', () async {
    final first = wire('1'), second = wire('2');
    await read(manager(live: first));
    await read(manager(live: second));
    final prefs = await SharedPreferences.getInstance();
    final stored =
        jsonDecode(prefs.getString(RemoteConfigManager.rawCacheKey)!) as Map;
    expect(stored.keys, unorderedEquals(['current', 'previous']));
    expect(stored['current']['raw_content'], second);
    expect(stored['previous']['raw_content'], first);
    expect(prefs.getString(RemoteConfigManager.rawCacheKey),
        isNot(contains('gateway.invalid')));
    expect(stored['current']['data'], isNull);
  });

  test('stale cache does not extend its offline lifetime', () async {
    final entries = {'current': record(wire('3'), days: 8)};
    await seed(entries);
    final result = await read(manager());
    expect(result.isStale, isTrue);
    expect(result.fetchTime, clock.subtract(const Duration(days: 8)));
    final prefs = await SharedPreferences.getInstance();
    expect(
        jsonDecode(prefs.getString(RemoteConfigManager.rawCacheKey)!), entries);
  });

  test('expired and future dated caches are rejected', () async {
    for (final age in [31, -1]) {
      await seed({'current': record(wire('3'), days: age)});
      expect((await read(manager())).isSuccess, isFalse);
    }
  });

  test('corrupt current falls back to previous and cannot overwrite it',
      () async {
    await seed({'current': record('damaged'), 'previous': record(wire('2'))});
    expect((await read(manager())).data?['config_version'], '2');
    await read(manager(live: wire('3')));
    final prefs = await SharedPreferences.getInstance();
    final stored =
        jsonDecode(prefs.getString(RemoteConfigManager.rawCacheKey)!) as Map;
    expect(stored['previous']['raw_content'], wire('2'));
  });

  test('unusable but decryptable current cannot overwrite valid previous',
      () async {
    final invalid = await signPlain({'config_version': '50'});
    await seed({'current': record(invalid), 'previous': record(wire('2'))});
    await read(manager(live: wire('3')));
    final prefs = await SharedPreferences.getInstance();
    final stored =
        jsonDecode(prefs.getString(RemoteConfigManager.rawCacheKey)!) as Map;
    expect(stored['previous']['raw_content'], wire('2'));
  });

  test('concurrent refresh callers share one source request', () async {
    var calls = 0;
    final value = RemoteConfigManager(sources: [
      _FakeConfigSource(
          sourceName: 'test',
          data: {
            'domains': ['https://api.invalid'],
            'gateway_urls': ['https://gateway.invalid']
          },
          delay: const Duration(milliseconds: 20),
          onFetch: (_) {
            calls++;
          }),
    ]);
    final results = await Future.wait([read(value), read(value)]);
    expect(calls, 1);
    expect(results.every((item) => item.isSuccess), isTrue);
  });

  test('lower version cannot regress valid cache; same version renews it',
      () async {
    await seed({'current': record(wire('8'), days: 8)});
    expect((await read(manager(live: wire('7')))).source, 'local_cache');
    final equal = await read(manager(live: wire('8')));
    expect(equal.source, 'live');
    expect(equal.isStale, isFalse);
    expect((await read(manager())).fetchTime, clock);
    expect((await read(manager(live: wire('9')))).data?['config_version'], '9');
  });

  test('old parsed caches and plaintext remote configurations are rejected',
      () async {
    SharedPreferences.setMockInitialValues({
      'xboard_remote_config_complete_current_v1': jsonEncode({
        'data': {
          'domains': ['https://api.invalid']
        }
      }),
    });
    expect((await read(manager())).isSuccess, isFalse);
    final plain = jsonEncode({
      'domains': ['https://api.invalid'],
      'gateway_urls': ['https://gateway.invalid']
    });
    expect((await read(manager(live: plain))).isSuccess, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(RemoteConfigManager.rawCacheKey), isNull);
  });

  test('signed disk cache is reverified with the current trust key', () async {
    final algorithm = Ed25519();
    final key = await algorithm.newKeyPair();
    final publicKey = base64Encode((await key.extractPublicKey()).bytes);
    final payload = (jsonDecode(wire('7')) as Map)['payload'] as String;
    final signature = await algorithm.sign(utf8.encode(payload), keyPair: key);
    final envelope = {
      '_format': 'fastcat-config-v2',
      'algorithm': 'Ed25519',
      'encoding': 'xor+base64',
      'payload': payload,
      'signature': base64Encode(signature.bytes),
    };
    await read(manager(live: jsonEncode(envelope), publicKey: publicKey));
    expect((await read(manager(publicKey: publicKey))).isSuccess, isTrue);
    expect((await read(manager())).isSuccess, isFalse);
    envelope['payload'] = (jsonDecode(wire('99')) as Map)['payload'] as String;
    await seed({'current': record(jsonEncode(envelope))});
    expect((await read(manager(publicKey: publicKey))).isSuccess, isFalse);
  });

  test(
      'unsigned, stripped and malformed envelopes are rejected online and on disk',
      () async {
    final signed = jsonDecode(wire('3')) as Map<String, dynamic>;
    final unsigned = signed['payload'] as String;
    final variants = [
      unsigned,
      jsonEncode({...signed}..remove('_format')),
      jsonEncode({...signed}..remove('signature')),
      jsonEncode({...signed, '_format': 'fastcat-config-v1'}),
      jsonEncode({...signed, 'algorithm': 'none'}),
      jsonEncode({...signed, 'encoding': 'json'}),
      jsonEncode({...signed, 'signature': 'invalid'}),
    ];
    for (final raw in variants) {
      SharedPreferences.setMockInitialValues({});
      expect((await read(manager(live: raw))).isSuccess, isFalse);
      await seed({'current': record(raw)});
      expect((await read(manager())).isSuccess, isFalse);
    }
    await seed({'current': record(wire('3'))});
    expect((await read(manager(publicKey: ''))).isSuccess, isFalse);
    expect((await read(manager(publicKey: 'invalid'))).isSuccess, isFalse);
  });

  test('unsigned primary cannot win over a signed emergency source', () async {
    final signed = wire('3');
    final legacy = (jsonDecode(signed) as Map)['payload'] as String;
    final result = await read(RemoteConfigManager(
      verificationPublicKey: testPublicKey,
      sources: [
        OssConfigSource(
            httpClient: _FakeHttpClient(legacy),
            url: 'https://old.invalid',
            name: 'legacy',
            verificationPublicKey: testPublicKey),
        OssConfigSource(
            httpClient: _FakeHttpClient(signed),
            url: 'https://v2.invalid',
            name: 'signed-emergency',
            emergency: true,
            verificationPublicKey: testPublicKey),
      ],
    ));
    expect(result.source, 'signed-emergency');
  });
}
