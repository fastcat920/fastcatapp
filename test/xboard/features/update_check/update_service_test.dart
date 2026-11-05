import 'package:fl_clash/xboard/config/models/update_info.dart';
import 'package:fl_clash/xboard/features/update_check/services/update_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final service = UpdateService();

  test('compares semantic versions without treating build numbers as releases',
      () {
    expect(service.isNewerVersion('3.5.7', '3.5.8'), isTrue);
    expect(service.isNewerVersion('3.5.8+7', '3.5.8'), isFalse);
    expect(service.isNewerVersion('v3.5.8', '3.5.9'), isTrue);
    expect(service.isNewerVersion('3.6.0', '3.5.9'), isFalse);
  });

  test('does not force a newer client to downgrade', () {
    expect(
      service.shouldForceUpdate(
        currentVersion: '3.6.0',
        latestVersion: '3.5.9',
        platformForce: true,
        minimumVersion: '3.5.8',
      ),
      isFalse,
    );
    expect(
      service.shouldForceUpdate(
        currentVersion: '3.5.7',
        latestVersion: '3.5.9',
        platformForce: false,
        minimumVersion: '3.5.8',
      ),
      isTrue,
    );
  });

  test('builds an App Store URL when only app_id is configured', () {
    final info = UpdatePlatformInfo.fromJson({
      'latest_version': '3.6.0',
      'app_id': '1234567890',
    });
    expect(info.resolvedUrl, 'https://apps.apple.com/app/id1234567890');
  });

  test('prefers the new platform schema and keeps explicit disablement', () {
    final config = UpdateRichConfig.fromJson({
      'schema_version': 2,
      'latest': {
        'ios': {
          'version': '3.5.9',
          'url': 'https://legacy.example/ios',
          'force': true,
        },
      },
      'platforms': {
        'ios': {
          'enabled': false,
          'source': 'app_store',
          'latest_version': '3.6.0',
          'min_supported_version': '3.5.8',
          'url': 'https://apps.apple.com/app/id123',
          'force': false,
        },
      },
    });

    final ios = config.platformInfo('ios');
    expect(ios?.version, '3.6.0');
    expect(ios?.enabled, isFalse);
    expect(ios?.source, 'app_store');
    expect(ios?.minSupportedVersion, '3.5.8');
  });

  test('falls back to legacy entries for platforms absent from new schema', () {
    final config = UpdateRichConfig.fromJson({
      'min_version': '3.5.8',
      'changelog': 'legacy notes',
      'latest': {
        'linux': {
          'version': '3.5.9',
          'url': 'https://example.com/linux',
          'force': true,
        },
      },
      'platforms': {
        'android': {
          'enabled': true,
          'latest_version': '3.6.0',
          'url': 'https://example.com/android',
        },
      },
    });

    expect(config.platformInfo('linux')?.version, '3.5.9');
    expect(config.localizedChangelog('linux', 'en'), 'legacy notes');
  });

  test('selects bilingual platform changelog from the active language', () {
    final config = UpdateRichConfig.fromJson({
      'platforms': {
        'android': {
          'enabled': true,
          'latest_version': '3.6.0',
          'url': 'https://example.com/android',
          'changelog': {
            'zh_CN': '修复节点加载问题',
            'en_US': 'Fixed node loading issues',
          },
        },
      },
    });

    expect(config.localizedChangelog('android', 'zh'), '修复节点加载问题');
    expect(
      config.localizedChangelog('android', 'en'),
      'Fixed node loading issues',
    );
  });
}
