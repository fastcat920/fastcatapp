import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/xboard/config/gateway_config.dart';
import 'package:fl_clash/xboard/config/xboard_config.dart';
import 'package:fl_clash/xboard/domain/domain.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/xboard/features/auth/services/device_heartbeat_service.dart';
import 'package:fl_clash/xboard/features/initialization/initialization.dart';
import 'package:fl_clash/xboard/features/profile/providers/profile_import_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DiagnosticBundleService {
  const DiagnosticBundleService._();

  static Future<String> build(WidgetRef ref) async {
    final buffer = StringBuffer();
    final packageInfo = globalState.packageInfo;
    final initState = ref.read(initializationProvider);
    final userState = ref.read(xboardUserProvider);
    final subscription =
        ref.read(subscriptionInfoProvider) ?? userState.subscriptionInfo;
    final importState = ref.read(profileImportProvider);
    final groups = ref.read(groupsProvider);
    final patchConfig = ref.read(patchClashConfigProvider);
    final networkProps = ref.read(networkSettingProvider);
    final overrideDns = ref.read(overrideDnsProvider);
    final realTunEnable = ref.read(realTunEnableProvider);
    final proxyState = ref.read(proxyStateProvider);
    final mode = ref.read(
      patchClashConfigProvider.select((state) => state.mode),
    );
    final helperStatus =
        Platform.isWindows ? await request.getHelperRuntimeStatus() : null;
    final gatewayRuntime = GatewayRuntimeService.instance;
    gatewayRuntime.syncFromCurrentConfig();
    final activeGateway = gatewayRuntime.activeConfig;
    final logs = globalState.appState.logs.list.reversed.take(30).toList();

    buffer
      ..writeln('Fastcat Diagnostic Bundle')
      ..writeln('Generated: ${_fmt(DateTime.now())}')
      ..writeln('')
      ..writeln('[App]')
      ..writeln('Name: ${packageInfo.appName}')
      ..writeln('Package: ${packageInfo.packageName}')
      ..writeln('Version: ${packageInfo.version}+${packageInfo.buildNumber}')
      ..writeln(
          'Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}')
      ..writeln('UA: ${globalState.ua}')
      ..writeln('')
      ..writeln('[Runtime]')
      ..writeln('Mode: ${mode.name}')
      ..writeln('Connected: ${globalState.appState.runTime != null}')
      ..writeln('Groups: ${groups.length}')
      ..writeln('Nodes: ${_countNodes(groups)}')
      ..writeln('Importing subscription: ${importState.isImporting}')
      ..writeln(
          'Switch stage: ${globalState.coreSwitchStatusNotifier.value.label}')
      ..writeln('')
      ..writeln('[Core/TUN]')
      ..writeln('Core connected: ${globalState.appState.runTime != null}')
      ..writeln('Configured TUN: ${patchConfig.tun.enable}')
      ..writeln('Real TUN: $realTunEnable')
      ..writeln('TUN stack: ${patchConfig.tun.stack.name}')
      ..writeln('Route mode: ${networkProps.routeMode.name}')
      ..writeln('')
      ..writeln('[DNS/System Proxy]')
      ..writeln('Override DNS: $overrideDns')
      ..writeln('Auto set system DNS: ${networkProps.autoSetSystemDns}')
      ..writeln('System proxy enabled: ${networkProps.systemProxy}')
      ..writeln('System proxy running: ${proxyState.isStart}')
      ..writeln('System proxy port: ${proxyState.port}')
      ..writeln('')
      ..writeln('[Windows Helper]')
      ..writeln('Available: ${helperStatus?.tokenMatches == true}')
      ..writeln('Version: ${helperStatus?.version ?? '-'}')
      ..writeln(
          'Helper path: ${SensitiveMasker.maskText(helperStatus?.helperPath ?? '-')}')
      ..writeln(
          'Service path matches: ${helperStatus?.servicePathMatches ?? '-'}')
      ..writeln('Core running: ${helperStatus?.coreRunning ?? '-'}')
      ..writeln('Core pid: ${helperStatus?.corePid ?? '-'}')
      ..writeln(
          'Recent stderr: ${helperStatus?.recentLogs.take(3).join(' | ') ?? '-'}')
      ..writeln('')
      ..writeln('[Initialization]')
      ..writeln('Status: ${initState.status.name}')
      ..writeln('Domain: ${_maskEndpoint(initState.currentDomain)}')
      ..writeln('Step: ${initState.currentStepDescription ?? '-'}')
      ..writeln(
          'Error: ${SensitiveMasker.maskText(initState.errorMessage ?? '-')}')
      ..writeln('')
      ..writeln('[Gateway]')
      ..writeln(
          'Active: ${activeGateway == null ? '-' : '${gatewayDisplayLabel(activeGateway.baseUrl)}${activeGateway.apiPrefix}'}')
      ..writeln(
          'Config version: ${XBoardConfig.configVersion.isEmpty ? '-' : XBoardConfig.configVersion}')
      ..writeln('Candidates: ${gatewayRuntime.candidates.length}');

    for (final candidate in gatewayRuntime.candidates.take(8)) {
      buffer.writeln(
        '- ${gatewayDisplayLabel(candidate.baseUrl)}${candidate.apiPrefix} '
        '| ${candidate.verificationStatus.name} '
        '| source=${candidate.source} '
        '| http=${candidate.lastVerificationStatusCode ?? '-'} '
        '| failures=${candidate.failureCount}',
      );
    }

    buffer
      ..writeln('')
      ..writeln('[Account]')
      ..writeln('Authenticated: ${userState.isAuthenticated}')
      ..writeln(
          'Email: ${_maskEmail(userState.email ?? subscription?.email ?? '')}')
      ..writeln('Plan ID: ${subscription?.planId ?? '-'}')
      ..writeln(
          'Expire: ${subscription?.expiredAt == null ? '-' : _fmt(subscription!.expiredAt!)}')
      ..writeln(
          'Transfer: ${subscription == null ? '-' : '${subscription.totalUsedBytes}/${subscription.transferLimit}'}')
      ..writeln('Device limit: ${subscription?.deviceLimit ?? '-'}')
      ..writeln('')
      ..writeln('[Device Session]')
      ..writeln(
          'Heartbeat in flight: ${XBoardDeviceHeartbeatService.isInFlight}')
      ..writeln(
          'Last attempt: ${_fmtNullable(XBoardDeviceHeartbeatService.lastAttemptAt)}')
      ..writeln(
          'Last success: ${_fmtNullable(XBoardDeviceHeartbeatService.lastSuccessAt)}')
      ..writeln(
          'Last reason: ${XBoardDeviceHeartbeatService.lastReason ?? '-'}')
      ..writeln('')
      ..writeln('[Recent Gateway Events]');

    for (final event in gatewayRuntime.recentEvents.reversed.take(12)) {
      buffer.writeln(
          '- ${_fmt(event.timestamp)} | ${event.type.name} | ${event.message}');
    }

    buffer
      ..writeln('')
      ..writeln('[Recent Logs]');
    for (final log in logs) {
      buffer.writeln(
          '- ${log.dateTime} | ${log.logLevel.name} | ${SensitiveMasker.maskText(log.payload)}');
    }

    return buffer.toString();
  }

  static Future<void> copy(WidgetRef ref) async {
    final text = await build(ref);
    await Clipboard.setData(ClipboardData(text: text));
  }

  static int _countNodes(List<Group> groups) {
    final names = <String>{};
    for (final group in groups) {
      for (final proxy in group.all) {
        names.add(proxy.name);
      }
    }
    return names.length;
  }

  static String _fmtNullable(DateTime? value) =>
      value == null ? '-' : _fmt(value);

  static String _maskEndpoint(String? value) {
    final endpoint = value?.trim();
    if (endpoint == null || endpoint.isEmpty) return '-';
    return gatewayDisplayLabel(endpoint);
  }

  static String _fmt(DateTime value) {
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }

  static String _maskEmail(String email) {
    if (email.isEmpty || !email.contains('@')) return '-';
    final parts = email.split('@');
    final name = parts.first;
    final domain = parts.skip(1).join('@');
    final masked = name.length <= 2
        ? '${name[0]}*'
        : '${name[0]}***${name[name.length - 1]}';
    return '$masked@$domain';
  }
}
