import 'package:fl_clash/xboard/features/update_check/services/update_cache_service.dart';
import 'package:fl_clash/xboard/features/update_check/services/update_service.dart';
import 'package:fl_clash/xboard/features/update_check/providers/update_check_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('persists and restores the last confirmed update', () async {
    final service = UpdateCacheService();
    final checkedAt = DateTime.utc(2026, 8, 17, 12, 30);

    await service.save(
      CachedUpdateInfo(
        platform: 'android',
        currentVersion: '3.5.7',
        latestVersion: '3.5.8',
        updateUrl: 'https://example.com/app.apk',
        releaseNotes: 'Fixes',
        forceUpdate: false,
        checkedAt: checkedAt,
      ),
    );

    final restored = await service.load();
    expect(restored, isNotNull);
    expect(restored!.platform, 'android');
    expect(restored.currentVersion, '3.5.7');
    expect(restored.latestVersion, '3.5.8');
    expect(restored.updateUrl, 'https://example.com/app.apk');
    expect(restored.releaseNotes, 'Fixes');
    expect(restored.forceUpdate, isFalse);
    expect(restored.checkedAt, checkedAt);
  });

  test('keeps prompted version separate from cached update state', () async {
    final service = UpdateCacheService();

    await service.markOptionalVersionPrompted(' 3.5.8 ');
    expect(await service.getPromptedOptionalVersion(), '3.5.8');

    await service.clearPromptedOptionalVersion();
    expect(await service.getPromptedOptionalVersion(), isNull);
  });

  test('clears a cached update without clearing unrelated preferences',
      () async {
    SharedPreferences.setMockInitialValues({'unrelated': 'keep'});
    final service = UpdateCacheService();
    await service.save(
      CachedUpdateInfo(
        platform: 'windows',
        currentVersion: '3.5.7',
        latestVersion: '3.5.8',
        updateUrl: '',
        releaseNotes: '',
        forceUpdate: true,
        checkedAt: DateTime.utc(2026),
      ),
    );

    await service.clear();

    expect(await service.load(), isNull);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('unrelated'), 'keep');
  });

  test('restores the update badge when the installed version is older',
      () async {
    final cache = UpdateCacheService();
    await cache.save(
      CachedUpdateInfo(
        platform: 'android',
        currentVersion: '3.5.7',
        latestVersion: '3.5.8',
        updateUrl: 'https://example.com/app.apk',
        releaseNotes: 'Fixes',
        forceUpdate: true,
        checkedAt: DateTime.utc(2026),
      ),
    );
    final notifier = UpdateCheckNotifier(
      updateService: _FakeUpdateService('3.5.7'),
      cacheService: cache,
    );
    addTearDown(notifier.dispose);

    await notifier.restoreCachedUpdate();

    expect(notifier.state.hasUpdate, isTrue);
    expect(notifier.state.latestVersion, '3.5.8');
    expect(notifier.state.forceUpdate, isFalse);
  });

  test('clears stale update state after the app has been upgraded', () async {
    final cache = UpdateCacheService();
    await cache.save(
      CachedUpdateInfo(
        platform: 'android',
        currentVersion: '3.5.7',
        latestVersion: '3.5.8',
        updateUrl: 'https://example.com/app.apk',
        releaseNotes: '',
        forceUpdate: false,
        checkedAt: DateTime.utc(2026),
      ),
    );
    await cache.markOptionalVersionPrompted('3.5.8');
    final notifier = UpdateCheckNotifier(
      updateService: _FakeUpdateService('3.5.8'),
      cacheService: cache,
    );
    addTearDown(notifier.dispose);

    await notifier.restoreCachedUpdate();

    expect(notifier.state.hasUpdate, isFalse);
    expect(await cache.load(), isNull);
    expect(await cache.getPromptedOptionalVersion(), isNull);
  });
}

class _FakeUpdateService extends UpdateService {
  _FakeUpdateService(this.version);

  final String version;

  @override
  Future<String> getCurrentVersion() async => version;

  @override
  String getPlatformName() => 'android';
}
