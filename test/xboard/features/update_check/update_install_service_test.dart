import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:fl_clash/xboard/features/update_check/models/update_artifact.dart';
import 'package:fl_clash/xboard/features/update_check/services/update_install_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('fastcat-install-test');
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });
  test('refuses a modified installer before invoking any OS installer',
      () async {
    final hash = sha256.convert([1, 2, 3]).toString();
    final file = File('${directory.path}/$hash.apk');
    await file.writeAsBytes([1, 2, 4]);
    final artifact = UpdateArtifact(
        url: 'https://example.com/app.apk', sha256: hash, type: 'apk');
    await expectLater(
        UpdateInstallService().install(file, artifact, version: '3.6.3'),
        throwsFormatException);
    expect(
        await File('${directory.path}/pending-install.json').exists(), false);
  });
  test('receipt confirms only the actual installed version and build',
      () async {
    PackageInfo.setMockInitialValues(
        appName: 'FastCat',
        packageName: 'com.fastcat.app',
        version: '3.6.3',
        buildNumber: '9',
        buildSignature: '');
    final receipt = File('${directory.path}/pending-install.json');
    await receipt.writeAsString(jsonEncode({'version': '3.6.3', 'build': 10}));
    await UpdateInstallService.reconcileAndClean(directory: directory);
    expect(await receipt.exists(), true);
    await receipt.writeAsString(jsonEncode({'version': '3.6.3', 'build': 9}));
    await UpdateInstallService.reconcileAndClean(directory: directory);
    expect(await receipt.exists(), false);
  });
  test('AppImage helper replaces atomically and retains original backup',
      () async {
    final helper = File('${directory.path}/helper.sh');
    await helper.writeAsString(UpdateInstallService.appImageHelper);
    final source = File('${directory.path}/new image');
    final target = File('${directory.path}/old image');
    await source.writeAsString('#!/bin/sh\nexit 0\n');
    await target.writeAsString('previous version');
    final process = await Process.run(
        '/bin/sh', [helper.path, source.path, target.path, '2147483647']);
    expect(process.exitCode, 0, reason: '${process.stderr}');
    expect(await target.readAsString(), await source.readAsString());
    expect(await File('${target.path}.fastcat-backup').readAsString(),
        'previous version');
  });
}
