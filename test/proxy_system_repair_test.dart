import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:proxy/proxy.dart';

class FakeMac {
  bool permissionDenied = false;
  bool cancelAuthorization = false;
  bool authorizedWriteWorks = true;
  bool malformedStatus = false;
  String? otherWriteError;
  String service = 'Wi-Fi';
  final states = <String, bool>{};
  final calls = <List<String>>[];
  final messages = <String>[];
  Completer<void>? holdFirstWrite;
  int authorizations = 0;
  late final proxy = Proxy(
    operatingSystem: 'macos',
    runProcess: run,
    onDiagnostic: messages.add,
  );

  Future<ProcessResult> run(String executable, List<String> args) async {
    calls.add([executable, ...args]);
    ProcessResult result(String output, {int code = 0}) =>
        ProcessResult(1, code, output, '');
    if (executable == '/sbin/route') return result('interface: en0\n');
    if (executable == '/usr/bin/osascript') {
      authorizations++;
      if (cancelAuthorization) return result('User canceled. (-128)', code: 1);
      if (authorizedWriteWorks) {
        final enabled = !args.last.contains('-setautoproxystate');
        for (final type in [
          'webproxy',
          'securewebproxy',
          'socksfirewallproxy'
        ]) {
          states['$service/$type'] = enabled;
        }
      }
      return result('');
    }
    final command = args.first;
    if (command == '-listallnetworkservices') {
      return result(
          'An asterisk (*) denotes disabled services.\nEthernet\n$service\n');
    }
    if (command == '-listnetworkserviceorder') {
      // Deliberately no blank separator; active Wi-Fi is NOT the first service.
      return result('(1) Ethernet\n(Hardware Port: Ethernet, Device: en1)\n'
          '(2) $service\n(Hardware Port: Wi-Fi, Device: en0)\n');
    }
    if (command.startsWith('-get')) {
      if (malformedStatus) return result('Error: unavailable');
      final type = command.substring(4);
      final enabled = states['${args[1]}/$type'] ?? false;
      return result('Enabled: ${enabled ? 'Yes' : 'No'}\n'
          'Server: ${enabled ? '127.0.0.1' : ''}\nPort: ${enabled ? 7890 : 0}\n');
    }
    if (holdFirstWrite != null) {
      final gate = holdFirstWrite!;
      holdFirstWrite = null;
      await gate.future;
    }
    if (otherWriteError != null) return result(otherWriteError!, code: 1);
    if (permissionDenied) {
      // Real networksetup can fail via stdout even with exit code zero.
      return result(
          'You need administrator access to run this tool... exiting!');
    }
    for (final type in ['webproxy', 'securewebproxy', 'socksfirewallproxy']) {
      if (command == '-set$type') states['${args[1]}/$type'] = true;
      if (command == '-set${type}state') {
        states['${args[1]}/$type'] = args[2] == 'on';
      }
    }
    return result('');
  }
}

void main() {
  test(
      'ordinary connect never prompts; explicit repair retries permission failure',
      () async {
    final mac = FakeMac()..permissionDenied = true;
    expect(await mac.proxy.startProxy(7890), false);
    expect(mac.authorizations, 0);
    expect(await mac.proxy.repairProxy(7890, ['localhost']), true);
    expect(mac.authorizations, 1);
    expect((await mac.proxy.getSystemProxyStatus()).source, 'macos:Wi-Fi');
    expect(mac.messages.join('\n'), contains('-setwebproxy exit=0'));
    expect(mac.messages.join('\n'), contains('administrator access'));
    expect(mac.messages.join('\n'), isNot(contains('do shell script')));
  });

  test('authorized proxy can also be disabled on disconnect', () async {
    final mac = FakeMac()..permissionDenied = true;
    expect(await mac.proxy.repairProxy(7890, []), true);
    expect(await mac.proxy.stopProxy(), true);
    expect((await mac.proxy.getSystemProxyStatus()).enabled, false);
    expect(mac.authorizations, 2);
    expect(await mac.proxy.stopProxy(), true);
    expect(mac.authorizations, 2,
        reason: 'already disabled; no new authorization prompt');
  });

  test('authorization cancellation is a failure and next repair can retry',
      () async {
    final mac = FakeMac()
      ..permissionDenied = true
      ..cancelAuthorization = true;
    expect(await mac.proxy.repairProxy(7890, []), false);
    expect(mac.proxy.isAuthorizing, false);
    expect(mac.messages.join('\n'), contains('(-128)'));
    mac.cancelAuthorization = false;
    expect(await mac.proxy.repairProxy(7890, []), true);
  });

  test('do not elevate arbitrary configuration errors', () async {
    final mac = FakeMac()..otherWriteError = 'Invalid network service';
    expect(await mac.proxy.repairProxy(7890, []), false);
    expect(mac.authorizations, 0);
  });

  test('authorization success alone is not success without state readback',
      () async {
    final mac = FakeMac()
      ..permissionDenied = true
      ..authorizedWriteWorks = false;
    expect(await mac.proxy.repairProxy(7890, []), false);
  });

  test('malformed status is unavailable, not disabled or a successful stop',
      () async {
    final mac = FakeMac()..malformedStatus = true;
    expect((await mac.proxy.getSystemProxyStatus()).available, false);
    expect(await mac.proxy.stopProxy(), false);
  });

  test('slow old stop cannot overwrite newer start', () async {
    final mac = FakeMac();
    final gate = Completer<void>();
    mac.holdFirstWrite = gate;
    final stop = mac.proxy.stopProxy();
    await Future<void>.delayed(Duration.zero);
    final start = mac.proxy.startProxy(7890);
    await Future<void>.delayed(Duration.zero);
    expect(mac.calls.where((call) => call.contains('-setwebproxy')), isEmpty);
    gate.complete();
    expect(await stop, true);
    expect(await start, true);
    expect((await mac.proxy.getSystemProxyStatus()).matches('127.0.0.1', 7890),
        true);
  });

  test('disconnect queued during repair is applied after repair', () async {
    final mac = FakeMac();
    final gate = Completer<void>();
    mac.holdFirstWrite = gate;
    final repair = mac.proxy.repairProxy(7890, []);
    await Future<void>.delayed(Duration.zero);
    final stop = mac.proxy.stopProxy();
    gate.complete();
    expect(await repair, true);
    expect(await stop, true);
    expect((await mac.proxy.getSystemProxyStatus()).enabled, false);
  });

  test('service and bypass arguments remain quoted in authorized script',
      () async {
    final mac = FakeMac()
      ..permissionDenied = true
      ..service = 'Wi-Fi "office"';
    expect(await mac.proxy.repairProxy(7890, [r"a'; echo $(id); '"]), true);
    final script =
        mac.calls.firstWhere((call) => call.first == '/usr/bin/osascript').last;
    expect(script, contains(r'Wi-Fi \"office\"'));
    expect(script, contains(r"'a'\\''; echo $(id); '\\'''"));
  });

  test('queue recovers after a thrown platform call', () async {
    var fail = true;
    final mac = FakeMac();
    final proxy = Proxy(
        operatingSystem: 'macos',
        runProcess: (exe, args) async {
          if (fail) {
            fail = false;
            throw const ProcessException('networksetup', []);
          }
          return mac.run(exe, args);
        });
    expect(await proxy.startProxy(7890), false);
    expect(await proxy.startProxy(7890), true);
  });
}
