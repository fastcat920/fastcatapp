import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:proxy/proxy.dart';
import 'package:proxy/proxy_platform_interface.dart';

class _WindowsProxy extends ProxyPlatform {
  Map<String, String> values = {
    'flags': '12', // PAC + auto-detect
    'server': 'company.invalid:8080',
    'bypass': '*.local',
    'pacUrl': 'https://company.invalid/proxy.pac',
  };
  final patches = <Map<String, String>>[];
  bool failOnce = false;

  @override
  Future<Map<String, String>?> readProxyConfiguration() async => Map.of(values);

  @override
  Future<bool?> writeProxyConfiguration(Map<String, String> patch) async {
    patches.add(Map.of(patch));
    for (final entry in patch.entries) {
      values[entry.key] = entry.value;
      if (failOnce) {
        failOnce = false;
        return false;
      }
    }
    return true;
  }
}

class _LinuxSettings {
  _LinuxSettings({this.kde = false});
  final bool kde;
  final values = <String, String>{};
  final writes = <List<String>>[];
  String? failKeyOnce;
  late final proxy = Proxy(
    operatingSystem: 'linux',
    environment: {
      'XDG_CURRENT_DESKTOP': kde ? 'KDE' : 'GNOME',
      'HOME': '/test'
    },
    runProcess: (executable, args) async {
      ProcessResult result(String output, [int code = 0]) =>
          ProcessResult(1, code, output, '');
      if (executable == 'which') return result(args.first);
      final read = executable.startsWith('kread') || args.first == 'get';
      final key =
          kde ? args[args.indexOf('--key') + 1] : '${args[1]}/${args[2]}';
      if (read) {
        return result(values[key] ??
            (kde ? args.last : throw StateError('Unknown setting $key')));
      }
      writes.add([executable, ...args]);
      if (key == failKeyOnce) {
        failKeyOnce = null;
        return result('write denied', 1);
      }
      if (args.last == '--delete') {
        values.remove(key);
      } else {
        values[key] = args.last;
      }
      return result('');
    },
  );

  void seedGnome() {
    for (final type in ['http', 'https', 'socks']) {
      values['org.gnome.system.proxy.$type/host'] = "'company.invalid'";
      values['org.gnome.system.proxy.$type/port'] = '8080';
    }
    values['org.gnome.system.proxy/mode'] = "'auto'";
    values['org.gnome.system.proxy/ignore-hosts'] =
        "['*.local', '127.0.0.0/8']";
    values['org.gnome.system.proxy/autoconfig-url'] =
        "'https://company.invalid/proxy.pac'";
  }
}

void main() {
  late ProxyPlatform previous;
  setUp(() => previous = ProxyPlatform.instance);
  tearDown(() => ProxyPlatform.instance = previous);

  test(
      'Windows preserves original proxy/PAC and repeated starts restore first snapshot',
      () async {
    final native = _WindowsProxy();
    ProxyPlatform.instance = native;
    final original = Map.of(native.values);
    final proxy = Proxy(operatingSystem: 'windows');
    expect(await proxy.stopProxy(), true);
    expect(native.patches, isEmpty);
    expect(await proxy.startProxy(7890, ['localhost']), true);
    expect(native.values['flags'], '3');
    expect(native.values['pacUrl'], '');
    expect(await proxy.startProxy(7891), true);
    expect(await proxy.stopProxy(), true);
    expect(native.values, original);
  });

  test('Windows does not disable another app that replaced its endpoint',
      () async {
    final native = _WindowsProxy();
    ProxyPlatform.instance = native;
    final proxy = Proxy(operatingSystem: 'windows');
    await proxy.startProxy(7890);
    native.values['server'] = 'another-app.invalid:8081';
    expect(await proxy.stopProxy(), true);
    expect(native.values['server'], 'another-app.invalid:8081');
    expect(native.values['flags'], '3');
    expect(native.values['bypass'], '*.local');
  });

  test('Windows rolls back a partial native write, not unmodified properties',
      () async {
    final native = _WindowsProxy()..failOnce = true;
    ProxyPlatform.instance = native;
    final original = Map.of(native.values);
    final proxy = Proxy(operatingSystem: 'windows');
    expect(await proxy.startProxy(7890), false);
    expect(native.values, original);
    expect(native.patches.last, {'flags': '12'});
  });

  test('GNOME restores exact GVariant values and leaves the PAC URL untouched',
      () async {
    final settings = _LinuxSettings()..seedGnome();
    final original = Map.of(settings.values);
    expect(await settings.proxy.stopProxy(), true);
    expect(settings.writes, isEmpty);
    expect(await settings.proxy.startProxy(7890, ['localhost']), true);
    expect(settings.values['org.gnome.system.proxy/mode'], "'manual'");
    expect(await settings.proxy.stopProxy(), true);
    expect(settings.values, original);
    expect(settings.writes.any((command) => command.contains('autoconfig-url')),
        false);
  });

  test('GNOME foreign endpoint retains its manual mode', () async {
    final settings = _LinuxSettings()..seedGnome();
    await settings.proxy.startProxy(7890);
    settings.values['org.gnome.system.proxy.http/host'] = "'other-app.invalid'";
    expect(await settings.proxy.stopProxy(), true);
    expect(settings.values['org.gnome.system.proxy.http/host'],
        "'other-app.invalid'");
    expect(settings.values['org.gnome.system.proxy/mode'], "'manual'");
  });

  test(
      'GNOME partial failure restores changed endpoints without enabling manual mode',
      () async {
    final settings = _LinuxSettings()..seedGnome();
    final original = Map.of(settings.values);
    settings.failKeyOnce = 'org.gnome.system.proxy.https/host';
    expect(await settings.proxy.startProxy(7890), false);
    expect(settings.values, original);
  });

  test('KDE removes new keys on stop and restores existing mode/bypass',
      () async {
    final settings = _LinuxSettings(kde: true);
    settings.values.addAll({'ProxyType': '2', 'NoProxyFor': '*.local'});
    final original = Map.of(settings.values);
    expect(await settings.proxy.startProxy(7890), true);
    expect(settings.values['ProxyType'], '1');
    expect(await settings.proxy.stopProxy(), true);
    expect(settings.values, original);
  });
}
