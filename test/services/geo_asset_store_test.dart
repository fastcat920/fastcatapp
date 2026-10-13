import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fl_clash/clash/geo_asset_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory home;
  late List<String> restored;
  late GeoAssetStore store;
  const names = ['geoip.metadb', 'ASN.mmdb', 'GeoIP.dat', 'GeoSite.dat'];

  setUp(() async {
    home = await Directory.systemTemp.createTemp('fastcat-geo-test-');
    restored = [];
    store = GeoAssetStore(
        loadAsset: (_) async => Uint8List.fromList([1, 2, 3]),
        onRestored: restored.add);
  });
  tearDown(() async => home.delete(recursive: true));

  Future<void> seed() async {
    for (final name in names) {
      await File(p.join(home.path, name)).writeAsBytes([4, 5, 6]);
    }
  }

  String report(List<String> invalid, {String error = ''}) =>
      jsonEncode({'invalid': invalid, 'error': error});

  test('missing and empty files recover from bundled assets', () async {
    await File(p.join(home.path, 'GeoIP.dat')).writeAsBytes([]);
    await store.ensure(home.path);
    expect(restored.toSet(), names.toSet());
    for (final name in names) {
      expect(await File(p.join(home.path, name)).readAsBytes(), [1, 2, 3]);
    }
  });

  test('valid updates remain untouched on repeated checks', () async {
    await seed();
    await store.ensure(home.path, checkGeoData: () async => report([]));
    await store.ensure(home.path, checkGeoData: () async => report([]));
    expect(restored, isEmpty);
    expect(await File(p.join(home.path, names.first)).readAsBytes(), [4, 5, 6]);
  });

  test('only rejected alias is restored and revalidated', () async {
    await seed();
    await File(p.join(home.path, names.first))
        .rename(p.join(home.path, 'Country.mmdb'));
    var calls = 0;
    await store.ensure(home.path,
        checkGeoData: () async => report(calls++ == 0 ? ['Country.mmdb'] : []));
    expect(restored, ['Country.mmdb']);
    expect(calls, 2);
    expect(await File(p.join(home.path, 'geoip.metadb')).exists(), isFalse);
    expect(await File(p.join(home.path, 'GeoIP.dat')).readAsBytes(), [4, 5, 6]);
  });

  test('readability errors do not overwrite files', () async {
    await seed();
    await expectLater(
        store.ensure(home.path,
            checkGeoData: () async =>
                report([], error: 'cannot read Geo data directory')),
        throwsStateError);
    expect(restored, isEmpty);
  });

  test('untrusted response cannot target unrelated files', () async {
    await seed();
    await expectLater(
        store.ensure(home.path, checkGeoData: () async => report(['../other'])),
        throwsFormatException);
    expect(restored, isEmpty);
  });

  test('missing asset does not delete existing rejected file', () async {
    await seed();
    final brokenBundle = GeoAssetStore(loadAsset: (_) async => Uint8List(0));
    await expectLater(
        brokenBundle.ensure(home.path,
            checkGeoData: () async => report(['GeoIP.dat'])),
        throwsFormatException);
    expect(await File(p.join(home.path, 'GeoIP.dat')).readAsBytes(), [4, 5, 6]);
  });

  test('directory replaced with a file fails explicitly', () async {
    final target = File(p.join(home.path, 'blocked'));
    await target.writeAsString('not a directory');
    await expectLater(
        store.ensure(target.path), throwsA(isA<FileSystemException>()));
    expect(await target.readAsString(), 'not a directory');
  });

  test('empty or relative directories cannot target the working directory',
      () async {
    for (final path in ['', 'relative-geo-data']) {
      await expectLater(
          store.ensure(path), throwsA(isA<FileSystemException>()));
    }
    expect(restored, isEmpty);
  });
}
