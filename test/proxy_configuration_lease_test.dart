import 'package:flutter_test/flutter_test.dart';
import 'package:proxy/proxy_configuration_lease.dart';

void main() {
  late Map<String, String> system;
  late List<Map<String, String>> writes;
  late ProxyConfigurationLease lease;
  var failNextWrite = false;
  var readUnavailable = false;

  setUp(() {
    system = {'mode': 'auto', 'server': 'original', 'bypass': 'local'};
    writes = [];
    failNextWrite = false;
    readUnavailable = false;
    lease = ProxyConfigurationLease(
      groups: const [
        {'mode', 'server'}
      ],
      read: () async => readUnavailable ? null : Map.of(system),
      write: (values) async {
        writes.add(Map.of(values));
        for (final entry in values.entries) {
          system[entry.key] = entry.value;
          if (failNextWrite) {
            failNextWrite = false;
            return false;
          }
        }
        return true;
      },
    );
  });
  const target = {'mode': 'manual', 'server': 'ours', 'bypass': ''};

  test('unowned restore is a no-op even when the system cannot be read',
      () async {
    readUnavailable = true;
    expect(await lease.restore(), true);
    expect(writes, isEmpty);
  });

  test('repeated starts preserve the original snapshot, not the last app port',
      () async {
    expect(await lease.apply(target), true);
    expect(await lease.apply({...target, 'server': 'ours-new'}), true);
    expect(await lease.restore(), true);
    expect(system, {'mode': 'auto', 'server': 'original', 'bypass': 'local'});
  });

  test('partial writes roll back only confirmed applied properties', () async {
    failNextWrite = true;
    expect(await lease.apply(target), false);
    expect(writes, [
      {'mode': 'manual', 'server': 'ours', 'bypass': ''},
      {'mode': 'auto'}
    ]);
    expect(system, {'mode': 'auto', 'server': 'original', 'bypass': 'local'});
    expect(lease.isEmpty, true);
  });

  test(
      'failed refresh returns to the working connection, then stop restores original',
      () async {
    expect(await lease.apply(target), true);
    failNextWrite = true;
    expect(
        await lease.apply({...target, 'server': 'new-port', 'bypass': 'new'}),
        false);
    expect(system, target);
    expect(await lease.restore(), true);
    expect(system['server'], 'original');
    expect(system['mode'], 'auto');
  });

  test(
      'foreign endpoint releases its enabled mode but independent bypass is restored',
      () async {
    await lease.apply(target);
    system['server'] = 'other-app';
    expect(await lease.restore(), true);
    expect(
        system, {'mode': 'manual', 'server': 'other-app', 'bypass': 'local'});
  });

  test('unchanged settings are not adopted, even if they already match ours',
      () async {
    system = Map.of(target);
    expect(await lease.apply(target), true);
    expect(await lease.restore(), true);
    expect(writes, isEmpty);
  });

  test(
      'unavailable readback cannot report successful setup or blind restoration',
      () async {
    final originalWrite = lease.write;
    lease = ProxyConfigurationLease(
      read: () async => readUnavailable ? null : Map.of(system),
      write: (values) async {
        final result = await originalWrite(values);
        readUnavailable = true;
        return result;
      },
    );
    expect(await lease.apply(target), false);
    expect(await lease.restore(), false);
    expect(writes.length, 1);
  });
}
