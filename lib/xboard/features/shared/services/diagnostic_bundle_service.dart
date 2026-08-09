import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';
import 'package:fl_clash/xboard/config/gateway_config.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/xboard/features/diagnostics/services/network_diagnostic_snapshot.dart';
import 'package:fl_clash/xboard/features/initialization/initialization.dart';
import 'package:fl_clash/xboard/features/profile/providers/profile_import_provider.dart';
import 'package:fl_clash/xboard/features/subscription/services/subscription_status_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';

final deviceHealthSummaryProvider =
    FutureProvider.autoDispose<DeviceHealthSummary>((ref) async {
  final sdk = await ref.read(xboardSdkProvider.future);
  final token = await sdk.getToken();
  if (token == null || token.isEmpty || !token.contains('dg_')) {
    throw Exception('device gateway session unavailable');
  }
  final headers = <String, String>{'Authorization': token};

  try {
    await sdk.httpService.postRequest(
      '/user/devices/heartbeat',
      <String, dynamic>{},
      headers: headers,
    );
  } catch (_) {}

  final response = await sdk.httpService.getRequest(
    '/user/devices',
    headers: headers,
  );
  final data = _mapOf(response['data']);
  return DeviceHealthSummary(
    activeCount: _intFromAny(data?['active_count']),
    deviceLimit: _intFromAnyOrNull(data?['device_limit']),
  );
});

class DeviceHealthSummary {
  const DeviceHealthSummary({
    required this.activeCount,
    required this.deviceLimit,
  });

  final int activeCount;
  final int? deviceLimit;

  String deviceLimitText(AppLocalizations l10n) {
    if (deviceLimit == null || deviceLimit == 0) {
      return l10n.xboardDeviceUnlimited;
    }
    return '$deviceLimit';
  }
}

class DiagnosticBundleService {
  const DiagnosticBundleService._();

  static Future<String> buildReport(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n, {
    bool includeNetworkDiagnostics = true,
    bool includeMetadata = true,
  }) async {
    final initState = ref.read(initializationProvider);
    final userState = ref.read(xboardUserProvider);
    final subscription =
        ref.read(subscriptionInfoProvider) ?? userState.subscriptionInfo;
    final profileInfo = ref.read(currentProfileProvider)?.subscriptionInfo;
    final importState = ref.read(profileImportProvider);
    final groups = ref.read(groupsProvider);
    final patchConfig = ref.read(patchClashConfigProvider);
    final networkProps = ref.read(networkSettingProvider);
    final overrideDns = ref.read(overrideDnsProvider);
    final realTunEnable = ref.read(realTunEnableProvider);
    final proxyState = ref.read(proxyStateProvider);
    final gatewayRuntime = GatewayRuntimeService.instance
      ..syncFromCurrentConfig();
    final activeGateway = gatewayRuntime.activeConfig;
    final currentProxy = _resolveCurrentProxy(ref);
    final latestGatewayEvent = gatewayRuntime.recentEvents.isNotEmpty
        ? gatewayRuntime.recentEvents.last.message
        : null;
    final businessApiLabel = _resolveBusinessApiLabel(activeGateway);
    final coreRunning = globalState.appState.runTime != null;
    final vpnConnected = globalState.isStart;
    final gatewayOk = activeGateway != null && initState.isReady;
    final nodeCount = _countNodes(groups);
    final nodesOk = currentProxy != null && !importState.isImporting;
    final subscriptionStatus = userState.isAuthenticated
        ? subscriptionStatusService.checkSubscriptionStatus(
            userState: userState,
            profileSubscriptionInfo: profileInfo,
          )
        : null;
    final subscriptionOk = subscriptionStatus == null
        ? subscription != null
        : subscriptionStatus.type == SubscriptionStatusType.valid;
    final subscriptionValue = subscriptionStatus?.getMessage(context) ??
        (subscription == null
            ? l10n.xboardNoAvailableSubscription
            : l10n.xboardHealthy);
    final subscriptionDetail = subscriptionStatus?.getDetailMessage(context);
    final tunPending = patchConfig.tun.enable && !realTunEnable;
    final actualProxy = system.isDesktop && proxy != null
        ? await proxy!.getSystemProxyStatus()
        : null;
    final localProxyListening = coreRunning && system.isDesktop
        ? await _probeLocalProxy(proxyState.port)
        : false;
    final actualProxyMatches =
        actualProxy?.matches('127.0.0.1', proxyState.port) == true;
    final systemProxyHealthy = !system.isDesktop ||
        realTunEnable ||
        (coreRunning &&
            networkProps.systemProxy &&
            localProxyListening &&
            actualProxyMatches);
    final systemProxyValue = realTunEnable
        ? l10n.xboardProxyStatusTunActive
        : !coreRunning
            ? l10n.xboardHealthDisabled
            : !networkProps.systemProxy
                ? l10n.xboardProxyStatusClientDisabled
                : !localProxyListening
                    ? l10n.xboardProxyStatusPortUnavailable
                    : actualProxy?.available != true
                        ? l10n.xboardProxyStatusReadFailed
                        : actualProxy?.enabled != true
                            ? l10n.xboardProxyStatusSystemDisabled
                            : !actualProxyMatches
                                ? l10n.xboardProxyStatusMismatch
                                : l10n.xboardHealthEnabled;
    final actualProxyValue = actualProxy?.available != true
        ? l10n.xboardNetworkDiagnosticsUnavailable
        : actualProxy?.enabled != true
            ? l10n.xboardHealthDisabled
            : '${actualProxy?.host ?? '-'}:${actualProxy?.port ?? '-'}';
    DeviceHealthSummary? deviceSummary;
    try {
      deviceSummary = await ref.read(deviceHealthSummaryProvider.future);
    } catch (_) {}
    final helperStatus =
        Platform.isWindows ? await request.getHelperRuntimeStatus() : null;
    final snapshot = NetworkDiagnosticSnapshotStore.latest;
    final networkError =
        snapshot?.conclusionSeverity == NetworkDiagnosticSeverity.error;
    final networkWarning =
        snapshot?.conclusionSeverity == NetworkDiagnosticSeverity.warning;
    final networkType = includeMetadata
        ? snapshot?.networkType ?? await _resolveNetworkType(l10n)
        : null;

    final problems = <String>[
      if (!coreRunning) l10n.xboardDiagnosticIssueCore,
      if (!gatewayOk) l10n.xboardDiagnosticIssueGateway,
      if (!subscriptionOk) l10n.xboardSubscriptionHealth,
      if (deviceSummary == null) l10n.xboardDeviceHealth,
      if (!nodesOk) l10n.xboardDiagnosticIssueNodes,
      if (!systemProxyHealthy) l10n.xboardDiagnosticIssueProxy,
    ];
    final overall = problems.isNotEmpty || networkError
        ? l10n.xboardDiagnosticOverallAbnormal
        : tunPending || networkWarning
            ? l10n.xboardDiagnosticOverallAttention
            : snapshot == null
                ? l10n.xboardDiagnosticOverallServiceHealthy
                : l10n.xboardDiagnosticOverallHealthy;

    final buffer = StringBuffer()
      ..writeln(
        '=== ${includeMetadata ? l10n.xboardDiagnosticSummaryTitle : l10n.xboardDiagnosticServiceStatus} ===',
      );
    if (includeMetadata) {
      buffer
        ..writeln(
          '${l10n.xboardNetworkDiagnosticsTime}: ${_fmt(DateTime.now())}',
        )
        ..writeln('${l10n.xboardDiagnosticPlatform}: ${_platformLabel()}')
        ..writeln('${l10n.xboardNetworkDiagnosticsNetworkType}: $networkType')
        ..writeln(
          '${l10n.xboardNetworkDiagnosticsVpnStatus}: '
          '${vpnConnected ? l10n.xboardNetworkDiagnosticsConnected : l10n.xboardNetworkDiagnosticsDisconnected}',
        );
    }
    buffer
      ..writeln()
      ..writeln('${l10n.xboardDiagnosticOverall}: $overall');

    _writeSection(buffer, l10n.xboardDiagnosticBusinessServices, [
      _ReportItem(
        initState.isReady,
        l10n.xboardServerStatus,
        initState.isReady
            ? l10n.xboardHealthy
            : initState.currentStepDescription ??
                initState.errorMessage ??
                l10n.xboardNeedsAttention,
        details: [
          if (businessApiLabel.isNotEmpty)
            '${l10n.xboardCurrentBusinessApi}: $businessApiLabel',
        ],
      ),
      _ReportItem(
        gatewayOk,
        l10n.xboardGatewayStatus,
        activeGateway == null
            ? l10n.xboardNoGatewayActive
            : '${l10n.xboardCurrentGateway}: '
                '${gatewayDisplayLabel(activeGateway.baseUrl)}',
        details: [
          l10n.xboardGatewayCandidateCount(gatewayRuntime.candidates.length),
          if (latestGatewayEvent != null)
            '${l10n.xboardHealthLastEvent}: '
                '${SensitiveMasker.maskText(latestGatewayEvent)}',
        ],
      ),
      _ReportItem(
        subscriptionOk,
        l10n.xboardSubscriptionHealth,
        subscriptionValue,
        details: [
          if (subscriptionDetail != null) subscriptionDetail,
          if (importState.message?.trim().isNotEmpty == true)
            l10n.xboardHealthSubscriptionImport(importState.message!),
        ],
      ),
      _ReportItem(
        deviceSummary != null,
        l10n.xboardDeviceHealth,
        l10n.xboardDeviceSummary(
          deviceSummary?.activeCount ?? '-',
          deviceSummary?.deviceLimitText(l10n) ??
              _deviceLimitText(subscription?.deviceLimit, l10n),
        ),
      ),
    ]);

    _writeSection(buffer, l10n.xboardDiagnosticProxyAndSystem, [
      _ReportItem(
        nodesOk,
        l10n.xboardNodeHealth,
        importState.isImporting
            ? l10n.xboardImportingSubscription
            : currentProxy == null
                ? l10n.xboardNoAvailableNodes
                : '${l10n.xboardCurrentNode}: ${currentProxy.name}',
        details: [l10n.xboardNodeCount(nodeCount)],
      ),
      if (Platform.isWindows)
        _ReportItem(
          helperStatus?.tokenMatches == true,
          l10n.xboardHealthHelper,
          helperStatus?.tokenMatches == true
              ? l10n.xboardHealthHelperAvailable
              : l10n.xboardHealthHelperUnavailable,
          details: [
            if (helperStatus?.version != null)
              'Version: ${helperStatus?.version}',
          ],
        ),
      _ReportItem(
        coreRunning,
        l10n.core,
        coreRunning ? l10n.xboardHealthCoreRunning : l10n.notConnected,
        details: [
          globalState.coreSwitchStatusNotifier.value.localizedLabel(l10n),
        ],
      ),
      _ReportItem(
        !tunPending,
        l10n.action_tun,
        realTunEnable
            ? l10n.xboardHealthTunApplied
            : patchConfig.tun.enable
                ? l10n.xboardHealthTunPending
                : l10n.xboardHealthDisabled,
        warning: tunPending,
        details: [
          'stack=${patchConfig.tun.stack.name}, '
              'route=${networkProps.routeMode.name}',
        ],
      ),
      _ReportItem(
        true,
        l10n.xboardHealthDns,
        overrideDns ? l10n.xboardHealthDnsCustom : l10n.xboardHealthDnsDefault,
        details: [
          'autoSetSystemDns=${networkProps.autoSetSystemDns}',
        ],
      ),
      if (system.isDesktop)
        _ReportItem(
          systemProxyHealthy,
          l10n.systemProxy,
          systemProxyValue,
          details: [
            '${l10n.xboardProxyExpectedAddress}: '
                '127.0.0.1:${proxyState.port}',
            '${l10n.xboardProxyLocalPort}: '
                '${localProxyListening ? l10n.xboardProxyListening : l10n.xboardProxyNotListening}',
            '${l10n.xboardProxyActualAddress}: $actualProxyValue',
            '${l10n.xboardProxyClientSetting}: '
                '${networkProps.systemProxy ? l10n.xboardHealthEnabled : l10n.xboardHealthDisabled}',
            if (actualProxy?.source?.isNotEmpty == true)
              '${l10n.xboardProxyStatusSource}: ${actualProxy?.source}',
          ],
        ),
    ]);

    if (includeNetworkDiagnostics) {
      buffer
        ..writeln()
        ..writeln('[${l10n.xboardDiagnosticLatestNetwork}]');
      if (snapshot == null) {
        buffer.writeln('- ${l10n.xboardDiagnosticNetworkNotRun}');
      } else {
        _writeNetworkSummary(buffer, snapshot, l10n);
      }
    }

    buffer
      ..writeln()
      ..writeln('[${l10n.xboardDiagnosticSuggestion}]')
      ..writeln(
        networkError || networkWarning
            ? _networkSuggestion(snapshot!, l10n)
            : problems.isNotEmpty
                ? l10n.xboardDiagnosticSuggestionRepair
                : tunPending
                    ? l10n.xboardDiagnosticSuggestionTun
                    : snapshot == null
                        ? l10n.xboardDiagnosticSuggestionRunNetwork
                        : l10n.xboardDiagnosticSuggestionNone,
      );
    return buffer.toString();
  }

  static String buildNetworkReport(
    NetworkDiagnosticSnapshot snapshot,
    AppLocalizations l10n,
  ) {
    final buffer = StringBuffer()
      ..writeln('=== ${l10n.xboardNetworkDiagnosticsReportTitle} ===')
      ..writeln(
        '${l10n.xboardNetworkDiagnosticsTime}: '
        '${snapshot.generatedAt.toIso8601String()}',
      )
      ..writeln('${l10n.xboardNetworkDiagnosticsDomain}: [redacted-domain]')
      ..writeln(
        '${l10n.xboardNetworkDiagnosticsNetworkType}: ${snapshot.networkType}',
      )
      ..writeln('vpn_connected: ${snapshot.vpnConnected}')
      ..writeln();
    _writeNetworkSummary(
      buffer,
      snapshot,
      l10n,
      includeSnapshotTime: false,
    );
    return buffer.toString();
  }

  static Future<void> copyReport(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final text = await buildReport(context, ref, l10n);
    await Clipboard.setData(ClipboardData(text: text));
  }

  static String buildCurrentNodeLatencyReport(WidgetRef ref) {
    final groups = ref.read(groupsProvider);
    if (groups.isEmpty) {
      return '[node_latency_snapshot]\nstatus: no_available_group\n';
    }
    final currentGroupName =
        globalState.appController.getCurrentGroupName()?.toString();
    final group = groups.firstWhere(
      (item) => item.name == currentGroupName,
      orElse: () => groups.firstWhere(
        (item) => item.hidden != true && item.name != GroupName.GLOBAL.name,
        orElse: () => groups.first,
      ),
    );
    final delayMap = globalState.appState.delayMap;
    final seen = <String>{};
    final buffer = StringBuffer()
      ..writeln('[node_latency_snapshot]')
      ..writeln('source: latest_client_result (no_retest)')
      ..writeln('group: ${group.name}');
    for (final proxy in group.all) {
      final state = globalState.appController.getProxyCardState(proxy.name);
      final name = state.proxyName.isEmpty ? proxy.name : state.proxyName;
      if (!seen.add(name)) continue;
      final testUrl = globalState.appController.getRealTestUrl(
        state.testUrl ?? group.testUrl,
      );
      final delay = delayMap[testUrl]?[name];
      final value = delay == null
          ? 'not_tested'
          : delay < 0
              ? 'timeout'
              : '${delay}ms';
      buffer.writeln('- $name: $value');
    }
    if (seen.isEmpty) buffer.writeln('status: no_available_nodes');
    return buffer.toString();
  }

  static void _writeNetworkSummary(
    StringBuffer buffer,
    NetworkDiagnosticSnapshot snapshot,
    AppLocalizations l10n, {
    bool includeSnapshotTime = true,
  }) {
    if (includeSnapshotTime) {
      buffer.writeln(
        '${l10n.xboardDiagnosticNetworkSnapshotTime}: '
        '${_fmt(snapshot.generatedAt)}',
      );
    }
    buffer
      ..writeln(
        '${l10n.xboardNetworkDiagnosticsVpnStatus}: ${snapshot.vpnStatus}',
      )
      ..writeln(
        '${l10n.xboardNetworkDiagnosticsNode}: '
        '${snapshot.nodeAvailable ? '[redacted-node]' : '-'}',
      )
      ..writeln(
        '${l10n.xboardNetworkDiagnosticsConclusion}: ${snapshot.conclusion}',
      );
    _writeNetworkItems(
      buffer,
      l10n.xboardNetworkDiagnosticsDns,
      snapshot.dnsResults,
    );
    _writeNetworkItems(
      buffer,
      l10n.xboardNetworkDiagnosticsIpConnectivity,
      snapshot.ipResults,
    );
    if (snapshot.nodeResult.isNotEmpty) {
      _writeNetworkItems(
        buffer,
        l10n.xboardNetworkDiagnosticsNodeLayers,
        snapshot.nodeLayerResults,
      );
      buffer
        ..writeln(
          '  diagnostic_status: '
          '${snapshot.nodeResult['diagnostic-status'] ?? 'legacy'}',
        )
        ..writeln('  target_port: ${snapshot.nodeResult['port'] ?? '-'}')
        ..writeln('  transport: ${snapshot.nodeResult['network'] ?? '-'}')
        ..writeln('  proxy_type: ${snapshot.nodeResult['proxy-type'] ?? '-'}')
        ..writeln(
          '  failure_stage: ${snapshot.nodeResult['failure-stage'] ?? '-'}',
        )
        ..writeln('  tcp_status: ${snapshot.nodeResult['tcp-status'] ?? '-'}')
        ..writeln(
          '  error: ${_maskNetworkValue(snapshot.nodeResult['error']?.toString() ?? '-')}',
        );
    }
    _writeNetworkItems(
      buffer,
      l10n.xboardNetworkDiagnosticsDirectHttps,
      snapshot.directResults,
    );
    _writeNetworkItems(
      buffer,
      l10n.xboardNetworkDiagnosticsProxyHttps,
      snapshot.proxyResults,
    );
  }

  static void _writeSection(
    StringBuffer buffer,
    String title,
    List<_ReportItem> items,
  ) {
    buffer
      ..writeln()
      ..writeln('[$title]');
    for (final item in items) {
      final marker = item.warning
          ? '⚠'
          : item.ok
              ? '✓'
              : '✗';
      buffer.writeln('$marker ${item.label}: ${item.value}');
      for (final detail in item.details.where((item) => item.isNotEmpty)) {
        buffer.writeln('  $detail');
      }
    }
  }

  static void _writeNetworkItems(
    StringBuffer buffer,
    String title,
    List<NetworkDiagnosticItem> items,
  ) {
    buffer
      ..writeln()
      ..writeln('$title:');
    if (items.isEmpty) {
      buffer.writeln('  -');
      return;
    }
    for (final item in items) {
      final elapsed = item.elapsedMs > 0 ? '${item.elapsedMs}ms' : '—';
      buffer.writeln(
        '  ${item.marker} ${item.label}: '
        '${_maskNetworkValue(item.detail)} ($elapsed)',
      );
    }
  }

  static String _networkSuggestion(
    NetworkDiagnosticSnapshot snapshot,
    AppLocalizations l10n,
  ) {
    return switch (snapshot.conclusionReason) {
      NetworkDiagnosticReason.noNetwork ||
      NetworkDiagnosticReason.disconnectedDns ||
      NetworkDiagnosticReason.disconnectedNetwork ||
      NetworkDiagnosticReason.dns ||
      NetworkDiagnosticReason.network =>
        l10n.xboardDiagnosticSuggestionNetwork,
      NetworkDiagnosticReason.nodeDns ||
      NetworkDiagnosticReason.tcp ||
      NetworkDiagnosticReason.tcpRefused ||
      NetworkDiagnosticReason.tls ||
      NetworkDiagnosticReason.protocol ||
      NetworkDiagnosticReason.udp ||
      NetworkDiagnosticReason.nodeUnknown ||
      NetworkDiagnosticReason.proxy =>
        l10n.xboardDiagnosticSuggestionNode,
      NetworkDiagnosticReason.disconnectedHealthy ||
      NetworkDiagnosticReason.proxyWorking =>
        snapshot.conclusion,
      NetworkDiagnosticReason.healthy => l10n.xboardDiagnosticSuggestionNone,
    };
  }

  static String _maskNetworkValue(String value) {
    final ipv4Masked = value.replaceAll(
      RegExp(r'\b(?:\d{1,3}\.){3}\d{1,3}\b'),
      '[redacted-ip]',
    );
    return ipv4Masked.replaceAllMapped(
      RegExp(r'[0-9a-fA-F:]{2,}'),
      (match) {
        final candidate = match.group(0)!;
        final address = InternetAddress.tryParse(candidate);
        return address?.type == InternetAddressType.IPv6
            ? '[redacted-ipv6]'
            : candidate;
      },
    );
  }

  static Future<String> _resolveNetworkType(AppLocalizations l10n) async {
    try {
      final results = await Connectivity().checkConnectivity();
      if (results.isEmpty || results.contains(ConnectivityResult.none)) {
        return l10n.xboardNetworkDiagnosticsNetworkNone;
      }
      return results.map((result) {
        switch (result) {
          case ConnectivityResult.wifi:
            return 'Wi-Fi';
          case ConnectivityResult.mobile:
            return l10n.xboardNetworkDiagnosticsNetworkMobile;
          case ConnectivityResult.ethernet:
            return l10n.xboardNetworkDiagnosticsNetworkEthernet;
          case ConnectivityResult.vpn:
            return 'VPN';
          case ConnectivityResult.bluetooth:
            return 'Bluetooth';
          case ConnectivityResult.other:
          case ConnectivityResult.satellite:
            return l10n.xboardNetworkDiagnosticsNetworkOther;
          case ConnectivityResult.none:
            return l10n.xboardNetworkDiagnosticsNetworkNone;
        }
      }).join(' + ');
    } catch (_) {
      return l10n.xboardNetworkDiagnosticsUnavailable;
    }
  }

  static Proxy? _resolveCurrentProxy(WidgetRef ref) {
    final groups = ref.read(groupsProvider);
    if (groups.isEmpty) return null;
    final selectedMap = ref.read(selectedMapProvider);
    final mode = ref.read(
      patchClashConfigProvider.select((state) => state.mode),
    );

    final group = mode == Mode.global
        ? groups.firstWhere(
            (item) => item.name == GroupName.GLOBAL.name,
            orElse: () => groups.first,
          )
        : groups.firstWhere(
            (item) => item.hidden != true && item.name != GroupName.GLOBAL.name,
            orElse: () => groups.first,
          );
    if (group.all.isEmpty) return null;
    final selectedName = selectedMap[group.name] ?? group.now ?? '';
    if (selectedName.isEmpty) return group.all.first;
    return group.all.firstWhere(
      (proxy) => proxy.name == selectedName,
      orElse: () => group.all.first,
    );
  }

  static String _resolveBusinessApiLabel(GatewayEndpointConfig? fallback) {
    final sdk = XBoardSDK.instance;
    if (sdk.isInitialized) {
      final baseUrl = sdk.httpService.baseUrl.trim();
      if (baseUrl.isNotEmpty) return gatewayDisplayLabel(baseUrl);
    }
    if (fallback == null) return '';
    return gatewayDisplayLabel(fallback.baseUrl);
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

  static String _deviceLimitText(
    int? deviceLimit,
    AppLocalizations l10n,
  ) {
    if (deviceLimit == null || deviceLimit == 0) {
      return l10n.xboardDeviceUnlimited;
    }
    return '$deviceLimit';
  }

  static String _platformLabel() {
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    return Platform.operatingSystem;
  }

  static Future<bool> _probeLocalProxy(int port) async {
    Socket? socket;
    try {
      socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        port,
        timeout: const Duration(milliseconds: 800),
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      socket?.destroy();
    }
  }

  static String _fmt(DateTime value) {
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }
}

class _ReportItem {
  const _ReportItem(
    this.ok,
    this.label,
    this.value, {
    this.warning = false,
    this.details = const [],
  });

  final bool ok;
  final String label;
  final String value;
  final bool warning;
  final List<String> details;
}

Map<String, dynamic>? _mapOf(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return null;
}

int _intFromAny(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

int? _intFromAnyOrNull(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
