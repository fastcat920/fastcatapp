import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

/// Repairs only missing, empty, or native-parser-rejected routing databases.
/// A valid database downloaded by the user is never replaced by a bundled copy.
class GeoAssetStore {
  GeoAssetStore({required this.loadAsset, this.onRestored});

  final Future<Uint8List> Function(String name) loadAsset;
  final void Function(String name)? onRestored;
  Future<void> _pending = Future<void>.value();

  static const _assets = {
    'geoip.metadb': 'geoip.metadb',
    'country.mmdb': 'geoip.metadb',
    'geoip.db': 'geoip.metadb',
    'asn.mmdb': 'ASN.mmdb',
    'geoip.dat': 'GeoIP.dat',
    'geosite.dat': 'GeoSite.dat',
  };

  Future<void> ensure(
    String homePath, {
    Future<String> Function()? checkGeoData,
  }) {
    final task = _pending.then((_) => _ensure(homePath, checkGeoData));
    _pending = task.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return task;
  }

  Future<void> _ensure(
    String homePath,
    Future<String> Function()? checkGeoData,
  ) async {
    if (homePath.trim().isEmpty || !p.isAbsolute(homePath)) {
      throw const FileSystemException(
          'Geo data directory must be a non-empty absolute path');
    }
    final home = Directory(homePath);
    try {
      await home.create(recursive: true);
      // Listing also checks readability before native code resolves Geo paths.
      final entries = await home.list(followLinks: false).toList();
      final names = entries.map((e) => p.basename(e.path)).toList();
      for (final asset in _assets.values.toSet()) {
        final candidates =
            names.where((name) => _assets[name.toLowerCase()] == asset);
        if (candidates.isEmpty) {
          await _restore(home, asset);
          continue;
        }
        for (final name in candidates) {
          final type = await FileSystemEntity.type(p.join(homePath, name),
              followLinks: false);
          if (type != FileSystemEntityType.file) {
            throw FileSystemException(
                'Geo data path is not a regular file', p.join(homePath, name));
          }
          if (await File(p.join(homePath, name)).length() == 0) {
            await _restore(home, name);
          }
        }
      }
      if (checkGeoData == null) return;
      final invalid = _invalidFiles(await checkGeoData());
      for (final name in invalid) {
        await _restore(home, name);
      }
      if (invalid.isNotEmpty &&
          _invalidFiles(await checkGeoData()).isNotEmpty) {
        throw const FormatException(
            'Bundled Geo data failed native validation');
      }
    } on FileSystemException catch (error) {
      throw FileSystemException(
        'Geo data directory cannot be read or repaired: ${error.message}',
        error.path ?? homePath,
        error.osError,
      );
    }
  }

  List<String> _invalidFiles(String response) {
    final result = jsonDecode(response);
    if (result is! Map ||
        result['invalid'] is! List ||
        result['error'] is! String) {
      throw const FormatException('Invalid core Geo validation response');
    }
    if ((result['error'] as String).isNotEmpty) {
      throw StateError(result['error'] as String);
    }
    final names = <String>[];
    for (final name in result['invalid'] as List) {
      if (name is! String || !_assets.containsKey(name.toLowerCase())) {
        throw const FormatException('Unknown Geo data file returned by core');
      }
      names.add(name);
    }
    return names.toSet().toList();
  }

  Future<void> _restore(Directory home, String name) async {
    final assetName = _assets[name.toLowerCase()];
    if (assetName == null) throw const FormatException('Unknown Geo data file');
    final bytes = await loadAsset(assetName);
    if (bytes.isEmpty) {
      throw FormatException('Bundled Geo data is empty: $assetName');
    }
    final staging = await home.createTemp('.fastcat-geo-');
    try {
      final file = File(p.join(staging.path, name));
      await file.writeAsBytes(bytes, flush: true);
      // Same-volume rename leaves an existing file intact if writing fails.
      await file.rename(p.join(home.path, name));
      onRestored?.call(name);
    } finally {
      await staging.delete(recursive: true);
    }
  }
}
