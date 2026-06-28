import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class AppPath {
  static AppPath? _instance;
  Completer<Directory> dataDir = Completer();
  Completer<Directory> downloadDir = Completer();
  Completer<Directory> tempDir = Completer();
  late String appDirPath;

  AppPath._internal() {
    appDirPath = join(dirname(Platform.resolvedExecutable));
    _applicationDataDirectory().then((value) {
      dataDir.complete(value);
    });
    getTemporaryDirectory().then((value) {
      tempDir.complete(value);
    });
    getDownloadsDirectory().then((value) {
      downloadDir.complete(value);
    });
  }

  factory AppPath() {
    _instance ??= AppPath._internal();
    return _instance!;
  }

  String get executableExtension {
    return Platform.isWindows ? ".exe" : "";
  }

  String get executableDirPath {
    final currentExecutablePath = Platform.resolvedExecutable;
    return dirname(currentExecutablePath);
  }

  String get corePath {
    final coreName = Platform.isWindows ? "fastcatCore.exe" : "fastcatCore";
    return join(executableDirPath, coreName);
  }

  String get helperPath {
    return join(executableDirPath, "$appHelperService$executableExtension");
  }

  Future<String> get downloadDirPath async {
    final directory = await downloadDir.future;
    return directory.path;
  }

  Future<String> get homeDirPath async {
    final directory = await dataDir.future;
    return directory.path;
  }

  Future<String> get lockFilePath async {
    final directory = await dataDir.future;
    return join(directory.path, "fastcat.lock");
  }

  Future<String> get sharedPreferencesPath async {
    final directory = await dataDir.future;
    return join(directory.path, "shared_preferences.json");
  }

  Future<String> get profilesPath async {
    final directory = await dataDir.future;
    return join(directory.path, profilesDirectoryName);
  }

  Future<String> getProfilePath(String id) async {
    final directory = await profilesPath;
    return join(directory, "$id.yaml");
  }

  Future<String> getProvidersDirPath(String id) async {
    final directory = await profilesPath;
    return join(
      directory,
      "providers",
      id,
    );
  }

  Future<String> getProvidersFilePath(
    String id,
    String type,
    String url,
  ) async {
    final directory = await profilesPath;
    return join(
      directory,
      "providers",
      id,
      type,
      url.toMd5(),
    );
  }

  Future<String> get tempPath async {
    final directory = await tempDir.future;
    return directory.path;
  }

  Future<void> migrateLegacyDesktopData() async {
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) {
      return;
    }
    final target = await dataDir.future;
    await _migrateLegacyDesktopData(target);
  }

  Future<Directory> _applicationDataDirectory() async {
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) {
      return getApplicationSupportDirectory();
    }
    final directory = await _canonicalBrandedDesktopDataDirectory();
    if (await _consumePendingClearCacheRequest(directory)) {
      await directory.create(recursive: true);
      return directory;
    }
    await directory.create(recursive: true);
    await _migrateLegacyDesktopData(directory);
    return directory;
  }

  Future<Directory> _canonicalBrandedDesktopDataDirectory() async {
    final directory = Directory(_brandedDesktopDataPath());
    await _normalizeDesktopBrandDirectoryName(directory);
    return directory;
  }

  Future<void> _normalizeDesktopBrandDirectoryName(Directory target) async {
    final parent = target.parent;
    if (!await parent.exists()) return;

    Directory? differentCaseDirectory;
    await for (final entity in parent.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final name = basename(entity.path);
      if (name == appNameEn) return;
      if (name.toLowerCase() == appNameEn.toLowerCase()) {
        differentCaseDirectory = entity;
      }
    }
    if (differentCaseDirectory == null) return;

    final renamed = await _renameDirectoryToCanonicalName(
      source: differentCaseDirectory,
      target: target,
    );
    if (renamed) return;

    await _copyDirectoryContentsIfMissing(differentCaseDirectory, target);
  }

  Future<bool> _renameDirectoryToCanonicalName({
    required Directory source,
    required Directory target,
  }) async {
    if (source.path == target.path) return true;
    final temp = Directory(
      join(
        target.parent.path,
        '${appNameEn}_rename_${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
    try {
      final staged = await source.rename(temp.path);
      await staged.rename(target.path);
      return true;
    } catch (_) {
      try {
        if (await temp.exists()) {
          await temp.rename(source.path);
        }
      } catch (_) {}
    }
    try {
      await source.rename(target.path);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> markClearCacheOnNextStart() async {
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) {
      return;
    }
    final marker = File(_clearCacheMarkerPath);
    await marker.parent.create(recursive: true);
    await marker.writeAsString(DateTime.now().toIso8601String(), flush: true);
  }

  String _brandedDesktopDataPath() {
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      final userProfile = Platform.environment['USERPROFILE'];
      final base = appData?.isNotEmpty == true
          ? appData!
          : join(userProfile ?? Directory.current.path, 'AppData', 'Roaming');
      return join(base, appNameEn);
    }
    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? Directory.current.path;
      return join(home, 'Library', 'Application Support', appNameEn);
    }
    final xdgDataHome = Platform.environment['XDG_DATA_HOME'];
    final home = Platform.environment['HOME'] ?? Directory.current.path;
    final base = xdgDataHome?.isNotEmpty == true
        ? xdgDataHome!
        : join(home, '.local', 'share');
    return join(base, appNameEn);
  }

  Future<void> _migrateLegacyDesktopData(Directory target) async {
    final legacyDirs = _legacyDesktopDataDirectories();
    for (final legacyDir in legacyDirs) {
      if (legacyDir.path == target.path || !await legacyDir.exists()) continue;
      await _copyFileIfMissing(
        join(legacyDir.path, 'shared_preferences.json'),
        join(target.path, 'shared_preferences.json'),
      );
      await _copyDirectoryIfMissing(
        Directory(join(legacyDir.path, profilesDirectoryName)),
        Directory(join(target.path, profilesDirectoryName)),
      );
    }
    if (Platform.isMacOS) {
      await _migrateLegacyMacOSPreferencesPlist(target);
    }
  }

  Future<bool> _consumePendingClearCacheRequest(Directory target) async {
    final marker = File(_clearCacheMarkerPath);
    if (!await marker.exists()) return false;
    await _deleteCacheFilesIn(target);
    for (final legacyDir in _legacyDesktopDataDirectories()) {
      await _deleteCacheFilesIn(legacyDir);
    }
    if (Platform.isMacOS) {
      await _deleteLegacyMacOSPreferencesPlists();
    }
    try {
      await marker.delete();
    } catch (_) {
      return true;
    }
    return true;
  }

  List<Directory> _legacyDesktopDataDirectories() {
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      if (appData?.isNotEmpty != true) return [];
      return [
        Directory(join(appData!, 'com.follow', appName)),
        Directory(join(appData, 'com.follow', 'fastcat')),
        Directory(join(appData, 'fastcat')),
      ];
    }
    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? Directory.current.path;
      return [
        Directory(join(home, 'Library', 'Application Support', packageName)),
        Directory(
            join(home, 'Library', 'Application Support', 'com.core.fastcat')),
        Directory(join(home, 'Library', 'Application Support', 'fastcat')),
      ];
    }
    final xdgDataHome = Platform.environment['XDG_DATA_HOME'];
    final home = Platform.environment['HOME'] ?? Directory.current.path;
    final base = xdgDataHome?.isNotEmpty == true
        ? xdgDataHome!
        : join(home, '.local', 'share');
    return [
      Directory(join(base, packageName)),
      Directory(join(base, 'fastcat')),
    ];
  }

  Future<void> _migrateLegacyMacOSPreferencesPlist(Directory target) async {
    final home = Platform.environment['HOME'] ?? Directory.current.path;
    final candidates = [
      '$packageName.plist',
      'com.core.fastcat.plist',
    ];
    final destination = File(join(target.path, 'shared_preferences.json'));
    if (await destination.exists()) return;
    File? source;
    for (final candidate in candidates) {
      final file = File(join(home, 'Library', 'Preferences', candidate));
      if (await file.exists()) {
        source = file;
        break;
      }
    }
    if (source == null) return;
    final result = await Process.run(
      'plutil',
      ['-convert', 'json', '-o', '-', source.path],
      runInShell: false,
    );
    if (result.exitCode != 0 || result.stdout is! String) return;
    try {
      final decoded = (result.stdout as String).isEmpty
          ? <String, Object?>{}
          : Map<String, Object?>.from(jsonDecode(result.stdout as String));
      final migrated = <String, Object?>{};
      for (final entry in decoded.entries) {
        final key = entry.key.startsWith('flutter.')
            ? entry.key
            : 'flutter.${entry.key}';
        migrated[key] = entry.value;
      }
      await destination.parent.create(recursive: true);
      await destination.writeAsString(
        const JsonEncoder.withIndent('  ').convert(migrated),
        flush: true,
      );
    } catch (_) {
      return;
    }
  }

  Future<void> _deleteCacheFilesIn(Directory directory) async {
    final sharedPreferencesFile =
        File(join(directory.path, 'shared_preferences.json'));
    if (await sharedPreferencesFile.exists()) {
      await sharedPreferencesFile.delete();
    }
    final profilesDirectory =
        Directory(join(directory.path, profilesDirectoryName));
    if (await profilesDirectory.exists()) {
      await profilesDirectory.delete(recursive: true);
    }
  }

  Future<void> _deleteLegacyMacOSPreferencesPlists() async {
    final home = Platform.environment['HOME'] ?? Directory.current.path;
    final candidates = [
      '$packageName.plist',
      'com.core.fastcat.plist',
    ];
    for (final candidate in candidates) {
      final file = File(join(home, 'Library', 'Preferences', candidate));
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  String get _clearCacheMarkerPath {
    return join(Directory.systemTemp.path, '${appNameEn}_clear_cache_on_start');
  }

  Future<void> _copyFileIfMissing(String sourcePath, String targetPath) async {
    final source = File(sourcePath);
    final target = File(targetPath);
    if (!await source.exists() || await target.exists()) return;
    await target.parent.create(recursive: true);
    await source.copy(target.path);
  }

  Future<void> _copyDirectoryIfMissing(
      Directory source, Directory target) async {
    if (!await source.exists() || await target.exists()) return;
    await _copyDirectoryContentsIfMissing(source, target);
  }

  Future<void> _copyDirectoryContentsIfMissing(
      Directory source, Directory target) async {
    if (!await source.exists()) return;
    await target.create(recursive: true);
    await for (final entity
        in source.list(recursive: true, followLinks: false)) {
      final relativePath = relative(entity.path, from: source.path);
      final targetPath = join(target.path, relativePath);
      if (entity is Directory) {
        await Directory(targetPath).create(recursive: true);
      } else if (entity is File) {
        final targetFile = File(targetPath);
        if (await targetFile.exists()) continue;
        await targetFile.parent.create(recursive: true);
        await entity.copy(targetFile.path);
      }
    }
  }
}

final appPath = AppPath();
