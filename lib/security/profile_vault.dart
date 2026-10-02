import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../common/path.dart';
import '../xboard/security/fastcat_subscription_decoder.dart';
import 'fastcat_local_cache_codec.dart';

/// Stores profiles as authenticated encrypted envelopes.
///
/// Server subscription envelopes are preserved byte-for-byte after validation.
/// Legacy/manual YAML is wrapped with the existing rotating FastCat key. A
/// previous envelope is retained so an interrupted refresh does not make the
/// profile unusable.
class ProfileVault {
  ProfileVault._();

  static final instance = ProfileVault._();

  Future<bool> exists(String profileId) async {
    await migrateLegacy(profileId);
    return File(await appPath.getProfilePath(profileId)).exists();
  }

  Future<DateTime> lastModified(String profileId) async {
    await migrateLegacy(profileId);
    return File(await appPath.getProfilePath(profileId)).lastModified();
  }

  Future<String> readText(String profileId) async {
    await migrateLegacy(profileId);
    final currentPath = await appPath.getProfilePath(profileId);
    Object? currentError;
    try {
      return await _readEnvelope(currentPath, profileId);
    } catch (error) {
      currentError = error;
    }

    final previousPath = _previousPath(currentPath);
    if (await File(previousPath).exists()) {
      try {
        final plaintext = await _readEnvelope(previousPath, profileId);
        await _restorePrevious(currentPath, previousPath);
        return plaintext;
      } catch (_) {}
    }
    throw currentError;
  }

  /// Encrypts a manual or legacy YAML profile before it reaches disk.
  Future<void> writeText(String profileId, String yaml) async {
    final envelope = FastCatLocalCacheCodec.encode(
      yaml,
      recordId: _profileRecordId(profileId),
    );
    await _atomicWrite(await appPath.getProfilePath(profileId), envelope);
  }

  /// Validates a server envelope, then persists the original encrypted value.
  Future<void> writeEncryptedEnvelope(
    String profileId,
    String envelope,
  ) async {
    FastCatSubscriptionDecoder.decode(envelope);
    await _atomicWrite(
        await appPath.getProfilePath(profileId), envelope.trim());
  }

  Future<void> delete(String profileId) async {
    final currentPath = await appPath.getProfilePath(profileId);
    for (final path in [
      currentPath,
      _previousPath(currentPath),
      _stagingPath(currentPath),
      '$currentPath.damaged',
      await appPath.getLegacyProfilePath(profileId),
    ]) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }

  /// Removes profile artifacts that no longer have a retained metadata entry.
  /// Unknown files and symbolic links are deliberately left untouched.
  Future<int> pruneOrphanedProfiles(
    Set<String> retainedProfileIds, {
    Duration? minimumOrphanAge,
  }) async {
    var removed = 0;
    final now = DateTime.now();
    final profiles = Directory(await appPath.profilesPath);
    if (await profiles.exists()) {
      await for (final entity in profiles.list(followLinks: false)) {
        if (entity is! File) continue;
        final profileId = _profileIdForManagedFile(p.basename(entity.path));
        if (profileId == null || retainedProfileIds.contains(profileId)) {
          continue;
        }
        if (await _isInsideGracePeriod(entity, minimumOrphanAge, now)) {
          continue;
        }
        await entity.delete();
        removed++;
      }

      for (final directoryName in ['providers', 'providers-secure']) {
        removed += await _pruneProfileDirectories(
          Directory(p.join(profiles.path, directoryName)),
          retainedProfileIds,
          minimumOrphanAge: minimumOrphanAge,
          now: now,
        );
      }
    }

    final temp = await appPath.tempDir.future;
    removed += await _pruneProfileDirectories(
      Directory(p.join(temp.path, 'fastcat-runtime-providers')),
      retainedProfileIds,
      minimumOrphanAge: minimumOrphanAge,
      now: now,
    );
    return removed;
  }

  /// Migrates pre-vault YAML once and leaves the original intact unless the
  /// encrypted replacement has been written and authenticated successfully.
  Future<void> migrateLegacy(String profileId) async {
    final encrypted = File(await appPath.getProfilePath(profileId));
    if (await encrypted.exists()) return;
    final legacy = File(await appPath.getLegacyProfilePath(profileId));
    if (!await legacy.exists()) return;
    final yaml = await legacy.readAsString();
    if (yaml.trim().isEmpty) return;
    await writeText(profileId, yaml);
    if (await readText(profileId) != yaml) {
      throw const FormatException('Profile migration verification failed');
    }
    await legacy.delete();
  }

  Future<void> migrateAllLegacyProfiles() async {
    final profiles = Directory(await appPath.profilesPath);
    if (!await profiles.exists()) return;
    await for (final entity in profiles.list(followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.yaml')) continue;
      try {
        await migrateLegacy(p.basenameWithoutExtension(entity.path));
      } catch (_) {
        // Leave the source untouched so a build with the right key can retry.
      }
    }
  }

  /// Restores provider snapshots only into the temporary runtime directory.
  Future<void> prepareRuntimeProviders(String profileId) async {
    await _migrateLegacyProviders(profileId);
    final runtime =
        Directory(await appPath.getRuntimeProvidersDirPath(profileId));
    if (await runtime.exists()) await runtime.delete(recursive: true);
    final secure =
        Directory(await appPath.getSecureProvidersDirPath(profileId));
    if (!await secure.exists()) return;
    await for (final entity
        in secure.list(recursive: true, followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.fcfg')) continue;
      final relativePath = p.relative(entity.path, from: secure.path);
      final runtimeRelative =
          relativePath.substring(0, relativePath.length - 5);
      final destination = File(p.join(runtime.path, runtimeRelative));
      final plaintext = FastCatLocalCacheCodec.decode(
        await entity.readAsString(),
        recordId: _providerRecordId(profileId, runtimeRelative),
      );
      await destination.parent.create(recursive: true);
      await destination.writeAsBytes(base64Decode(plaintext), flush: true);
    }
  }

  /// Encrypts provider files created by the running core before persistence.
  Future<void> snapshotRuntimeProviders(String profileId) async {
    final runtime =
        Directory(await appPath.getRuntimeProvidersDirPath(profileId));
    if (!await runtime.exists()) return;
    final secure =
        Directory(await appPath.getSecureProvidersDirPath(profileId));
    await for (final entity
        in runtime.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final relativePath = p.relative(entity.path, from: runtime.path);
      final envelope = FastCatLocalCacheCodec.encode(
        base64Encode(await entity.readAsBytes()),
        recordId: _providerRecordId(profileId, relativePath),
      );
      final destination = File(p.join(secure.path, '$relativePath.fcfg'));
      await destination.parent.create(recursive: true);
      await _atomicWrite(destination.path, envelope);
    }
  }

  Future<void> clearRuntimeProviders(String profileId) async {
    final directory =
        Directory(await appPath.getRuntimeProvidersDirPath(profileId));
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  Future<void> clearAllRuntimeProviders() async {
    final temp = await appPath.tempDir.future;
    final directory = Directory(p.join(temp.path, 'fastcat-runtime-providers'));
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  Future<void> removeProviders(String profileId) async {
    for (final directory in [
      Directory(await appPath.getProvidersDirPath(profileId)),
      Directory(await appPath.getSecureProvidersDirPath(profileId)),
      Directory(await appPath.getRuntimeProvidersDirPath(profileId)),
    ]) {
      if (await directory.exists()) await directory.delete(recursive: true);
    }
  }

  Future<String> _readEnvelope(String path, String profileId) async {
    final envelope = await File(path).readAsString();
    if (FastCatLocalCacheCodec.isLocalEnvelope(envelope)) {
      return FastCatLocalCacheCodec.decode(
        envelope,
        recordId: _profileRecordId(profileId),
      );
    }
    return FastCatSubscriptionDecoder.decode(envelope);
  }

  Future<void> _migrateLegacyProviders(String profileId) async {
    final legacy = Directory(await appPath.getProvidersDirPath(profileId));
    if (!await legacy.exists()) return;
    final secure =
        Directory(await appPath.getSecureProvidersDirPath(profileId));
    await for (final entity
        in legacy.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final relativePath = p.relative(entity.path, from: legacy.path);
      final envelope = FastCatLocalCacheCodec.encode(
        base64Encode(await entity.readAsBytes()),
        recordId: _providerRecordId(profileId, relativePath),
      );
      final destination = File(p.join(secure.path, '$relativePath.fcfg'));
      await destination.parent.create(recursive: true);
      await _atomicWrite(destination.path, envelope);
    }
    await legacy.delete(recursive: true);
  }

  Future<void> _atomicWrite(String targetPath, String content) async {
    final target = File(targetPath);
    final staging = File(_stagingPath(targetPath));
    final previous = File(_previousPath(targetPath));
    await target.parent.create(recursive: true);
    if (await staging.exists()) await staging.delete();
    await staging.writeAsString(content, flush: true);
    try {
      if (await target.exists()) {
        if (await previous.exists()) await previous.delete();
        await target.rename(previous.path);
      }
      await staging.rename(target.path);
    } catch (_) {
      if (!await target.exists() && await previous.exists()) {
        await previous.rename(target.path);
      }
      rethrow;
    }
  }

  Future<void> _restorePrevious(String currentPath, String previousPath) async {
    final current = File(currentPath);
    final previous = File(previousPath);
    final damaged = File('$currentPath.damaged');
    try {
      if (await damaged.exists()) await damaged.delete();
      if (await current.exists()) await current.rename(damaged.path);
      await previous.rename(current.path);
      if (await damaged.exists()) await damaged.delete();
    } catch (_) {
      // Reading the valid rollback already succeeded. Restoration is best effort.
    }
  }

  String _profileRecordId(String profileId) => 'profile|$profileId';

  String _providerRecordId(String profileId, String relativePath) =>
      'provider|$profileId|$relativePath';

  String? _profileIdForManagedFile(String fileName) {
    const suffixes = [
      '.fcfg.previous',
      '.fcfg.damaged',
      '.fcfg.new',
      '.fcfg',
      '.yaml',
    ];
    for (final suffix in suffixes) {
      if (fileName.endsWith(suffix) && fileName.length > suffix.length) {
        return fileName.substring(0, fileName.length - suffix.length);
      }
    }
    return null;
  }

  Future<int> _pruneProfileDirectories(
    Directory root,
    Set<String> retainedProfileIds, {
    Duration? minimumOrphanAge,
    required DateTime now,
  }) async {
    if (!await root.exists()) return 0;
    var removed = 0;
    await for (final entity in root.list(followLinks: false)) {
      if (entity is! Directory) continue;
      if (retainedProfileIds.contains(p.basename(entity.path))) continue;
      if (await _isInsideGracePeriod(entity, minimumOrphanAge, now)) continue;
      await entity.delete(recursive: true);
      removed++;
    }
    return removed;
  }

  Future<bool> _isInsideGracePeriod(
    FileSystemEntity entity,
    Duration? minimumOrphanAge,
    DateTime now,
  ) async {
    if (minimumOrphanAge == null) return false;
    try {
      final modified = (await entity.stat()).modified;
      return now.difference(modified) < minimumOrphanAge;
    } catch (_) {
      // A disappearing/unreadable orphan is harmless; let the normal delete
      // path report the actual filesystem error to the caller.
      return false;
    }
  }

  String _previousPath(String targetPath) => '$targetPath.previous';

  String _stagingPath(String targetPath) => '$targetPath.new';
}
