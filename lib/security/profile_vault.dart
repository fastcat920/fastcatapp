import 'dart:io';

import '../common/path.dart';

/// Plaintext profile storage kept behind the existing API for compatibility.
/// Subscription payload encryption is handled before this layer; cached YAML
/// remains readable by the native Clash core and provider paths stay stable.
class ProfileVault {
  ProfileVault._();

  static final instance = ProfileVault._();

  Future<bool> exists(String profileId) async =>
      File(await appPath.getProfilePath(profileId)).exists();

  Future<DateTime> lastModified(String profileId) async =>
      File(await appPath.getProfilePath(profileId)).lastModified();

  Future<String> readText(String profileId) async =>
      File(await appPath.getProfilePath(profileId)).readAsString();

  Future<void> writeText(String profileId, String yaml) async {
    final file = File(await appPath.getProfilePath(profileId));
    await file.parent.create(recursive: true);
    await file.writeAsString(yaml, flush: true);
  }

  Future<void> delete(String profileId) async {
    final file = File(await appPath.getProfilePath(profileId));
    if (await file.exists()) await file.delete();
  }

  Future<void> migrateLegacy(String profileId) async {}

  Future<void> migrateAllLegacyProfiles() async {}

  Future<void> prepareRuntimeProviders(String profileId) async {}

  Future<void> snapshotRuntimeProviders(String profileId) async {}

  Future<void> clearRuntimeProviders(String profileId) async {}

  Future<void> clearAllRuntimeProviders() async {}

  Future<void> removeProviders(String profileId) async {
    final directory = Directory(await appPath.getProvidersDirPath(profileId));
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}
