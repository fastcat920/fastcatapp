import 'dart:io';

import 'package:flutter/foundation.dart';
import "package:path/path.dart";

import 'proxy_platform_interface.dart';

enum ProxyTypes { http, https, socks }

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

  Future<bool> _startProxyWithLinux(int port, List<String> bypassDomain) async {
    try {
      final homeDir = Platform.environment['HOME']!;
      final configDir = join(homeDir, ".config");
      final cmdList = List<List<String>>.empty(growable: true);
      final desktop = Platform.environment['XDG_CURRENT_DESKTOP'];
      final isKDE = desktop?.toLowerCase().contains("kde") == true;
      if (isKDE) {
        cmdList.add(
          [
            "kwriteconfig5",
            "--file",
            "$configDir/kioslaverc",
            "--group",
            "Proxy Settings",
            "--key",
            "ProxyType",
            "1"
          ],
        );
        cmdList.add(
          [
            "kwriteconfig5",
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
        cmdList.add(
          ["gsettings", "set", "org.gnome.system.proxy", "mode", "manual"],
        );
        final ignoreHosts = "\"['${bypassDomain.join("', '")}']\"";
        cmdList.add(
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
          cmdList.add(
            [
              "gsettings",
              "set",
              "org.gnome.system.proxy.${type.name}",
              "host",
              url
            ],
          );
          cmdList.add(
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
          cmdList.add(
            [
              "kwriteconfig5",
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
      for (final cmd in cmdList) {
        if (!await _runLinuxCommandChecked(cmd)) {
          return false;
        }
      }
      return isKDE
          ? await _verifyLinuxKdeProxy(configDir, port)
          : await _verifyLinuxGnomeProxy(port);
    } catch (e) {
      _logLinuxProxyFailure("start proxy", e);
      return false;
    }
  }

  Future<bool> _stopProxyWithLinux() async {
    try {
      final homeDir = Platform.environment['HOME']!;
      final configDir = join(homeDir, ".config/");
      final cmdList = List<List<String>>.empty(growable: true);
      final desktop = Platform.environment['XDG_CURRENT_DESKTOP'];
      final isKDE = desktop?.toLowerCase().contains("kde") == true;
      if (isKDE) {
        cmdList.add(
          [
            "kwriteconfig5",
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
          ? await _verifyLinuxKdeProxyStopped(configDir)
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
      if (host != url || int.tryParse(portValue ?? "") != port) {
        _logLinuxProxyFailure(
          "verify GNOME ${type.name}",
          "host=$host port=$portValue",
        );
        return false;
      }
    }
    return true;
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

  Future<bool> _verifyLinuxKdeProxy(String configDir, int port) async {
    final proxyType = await _readKdeProxyValue(configDir, "ProxyType");
    if (proxyType != "1") {
      _logLinuxProxyFailure("verify KDE proxy type", "ProxyType=$proxyType");
      return false;
    }
    for (final type in ProxyTypes.values) {
      final key = "${type.name}Proxy";
      final value = await _readKdeProxyValue(configDir, key);
      final expectedValue = "${type.name}://$url:$port";
      if (value != expectedValue) {
        _logLinuxProxyFailure("verify KDE $key", "value=$value");
        return false;
      }
    }
    return true;
  }

  Future<bool> _verifyLinuxKdeProxyStopped(String configDir) async {
    final proxyType = await _readKdeProxyValue(configDir, "ProxyType");
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

  Future<String?> _readKdeProxyValue(String configDir, String key) {
    return _readLinuxCommandText([
      "kreadconfig5",
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
    return Process.run(command[0], command.sublist(1), runInShell: true);
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

  void _logLinuxProxyFailure(String action, Object details) {
    debugPrint("[Proxy][Linux] $action failed: $details");
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
  final bool enabled;
  final String? server;
  final int? port;

  const _MacosProxyState({
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
