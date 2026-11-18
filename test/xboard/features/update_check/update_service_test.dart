import 'package:fl_clash/xboard/config/models/update_info.dart';
import 'package:fl_clash/xboard/features/update_check/services/update_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:ffi';
import 'package:fl_clash/xboard/features/update_check/models/update_artifact.dart';
import 'package:fl_clash/xboard/features/update_check/models/update_check_state.dart';

void main() {
  final service = UpdateService();

  test('same version build updates never downgrade a newer release', () {
    expect(service.hasNewRelease('v3.6.2', '3.6.2', 8, 9), true);
    expect(service.hasNewRelease('3.6.2', '3.6.2', 9, 9), false);
    expect(service.hasNewRelease('3.6.3', '3.6.2', 1, 99), false);
  });
  test('selects only matching architecture and validates platform type', () {
    final info = UpdatePlatformInfo.fromJson({
      'latest_version': '3.6.3',
      'build': 9,
      'artifacts': {
        'arm64': {
          'url': 'https://example.com/app.apk',
          'sha256': 'a' * 64,
          'package_type': 'apk',
          'size': 100
        }
      },
    });
    final artifact =
        info.artifactFor(UpdateArtifact.architectureKeys(Abi.androidArm64));
    expect(artifact?.isValid, true);
    expect(artifact?.supportsPlatform('android'), true);
    expect(artifact?.supportsPlatform('windows'), false);
    expect(info.artifactFor(UpdateArtifact.architectureKeys(Abi.windowsX64)),
        null);
    expect(UpdatePlatformInfo.fromJson(info.toPlatformJson()).build, 9);
  });
  test('store link rejects external hosts and credentials', () {
    expect(
        UpdatePlatformInfo.fromJson({'url': 'https://example.com/install.ipa'})
            .storeUrl,
        '');
    expect(
        UpdatePlatformInfo.fromJson(
            {'url': 'https://user@apps.apple.com/app/id123'}).storeUrl,
        '');
    expect(
        UpdatePlatformInfo.fromJson(
            {'url': 'https://example.com', 'app_id': '123'}).storeUrl,
        'https://apps.apple.com/app/id123');
  });
  test('checking state retains the artifact but a new result can clear it', () {
    const artifact =
        UpdateArtifact(url: 'https://example.com', sha256: '', type: 'apk');
    const state = UpdateCheckState(artifact: artifact);
    expect(state.copyWith(isChecking: true).artifact, artifact);
    expect(state.copyWith(artifact: null).artifact, null);
  });

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

  test('ignores legacy entries and global release notes', () {
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

    expect(config.platformInfo('linux'), isNull);
    expect(config.localizedChangelog('linux', 'en'), '');
    expect(config.toJson().containsKey('latest'), false);
    expect(config.localizedChangelog('android', 'en'), '');
  });

  test('Android phone and TV share architecture-specific installers', () {
    final config = UpdateRichConfig.fromJson({
      'platforms': {
        'android': {
          'latest_version': '3.6.3',
          'artifacts': {
            'arm64': {
              'url': 'https://example.com/v8.apk',
              'package_type': 'apk',
              'sha256': 'a' * 64
            },
            'arm': {
              'url': 'https://example.com/v7.apk',
              'package_type': 'apk',
              'sha256': 'b' * 64
            },
          },
          'changelog': {'en_US': 'Phone changes'}
        },
        'android_tv': {
          'latest_version': '3.6.3',
          'changelog': {'en_US': 'TV changes'}
        },
      }
    });
    final phone = config.platformInfo('android')!;
    final tv = config.platformInfo('android_tv')!;
    expect(phone.artifacts.keys, ['arm64', 'arm']);
    expect(tv.artifacts['arm64']?.url, phone.artifacts['arm64']?.url);
    expect(tv.artifactFor(UpdateArtifact.architectureKeys(Abi.androidArm))?.url,
        'https://example.com/v7.apk');
    expect(config.localizedChangelog('android', 'en'), 'Phone changes');
    expect(config.localizedChangelog('android_tv', 'en'), 'Phone changes');
  });

  test('every client owns its release notes without cross-platform fallback',
      () {
    final config = UpdateRichConfig.fromJson({
      'platforms': {
        for (final platform in [
          'android',
          'ios',
          'tvos',
          'windows',
          'macos',
          'linux'
        ])
          platform: {
            'latest_version': '3.6.3',
            'changelog': {'zh_CN': '$platform 更新', 'en_US': '$platform release'}
          },
      }
    });
    for (final platform in config.platforms.keys) {
      expect(config.localizedChangelog(platform, 'en'), '$platform release');
      expect(config.localizedChangelog(platform, 'zh'), '$platform 更新');
    }
    expect(config.localizedChangelog('unknown', 'en'), '');
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
