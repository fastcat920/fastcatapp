import 'package:fl_clash/xboard/config/fetchers/remote_config_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

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

  setUp(() {
    SharedPreferences.setMockInitialValues({});
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
      'xboard_remote_config_complete_current_v1': jsonEncode({
        'source': 'working-before-outage',
        'config_version': '8',
        'data': cachedData,
      }),
    });
    final manager = RemoteConfigManager(
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
}
