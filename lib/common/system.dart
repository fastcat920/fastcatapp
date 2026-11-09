import 'dart:io';
import 'package:fl_clash/services/macos_dns_lease.dart';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/plugins/app.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/input.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class System {
  static System? _instance;
  late final _dnsLease = MacosDnsLease(
    currentService: getMacOSDefaultServiceName,
    read: _readMacOSDns,
    write: (service, servers) async {
      final result = await Process.run('networksetup', [
        '-setdnsservers',
        service,
        if (servers.isEmpty) 'Empty' else ...servers,
      ]);
      return result.exitCode == 0;
    },
  );

  /// Cached TV detection result (set once during init).
  bool _isTV = false;
  bool get isTV => _isTV;

  System._internal();

  factory System() {
    _instance ??= System._internal();
    return _instance!;
  }

  /// Detect Android TV at startup. Call once during app init.
  Future<void> detectTV() async {
    if (Platform.isAndroid) {
      _isTV = await app?.isTV() ?? false;
    }
  }

  @visibleForTesting
  void setTVForTesting(bool value) {
    _isTV = value;
  }

  bool get isDesktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  Future<int> get version async {
    final deviceInfo = await DeviceInfoPlugin().deviceInfo;
    return switch (Platform.operatingSystem) {
      "macos" => (deviceInfo as MacOsDeviceInfo).majorVersion,
      "android" => (deviceInfo as AndroidDeviceInfo).version.sdkInt,
      "windows" => (deviceInfo as WindowsDeviceInfo).majorVersion,
      "ios" => int.tryParse(
              (deviceInfo as IosDeviceInfo).systemVersion.split('.').first) ??
          0,
      String() => 0
    };
  }

  Future<bool> checkIsAdmin() async {
    final corePath = appPath.corePath.replaceAll(' ', '\\\\ ');
    if (Platform.isWindows) {
      final result = await windows?.checkService();
      return result == WindowsHelperServiceStatus.running;
    } else if (Platform.isMacOS) {
      final result = await Process.run('stat', ['-f', '%Su:%Sg %Sp', corePath]);
      final output = result.stdout.trim();
      if (output.startsWith('root:admin') && output.contains('rws')) {
        return true;
      }
      return false;
    } else if (Platform.isLinux) {
      final result = await Process.run('stat', ['-c', '%U:%G %A', corePath]);
      final output = result.stdout.trim();
      if (output.startsWith('root:') && output.contains('rws')) {
        return true;
      }
      return false;
    }
    return true;
  }

  Future<AuthorizeCode> authorizeCore() async {
    if (Platform.isAndroid || Platform.isIOS) {
      return AuthorizeCode.error;
    }
    final corePath = appPath.corePath.replaceAll(' ', '\\\\ ');
    final isAdmin = await checkIsAdmin();
    if (isAdmin) {
      return AuthorizeCode.none;
    }

    if (Platform.isWindows) {
      final result = await windows?.registerService();
      if (result == true) {
        return AuthorizeCode.success;
      }
      return AuthorizeCode.error;
    }

    if (Platform.isMacOS) {
      // chown/chmod 会破坏 codesign 签名，必须重新签名，否则 macOS 会 SIGTERM 杀进程
      final shell =
          'chown root:admin $corePath && chmod +sx $corePath && codesign --force --sign - $corePath';
      final arguments = [
        "-e",
        'do shell script "$shell" with administrator privileges',
      ];
      final result = await Process.run("osascript", arguments);
      if (result.exitCode != 0) {
        return AuthorizeCode.error;
      }
      return AuthorizeCode.success;
    } else if (Platform.isLinux) {
      final shell = Platform.environment['SHELL'] ?? 'bash';
      final password = await globalState.showCommonDialog<String>(
        child: InputDialog(
          title: appLocalizations.pleaseInputAdminPassword,
          value: '',
        ),
      );
      final arguments = [
        "-c",
        'echo "$password" | sudo -S chown root:root "$corePath" && echo "$password" | sudo -S chmod +sx "$corePath"'
      ];
      final result = await Process.run(shell, arguments);
      if (result.exitCode != 0) {
        return AuthorizeCode.error;
      }
      return AuthorizeCode.success;
    }
    return AuthorizeCode.error;
  }

  Future<String?> getMacOSDefaultServiceName() async {
    if (!Platform.isMacOS) {
      return null;
    }
    final result = await Process.run('route', ['-n', 'get', 'default']);
    if (result.exitCode != 0) return null;
    final device = RegExp(r'interface:\s*(\S+)')
        .firstMatch(result.stdout.toString())
        ?.group(1);
    if (device == null) return null;
    final services =
        await Process.run('networksetup', ['-listnetworkserviceorder']);
    if (services.exitCode != 0) return null;
    return macosServiceForDevice(services.stdout.toString(), device);
  }

  Future<List<String>?> _readMacOSDns(String service) async {
    final result =
        await Process.run('networksetup', ['-getdnsservers', service]);
    if (result.exitCode != 0) return null;
    final output = result.stdout.toString().trim();
    if (output.startsWith("There aren't any DNS Servers set on")) return [];
    final servers = output
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (servers.any((s) => InternetAddress.tryParse(s) == null)) return null;
    return servers;
  }

  Future<bool> setMacOSDns(bool restore) async {
    if (!Platform.isMacOS) return true;
    try {
      return await (restore ? _dnsLease.restore() : _dnsLease.apply());
    } catch (error) {
      commonPrint.log('[DNS] settings operation failed: $error');
      return false;
    }
  }

  back() async {
    await app?.moveTaskToBack();
    await window?.hide();
  }

  exit() async {
    if (Platform.isAndroid || Platform.isIOS) {
      await SystemNavigator.pop();
    }
    await window?.close();
  }
}

final system = System();
