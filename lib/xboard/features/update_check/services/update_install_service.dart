import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import '../models/update_artifact.dart';

class InstallResult {
  const InstallResult(this.status, {this.exitRequired = false});
  final String status;
  final bool exitRequired;
}

class UpdateInstallService {
  static const channel = MethodChannel('fastcat/update');
  static Future<bool> openStore(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'apps.apple.com' ||
        uri.userInfo.isNotEmpty) {
      return false;
    }
    final native = uri.replace(scheme: 'itms-apps');
    try {
      if (await launchUrl(native, mode: LaunchMode.externalApplication)) {
        return true;
      }
    } catch (_) {
      /* Try the HTTPS store link when the native scheme is unavailable. */
    }
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // Fixed script, data passed as positional arguments. Replace only after the
  // original process has exited, on the same filesystem, retaining a rollback copy.
  static const appImageHelper = r'''#!/bin/sh
set -eu
source_file=$1
target_file=$2
old_pid=$3
attempt=0
while kill -0 "$old_pid" 2>/dev/null; do
  attempt=$((attempt + 1))
  [ "$attempt" -lt 60 ] || exit 1
  sleep 1
done
[ -f "$target_file" ] && [ ! -L "$target_file" ] || exit 1
staging_file=$(mktemp "$target_file.fastcat-new.XXXXXX")
[ ! -L "$target_file.fastcat-backup" ] || exit 1
trap 'rm -f -- "$staging_file"' EXIT
cp -- "$source_file" "$staging_file"
chmod u+x "$staging_file"
cp -p -- "$target_file" "$target_file.fastcat-backup"
mv -f -- "$staging_file" "$target_file"
"$target_file" >/dev/null 2>&1 &
''';

  /// Receipt records an attempted install, never a successful install. Only the
  /// running package version/build can confirm completion on the next launch.
  static Future<void> reconcileAndClean({Directory? directory}) async {
    final root = directory ??
        Directory(
            p.join((await getApplicationSupportDirectory()).path, 'updates'));
    if (!await root.exists()) {
      return;
    }
    final receipt = File(p.join(root.path, 'pending-install.json'));
    if (await receipt.exists()) {
      try {
        final data = jsonDecode(await receipt.readAsString()) as Map;
        final package = await PackageInfo.fromPlatform();
        final build = Platform.isAndroid
            ? await channel.invokeMethod<int>('getBuild')
            : int.tryParse(package.buildNumber);
        if (package.version == data['version'] &&
            (data['build'] == null || build == data['build'])) {
          await receipt.delete();
        }
      } catch (_) {/* A corrupt receipt never blocks application startup. */}
    }
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    await for (final entry in root.list(followLinks: false)) {
      if (entry is! File ||
          !RegExp(r'^[a-f0-9]{64}\.(apk|exe|dmg|deb|rpm|appimage)(\.part)?$')
              .hasMatch(p.basename(entry.path))) {
        continue;
      }
      if ((await entry.stat()).modified.isBefore(cutoff)) {
        await entry.delete();
      }
    }
  }

  Future<InstallResult> install(File file, UpdateArtifact artifact,
      {required String version, int? build}) async {
    if (!await file.exists() ||
        p.basename(file.path) != '${artifact.sha256}.${artifact.type}') {
      throw const FormatException('installer_missing');
    }
    if ((await sha256.bind(file.openRead()).first).toString() !=
        artifact.sha256) {
      throw const FormatException('installer_changed');
    }
    // A receipt is only acknowledged on a subsequent launch of the target version.
    await File(p.join(file.parent.path, 'pending-install.json')).writeAsString(
        jsonEncode({
          'version': version,
          'build': build,
          'file': p.basename(file.path)
        }),
        flush: true);
    if (Platform.isAndroid && artifact.type == 'apk') {
      final status = await channel.invokeMethod<String>(
          'install', {'path': file.path, 'sha256': artifact.sha256});
      return InstallResult(status ?? 'manual');
    }
    if (Platform.isWindows && artifact.type == 'exe') {
      await channel.invokeMethod<String>('install', {'path': file.path});
      return const InstallResult('installer_opened', exitRequired: true);
    }
    if (Platform.isMacOS && artifact.type == 'dmg') {
      final process = await Process.run('/usr/bin/open', [file.path]);
      if (process.exitCode != 0) {
        throw const ProcessException('open', [], 'Could not open disk image');
      }
      return const InstallResult('macos_manual');
    }
    if (Platform.isLinux &&
        ['deb', 'rpm', 'appimage'].contains(artifact.type)) {
      if (artifact.type == 'appimage') {
        final original = Platform.environment['APPIMAGE'];
        if (original != null &&
            p.isAbsolute(original) &&
            await FileSystemEntity.type(original, followLinks: false) ==
                FileSystemEntityType.file) {
          final parent = Directory(p.dirname(original));
          final probe = File(p.join(parent.path, '.fastcat-write-$pid'));
          try {
            await probe.writeAsString('');
            await probe.delete();
            final helper =
                File(p.join(file.parent.path, 'install-appimage.sh'));
            await helper.writeAsString(appImageHelper, flush: true);
            await Process.start(
                '/bin/sh', [helper.path, file.path, original, '$pid'],
                mode: ProcessStartMode.detached);
            return const InstallResult('installer_opened', exitRequired: true);
          } on FileSystemException {
            // A system-owned installation needs a normal user-driven replacement.
          }
        }
        await Process.run('xdg-open', [file.parent.path]);
        return const InstallResult('appimage_manual');
      }
      final result = await Process.run('xdg-open', [file.path]);
      if (result.exitCode != 0) {
        await Process.run('xdg-open', [file.parent.path]);
        return const InstallResult('linux_manual');
      }
      return const InstallResult('linux_manual');
    }
    throw UnsupportedError('Installer does not match this platform');
  }
}
