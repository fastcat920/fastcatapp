import 'dart:io';

import 'package:flutter/foundation.dart';
import "package:path/path.dart";

import 'proxy_platform_interface.dart';

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
  static String url = "127.0.0.1";

  @override
  Future<bool?> startProxy(
    int port, [
    List<String> bypassDomain = const [],
  ]) async {
    return switch (Platform.operatingSystem) {
      "macos" => await _startProxyWithMacos(port, bypassDomain),
      "linux" => await _startProxyWithLinux(port, bypassDomain),
      "windows" => await ProxyPlatform.instance.startProxy(port, bypassDomain),
      String() => false,
    };
  }

  @override
  Future<bool?> stopProxy() async {
    return switch (Platform.operatingSystem) {
      "macos" => await _stopProxyWithMacos(),
      "linux" => await _stopProxyWithLinux(),
      "windows" => await ProxyPlatform.instance.stopProxy(),
      String() => false,
    };
  }

  Future<SystemProxyStatus> getSystemProxyStatus() async {
    try {
      final data = switch (Platform.operatingSystem) {
        "macos" => await _getMacosProxyStatus(),
        "linux" => await _getLinuxProxyStatus(),
        "windows" => await ProxyPlatform.instance.getProxyStatus(),
        String() => null,
      };
      return SystemProxyStatus.fromMap(data);
    } catch (error) {
      debugPrint("[Proxy] read status failed: $error");
      return const SystemProxyStatus.unavailable();
    }
  }

  Future<Map<String, dynamic>> _getLinuxProxyStatus() async {
    final desktop = Platform.environment['XDG_CURRENT_DESKTOP'];
    final isKDE = desktop?.toLowerCase().contains("kde") == true;
    if (isKDE) {
      final homeDir = Platform.environment['HOME'];
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

  Future<bool> _startProxyWithLinux(int port, List<String> bypassDomain) async {
    try {
      final homeDir = Platform.environment['HOME']!;
      final configDir = join(homeDir, ".config");
      final requiredCommands = List<List<String>>.empty(growable: true);
      final optionalCommands = List<List<String>>.empty(growable: true);
      final desktop = Platform.environment['XDG_CURRENT_DESKTOP'];
      final isKDE = desktop?.toLowerCase().contains("kde") == true;
      final kdeWriteCommand = isKDE
          ? await _resolveLinuxCommand(["kwriteconfig6", "kwriteconfig5"])
          : null;
      final kdeReadCommand = isKDE
          ? await _resolveLinuxCommand(["kreadconfig6", "kreadconfig5"])
          : null;
      if (isKDE) {
        requiredCommands.add(
          [
            kdeWriteCommand!,
            "--file",
            "$configDir/kioslaverc",
            "--group",
            "Proxy Settings",
            "--key",
            "ProxyType",
            "1"
          ],
        );
        optionalCommands.add(
          [
            kdeWriteCommand,
            "--file",
            "$configDir/kioslaverc",
            "--group",
            "Proxy Settings",
            "--key",
            "NoProxyFor",
            bypassDomain.join(",")
          ],
        );
      } else {
        requiredCommands.add(
          ["gsettings", "set", "org.gnome.system.proxy", "mode", "manual"],
        );
        final ignoreHosts = _toGSettingsStringList(bypassDomain);
        optionalCommands.add(
          [
            "gsettings",
            "set",
            "org.gnome.system.proxy",
            "ignore-hosts",
            ignoreHosts
          ],
        );
      }
      for (final type in ProxyTypes.values) {
        if (!isKDE) {
          requiredCommands.add(
            [
              "gsettings",
              "set",
              "org.gnome.system.proxy.${type.name}",
              "host",
              url
            ],
          );
          requiredCommands.add(
            [
              "gsettings",
              "set",
              "org.gnome.system.proxy.${type.name}",
              "port",
              "$port"
            ],
          );
        }
        if (isKDE) {
          requiredCommands.add(
            [
              kdeWriteCommand!,
              "--file",
              "$configDir/kioslaverc",
              "--group",
              "Proxy Settings",
              "--key",
              "${type.name}Proxy",
              "${type.name}://$url:$port"
            ],
          );
        }
      }
      var commandSuccess = true;
      for (final cmd in requiredCommands) {
        commandSuccess = await _runLinuxCommandChecked(cmd) && commandSuccess;
      }
      for (final cmd in optionalCommands) {
        final success = await _runLinuxCommandChecked(cmd);
        if (!success) {
          _logLinuxProxyWarning(
            "optional command",
            "ignored failure: ${cmd.join(" ")}",
          );
        }
      }
      final verified = isKDE
          ? await _verifyLinuxKdeProxy(configDir, port, kdeReadCommand!)
          : await _verifyLinuxGnomeProxy(port);
      if (verified) {
        if (!commandSuccess) {
          _logLinuxProxyWarning(
            "start proxy",
            "settings verified after command failure",
          );
        }
        return true;
      }
      return false;
    } catch (e) {
      _logLinuxProxyFailure("start proxy", e);
      return false;
    }
  }

  Future<bool> _stopProxyWithLinux() async {
    try {
      final homeDir = Platform.environment['HOME']!;
      final configDir = join(homeDir, ".config");
      final cmdList = List<List<String>>.empty(growable: true);
      final desktop = Platform.environment['XDG_CURRENT_DESKTOP'];
      final isKDE = desktop?.toLowerCase().contains("kde") == true;
      final kdeWriteCommand = isKDE
          ? await _resolveLinuxCommand(["kwriteconfig6", "kwriteconfig5"])
          : null;
      final kdeReadCommand = isKDE
          ? await _resolveLinuxCommand(["kreadconfig6", "kreadconfig5"])
          : null;
      if (isKDE) {
        cmdList.add(
          [
            kdeWriteCommand!,
            "--file",
            "$configDir/kioslaverc",
            "--group",
            "Proxy Settings",
            "--key",
            "ProxyType",
            "0"
          ],
        );
      } else {
        cmdList.add(
          ["gsettings", "set", "org.gnome.system.proxy", "mode", "none"],
        );
      }
      for (final cmd in cmdList) {
        if (!await _runLinuxCommandChecked(cmd)) {
          return false;
        }
      }
      return isKDE
          ? await _verifyLinuxKdeProxyStopped(configDir, kdeReadCommand!)
          : await _verifyLinuxGnomeProxyStopped();
    } catch (e) {
      _logLinuxProxyFailure("stop proxy", e);
      return false;
    }
  }

  Future<bool> _verifyLinuxGnomeProxy(int port) async {
    final mode = await _readGSettingsValue([
      "gsettings",
      "get",
      "org.gnome.system.proxy",
      "mode",
    ]);
    if (mode != "manual") {
      _logLinuxProxyFailure("verify GNOME mode", "mode=$mode");
      return false;
    }
    var hasMatchedProxy = false;
    for (final type in ProxyTypes.values) {
      final schema = "org.gnome.system.proxy.${type.name}";
      final host = await _readGSettingsValue([
        "gsettings",
        "get",
        schema,
        "host",
      ]);
      final portValue = await _readGSettingsValue([
        "gsettings",
        "get",
        schema,
        "port",
      ]);
      final matched = _matchesLinuxProxy(host, portValue, port);
      hasMatchedProxy = hasMatchedProxy || matched;
      if (!matched) {
        _logLinuxProxyWarning(
          "verify GNOME ${type.name}",
          "host=$host port=$portValue",
        );
      }
    }
    if (!hasMatchedProxy) {
      _logLinuxProxyFailure("verify GNOME proxy", "no matching proxy entry");
    }
    return hasMatchedProxy;
  }

  Future<bool> _verifyLinuxGnomeProxyStopped() async {
    final mode = await _readGSettingsValue([
      "gsettings",
      "get",
      "org.gnome.system.proxy",
      "mode",
    ]);
    final success = mode == "none";
    if (!success) {
      _logLinuxProxyFailure("verify GNOME stop", "mode=$mode");
    }
    return success;
  }

  Future<bool> _verifyLinuxKdeProxy(
    String configDir,
    int port,
    String readCommand,
  ) async {
    final proxyType =
        await _readKdeProxyValue(configDir, readCommand, "ProxyType");
    if (proxyType != "1") {
      _logLinuxProxyFailure("verify KDE proxy type", "ProxyType=$proxyType");
      return false;
    }
    var hasMatchedProxy = false;
    for (final type in ProxyTypes.values) {
      final key = "${type.name}Proxy";
      final value = await _readKdeProxyValue(configDir, readCommand, key);
      final expectedValue = "${type.name}://$url:$port";
      final matched = value == expectedValue;
      hasMatchedProxy = hasMatchedProxy || matched;
      if (!matched) {
        _logLinuxProxyWarning("verify KDE $key", "value=$value");
      }
    }
    if (!hasMatchedProxy) {
      _logLinuxProxyFailure("verify KDE proxy", "no matching proxy entry");
    }
    return hasMatchedProxy;
  }

  Future<bool> _verifyLinuxKdeProxyStopped(
    String configDir,
    String readCommand,
  ) async {
    final proxyType =
        await _readKdeProxyValue(configDir, readCommand, "ProxyType");
    final success = proxyType == "0";
    if (!success) {
      _logLinuxProxyFailure("verify KDE stop", "ProxyType=$proxyType");
    }
    return success;
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
    return Process.run(command[0], command.sublist(1));
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

  bool _matchesLinuxProxy(String? host, String? portValue, int port) {
    return host == url && int.tryParse(portValue ?? "") == port;
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
      final result = await Process.run("which", [command]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  void _logLinuxProxyFailure(String action, Object details) {
    debugPrint("[Proxy][Linux] $action failed: $details");
  }

  void _logLinuxProxyWarning(String action, Object details) {
    debugPrint("[Proxy][Linux] $action warning: $details");
  }

  Future<bool> _startProxyWithMacos(int port, List<String> bypassDomain) async {
    try {
      final services = await _getNetworkDeviceListWithMacos();
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
        );
        anySuccess = anySuccess || success;
        if (service == primaryService) {
          primarySuccess = success;
        }
      }
      return primaryService == null ? anySuccess : primarySuccess;
    } catch (e) {
      _logMacosProxyFailure("start proxy", e);
      return false;
    }
  }

  Future<bool> _stopProxyWithMacos() async {
    try {
      final services = await _getNetworkDeviceListWithMacos();
      final primaryService = await _getMacosPrimaryNetworkService(services);
      final orderedServices = _prioritizeMacosNetworkServices(
        services: services,
        primaryService: primaryService,
      );
      var anySuccess = false;
      var primarySuccess = false;
      for (final service in orderedServices) {
        final success = await _stopMacosProxyForService(service);
        anySuccess = anySuccess || success;
        if (service == primaryService) {
          primarySuccess = success;
        }
      }
      return primaryService == null ? anySuccess : primarySuccess;
    } catch (e) {
      _logMacosProxyFailure("stop proxy", e);
      return false;
    }
  }

  Future<List<String>> _getNetworkDeviceListWithMacos() async {
    final res = await _runNetworkSetup(["-listallnetworkservices"]);
    if (res.exitCode != 0) {
      _logMacosProxyFailure("list network services", res.stderr);
      return [];
    }
    final lines = res.stdout.toString().split("\n");
    lines.removeWhere(
        (element) => element.contains("*") || element.trim().isEmpty);
    return lines;
  }

  Future<String?> _getMacosPrimaryNetworkService(List<String> services) async {
    final routeResult = await Process.run("route", ["-n", "get", "default"]);
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
    final serviceBlock =
        serviceOrderResult.stdout.toString().split("\n\n").firstWhere(
              (block) => block.contains("Device: $interfaceName"),
              orElse: () => "",
            );
    if (serviceBlock.isEmpty) {
      return null;
    }
    final serviceNameLine = serviceBlock.split("\n").firstWhere(
        (line) => RegExp(r"^\(\d+\)\s+").hasMatch(line.trim()),
        orElse: () => "");
    final match = RegExp(r"^\(\d+\)\s+(.+)$").firstMatch(
      serviceNameLine.trim(),
    );
    final serviceName = match?.group(1);
    if (serviceName == null || !services.contains(serviceName)) {
      return null;
    }
    return serviceName;
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

  Future<bool> _setMacosProxyForService({
    required String service,
    required int port,
    required List<String> bypassDomain,
  }) async {
    final commands = <List<String>>[
      ["-setwebproxy", service, url, "$port"],
      ["-setwebproxystate", service, "on"],
      ["-setsecurewebproxy", service, url, "$port"],
      ["-setsecurewebproxystate", service, "on"],
      ["-setsocksfirewallproxy", service, url, "$port"],
      ["-setsocksfirewallproxystate", service, "on"],
      [
        "-setproxybypassdomains",
        service,
        ...(bypassDomain.isEmpty ? [""] : bypassDomain),
      ],
    ];
    for (final command in commands) {
      if (!await _runNetworkSetupChecked(command)) {
        return false;
      }
    }
    return await _verifyMacosProxyService(service, port);
  }

  Future<bool> _stopMacosProxyForService(String service) async {
    final commands = <List<String>>[
      ["-setautoproxystate", service, "off"],
      ["-setwebproxystate", service, "off"],
      ["-setsecurewebproxystate", service, "off"],
      ["-setsocksfirewallproxystate", service, "off"],
      ["-setproxybypassdomains", service, ""],
    ];
    for (final command in commands) {
      if (!await _runNetworkSetupChecked(command)) {
        return false;
      }
    }
    return await _verifyMacosProxyServiceStopped(service);
  }

  Future<bool> _verifyMacosProxyService(String service, int port) async {
    final states = await Future.wait([
      _getMacosProxyState("-getwebproxy", service),
      _getMacosProxyState("-getsecurewebproxy", service),
      _getMacosProxyState("-getsocksfirewallproxy", service),
    ]);
    final success = states.every(
      (state) => state.enabled && state.server == url && state.port == port,
    );
    if (!success) {
      _logMacosProxyFailure(
        "verify proxy for $service",
        states.map((state) => state.toString()).join("; "),
      );
    }
    return success;
  }

  Future<bool> _verifyMacosProxyServiceStopped(String service) async {
    final states = await Future.wait([
      _getMacosProxyState("-getwebproxy", service),
      _getMacosProxyState("-getsecurewebproxy", service),
      _getMacosProxyState("-getsocksfirewallproxy", service),
    ]);
    final success = states.every((state) => !state.enabled);
    if (!success) {
      _logMacosProxyFailure(
        "verify proxy stopped for $service",
        states.map((state) => state.toString()).join("; "),
      );
    }
    return success;
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
    return Process.run("/usr/sbin/networksetup", arguments);
  }

  Future<bool> _runNetworkSetupChecked(List<String> arguments) async {
    final result = await _runNetworkSetup(arguments);
    if (result.exitCode == 0) {
      return true;
    }
    _logMacosProxyFailure(
      "networksetup ${arguments.join(" ")}",
      result.stderr.toString().isEmpty ? result.stdout : result.stderr,
    );
    return false;
  }

  void _logMacosProxyFailure(String action, Object details) {
    debugPrint("[Proxy][macOS] $action failed: $details");
  }
}

class _MacosProxyState {
  final bool available;
  final bool enabled;
  final String? server;
  final int? port;

  const _MacosProxyState({
    this.available = false,
    this.enabled = false,
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
      available: values.isNotEmpty,
      enabled:
          enabledValue == "yes" || enabledValue == "on" || enabledValue == "1",
      server: values["server"],
      port: int.tryParse(values["port"] ?? ""),
    );
  }

  @override
  String toString() {
    return "enabled=$enabled server=$server port=$port";
  }
}
