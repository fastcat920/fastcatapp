import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_clash/services/macos_dns_lease.dart';

void main() {
  test('maps the matching network device without truncating service names', () {
    const output =
        '(1) Wi-Fi\n(Hardware Port: Wi-Fi, Device: en0)\n(2) USB 10/100/1000 LAN\n(Hardware Port: USB LAN, Device: en7)';
    expect(macosServiceForDevice(output, 'en7'), 'USB 10/100/1000 LAN');
    expect(macosServiceForDevice(output, 'en0'), 'Wi-Fi');
    expect(macosServiceForDevice(output, 'en1'), isNull);
  });
  test('restores original services after switching physical network', () async {
    var active = 'Wi-Fi';
    final values = {
      'Wi-Fi': ['1.1.1.1'],
      'USB LAN': ['9.9.9.9']
    };
    final lease = MacosDnsLease(
        currentService: () async => active,
        read: (s) async => List.of(values[s]!),
        write: (s, v) async {
          values[s] = List.of(v);
          return true;
        });
    expect(await lease.apply(), isTrue);
    expect(await lease.apply(), isTrue);
    active = 'USB LAN';
    expect(await lease.apply(), isTrue);
    expect(await lease.restore(), isTrue);
    expect(values, {
      'Wi-Fi': ['1.1.1.1'],
      'USB LAN': ['9.9.9.9']
    });
  });
  test('does not overwrite a subsequent external DNS edit', () async {
    var values = <String>[];
    final lease = MacosDnsLease(
        currentService: () async => 'Wi-Fi',
        read: (_) async => List.of(values),
        write: (_, v) async {
          values = List.of(v);
          return true;
        });
    await lease.apply();
    values = ['8.8.8.8'];
    expect(await lease.restore(), isTrue);
    expect(values, ['8.8.8.8']);
  });
  test(
      'failed partial write stays recoverable; unknown readback is not success',
      () async {
    var values = ['1.1.1.1'];
    var readable = true;
    var writeOk = false;
    final lease = MacosDnsLease(
        currentService: () async => 'Wi-Fi',
        read: (_) async => readable ? List.of(values) : null,
        write: (_, v) async {
          values = List.of(v);
          return writeOk;
        });
    expect(await lease.apply(), isFalse);
    readable = false;
    expect(await lease.restore(), isFalse);
    readable = true;
    writeOk = true;
    expect(await lease.restore(), isTrue);
    expect(values, ['1.1.1.1']);
  });
  test('restore waits for a pending enable and restores automatic DNS',
      () async {
    var values = <String>[];
    final gate = Completer<void>();
    var first = true;
    final lease = MacosDnsLease(
        currentService: () async => 'Wi-Fi',
        read: (_) async => List.of(values),
        write: (_, v) async {
          if (first) {
            first = false;
            await gate.future;
          }
          values = List.of(v);
          return true;
        });
    final enable = lease.apply();
    final restore = lease.restore();
    await Future<void>.delayed(Duration.zero);
    gate.complete();
    expect(await enable, isTrue);
    expect(await restore, isTrue);
    expect(values, isEmpty);
  });
}
