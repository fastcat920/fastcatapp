import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/xboard/config/gateway_config.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/xboard/features/initialization/initialization.dart';
import 'package:fl_clash/xboard/features/profile/providers/profile_import_provider.dart';
import 'package:fl_clash/xboard/features/shared/services/diagnostic_bundle_service.dart';
import 'package:fl_clash/xboard/features/shared/services/service_endpoint_health_service.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:fl_clash/xboard/features/subscription/services/subscription_status_service.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _windowsHelperStatusProvider =
    FutureProvider.autoDispose<WindowsHelperRuntimeStatus?>((ref) async {
  if (!Platform.isWindows) return null;
  return request.getHelperRuntimeStatus();
});

final _systemProxyHealthProvider =
    FutureProvider.autoDispose<_SystemProxyHealth>((ref) async {
  final proxyState = ref.watch(proxyStateProvider);
  final tunActive = ref.watch(realTunEnableProvider);
  if (!system.isDesktop || proxy == null) {
    return _SystemProxyHealth.notRequired(
      expectedPort: proxyState.port,
      tunActive: tunActive,
    );
  }

  final actual = await proxy!.getSystemProxyStatus();
  final listening = proxyState.isStart
      ? await _isLocalProxyListening(proxyState.port)
      : false;
  return _SystemProxyHealth(
    coreRunning: proxyState.isStart,
    tunActive: tunActive,
    configuredEnabled: proxyState.systemProxy,
    expectedHost: '127.0.0.1',
    expectedPort: proxyState.port,
    listening: listening,
    actualAvailable: actual.available,
    actualEnabled: actual.enabled,
    actualConsistent: actual.consistent,
    actualHost: actual.host,
    actualPort: actual.port,
    source: actual.source,
  );
});

class ConnectionHealthDialog extends ConnectionHealthView {
  const ConnectionHealthDialog({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          return Scaffold(
            appBar: AppBar(title: Text(l10n.xboardConnectionHealth)),
            body: const ConnectionHealthView(),
          );
        },
      ),
    );
  }
}

class ConnectionHealthView extends ConsumerStatefulWidget {
  const ConnectionHealthView({super.key, this.showHeader = true});

  final bool showHeader;

  @override
  ConsumerState<ConnectionHealthView> createState() =>
      _ConnectionHealthViewState();
}

class _ConnectionHealthViewState extends ConsumerState<ConnectionHealthView> {
  bool _isRefreshing = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final initState = ref.watch(initializationProvider);
    final userState = ref.watch(xboardUserProvider);
    final subscriptionInfo =
        ref.watch(subscriptionInfoProvider) ?? userState.subscriptionInfo;
    final profileInfo = ref.watch(currentProfileProvider)?.subscriptionInfo;
    final groups = ref.watch(groupsProvider);
    final importState = ref.watch(profileImportProvider);
    final gatewayRuntime = GatewayRuntimeService.instance;
    gatewayRuntime.syncFromCurrentConfig();
    final activeGateway = gatewayRuntime.activeConfig;
    final currentProxy = _resolveCurrentProxy(ref);
    final endpointHealth = ref.watch(serviceEndpointHealthProvider);
    final helperStatus = ref.watch(_windowsHelperStatusProvider);
    final networkProps = ref.watch(networkSettingProvider);
    final patchConfig = ref.watch(patchClashConfigProvider);
    final realTunEnable = ref.watch(realTunEnableProvider);
    final overrideDns = ref.watch(overrideDnsProvider);
    final systemProxyHealth = ref.watch(_systemProxyHealthProvider);

    final subscriptionStatus = userState.isAuthenticated
        ? subscriptionStatusService.checkSubscriptionStatus(
            userState: userState,
            profileSubscriptionInfo: profileInfo,
          )
        : null;
    final subscriptionOk = subscriptionStatus == null ||
        subscriptionStatus.type == SubscriptionStatusType.valid;
    final gatewayOk = activeGateway != null && initState.isReady;
    final nodeOk = groups.isNotEmpty && currentProxy != null;
    final allHealthy = gatewayOk && subscriptionOk && nodeOk;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      children: [
        if (widget.showHeader)
          Row(
            children: [
              Icon(
                allHealthy ? Icons.verified_outlined : Icons.health_and_safety,
                color: allHealthy
                    ? XbUiStatusColor.success(context)
                    : theme.colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.xboardConnectionHealth,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: XbFontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        if (widget.showHeader) const SizedBox(height: 8),
        if (widget.showHeader)
          Text(
            l10n.xboardConnectionHealthSubtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        if (widget.showHeader) const SizedBox(height: 16),
        _ConnectionSectionHeader(l10n.xboardDiagnosticBusinessServices),
        _EndpointHealthCard(
          icon: Icons.cloud_done_outlined,
          title: l10n.xboardServerStatus,
          summary: endpointHealth,
          business: true,
          fallbackHealthy: initState.isReady,
          fallbackText: initState.currentStepDescription ??
              initState.errorMessage ??
              l10n.xboardNeedsAttention,
        ),
        _EndpointHealthCard(
          icon: Icons.hub_outlined,
          title: l10n.xboardGatewayStatus,
          summary: endpointHealth,
          business: false,
          fallbackHealthy: gatewayOk,
          fallbackText: activeGateway == null
              ? l10n.xboardNoGatewayActive
              : l10n.xboardHealthy,
        ),
        _HealthRow(
          icon: Icons.card_membership_outlined,
          title: l10n.xboardSubscriptionHealth,
          value: subscriptionStatus?.getMessage(context) ??
              (subscriptionInfo == null
                  ? l10n.xboardNoAvailableSubscription
                  : l10n.xboardHealthy),
          detail: [
            if (subscriptionStatus?.getDetailMessage(context) != null)
              subscriptionStatus!.getDetailMessage(context)!,
            if (importState.message?.trim().isNotEmpty == true)
              l10n.xboardHealthSubscriptionImport(importState.message!),
          ].join('\n'),
          healthy: subscriptionOk && !importState.isImporting,
        ),
        _DeviceHealthRow(fallbackDeviceLimit: subscriptionInfo?.deviceLimit),
        _ConnectionSectionHeader(l10n.xboardDiagnosticProxyAndSystem),
        _HealthRow(
          icon: Icons.language_outlined,
          title: l10n.xboardNodeHealth,
          value: importState.isImporting
              ? l10n.xboardImportingSubscription
              : nodeOk
                  ? '${l10n.xboardCurrentNode}: ${currentProxy.name}'
                  : l10n.xboardNoAvailableNodes,
          detail: l10n.xboardNodeCount(_countNodes(groups)),
          healthy: nodeOk && !importState.isImporting,
        ),
        if (Platform.isWindows) _HelperHealthRow(summary: helperStatus),
        _HealthRow(
          icon: Icons.power_settings_new,
          title: l10n.core,
          value: globalState.appState.runTime != null
              ? l10n.xboardHealthCoreRunning
              : l10n.notConnected,
          detail: globalState.coreSwitchStatusNotifier.value.localizedLabel(
            l10n,
          ),
          healthy: globalState.appState.runTime != null,
        ),
        _HealthRow(
          icon: Icons.stacked_line_chart,
          title: l10n.action_tun,
          value: patchConfig.tun.enable
              ? (realTunEnable
                  ? l10n.xboardHealthTunApplied
                  : l10n.xboardHealthTunPending)
              : l10n.xboardHealthDisabled,
          detail:
              'stack=${patchConfig.tun.stack.name}, route=${networkProps.routeMode.name}',
          healthy: !patchConfig.tun.enable || realTunEnable,
        ),
        _HealthRow(
          icon: Icons.dns_outlined,
          title: l10n.xboardHealthDns,
          value: overrideDns
              ? l10n.xboardHealthDnsCustom
              : l10n.xboardHealthDnsDefault,
          detail: 'autoSetSystemDns=${networkProps.autoSetSystemDns}',
          healthy: true,
        ),
        _SystemProxyHealthRow(
          summary: systemProxyHealth,
          configuredEnabled: networkProps.systemProxy,
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () => _repairConnection(context, ref),
          icon: const Icon(Icons.build_circle_outlined),
          label: Text(l10n.xboardOneClickRepair),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            await DiagnosticBundleService.copyReport(context, ref, l10n);
            if (context.mounted) {
              XBoardNotification.showSuccess(
                l10n.xboardNetworkDiagnosticsCopied,
              );
            }
          },
          icon: const Icon(Icons.content_copy_outlined),
          label: Text(l10n.xboardNetworkDiagnosticsCopyReport),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _isRefreshing
              ? null
              : () async {
                  setState(() => _isRefreshing = true);
                  try {
                    await ref.read(initializationProvider.notifier).refresh();
                    await ref
                        .read(xboardUserProvider.notifier)
                        .refreshSubscriptionInfo();
                    ref.invalidate(_windowsHelperStatusProvider);
                    ref.invalidate(_systemProxyHealthProvider);
                    ref.invalidate(serviceEndpointHealthProvider);
                  } finally {
                    if (mounted) setState(() => _isRefreshing = false);
                  }
                },
          icon: _isRefreshing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
          label: Text(l10n.xboardRefreshStatus),
        ),
      ],
    );
  }
}

Future<void> _repairConnection(
  BuildContext context,
  WidgetRef ref,
) async {
  final l10n = AppLocalizations.of(context);

  Future<String?> runRepair() async {
    if (Platform.isWindows) {
      await windows?.registerService(forceRepair: true);
      ref.invalidate(_windowsHelperStatusProvider);
    }
    if (Platform.isWindows) {
      await Process.run('ipconfig', ['/flushdns']);
    } else if (Platform.isMacOS) {
      await system.setMacOSDns(true);
    }
    if (ref.read(currentProfileProvider) != null) {
      await globalState.appController.applyProfile(silence: true);
    }

    final proxyState = ref.read(proxyStateProvider);
    final tunActive = ref.read(realTunEnableProvider);
    if (system.isDesktop && proxy != null) {
      if (!proxyState.isStart) {
        await proxy?.stopProxy();
        return l10n.xboardProxyRepairCoreNotRunning;
      }
      if (!tunActive) {
        final listening = await _waitForLocalProxy(proxyState.port);
        if (!listening) {
          return l10n.xboardProxyRepairPortUnavailable;
        }
        await proxy?.stopProxy();
        final started = await proxy?.startProxy(
          proxyState.port,
          proxyState.bassDomain,
        );
        if (started != true) {
          return l10n.xboardProxyRepairWriteFailed;
        }
        final actual = await proxy!.getSystemProxyStatus();
        if (!actual.matches('127.0.0.1', proxyState.port)) {
          return l10n.xboardProxyRepairVerifyFailed;
        }
        ref.read(networkSettingProvider.notifier).updateState(
              (state) => state.copyWith(systemProxy: true),
            );
      }
    }
    await ref.read(initializationProvider.notifier).refresh();
    await ref.read(xboardUserProvider.notifier).refreshSubscriptionInfo(
          importProfile: false,
        );
    ref.invalidate(serviceEndpointHealthProvider);
    ref.invalidate(_systemProxyHealthProvider);
    return null;
  }

  final commonScaffoldState = context.commonScaffoldState;
  String? repairError;
  Future<void> executeRepair() async {
    try {
      repairError = await runRepair();
    } catch (error) {
      commonPrint.log('[ConnectionHealth] repair failed: $error');
      repairError = l10n.xboardOperationFailed;
    }
  }

  if (commonScaffoldState?.mounted == true) {
    await commonScaffoldState!.loadingRun<void>(
      executeRepair,
      title: l10n.xboardOneClickRepair,
    );
  } else {
    await executeRepair();
  }
  ref.invalidate(_systemProxyHealthProvider);
  if (context.mounted) {
    if (repairError == null) {
      XBoardNotification.showSuccess(l10n.xboardRepairCompleted);
    } else {
      XBoardNotification.showError(repairError!);
    }
  }
}

Future<bool> _isLocalProxyListening(int port) async {
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

Future<bool> _waitForLocalProxy(int port) async {
  for (var attempt = 0; attempt < 6; attempt++) {
    if (await _isLocalProxyListening(port)) return true;
    if (attempt < 5) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }
  return false;
}

int _countNodes(List<Group> groups) {
  final names = <String>{};
  for (final group in groups) {
    for (final proxy in group.all) {
      names.add(proxy.name);
    }
  }
  return names.length;
}

Proxy? _resolveCurrentProxy(WidgetRef ref) {
  final groups = ref.watch(groupsProvider);
  if (groups.isEmpty) return null;
  final selectedMap = ref.watch(selectedMapProvider);
  final mode = ref.watch(
    patchClashConfigProvider.select((state) => state.mode),
  );

  Group group;
  if (mode == Mode.global) {
    group = groups.firstWhere(
      (item) => item.name == GroupName.GLOBAL.name,
      orElse: () => groups.first,
    );
  } else {
    group = groups.firstWhere(
      (item) => item.hidden != true && item.name != GroupName.GLOBAL.name,
      orElse: () => groups.first,
    );
  }
  if (group.all.isEmpty) return null;
  final selectedName = selectedMap[group.name] ?? group.now ?? '';
  if (selectedName.isEmpty) return group.all.first;
  return group.all.firstWhere(
    (proxy) => proxy.name == selectedName,
    orElse: () => group.all.first,
  );
}

class _DeviceHealthRow extends ConsumerWidget {
  const _DeviceHealthRow({this.fallbackDeviceLimit});

  final int? fallbackDeviceLimit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final summary = ref.watch(deviceHealthSummaryProvider);
    final fallbackLimitText =
        fallbackDeviceLimit == null || fallbackDeviceLimit == 0
            ? l10n.xboardDeviceUnlimited
            : '$fallbackDeviceLimit';
    return _HealthRow(
      icon: Icons.devices_outlined,
      title: l10n.xboardDeviceHealth,
      value: summary.when(
        data: (data) => l10n.xboardDeviceSummary(
          data.activeCount,
          data.deviceLimitText(l10n),
        ),
        loading: () => l10n.loading,
        error: (_, __) => l10n.xboardDeviceSummary('-', fallbackLimitText),
      ),
      healthy: !summary.hasError,
    );
  }
}

class _EndpointHealthCard extends StatelessWidget {
  const _EndpointHealthCard({
    required this.icon,
    required this.title,
    required this.summary,
    required this.business,
    required this.fallbackHealthy,
    required this.fallbackText,
  });

  final IconData icon;
  final String title;
  final AsyncValue<ServiceEndpointHealthSnapshot> summary;
  final bool business;
  final bool fallbackHealthy;
  final String fallbackText;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return summary.when(
      loading: () => _buildContainer(
        context,
        healthy: fallbackHealthy,
        headerValue: l10n.xboardServiceCheckingEndpoints,
        children: const [
          Padding(
            padding: EdgeInsets.fromLTRB(12, 2, 12, 14),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        ],
      ),
      error: (_, __) => _buildContainer(
        context,
        healthy: false,
        headerValue: l10n.xboardServiceStatusUnavailable,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            child: Text(
              fallbackText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
      data: (snapshot) {
        final items = business ? snapshot.businessApis : snapshot.gateways;
        final supported = !business || snapshot.businessStatusSupported;
        final unsupported = business &&
            snapshot.businessStatusError == ServiceEndpointState.unsupported;
        final healthyCount = items.where((item) => item.healthy).length;
        final headerValue = items.isEmpty
            ? unsupported
                ? l10n.xboardServiceStatusUnsupported
                : supported
                    ? fallbackText
                    : l10n.xboardServiceStatusUnavailable
            : l10n.xboardServiceAvailableCount(healthyCount, items.length);
        final healthy = items.isEmpty
            ? fallbackHealthy && supported
            : healthyCount > 0 &&
                items.any((item) => item.active && item.healthy);
        return _buildContainer(
          context,
          healthy: healthy,
          headerValue: headerValue,
          children: [
            if (business && snapshot.businessStatusSource.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Text(
                  '${l10n.xboardServiceStatusSource}: ${snapshot.businessStatusSource}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                child: Text(
                  headerValue,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              for (final item in _activeFirst(items))
                _EndpointStatusRow(item: item, business: business),
          ],
        );
      },
    );
  }

  Widget _buildContainer(
    BuildContext context, {
    required bool healthy,
    required String headerValue,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    final statusColor = healthy
        ? XbUiStatusColor.success(context)
        : XbUiStatusColor.pending(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.12),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          childrenPadding: EdgeInsets.zero,
          leading: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: statusColor, size: 18),
          ),
          title: Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: XbFontWeight.bold,
            ),
          ),
          subtitle: Text(
            headerValue,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          children: children,
        ),
      ),
    );
  }

  List<ServiceEndpointHealthItem> _activeFirst(
    List<ServiceEndpointHealthItem> source,
  ) {
    final result = List<ServiceEndpointHealthItem>.from(source);
    result.sort((a, b) {
      if (a.active != b.active) return a.active ? -1 : 1;
      return a.index.compareTo(b.index);
    });
    return result;
  }
}

class _EndpointStatusRow extends StatelessWidget {
  const _EndpointStatusRow({required this.item, required this.business});

  final ServiceEndpointHealthItem item;
  final bool business;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final color = _statusColor(context, item.state);
    final role = item.active
        ? l10n.xboardServiceInUse
        : item.primary
            ? l10n.xboardServicePrimary
            : l10n.xboardServiceBackup(item.index - 1);
    final endpointName = business
        ? l10n.xboardBusinessApiLabel(item.index)
        : l10n.xboardGatewayApiLabel(item.index);
    final details = <String>[
      _stateLabel(l10n, item.state),
      if (item.latencyMs != null && item.latencyMs! >= 0)
        l10n.xboardServiceLatency(item.latencyMs!),
      if (item.recoveryRequired > 0 &&
          item.recoverySuccessCount > 0 &&
          item.state == ServiceEndpointState.recovering)
        l10n.xboardServiceRecoveryProgress(
          item.recoverySuccessCount,
          item.recoveryRequired,
        ),
      if (item.circuitRemainingSeconds > 0)
        l10n.xboardServiceCircuitRemaining(item.circuitRemainingSeconds),
      if (item.statusCode != null) 'HTTP ${item.statusCode}',
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        endpointName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: XbFontWeight.semibold,
                        ),
                      ),
                    ),
                    Text(
                      role,
                      style: theme.textTheme.labelSmall?.copyWith(color: color),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  item.address,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  details.join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(BuildContext context, ServiceEndpointState state) {
    return switch (state) {
      ServiceEndpointState.healthy => XbUiStatusColor.success(context),
      ServiceEndpointState.recovering ||
      ServiceEndpointState.circuitOpen =>
        XbUiStatusColor.pending(context),
      ServiceEndpointState.unknown ||
      ServiceEndpointState.unsupported =>
        Theme.of(context).colorScheme.onSurfaceVariant,
      _ => Theme.of(context).colorScheme.error,
    };
  }

  String _stateLabel(
    AppLocalizations l10n,
    ServiceEndpointState state,
  ) {
    return switch (state) {
      ServiceEndpointState.healthy => l10n.xboardServiceStateHealthy,
      ServiceEndpointState.recovering => l10n.xboardServiceStateRecovering,
      ServiceEndpointState.circuitOpen => l10n.xboardServiceStateCircuitOpen,
      ServiceEndpointState.timeout => l10n.xboardServiceStateTimeout,
      ServiceEndpointState.serviceError => l10n.xboardServiceStateServerError,
      ServiceEndpointState.unreachable => l10n.xboardServiceStateUnreachable,
      ServiceEndpointState.unavailable => l10n.xboardServiceStateUnavailable,
      ServiceEndpointState.unsupported ||
      ServiceEndpointState.unknown =>
        l10n.xboardServiceStateUnknown,
    };
  }
}

class _HelperHealthRow extends StatelessWidget {
  const _HelperHealthRow({required this.summary});

  final AsyncValue<WindowsHelperRuntimeStatus?> summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (!Platform.isWindows) {
      return _HealthRow(
        icon: Icons.admin_panel_settings_outlined,
        title: l10n.xboardHealthHelper,
        value: l10n.xboardHealthHelperNotRequired,
        healthy: true,
      );
    }
    return summary.when(
      data: (status) {
        final healthy = status?.tokenMatches == true;
        return _HealthRow(
          icon: Icons.admin_panel_settings_outlined,
          title: l10n.xboardHealthHelper,
          value: healthy
              ? l10n.xboardHealthHelperAvailable
              : l10n.xboardHealthHelperUnavailable,
          detail: status == null
              ? l10n.xboardHealthHelperNoResponse
              : [
                  'version=${status.version.isEmpty ? '-' : status.version}',
                  'core=${status.coreRunning ? 'running' : 'stopped'}',
                  'pid=${status.corePid ?? '-'}',
                  'servicePathMatches=${status.servicePathMatches ?? '-'}',
                  if (status.recentLogs.isNotEmpty)
                    'stderr=${status.recentLogs.last.trim()}',
                ].join('\n'),
          healthy: healthy,
        );
      },
      loading: () => _HealthRow(
        icon: Icons.admin_panel_settings_outlined,
        title: l10n.xboardHealthHelper,
        value: l10n.xboardHealthHelperChecking,
        healthy: true,
      ),
      error: (error, _) => _HealthRow(
        icon: Icons.admin_panel_settings_outlined,
        title: l10n.xboardHealthHelper,
        value: l10n.xboardHealthHelperCheckFailed,
        detail: SensitiveMasker.maskText(error.toString()),
        healthy: false,
      ),
    );
  }
}

class _SystemProxyHealthRow extends StatelessWidget {
  const _SystemProxyHealthRow({
    required this.summary,
    required this.configuredEnabled,
  });

  final AsyncValue<_SystemProxyHealth> summary;
  final bool configuredEnabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (!system.isDesktop) {
      return _HealthRow(
        icon: Icons.settings_ethernet,
        title: l10n.systemProxy,
        value: l10n.xboardHealthHelperNotRequired,
        healthy: true,
      );
    }
    return summary.when(
      data: (health) {
        final value = health.tunActive
            ? l10n.xboardProxyStatusTunActive
            : !health.coreRunning
                ? (health.actualEnabled
                    ? l10n.xboardProxyStatusStale
                    : l10n.xboardHealthDisabled)
                : !health.configuredEnabled
                    ? l10n.xboardProxyStatusClientDisabled
                    : !health.listening
                        ? l10n.xboardProxyStatusPortUnavailable
                        : !health.actualAvailable
                            ? l10n.xboardProxyStatusReadFailed
                            : !health.actualEnabled
                                ? l10n.xboardProxyStatusSystemDisabled
                                : !health.actualMatches
                                    ? l10n.xboardProxyStatusMismatch
                                    : l10n.xboardHealthEnabled;
        final actual = !health.actualAvailable
            ? l10n.xboardNetworkDiagnosticsUnavailable
            : !health.actualEnabled
                ? l10n.xboardHealthDisabled
                : '${health.actualHost ?? '-'}:${health.actualPort ?? '-'}';
        return _HealthRow(
          icon: Icons.settings_ethernet,
          title: l10n.systemProxy,
          value: value,
          detail: [
            '${l10n.xboardProxyExpectedAddress}: ${health.expectedHost}:${health.expectedPort}',
            '${l10n.xboardProxyLocalPort}: ${health.listening ? l10n.xboardProxyListening : l10n.xboardProxyNotListening}',
            '${l10n.xboardProxyActualAddress}: $actual',
            '${l10n.xboardProxyClientSetting}: ${configuredEnabled ? l10n.xboardHealthEnabled : l10n.xboardHealthDisabled}',
            if (health.source?.isNotEmpty == true)
              '${l10n.xboardProxyStatusSource}: ${health.source}',
          ].join('\n'),
          healthy: health.healthy,
        );
      },
      loading: () => _HealthRow(
        icon: Icons.settings_ethernet,
        title: l10n.systemProxy,
        value: l10n.xboardHealthHelperChecking,
        healthy: true,
      ),
      error: (error, _) => _HealthRow(
        icon: Icons.settings_ethernet,
        title: l10n.systemProxy,
        value: l10n.xboardProxyStatusReadFailed,
        detail: SensitiveMasker.maskText(error.toString()),
        healthy: false,
      ),
    );
  }
}

class _SystemProxyHealth {
  const _SystemProxyHealth({
    required this.coreRunning,
    required this.tunActive,
    required this.configuredEnabled,
    required this.expectedHost,
    required this.expectedPort,
    required this.listening,
    required this.actualAvailable,
    required this.actualEnabled,
    required this.actualConsistent,
    this.actualHost,
    this.actualPort,
    this.source,
  });

  factory _SystemProxyHealth.notRequired({
    required int expectedPort,
    required bool tunActive,
  }) {
    return _SystemProxyHealth(
      coreRunning: false,
      tunActive: tunActive,
      configuredEnabled: false,
      expectedHost: '127.0.0.1',
      expectedPort: expectedPort,
      listening: false,
      actualAvailable: false,
      actualEnabled: false,
      actualConsistent: false,
    );
  }

  final bool coreRunning;
  final bool tunActive;
  final bool configuredEnabled;
  final String expectedHost;
  final int expectedPort;
  final bool listening;
  final bool actualAvailable;
  final bool actualEnabled;
  final bool actualConsistent;
  final String? actualHost;
  final int? actualPort;
  final String? source;

  bool get actualMatches =>
      actualAvailable &&
      actualEnabled &&
      actualConsistent &&
      actualHost == expectedHost &&
      actualPort == expectedPort;

  bool get healthy {
    if (tunActive) return true;
    if (!coreRunning) return !actualEnabled;
    return configuredEnabled && listening && actualMatches;
  }
}

class _HealthRow extends StatelessWidget {
  const _HealthRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.healthy,
    this.detail,
  });

  final IconData icon;
  final String title;
  final String value;
  final String? detail;
  final bool healthy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = healthy
        ? XbUiStatusColor.success(context)
        : XbUiStatusColor.pending(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: statusColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: XbFontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (detail != null && detail!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    detail!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.72),
                      height: 1.25,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            healthy ? Icons.check_circle : Icons.info,
            color: statusColor,
            size: 18,
          ),
        ],
      ),
    );
  }
}

class _ConnectionSectionHeader extends StatelessWidget {
  const _ConnectionSectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: XbFontWeight.bold,
        ),
      ),
    );
  }
}
