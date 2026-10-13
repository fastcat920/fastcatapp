import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import "package:path/path.dart";

import 'proxy_platform_interface.dart';
import 'proxy_configuration_lease.dart';

enum ProxyTypes { http, https, socks }

class SystemProxyStatus {
  const SystemProxyStatus({
    required this.available,
    required this.enabled,
    required this.consistent,
    this.host,
    this.port,
    this.source,
  });

  const SystemProxyStatus.unavailable()
      : available = false,
        enabled = false,
        consistent = false,
        host = null,
        port = null,
        source = null;

  factory SystemProxyStatus.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const SystemProxyStatus.unavailable();
    return SystemProxyStatus(
      available: map['available'] == true,
      enabled: map['enabled'] == true,
      consistent: map['consistent'] != false,
      host: map['host']?.toString(),
      port: map['port'] is num ? (map['port'] as num).toInt() : null,
      source: map['source']?.toString(),
    );
  }

  final bool available;
  final bool enabled;
  final bool consistent;
  final String? host;
  final int? port;
  final String? source;

  bool matches(String expectedHost, int expectedPort) {
    return available &&
        enabled &&
        consistent &&
        host == expectedHost &&
        port == expectedPort;
  }
}

class Proxy extends ProxyPlatform {
  Proxy({
    this.onDiagnostic,
    @visibleForTesting String? operatingSystem,
    @visibleForTesting Map<String, String>? environment,
    @visibleForTesting
    Future<ProcessResult> Function(String, List<String>)? runProcess,
  })  : _operatingSystem = operatingSystem ?? Platform.operatingSystem,
        _environment = environment ?? Platform.environment,
        _runProcess = runProcess ??
            ((executable, arguments) => Process.run(executable, arguments));

  final String _operatingSystem;
  final Map<String, String> _environment;
  final Future<ProcessResult> Function(String, List<String>) _runProcess;
  final void Function(String)? onDiagnostic;
  Future<void> _pendingOperation = Future<void>.value();
  bool _macosAuthorizationNeeded = false;
  final Set<String> _authorizedMacosServices = {};
  final Map<String, ProxyConfigurationLease> _macosLeases = {};
  String? _macosRepairService;
  late final _linuxLease = ProxyConfigurationLease(
    read: _readLinuxConfiguration,
    write: _writeLinuxConfiguration,
    groups: [
      if (_isKde)
        {'ProxyType', for (final type in ProxyTypes.values) '${type.name}Proxy'}
      else
        {
          'org.gnome.system.proxy/mode',
          for (final type in ProxyTypes.values) ...[
            'org.gnome.system.proxy.${type.name}/host',
            'org.gnome.system.proxy.${type.name}/port',
          ],
        },
    ],
  );
  late final _windowsLease = ProxyConfigurationLease(
    read: () => ProxyPlatform.instance.readProxyConfiguration(),
    write: (values) async =>
        await ProxyPlatform.instance.writeProxyConfiguration(values) == true,
    groups: const [
      {'flags', 'server', 'pacUrl'}
    ],
  );
  bool _isAuthorizing = false;
  bool get isAuthorizing => _isAuthorizing;
  bool get hasAuthorizedSystemProxy => _authorizedMacosServices.isNotEmpty;

  // All callers (connect, disconnect, repair and exit) share this queue.
  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _pendingOperation.then((_) => operation());
    _pendingOperation =
        result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  void _diagnostic(String message) {
    try {
      if (onDiagnostic != null) {
        onDiagnostic!(message);
      } else {
        debugPrint(message);
      }
    } catch (_) {
      // Diagnostics must not break system proxy operations.
    }
  }

  static String url = "127.0.0.1";

  @override
  Future<bool?> startProxy(
    int port, [
    List<String> bypassDomain = const [],
  ]) =>
      _serialize(() => _startProxy(port, bypassDomain));

  Future<bool?> _startProxy(int port, List<String> bypassDomain) async {
    return switch (_operatingSystem) {
      "macos" => await _startProxyWithMacos(port, bypassDomain),
      "linux" => await _startProxyWithLinux(port, bypassDomain),
      "windows" => await _windowsLease.apply({
          'flags': '3',
          'server': '$url:$port',
          'bypass': bypassDomain.join(';'),
          'pacUrl': '',
        }),
      String() => false,
    };
  }

  @override
  Future<bool?> stopProxy() => _serialize(_stopProxy);

  Future<bool?> _stopProxy() async {
    return switch (_operatingSystem) {
      "macos" => await _stopProxyWithMacos(),
      "linux" => await _stopProxyWithLinux(),
      "windows" => await _windowsLease.restore(),
      String() => false,
    };
  }

  /// Called only after the user confirms repair. The first authorization grant
  /// is never requested by auto-connect; subsequent cleanup may reuse it.
  /// Reapply in place instead of disabling a working proxy before attempting a write.
  Future<bool> repairProxy(int port, List<String> bypassDomain) =>
      _serialize(() async {
        final started = _operatingSystem == 'macos'
            ? await _startProxyWithMacos(port, bypassDomain,
                allowAuthorization: true)
            : await _startProxy(port, bypassDomain);
        return started == true &&
            (await getSystemProxyStatus()).matches(url, port);
      });

  Future<SystemProxyStatus> getSystemProxyStatus() async {
    try {
      final data = switch (_operatingSystem) {
        "macos" => await _getMacosProxyStatus(),
        "linux" => await _getLinuxProxyStatus(),
        "windows" => await ProxyPlatform.instance.getProxyStatus(),
        String() => null,
      };
      return SystemProxyStatus.fromMap(data);
    } catch (error) {
      _diagnostic("[Proxy] read status failed: $error");
      return const SystemProxyStatus.unavailable();
    }
  }

  Future<Map<String, dynamic>> _getLinuxProxyStatus() async {
    final desktop = _environment['XDG_CURRENT_DESKTOP'];
    final isKDE = desktop?.toLowerCase().contains("kde") == true;
    if (isKDE) {
      final homeDir = _environment['HOME'];
      if (homeDir == null) return _unavailableStatus("kde");
      final configDir = join(homeDir, ".config");
      final readCommand = await _resolveLinuxCommand(
        ["kreadconfig6", "kreadconfig5"],
      );
      final proxyType =
          await _readKdeProxyValue(configDir, readCommand, "ProxyType");
      if (proxyType == null) return _unavailableStatus("kde");
      final raw = await _readKdeProxyValue(
        configDir,
        readCommand,
        "httpProxy",
      );
      final endpoint = _parseProxyEndpoint(raw);
      return {
        'available': true,
        'enabled': proxyType == "1",
        'consistent': endpoint != null || proxyType != "1",
        'host': endpoint?.$1,
        'port': endpoint?.$2,
        'source': 'kde',
      };
    }

    final mode = await _readGSettingsValue([
      "gsettings",
      "get",
      "org.gnome.system.proxy",
      "mode",
    ]);
    if (mode == null) return _unavailableStatus("gnome");
    final states = <(String?, int?)>[];
    for (final type in ProxyTypes.values) {
      final schema = "org.gnome.system.proxy.${type.name}";
      final host = await _readGSettingsValue(
        ["gsettings", "get", schema, "host"],
      );
      final port = int.tryParse(
        await _readGSettingsValue(
              ["gsettings", "get", schema, "port"],
            ) ??
            "",
      );
      states.add((host, port));
    }
    final first = states.first;
    return {
      'available': true,
      'enabled': mode == "manual",
      'consistent': states.every((item) => item == first),
      'host': first.$1,
      'port': first.$2,
      'source': 'gnome',
    };
  }

  Future<Map<String, dynamic>> _getMacosProxyStatus() async {
    final services = await _getNetworkDeviceListWithMacos();
    if (services.isEmpty) return _unavailableStatus("macos");
    final primaryService = await _getMacosPrimaryNetworkService(services);
    final service = primaryService ?? services.first;
    final states = await Future.wait([
      _getMacosProxyState("-getwebproxy", service),
      _getMacosProxyState("-getsecurewebproxy", service),
      _getMacosProxyState("-getsocksfirewallproxy", service),
    ]);
    if (states.any((state) => !state.available)) {
      return _unavailableStatus("macos:$service");
    }
    final selected = states.firstWhere(
      (state) => state.enabled,
      orElse: () => states.first,
    );
    final consistent = states.every(
      (state) =>
          state.enabled == selected.enabled &&
          (!state.enabled ||
              (state.server == selected.server && state.port == selected.port)),
    );
    return {
      'available': true,
      'enabled': states.any((state) => state.enabled),
      'consistent': consistent,
      'host': selected.server,
      'port': selected.port,
      'source': 'macos:$service',
    };
  }

  Map<String, dynamic> _unavailableStatus(String source) => {
        'available': false,
        'enabled': false,
        'consistent': false,
        'source': source,
      };

  (String, int)? _parseProxyEndpoint(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final value = raw.trim();
    final uri = Uri.tryParse(value.contains('://') ? value : 'http://$value');
    if (uri == null || uri.host.isEmpty || !uri.hasPort) return null;
    return (uri.host, uri.port);
  }

  bool get _isKde =>
      _environment['XDG_CURRENT_DESKTOP']?.toLowerCase().contains('kde') ==
      true;

  String? get _kdeConfigDirectory {
    final home = _environment['HOME'];
    return home == null ? null : join(home, '.config');
  }

  static const _absentKdeSetting = '__FASTCAT_MISSING_SETTING__';

  Future<bool> _startProxyWithLinux(int port, List<String> bypassDomain) async {
    try {
      final desired = <String, String>{};
      if (_isKde) {
        for (final type in ProxyTypes.values) {
          desired['${type.name}Proxy'] = '${type.name}://$url:$port';
        }
        desired['NoProxyFor'] = bypassDomain.join(',');
        desired['ProxyType'] = '1';
      } else {
        for (final type in ProxyTypes.values) {
          desired['org.gnome.system.proxy.${type.name}/host'] =
              _quoteGSettingsString(url);
          desired['org.gnome.system.proxy.${type.name}/port'] = '$port';
        }
        desired['org.gnome.system.proxy/ignore-hosts'] =
            _toGSettingsStringList(bypassDomain);
        desired['org.gnome.system.proxy/mode'] = "'manual'";
      }
      return await _linuxLease.apply(desired);
    } catch (error) {
      _logLinuxProxyFailure('start proxy', error);
      return false;
    }
  }

  Future<bool> _stopProxyWithLinux() => _linuxLease.restore();

  Future<Map<String, String>?> _readLinuxConfiguration() async {
    final values = <String, String>{};
    if (_isKde) {
      final directory = _kdeConfigDirectory;
      if (directory == null) return null;
      final command =
          await _resolveLinuxCommand(['kreadconfig6', 'kreadconfig5']);
      for (final key in [
        for (final type in ProxyTypes.values) '${type.name}Proxy',
        'NoProxyFor',
        'ProxyType',
      ]) {
        final value = await _readLinuxCommandText([
          command,
          '--file',
          '$directory/kioslaverc',
          '--group',
          'Proxy Settings',
          '--key',
          key,
          '--default',
          _absentKdeSetting,
        ]);
        if (value == null) return null;
        values[key] = value;
      }
    } else {
      for (final key in [
        for (final type in ProxyTypes.values) ...[
          'org.gnome.system.proxy.${type.name}/host',
          'org.gnome.system.proxy.${type.name}/port',
        ],
        'org.gnome.system.proxy/ignore-hosts',
        'org.gnome.system.proxy/mode',
      ]) {
        final parts = key.split('/');
        final value =
            await _readLinuxCommandText(['gsettings', 'get', ...parts]);
        if (value == null) return null;
        // Keep GVariant literals intact (quotes, escapes, lists) for restoration.
        values[key] = value.startsWith('uint32 ') ? value.substring(7) : value;
      }
    }
    return values;
  }

  Future<bool> _writeLinuxConfiguration(Map<String, String> values) async {
    final modeKey = _isKde ? 'ProxyType' : 'org.gnome.system.proxy/mode';
    // Switch modes last so partially installed endpoints are not activated.
    final entries = [
      ...values.entries.where((entry) => entry.key != modeKey),
      ...values.entries.where((entry) => entry.key == modeKey),
    ];
    final directory = _kdeConfigDirectory;
    final command = _isKde
        ? await _resolveLinuxCommand(['kwriteconfig6', 'kwriteconfig5'])
        : 'gsettings';
    for (final entry in entries) {
      if (_isKde && directory == null) return false;
      final arguments = _isKde
          ? [
              command,
              '--file',
              '$directory/kioslaverc',
              '--group',
              'Proxy Settings',
              '--key',
              entry.key,
              if (entry.value == _absentKdeSetting) '--delete' else entry.value,
            ]
          : [command, 'set', ...entry.key.split('/'), entry.value];
      if (!await _runLinuxCommandChecked(arguments)) return false;
    }
    return true;
  }

  Future<String?> _readGSettingsValue(List<String> command) async {
    final value = await _readLinuxCommandText(command);
    if (value == null) {
      return null;
    }
    return _normalizeLinuxSettingValue(value);
  }

  Future<String?> _readKdeProxyValue(
    String configDir,
    String readCommand,
    String key,
  ) {
    return _readLinuxCommandText([
      readCommand,
      "--file",
      "$configDir/kioslaverc",
      "--group",
      "Proxy Settings",
      "--key",
      key,
    ]);
  }

  Future<String?> _readLinuxCommandText(List<String> command) async {
    try {
      final result = await _runLinuxCommand(command);
      if (result.exitCode != 0) {
        _logLinuxProxyFailure(
          command.join(" "),
          result.stderr.toString().isEmpty ? result.stdout : result.stderr,
        );
        return null;
      }
      return result.stdout.toString().trim();
    } catch (e) {
      _logLinuxProxyFailure(command.join(" "), e);
      return null;
    }
  }

  Future<bool> _runLinuxCommandChecked(List<String> command) async {
    final result = await _runLinuxCommand(command);
    if (result.exitCode == 0) {
      return true;
    }
    _logLinuxProxyFailure(
      command.join(" "),
      result.stderr.toString().isEmpty ? result.stdout : result.stderr,
    );
    return false;
  }

  Future<ProcessResult> _runLinuxCommand(List<String> command) {
    return _runProcess(command[0], command.sublist(1));
  }

  String _normalizeLinuxSettingValue(String value) {
    var normalized = value.trim();
    if (normalized.startsWith("uint32 ")) {
      normalized = normalized.substring("uint32 ".length).trim();
    }
    if (normalized.length >= 2) {
      final first = normalized[0];
      final last = normalized[normalized.length - 1];
      if ((first == "'" && last == "'") || (first == '"' && last == '"')) {
        normalized = normalized.substring(1, normalized.length - 1);
      }
    }
    return normalized;
  }

  String _toGSettingsStringList(List<String> values) {
    return "[${values.map(_quoteGSettingsString).join(", ")}]";
  }

  String _quoteGSettingsString(String value) {
    final escaped = value.replaceAll(r"\", r"\\").replaceAll("'", r"\'");
    return "'$escaped'";
  }

  Future<String> _resolveLinuxCommand(List<String> candidates) async {
    for (final command in candidates) {
      if (await _linuxCommandExists(command)) {
        return command;
      }
    }
    return candidates.last;
  }

  Future<bool> _linuxCommandExists(String command) async {
    try {
      final result = await _runProcess("which", [command]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  void _logLinuxProxyFailure(String action, Object details) {
    debugPrint("[Proxy][Linux] $action failed: $details");
  }

  Future<bool> _startProxyWithMacos(int port, List<String> bypassDomain,
      {bool allowAuthorization = false}) async {
    try {
      final services = await _getNetworkDeviceListWithMacos();
      if (services.isEmpty) {
        _logMacosProxyFailure(
            'start proxy', 'No enabled network services found');
        return false;
      }
      final primaryService = await _getMacosPrimaryNetworkService(services);
      final orderedServices = _prioritizeMacosNetworkServices(
        services: services,
        primaryService: primaryService,
      );
      var anySuccess = false;
      var primarySuccess = false;
      for (final service in orderedServices) {
        final success = await _setMacosProxyForService(
          service: service,
          port: port,
          bypassDomain: bypassDomain,
          allowAuthorization: _authorizedMacosServices.contains(service) ||
              (allowAuthorization &&
                  service == (primaryService ?? services.first)),
        );
        anySuccess = anySuccess || success;
        if (service == primaryService) {
          primarySuccess = success;
          if (!success) return false;
        }
      }
      return primaryService == null ? anySuccess : primarySuccess;
    } catch (e) {
      _logMacosProxyFailure("start proxy", e);
      return false;
    }
  }

  Future<bool> _stopProxyWithMacos() async {
    var success = true;
    for (final entry in _macosLeases.entries.toList()) {
      success = await entry.value.restore() && success;
      if (entry.value.isEmpty) _macosLeases.remove(entry.key);
    }
    return success;
  }

  Future<List<String>> _getNetworkDeviceListWithMacos() async {
    final res = await _runNetworkSetup(["-listallnetworkservices"]);
    if (res.exitCode != 0) {
      _logMacosProxyFailure("list network services", res.stderr);
      return [];
    }
    final lines =
        res.stdout.toString().split("\n").map((line) => line.trim()).toList();
    lines.removeWhere(
        (element) => element.contains("*") || element.trim().isEmpty);
    return lines;
  }

  Future<String?> _getMacosPrimaryNetworkService(List<String> services) async {
    final routeResult =
        await _runProcess("/sbin/route", ["-n", "get", "default"]);
    if (routeResult.exitCode != 0) {
      _logMacosProxyFailure("get default route", routeResult.stderr);
      return null;
    }
    final routeOutput = routeResult.stdout.toString();
    final interfaceLine = routeOutput
        .split("\n")
        .firstWhere((line) => line.contains("interface:"), orElse: () => "");
    final interfaceName = interfaceLine.split(":").last.trim();
    if (interfaceName.isEmpty) {
      return null;
    }

    final serviceOrderResult =
        await _runNetworkSetup(["-listnetworkserviceorder"]);
    if (serviceOrderResult.exitCode != 0) {
      _logMacosProxyFailure(
        "list network service order",
        serviceOrderResult.stderr,
      );
      return null;
    }
    String? serviceName;
    // networksetup does not consistently separate service pairs by blank lines.
    for (final rawLine in serviceOrderResult.stdout.toString().split('\n')) {
      final line = rawLine.trim();
      final heading = RegExp(r'^\(\d+\)\s+(.+)$').firstMatch(line);
      if (heading != null) {
        serviceName = heading.group(1);
        continue;
      }
      final device = RegExp(r'Device:\s*([^,)\s]+)').firstMatch(line)?.group(1);
      if (device == interfaceName && services.contains(serviceName)) {
        return serviceName;
      }
    }
    return null;
  }

  List<String> _prioritizeMacosNetworkServices({
    required List<String> services,
    required String? primaryService,
  }) {
    if (primaryService == null) {
      return services;
    }
    return [
      primaryService,
      ...services.where((service) => service != primaryService),
    ];
  }

  static const _macosProxyKinds = [
    'webproxy',
    'securewebproxy',
    'socksfirewallproxy',
  ];

  Future<bool> _setMacosProxyForService({
    required String service,
    required int port,
    required List<String> bypassDomain,
    bool allowAuthorization = false,
  }) async {
    final before = await _readMacosConfiguration(service);
    if (before == null) return false;
    final automatic = List<dynamic>.from(jsonDecode(before['automatic']!));
    final desired = <String, String>{
      for (final type in _macosProxyKinds) ...{
        '$type.endpoint': jsonEncode([url, port]),
        '$type.enabled': 'on',
      },
      'bypass': jsonEncode(bypassDomain),
      'automatic': jsonEncode([automatic.first, false]),
      'discovery': 'off',
    };
    final lease = _macosLeases.putIfAbsent(
      service,
      () => ProxyConfigurationLease(
        read: () => _readMacosConfiguration(service),
        write: (values) => _writeMacosConfiguration(service, values),
        groups: [
          for (final type in _macosProxyKinds)
            {'$type.endpoint', '$type.enabled'},
        ],
      ),
    );
    _macosRepairService = allowAuthorization ? service : null;
    try {
      return await lease.apply(desired);
    } finally {
      _macosRepairService = null;
      if (lease.isEmpty) _macosLeases.remove(service);
    }
  }

  Future<Map<String, String>?> _readMacosConfiguration(String service) async {
    final result = <String, String>{};
    for (final type in _macosProxyKinds) {
      final state = await _getMacosProxyState('-get$type', service);
      if (!state.available) return null;
      // networksetup does not expose a saved proxy password. Do not replace
      // authenticated endpoints that we could not faithfully restore.
      if (state.authenticated) {
        _diagnostic(
            '[Proxy][macOS] preserving authenticated proxy for $service');
        return null;
      }
      result['$type.endpoint'] =
          jsonEncode([state.server ?? '', state.port ?? 0]);
      result['$type.enabled'] = state.enabled ? 'on' : 'off';
    }
    final bypass = await _runNetworkSetup(['-getproxybypassdomains', service]);
    final automatic = await _runNetworkSetup(['-getautoproxyurl', service]);
    final discovery =
        await _runNetworkSetup(['-getproxyautodiscovery', service]);
    if (bypass.exitCode != 0 ||
        automatic.exitCode != 0 ||
        discovery.exitCode != 0) {
      return null;
    }
    final autoText = automatic.stdout.toString();
    final autoUrl = RegExp(r'^URL:[ \t]*(.*)$', multiLine: true)
        .firstMatch(autoText)
        ?.group(1);
    final autoEnabled = RegExp(r'^Enabled:\s*(Yes|No|On|Off|1|0)\s*$',
            multiLine: true, caseSensitive: false)
        .firstMatch(autoText)
        ?.group(1)
        ?.toLowerCase();
    final discover = RegExp(r'Auto Proxy Discovery:\s*(On|Off|Yes|No)\s*$',
            caseSensitive: false)
        .firstMatch(discovery.stdout.toString().trim())
        ?.group(1)
        ?.toLowerCase();
    if (autoUrl == null || autoEnabled == null || discover == null) return null;
    final bypassText = bypass.stdout.toString().trim();
    if (bypassText.toLowerCase().startsWith('error:')) return null;
    result['bypass'] = jsonEncode(
      bypassText.isEmpty || bypassText.startsWith("There aren't any")
          ? <String>[]
          : bypassText
              .split('\n')
              .map((entry) => entry.trim())
              .where((entry) => entry.isNotEmpty)
              .toList(),
    );
    result['automatic'] = jsonEncode([
      autoUrl.trim(),
      ['yes', 'on', '1'].contains(autoEnabled)
    ]);
    result['discovery'] = ['yes', 'on'].contains(discover) ? 'on' : 'off';
    return result;
  }

  Future<bool> _writeMacosConfiguration(
      String service, Map<String, String> values) async {
    final commands = <List<String>>[];
    for (final type in _macosProxyKinds) {
      final endpoint = values['$type.endpoint'];
      var enabled = values['$type.enabled'];
      if (endpoint != null) {
        // Setting an endpoint may also enable it. If its enabled flag was
        // changed by somebody else, retain that flag rather than claiming it.
        if (enabled == null) {
          final state = await _getMacosProxyState('-get$type', service);
          if (!state.available) return false;
          enabled = state.enabled ? 'on' : 'off';
        }
        final parts = List<dynamic>.from(jsonDecode(endpoint));
        commands.add(
            ['-set$type', service, parts[0].toString(), parts[1].toString()]);
      }
      if (enabled != null) commands.add(['-set${type}state', service, enabled]);
    }
    if (values.containsKey('bypass')) {
      final bypass = List<String>.from(jsonDecode(values['bypass']!));
      commands.add([
        '-setproxybypassdomains',
        service,
        ...(bypass.isEmpty ? ['Empty'] : bypass)
      ]);
    }
    if (values.containsKey('automatic')) {
      final target = List<dynamic>.from(jsonDecode(values['automatic']!));
      final current = await _runNetworkSetup(['-getautoproxyurl', service]);
      final currentUrl = RegExp(r'^URL:[ \t]*(.*)$', multiLine: true)
          .firstMatch(current.stdout.toString())
          ?.group(1)
          ?.trim();
      // Only toggle PAC, never rewrite a PAC URL changed by another app.
      if (current.exitCode != 0 || currentUrl != target.first) return false;
      commands.add(
          ['-setautoproxystate', service, target.last == true ? 'on' : 'off']);
    }
    if (values.containsKey('discovery')) {
      commands.add(['-setproxyautodiscovery', service, values['discovery']!]);
    }
    _macosAuthorizationNeeded = false;
    for (var index = 0; index < commands.length; index++) {
      if (await _runNetworkSetupChecked(commands[index])) continue;
      if (_macosAuthorizationNeeded &&
          (_authorizedMacosServices.contains(service) ||
              _macosRepairService == service)) {
        final success =
            await _runAuthorizedMacosCommands(commands.sublist(index));
        // A partially completed authorized batch also needs privileged cleanup.
        final states = await Future.wait([
          for (final type in _macosProxyKinds)
            _getMacosProxyState('-get$type', service),
        ]);
        if (success ||
            states.any((state) =>
                state.available && state.server == url && state.enabled)) {
          _authorizedMacosServices.add(service);
        }
        return success;
      }
      return false;
    }
    return true;
  }

  Future<bool> _runAuthorizedMacosCommands(List<List<String>> commands) async {
    // Quote each shell argument, then quote the complete shell script for
    // AppleScript. Never interpolate an unescaped service name or bypass entry.
    String shellQuote(String value) => "'${value.replaceAll("'", "'\\''")}'";
    final script = commands
        .map((args) =>
            ['/usr/sbin/networksetup', ...args].map(shellQuote).join(' '))
        .join(' && ');
    final appleScript = script.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
    _diagnostic(
        '[Proxy][macOS] authorization requested for system proxy repair');
    late final ProcessResult result;
    _isAuthorizing = true;
    try {
      result = await _runProcess('/usr/bin/osascript', [
        '-e',
        'do shell script "$appleScript" with administrator privileges',
      ]);
    } finally {
      _isAuthorizing = false;
    }
    if (result.exitCode != 0) {
      _logMacosProxyFailure('authorized repair exit=${result.exitCode}',
          '${result.stderr} ${result.stdout}');
      return false;
    }
    return true;
  }

  Future<_MacosProxyState> _getMacosProxyState(
    String command,
    String service,
  ) async {
    final result = await _runNetworkSetup([command, service]);
    if (result.exitCode != 0) {
      _logMacosProxyFailure("$command $service", result.stderr);
      return const _MacosProxyState();
    }
    return _MacosProxyState.fromNetworkSetupOutput(result.stdout.toString());
  }

  Future<ProcessResult> _runNetworkSetup(List<String> arguments) {
    return _runProcess("/usr/sbin/networksetup", arguments);
  }

  Future<bool> _runNetworkSetupChecked(List<String> arguments) async {
    final result = await _runNetworkSetup(arguments);
    final output = '${result.stderr}\n${result.stdout}'.trim();
    // Some networksetup versions report authorization errors on stdout.
    final permissionError = RegExp(
      r'access denied|permission denied|not authorized|authorization denied|requires?.*(admin|root)|must be.*(admin|root)|administrator.*(access|privilege)|需要.*(管理员|权限)|权限不足',
      caseSensitive: false,
    ).hasMatch(output);
    if (result.exitCode == 0 &&
        !permissionError &&
        !RegExp(r'(^|\n)\s*\*?\*?\s*error:', caseSensitive: false)
            .hasMatch(output)) {
      return true;
    }
    _macosAuthorizationNeeded = permissionError;
    _logMacosProxyFailure(
      "networksetup ${arguments.first} exit=${result.exitCode}",
      output,
    );
    return false;
  }

  void _logMacosProxyFailure(String action, Object details) {
    final text = details.toString();
    _diagnostic(
        "[Proxy][macOS] $action failed: ${text.length > 2000 ? text.substring(0, 2000) : text}");
  }
}

class _MacosProxyState {
  final bool available;
  final bool enabled;
  final bool authenticated;
  final String? server;
  final int? port;

  const _MacosProxyState({
    this.available = false,
    this.enabled = false,
    this.authenticated = false,
    this.server,
    this.port,
  });

  factory _MacosProxyState.fromNetworkSetupOutput(String output) {
    final values = <String, String>{};
    for (final line in output.split("\n")) {
      final separatorIndex = line.indexOf(":");
      if (separatorIndex == -1) {
        continue;
      }
      values[line.substring(0, separatorIndex).trim().toLowerCase()] =
          line.substring(separatorIndex + 1).trim();
    }
    final enabledValue = values["enabled"]?.toLowerCase();
    return _MacosProxyState(
      available: values.containsKey('enabled') &&
          values.containsKey('server') &&
          values.containsKey('port'),
      enabled:
          enabledValue == "yes" || enabledValue == "on" || enabledValue == "1",
      authenticated: const ['1', 'yes', 'on'].contains(
        values['authenticated proxy enabled']?.toLowerCase(),
      ),
      server: values["server"],
      port: int.tryParse(values["port"] ?? ""),
    );
  }

  @override
  String toString() {
    return "enabled=$enabled server=$server port=$port";
  }
}
