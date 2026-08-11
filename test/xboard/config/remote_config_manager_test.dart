import 'package:fl_clash/xboard/config/fetchers/remote_config_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeConfigSource implements ConfigSource {
  _FakeConfigSource({
    required this.sourceName,
    required this.data,
    required this.delay,
    this.onFetch,
  });

  @override
  final String sourceName;
  final Map<String, dynamic> data;
  final Duration delay;
  final void Function(String source)? onFetch;

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
}
