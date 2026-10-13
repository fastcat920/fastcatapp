import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('ios/Runner/VPNManager.swift').readAsStringSync();

  test('already-running ensure waits for the configuration acknowledgement',
      () {
    final ensure = source.substring(source.indexOf('func ensureTunnelRunning'),
        source.indexOf('// MARK: - Connect / Disconnect'));
    expect(
        ensure, contains('sendConfigUpdate(config, completion: completion)'));
    expect(ensure,
        isNot(contains('if !config.isEmpty { sendConfigUpdate(config) }')));
  });

  test('running connect applies the profile before enabling traffic', () {
    final connect = source.substring(source.indexOf('func connect(config:'),
        source.indexOf('// Tunnel not running'));
    expect(connect.indexOf('sendConfigUpdate(config)'),
        lessThan(connect.indexOf('self.setTrafficMode(active: true)')));
    expect(connect, contains('guard updateError == nil else'));
    expect(connect.indexOf('self.isTrafficActive = true'),
        greaterThan(connect.indexOf('self.setTrafficMode(active: true)')));
  });

  test('missing and late native responses cannot become success', () {
    final traffic = source.substring(
        source.indexOf('private func setTrafficMode'),
        source.indexOf('// MARK: - Clash IPC'));
    expect(traffic, contains('IOSVPNIPC.isAcknowledged(response)'));
    expect(traffic, isNot(contains('response ?? ""')));
    final ipc = source.substring(source.indexOf('func sendClashMessage'),
        source.indexOf('// MARK: - Status notification'));
    expect(ipc, contains('let reply = IOSVPNReply(completion)'));
    expect(ipc, contains('method == "_updateConfig" ? 30 : 10'));
    expect(ipc, contains('asyncAfter'));
    expect(ipc, contains('reply.finish(nil)'));
    expect(ipc, isNot(contains('completion(String(data:')));
  });
}
