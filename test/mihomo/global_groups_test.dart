import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/mihomo/providers/core_gateway_provider.dart';
import 'package:fl_clash/mihomo/application/core_gateway.dart';
import 'package:fl_clash/mihomo/domain/core_models.dart';

class _Groups extends Groups {
  @override
  onUpdate(value) {}
  void replace(List<Group> value) => state = value;
  @override
  List<Group> build() => [
        const Group(
            name: 'Proxy',
            type: GroupType.Selector,
            now: 'Japan',
            all: [
              Proxy(name: 'Japan', type: 'ss'),
              Proxy(name: 'Hong Kong', type: 'ss')
            ])
      ];
}

class _Config extends PatchClashConfig {
  @override
  onUpdate(value) {}
  @override
  ClashConfig build() => const ClashConfig(mode: Mode.rule);
}

class _Delays extends DelayDataSource {
  @override
  DelayMap build() => {};
}

class _Gateway extends Fake implements CoreGateway {
  _Gateway(this.ref);
  final Ref ref;
  @override
  List<MihomoGroup> getGroups() => ref
      .read(currentGroupsStateProvider)
      .value
      .map((g) => MihomoGroup(
          name: g.name,
          type: g.type.name,
          selected: g.now,
          nodes: g.all
              .map((p) => MihomoNode(name: p.name, type: p.type))
              .toList()))
      .toList();
}

class _Stopped extends RunTime {
  @override
  int? build() => null;
}

void main() {
  ProviderContainer create() => ProviderContainer(overrides: [
        groupsProvider.overrideWith(_Groups.new),
        patchClashConfigProvider.overrideWith(_Config.new),
        delayDataSourceProvider.overrideWith(_Delays.new),
        selectedMapProvider.overrideWith((ref) => {}),
        coreGatewayProvider.overrideWith((ref) => _Gateway(ref)),
      ]);
  test('local profile without GLOBAL keeps nodes across mode switches', () {
    final c = create();
    addTearDown(c.dispose);
    c.listen(mihomoGroupsProvider, (_, __) {});
    expect(c.read(mihomoGroupsProvider).single.name, 'Proxy');
    c
        .read(patchClashConfigProvider.notifier)
        .updateState((s) => s.copyWith(mode: Mode.global));
    final global = c.read(mihomoGroupsProvider).single;
    expect(global.name, 'GLOBAL');
    expect(global.nodes.first.name, 'Japan');
    expect(global.selected, 'Japan');
    c
        .read(patchClashConfigProvider.notifier)
        .updateState((s) => s.copyWith(mode: Mode.rule));
    expect(c.read(mihomoGroupsProvider).single.name, 'Proxy');
    c
        .read(patchClashConfigProvider.notifier)
        .updateState((s) => s.copyWith(mode: Mode.direct));
    expect(c.read(mihomoGroupsProvider), isEmpty);
  });
  test('offline synthetic GLOBAL reads the saved choice instead of old now',
      () {
    final c = ProviderContainer(overrides: [
      groupsProvider.overrideWith(_Groups.new),
      patchClashConfigProvider.overrideWith(_Config.new),
      selectedMapProvider.overrideWith((ref) => {'GLOBAL': 'Hong Kong'}),
      runTimeProvider.overrideWith(() => _Stopped()),
    ]);
    addTearDown(c.dispose);
    c.listen(getSelectedProxyNameProvider('GLOBAL'), (_, __) {});
    c
        .read(patchClashConfigProvider.notifier)
        .updateState((s) => s.copyWith(mode: Mode.global));
    expect(c.read(getSelectedProxyNameProvider('GLOBAL')), 'Hong Kong');
    c
        .read(patchClashConfigProvider.notifier)
        .updateState((s) => s.copyWith(mode: Mode.rule));
    expect(c.read(getSelectedProxyNameProvider('Proxy')), 'Japan');
  });
  test('runtime GLOBAL selection is preserved', () {
    final c = create();
    addTearDown(c.dispose);
    c.listen(currentGroupsStateProvider, (_, __) {});
    (c.read(groupsProvider.notifier) as _Groups).replace([
      ...c.read(groupsProvider),
      const Group(name: 'GLOBAL', type: GroupType.Selector, now: 'Proxy')
    ]);
    c
        .read(patchClashConfigProvider.notifier)
        .updateState((s) => s.copyWith(mode: Mode.global));
    final g = c.read(currentGroupsStateProvider).value.single;
    expect(g.name, 'GLOBAL');
    expect(g.now, 'Proxy');
    expect(g.all.first.name, 'Japan');
  });
  test('empty subscription remains empty', () {
    final c = create();
    addTearDown(c.dispose);
    c.listen(currentGroupsStateProvider, (_, __) {});
    (c.read(groupsProvider.notifier) as _Groups).replace([]);
    c
        .read(patchClashConfigProvider.notifier)
        .updateState((s) => s.copyWith(mode: Mode.global));
    expect(c.read(currentGroupsStateProvider).value, isEmpty);
  });
}
