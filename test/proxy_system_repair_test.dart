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
  final endpoints = <String, (String, int)>{};
  final bypass = <String, List<String>>{};
  final pacUrls = <String, String>{};
  final pacEnabled = <String, bool>{};
  final discovery = <String, bool>{};
  final authenticated = <String>{};
  String? failWriteOnce;
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
        final script = args.last
            .substring('do shell script "'.length)
            .split('" with administrator privileges')
            .first
            .replaceAll(r'\"', '"')
            .replaceAll(r'\\', r'\');
        for (final command in _shellCommands(script)) {
          _write(command.sublist(1));
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
      if (command == '-getproxybypassdomains') {
        return result((bypass[args[1]] ?? []).join('\n'));
      }
      if (command == '-getautoproxyurl') {
        return result('URL: ${pacUrls[args[1]] ?? ''}\n'
            'Enabled: ${pacEnabled[args[1]] == true ? 'Yes' : 'No'}\n');
      }
      if (command == '-getproxyautodiscovery') {
        return result(
            'Auto Proxy Discovery: ${discovery[args[1]] == true ? 'On' : 'Off'}');
      }
      final type = command.substring(4);
      final enabled = states['${args[1]}/$type'] ?? false;
      final endpoint = endpoints['${args[1]}/$type'] ?? ('', 0);
      return result('Enabled: ${enabled ? 'Yes' : 'No'}\n'
          'Server: ${endpoint.$1}\nPort: ${endpoint.$2}\n'
          'Authenticated Proxy Enabled: ${authenticated.contains('${args[1]}/$type') ? 1 : 0}\n');
    }
    if (holdFirstWrite != null) {
      final gate = holdFirstWrite!;
      holdFirstWrite = null;
      await gate.future;
    }
    if (otherWriteError != null) return result(otherWriteError!, code: 1);
    if (command == failWriteOnce) {
      failWriteOnce = null;
      return result('Error: rejected', code: 1);
    }
    if (permissionDenied) {
      // Real networksetup can fail via stdout even with exit code zero.
      return result(
          'You need administrator access to run this tool... exiting!');
    }
    _write(args);
    return result('');
  }

  void _write(List<String> args) {
    for (final type in ['webproxy', 'securewebproxy', 'socksfirewallproxy']) {
      if (args.first == '-set$type') {
        endpoints['${args[1]}/$type'] = (args[2], int.parse(args[3]));
        states['${args[1]}/$type'] = true;
      }
      if (args.first == '-set${type}state') {
        states['${args[1]}/$type'] = args[2] == 'on';
      }
    }
    if (args.first == '-setproxybypassdomains') {
      bypass[args[1]] =
          args.sublist(2).where((x) => x.isNotEmpty && x != 'Empty').toList();
    }
    if (args.first == '-setautoproxystate') {
      pacEnabled[args[1]] = args[2] == 'on';
    }
    if (args.first == '-setproxyautodiscovery') {
      discovery[args[1]] = args[2] == 'on';
    }
  }
}

// Decode the quoted shell arguments generated for the fake authorization
// runner. The test never executes a shell or changes host proxy settings.
List<List<String>> _shellCommands(String script) {
  final result = <List<String>>[];
  var words = <String>[];
  var word = StringBuffer();
  var quoted = false;
  var started = false;
  void flush() {
    if (!started) return;
    final token = word.toString();
    if (token == '&&') {
      result.add(words);
      words = [];
    } else {
      words.add(token);
    }
    word = StringBuffer();
    started = false;
  }

  for (var i = 0; i < script.length; i++) {
    final c = script[i];
    if (c == "'") {
      quoted = !quoted;
      started = true;
    } else if (!quoted && c == r'\') {
      word.write(script[++i]);
      started = true;
    } else if (!quoted && c == ' ') {
      flush();
    } else {
      word.write(c);
      started = true;
    }
  }
  flush();
  if (words.isNotEmpty) result.add(words);
  return result;
}

void main() {
  test('startup stop does not touch pre-existing manual or PAC settings',
      () async {
    final mac = FakeMac();
    mac.states['Wi-Fi/webproxy'] = true;
    mac.endpoints['Wi-Fi/webproxy'] = ('company-proxy.invalid', 8080);
    mac.pacUrls['Wi-Fi'] = 'https://company.invalid/proxy.pac';
    mac.pacEnabled['Wi-Fi'] = true;
    expect(await mac.proxy.stopProxy(), true);
    expect(mac.calls, isEmpty);
    expect(mac.states['Wi-Fi/webproxy'], isTrue);
    expect(mac.pacEnabled['Wi-Fi'], isTrue);
  });

  test('normal disconnect restores manual endpoints, PAC and bypass', () async {
    final mac = FakeMac();
    mac.states['Wi-Fi/webproxy'] = true;
    mac.endpoints['Wi-Fi/webproxy'] = ('company-proxy.invalid', 8080);
    mac.bypass['Wi-Fi'] = ['*.local', 'company.invalid'];
    mac.pacUrls['Wi-Fi'] = 'https://company.invalid/proxy.pac';
    mac.pacEnabled['Wi-Fi'] = true;
    mac.discovery['Wi-Fi'] = true;
    expect(await mac.proxy.startProxy(7890, ['localhost']), true);
    expect(mac.pacEnabled['Wi-Fi'], isFalse);
    expect(await mac.proxy.stopProxy(), true);
    expect(mac.endpoints['Wi-Fi/webproxy'], ('company-proxy.invalid', 8080));
    expect(mac.states['Wi-Fi/webproxy'], isTrue);
    expect(mac.bypass['Wi-Fi'], ['*.local', 'company.invalid']);
    expect(mac.pacUrls['Wi-Fi'], 'https://company.invalid/proxy.pac');
    expect(mac.pacEnabled['Wi-Fi'], isTrue);
    expect(mac.discovery['Wi-Fi'], isTrue);
  });

  test('disconnect preserves another app endpoint and its enabled flag',
      () async {
    final mac = FakeMac();
    expect(await mac.proxy.startProxy(7890), true);
    mac.endpoints['Wi-Fi/webproxy'] = ('another-app.invalid', 8081);
    mac.bypass['Wi-Fi'] = ['other-app.invalid'];
    expect(await mac.proxy.stopProxy(), true);
    expect(mac.endpoints['Wi-Fi/webproxy'], ('another-app.invalid', 8081));
    expect(mac.states['Wi-Fi/webproxy'], isTrue);
    expect(mac.bypass['Wi-Fi'], ['other-app.invalid']);
    expect(mac.states['Wi-Fi/securewebproxy'], isFalse);
  });

  test('partial setup failure restores only settings actually applied',
      () async {
    final mac = FakeMac()..failWriteOnce = '-setsecurewebproxy';
    mac.endpoints['Wi-Fi/webproxy'] = ('previous.invalid', 8080);
    expect(await mac.proxy.startProxy(7890), false);
    expect(mac.endpoints['Wi-Fi/webproxy'], ('previous.invalid', 8080));
    expect(mac.states['Wi-Fi/webproxy'], isFalse);
    expect(mac.calls.where((call) => call.contains('-setsocksfirewallproxy')),
        isEmpty);
  });

  test('refuses authenticated endpoints whose password cannot be restored',
      () async {
    final mac = FakeMac()..authenticated.add('Wi-Fi/webproxy');
    expect(await mac.proxy.repairProxy(7890, []), false);
    expect(mac.calls.where((call) => call.any((arg) => arg.startsWith('-set'))),
        isEmpty);
    expect(mac.authorizations, 0);
  });

  test('existing localhost settings are never adopted as owned', () async {
    final mac = FakeMac();
    for (final service in ['Wi-Fi', 'Ethernet']) {
      for (final type in ['webproxy', 'securewebproxy', 'socksfirewallproxy']) {
        mac.states['$service/$type'] = true;
        mac.endpoints['$service/$type'] = ('127.0.0.1', 7890);
      }
    }
    expect(await mac.proxy.startProxy(7890), true);
    expect(await mac.proxy.stopProxy(), true);
    expect(mac.calls.where((call) => call.any((arg) => arg.startsWith('-set'))),
        isEmpty);
    expect(mac.states['Wi-Fi/webproxy'], isTrue);
  });

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

  test('malformed status is unavailable; an unowned stop needs no mutation',
      () async {
    final mac = FakeMac()..malformedStatus = true;
    expect((await mac.proxy.getSystemProxyStatus()).available, false);
    expect(await mac.proxy.stopProxy(), true);
    expect(mac.calls.where((call) => call.any((arg) => arg.startsWith('-set'))),
        isEmpty);
  });

  test('slow old stop cannot overwrite newer start', () async {
    final mac = FakeMac();
    expect(await mac.proxy.startProxy(7890), true);
    mac.calls.clear();
    final gate = Completer<void>();
    mac.holdFirstWrite = gate;
    final stop = mac.proxy.stopProxy();
    await Future<void>.delayed(Duration.zero);
    final start = mac.proxy.startProxy(7890);
    await Future<void>.delayed(Duration.zero);
    expect(
        mac.calls.where((call) =>
            call.contains('-setwebproxy') && call.contains('127.0.0.1')),
        isEmpty);
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
