import 'dart:async';

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/services/proxy_selection_sync.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const choices = [
    Proxy(name: 'DIRECT', type: 'Direct'),
    Proxy(name: 'HK1', type: 'Vless'),
    Proxy(name: 'HK2', type: 'Vless'),
    Proxy(name: 'Auto', type: 'URLTest'),
  ];
  late List<Group> live;
  late List<Group> published;
  late List<String> writes;
  late ProxySelectionSync sync;
  setUp(() {
    live = [
      const Group(
          name: 'GLOBAL',
          type: GroupType.Selector,
          now: 'DIRECT',
          all: choices),
      const Group(name: 'Auto', type: GroupType.URLTest, now: 'HK1'),
      const Group(
          name: 'Bypass',
          type: GroupType.Selector,
          now: 'DIRECT',
          all: choices),
    ];
    published = [];
    writes = [];
    sync = ProxySelectionSync(
      readGroups: () async => live,
      publishGroups: (groups) => published = groups,
      writeSelection: (group, node) async {
        writes.add('$group:$node');
        live = live
            .map((g) => g.name == group ? g.copyWith(now: node) : g)
            .toList();
        return '';
      },
    );
  });

  test('GLOBAL DIRECT is changed in the core, not just in display data',
      () async {
    await sync.synchronize(saved: {}, activeGroup: 'GLOBAL');
    expect(writes, ['GLOBAL:Auto']);
    expect(live.getGroup('GLOBAL')!.now, 'Auto');
    expect(published, live);
    expect(live.getGroup('Bypass')!.now, 'DIRECT');
  });

  test('restores the explicit user node after profile reload', () async {
    await sync.synchronize(saved: {'GLOBAL': 'HK2'}, activeGroup: 'GLOBAL');
    expect(writes, ['GLOBAL:HK2']);
    await sync.synchronize(saved: {'GLOBAL': 'HK2'}, activeGroup: 'GLOBAL');
    expect(writes, ['GLOBAL:HK2']);
  });

  test('does not replace a valid live selection when saved node was removed',
      () async {
    live[0] = live[0].copyWith(now: 'HK1');
    await sync.synchronize(saved: {'GLOBAL': 'removed'}, activeGroup: 'GLOBAL');
    expect(writes, isEmpty);
    expect(published.first.now, 'HK1');
  });

  test('rejects success response unless readback confirms it', () async {
    final broken = ProxySelectionSync(
      readGroups: () async => live,
      publishGroups: (groups) => published = groups,
      writeSelection: (_, __) async => '',
    );
    await expectLater(broken.select('GLOBAL', 'HK1'), throwsStateError);
    expect(published.first.now, 'DIRECT');
  });

  test('surfaces a core rejection and publishes actual state', () async {
    final broken = ProxySelectionSync(
      readGroups: () async => live,
      publishGroups: (groups) => published = groups,
      writeSelection: (_, __) async => 'Not found group',
    );
    await expectLater(broken.select('GLOBAL', 'HK1'), throwsStateError);
    expect(published.first.now, 'DIRECT');
  });

  test('empty core state is not treated as a successful sync', () async {
    live = [];
    await expectLater(
        sync.synchronize(saved: {}, activeGroup: 'GLOBAL'), throwsStateError);
  });

  test('serializes rapid selections and keeps the last confirmed choice',
      () async {
    await Future.wait(
        [sync.select('GLOBAL', 'HK1'), sync.select('GLOBAL', 'HK2')]);
    expect(writes, ['GLOBAL:HK1', 'GLOBAL:HK2']);
    expect(published.first.now, 'HK2');
  });

  test('timeout releases queue and a later explicit retry succeeds', () async {
    var fail = true;
    final delayed = ProxySelectionSync(
      timeout: const Duration(milliseconds: 10),
      readGroups: () async => live,
      publishGroups: (groups) => published = groups,
      writeSelection: (group, node) async {
        if (fail) return Completer<String>().future;
        live[0] = live[0].copyWith(now: node);
        return '';
      },
    );
    await expectLater(
        delayed.select('GLOBAL', 'HK1'), throwsA(isA<TimeoutException>()));
    fail = false;
    await delayed.select('GLOBAL', 'HK2');
    expect(published.first.now, 'HK2');
  });
}
