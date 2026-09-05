import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:pointycastle/export.dart';

import '../common/path.dart';

/// Encrypts persisted subscription profiles with a key unique to this install.
///
/// The profile delivery protocol and this vault solve different problems: the
/// former protects the server response, while this class protects the decoded
/// YAML after it has been cached on the device.
class ProfileVault {
  ProfileVault._();

  static final instance = ProfileVault._();

  static const _keyName = 'fastcat.profile-vault-key.v1';
  static const _header = 'FCATCFG1';

  final FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: const AndroidOptions(
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
    iOptions: const IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    mOptions: const MacOsOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  Future<bool> exists(String profileId) async =>
      File(await _path(profileId)).exists();

  Future<DateTime> lastModified(String profileId) async {
    await migrateLegacy(profileId);
    return File(await _path(profileId)).lastModified();
  }

  Future<String> readText(String profileId) async {
    await migrateLegacy(profileId);
    return utf8
        .decode(await _readEncryptedFile(await _path(profileId), profileId));
  }

  Future<void> writeText(String profileId, String yaml) async {
    await _writeEncryptedFile(
      await _path(profileId),
      profileId,
      Uint8List.fromList(utf8.encode(yaml)),
    );
  }

  Future<void> delete(String profileId) async {
    final encrypted = File(await _path(profileId));
    if (await encrypted.exists()) await encrypted.delete();
    // Remove a pre-vault profile left by an interrupted migration.
    final legacy = File(await appPath.getLegacyProfilePath(profileId));
    if (await legacy.exists()) await legacy.delete();
  }

  /// Migrates a pre-vault YAML file once. It is deliberately idempotent.
  Future<void> migrateLegacy(String profileId) async {
    if (await exists(profileId)) return;
    final legacy = File(await appPath.getLegacyProfilePath(profileId));
    if (!await legacy.exists()) return;
    final yaml = await legacy.readAsString();
    if (yaml.trim().isEmpty) return;
    await writeText(profileId, yaml);
    await legacy.delete();
  }

  /// Converts every legacy YAML profile after an upgrade. This runs in the
  /// background so first-frame startup is not delayed by old cache cleanup.
  Future<void> migrateAllLegacyProfiles() async {
    final profiles = Directory(await appPath.profilesPath);
    if (!await profiles.exists()) return;
    await for (final entity in profiles.list(followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.yaml')) continue;
      final name = p.basenameWithoutExtension(entity.path);
      await migrateLegacy(name);
    }
  }

  /// Restores encrypted provider snapshots into a private temporary directory
  /// for the active core process. Any previous plaintext runtime directory is
  /// cleared first, including remnants left by an unclean exit.
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
      final recordId = _providerRecordId(profileId, runtimeRelative);
      await destination.parent.create(recursive: true);
      await destination.writeAsBytes(
        await _readEncryptedFile(entity.path, recordId),
        flush: true,
      );
    }
  }

  /// Captures provider files created or updated by the running core. Plaintext
  /// runtime files remain available only until [clearRuntimeProviders].
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
      await _writeEncryptedFile(
        p.join(secure.path, '$relativePath.fcfg'),
        _providerRecordId(profileId, relativePath),
        await entity.readAsBytes(),
      );
    }
  }

  Future<void> clearRuntimeProviders(String profileId) async {
    final directory =
        Directory(await appPath.getRuntimeProvidersDirPath(profileId));
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  /// Removes plaintext provider remnants from an interrupted previous run.
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

  Future<void> _migrateLegacyProviders(String profileId) async {
    final legacy = Directory(await appPath.getProvidersDirPath(profileId));
    if (!await legacy.exists()) return;
    final secure =
        Directory(await appPath.getSecureProvidersDirPath(profileId));
    await for (final entity
        in legacy.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final relativePath = p.relative(entity.path, from: legacy.path);
      await _writeEncryptedFile(
        p.join(secure.path, '$relativePath.fcfg'),
        _providerRecordId(profileId, relativePath),
        await entity.readAsBytes(),
      );
    }
    await legacy.delete(recursive: true);
  }

  Future<String> _path(String profileId) => appPath.getProfilePath(profileId);

  Uint8List _aad(String profileId) =>
      Uint8List.fromList(utf8.encode('com.fastcat.app|$profileId|$_header'));

  String _providerRecordId(String profileId, String relativePath) =>
      'provider|$profileId|$relativePath';

  Future<void> _writeEncryptedFile(
    String path,
    String recordId,
    Uint8List bytes,
  ) async {
    final key = await _loadOrCreateKey();
    final nonce = _randomBytes(12);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(true, _parameters(key, nonce, recordId));
    final encrypted = cipher.process(bytes);
    final target = File(path);
    await target.parent.create(recursive: true);
    await target.writeAsString(
      '$_header.${base64Encode(nonce)}.${base64Encode(encrypted)}',
      flush: true,
    );
  }

  Future<Uint8List> _readEncryptedFile(String path, String recordId) async {
    final payload = await File(path).readAsString();
    final parts = payload.split('.');
    if (parts.length != 3 || parts.first != _header) {
      throw const FormatException('Unsupported encrypted profile format');
    }
    final nonce = base64Decode(parts[1]);
    if (nonce.length != 12) {
      throw const FormatException('Invalid encrypted profile nonce');
    }
    final cipher = GCMBlockCipher(AESEngine())
      ..init(false, _parameters(await _loadOrCreateKey(), nonce, recordId));
    return cipher.process(base64Decode(parts[2]));
  }

  AEADParameters _parameters(
    Uint8List key,
    Uint8List nonce,
    String profileId,
  ) =>
      AEADParameters(KeyParameter(key), 128, nonce, _aad(profileId));

  Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  Future<Uint8List> _loadOrCreateKey() async {
    final stored = await _secureStorage.read(key: _keyName);
    if (stored != null) {
      final key = base64Decode(stored);
      if (key.length == 32) return Uint8List.fromList(key);
      await _secureStorage.delete(key: _keyName);
    }
    final key = _randomBytes(32);
    await _secureStorage.write(key: _keyName, value: base64Encode(key));
    return key;
  }
}
