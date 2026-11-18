import 'dart:io';
import 'package:fl_clash/xboard/config/models/update_info.dart';
import 'package:fl_clash/xboard/features/update_check/services/linux_update_package_selector.dart';
import 'package:fl_clash/xboard/features/update_check/services/update_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'recognizes DEB/RPM distributions and rejects ambiguous or unsupported ones',
      () {
    for (final id in ['ubuntu', 'debian', 'linuxmint', 'deepin']) {
      expect(LinuxUpdatePackageSelector.fromOsRelease('ID=$id'), 'deb');
    }
    for (final id in ['fedora', 'rhel', 'rocky', 'opensuse-tumbleweed']) {
      expect(LinuxUpdatePackageSelector.fromOsRelease('ID=$id'), 'rpm');
    }
    expect(
        LinuxUpdatePackageSelector.fromOsRelease(
            'ID=custom\nID_LIKE="ubuntu debian"'),
        'deb');
    expect(
        LinuxUpdatePackageSelector.fromOsRelease(
            'ID=custom\nID_LIKE="fedora debian"'),
        null);
    expect(LinuxUpdatePackageSelector.fromOsRelease('ID=arch'), null);
  });
  test(
      'installed package owner takes priority over distro and process failures fall back safely',
      () async {
    final selector = LinuxUpdatePackageSelector(
        osRelease: () async => 'ID=fedora',
        run: (command, args) async => ProcessResult(
            0,
            command == 'dpkg-query' ? 0 : 1,
            command == 'dpkg-query' ? 'fastcat: /usr/bin/FastCat' : '',
            ''),
        executable: '/usr/bin/FastCat');
    expect(await selector.detect(), 'deb');
    final fallback = LinuxUpdatePackageSelector(
        osRelease: () async => 'ID=fedora',
        run: (command, args) async =>
            throw const ProcessException('missing', []));
    expect(await fallback.detect(), 'rpm');
  });
  test('ambiguous package ownership never chooses a package', () async {
    final selector = LinuxUpdatePackageSelector(
        osRelease: () async => 'ID=ubuntu',
        run: (command, args) async => ProcessResult(0, 0, 'owned', ''));
    expect(await selector.detect(), null);
  });
  final info = UpdatePlatformInfo.fromJson({
    'latest_version': '3.6.3',
    'artifacts': {
      'x64_deb': {
        'url': 'https://example.com/app.deb',
        'package_type': 'deb',
        'sha256': 'a' * 64
      },
      'x64_rpm': {
        'url': 'https://example.com/app.rpm',
        'package_type': 'rpm',
        'sha256': 'b' * 64
      },
      'arm64_deb': {
        'url': 'https://example.com/arm64.deb',
        'package_type': 'deb',
        'sha256': 'd' * 64
      },
      'arm64_rpm': {
        'url': 'https://example.com/arm64.rpm',
        'package_type': 'rpm',
        'sha256': 'e' * 64
      },
      'universal': {
        'url': 'https://example.com/Setup.exe',
        'package_type': 'exe',
        'sha256': 'c' * 64
      },
    }
  });
  test(
      'Linux x64 selects matching package type; ARM64 never uses an x64 installer',
      () async {
    for (final type in ['deb', 'rpm']) {
      final service = UpdateService(
          architectureProvider: () => ['x64', 'universal'],
          linuxPackageTypeProvider: () async => type);
      expect((await service.selectArtifact(info, 'linux'))?.type, type);
    }
    final arm = UpdateService(
        architectureProvider: () => ['arm64', 'universal'],
        linuxPackageTypeProvider: () async => 'deb');
    expect((await arm.selectArtifact(info, 'linux'))?.url,
        'https://example.com/arm64.deb');
    final unknown = UpdateService(
        architectureProvider: () => ['x64', 'universal'],
        linuxPackageTypeProvider: () async => null);
    expect(await unknown.selectArtifact(info, 'linux'), null);
  });
  test('both Windows architectures select the identical universal installer',
      () async {
    for (final architecture in ['x64', 'arm64']) {
      final service = UpdateService(
          architectureProvider: () => [architecture, 'universal']);
      expect((await service.selectArtifact(info, 'windows'))?.url,
          'https://example.com/Setup.exe');
    }
  });
}
