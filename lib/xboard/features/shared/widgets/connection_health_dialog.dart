import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';
import 'package:fl_clash/xboard/config/gateway_config.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/xboard/features/initialization/initialization.dart';
import 'package:fl_clash/xboard/features/profile/providers/profile_import_provider.dart';
import 'package:fl_clash/xboard/features/shared/services/diagnostic_bundle_service.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:fl_clash/xboard/features/subscription/services/subscription_status_service.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';

final _deviceHealthSummaryProvider =
    FutureProvider.autoDispose<_DeviceHealthSummary>((ref) async {
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
  return _DeviceHealthSummary(
    activeCount: _intFromAny(data?['active_count']),
    deviceLimit: _intFromAnyOrNull(data?['device_limit']),
  );
});

final _windowsHelperStatusProvider =
    FutureProvider.autoDispose<WindowsHelperRuntimeStatus?>((ref) async {
  if (!Platform.isWindows) return null;
  return request.getHelperRuntimeStatus();
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

class ConnectionHealthView extends ConsumerWidget {
  const ConnectionHealthView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    final businessApiLabel = _resolveBusinessApiLabel(activeGateway);
    final helperStatus = ref.watch(_windowsHelperStatusProvider);
    final networkProps = ref.watch(networkSettingProvider);
    final patchConfig = ref.watch(patchClashConfigProvider);
    final realTunEnable = ref.watch(realTunEnableProvider);
    final proxyState = ref.watch(proxyStateProvider);
    final overrideDns = ref.watch(overrideDnsProvider);

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
    final latestEvent = gatewayRuntime.recentEvents.isNotEmpty
        ? gatewayRuntime.recentEvents.last.message
        : null;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      children: [
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
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          l10n.xboardConnectionHealthSubtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        _HealthRow(
          icon: Icons.cloud_done_outlined,
          title: l10n.xboardServerStatus,
          value: initState.isReady
              ? l10n.xboardHealthy
              : initState.currentStepDescription ??
                  initState.errorMessage ??
                  l10n.xboardNeedsAttention,
          detail: businessApiLabel.isEmpty
              ? null
              : '${l10n.xboardCurrentBusinessApi}: $businessApiLabel',
          healthy: initState.isReady,
        ),
        _HealthRow(
          icon: Icons.hub_outlined,
          title: l10n.xboardGatewayStatus,
          value: activeGateway == null
              ? l10n.xboardNoGatewayActive
              : '${l10n.xboardCurrentGateway}: '
                  '${gatewayDisplayLabel(activeGateway.baseUrl)}',
          detail: [
            l10n.xboardGatewayCandidateCount(
              gatewayRuntime.candidates.length,
            ),
            if (latestEvent != null)
              '${l10n.xboardHealthLastEvent}: $latestEvent',
          ].join('\n'),
          healthy: gatewayOk,
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
        _DeviceHealthRow(fallbackDeviceLimit: subscriptionInfo?.deviceLimit),
        _HelperHealthRow(summary: helperStatus),
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
        _HealthRow(
          icon: Icons.settings_ethernet,
          title: l10n.systemProxy,
          value: networkProps.systemProxy
              ? l10n.xboardHealthEnabled
              : l10n.xboardHealthDisabled,
          detail: 'running=${proxyState.isStart}, port=${proxyState.port}',
          healthy: !networkProps.systemProxy || proxyState.isStart,
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
            await DiagnosticBundleService.copy(ref);
            if (context.mounted) {
              XBoardNotification.showSuccess(
                l10n.xboardDiagnosticBundleCopied,
              );
            }
          },
          icon: const Icon(Icons.content_copy_outlined),
          label: Text(l10n.xboardCopyDiagnosticBundle),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            await ref.read(initializationProvider.notifier).refresh();
            await ref
                .read(xboardUserProvider.notifier)
                .refreshSubscriptionInfo();
            ref.invalidate(_windowsHelperStatusProvider);
          },
          icon: const Icon(Icons.refresh),
          label: Text(l10n.xboardRefreshStatus),
        ),
      ],
    );
  }

  static Future<void> _repairConnection(
    BuildContext context,
    WidgetRef ref,
  ) async {
    Future<void> runRepair() async {
      if (Platform.isWindows) {
        await windows?.registerService(forceRepair: true);
        ref.invalidate(_windowsHelperStatusProvider);
      }
      if (Platform.isWindows) {
        await Process.run('ipconfig', ['/flushdns']);
      } else if (Platform.isMacOS) {
        await system.setMacOSDns(true);
      }
      final proxyState = ref.read(proxyStateProvider);
      await proxy?.stopProxy();
      if (proxyState.isStart && proxyState.systemProxy) {
        await proxy?.startProxy(proxyState.port, proxyState.bassDomain);
      }
      if (ref.read(currentProfileProvider) != null) {
        await globalState.appController.applyProfile(silence: true);
      }
      await ref.read(initializationProvider.notifier).refresh();
      await ref.read(xboardUserProvider.notifier).refreshSubscriptionInfo(
            importProfile: false,
          );
    }

    final commonScaffoldState = context.commonScaffoldState;
    final l10n = AppLocalizations.of(context);
    if (commonScaffoldState?.mounted == true) {
      await commonScaffoldState!.loadingRun<void>(
        runRepair,
        title: l10n.xboardOneClickRepair,
      );
    } else {
      await runRepair();
    }
    if (context.mounted) {
      XBoardNotification.showSuccess(l10n.xboardRepairCompleted);
    }
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

  static String _resolveBusinessApiLabel(GatewayEndpointConfig? fallback) {
    final sdk = XBoardSDK.instance;
    if (sdk.isInitialized) {
      final baseUrl = sdk.httpService.baseUrl.trim();
      if (baseUrl.isNotEmpty) {
        return gatewayDisplayLabel(baseUrl);
      }
    }
    if (fallback == null) return '';
    return gatewayDisplayLabel(fallback.baseUrl);
  }

  static Proxy? _resolveCurrentProxy(WidgetRef ref) {
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
}

class _DeviceHealthRow extends ConsumerWidget {
  const _DeviceHealthRow({this.fallbackDeviceLimit});

  final int? fallbackDeviceLimit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final summary = ref.watch(_deviceHealthSummaryProvider);
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
                    fontWeight: FontWeight.w700,
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

class _DeviceHealthSummary {
  const _DeviceHealthSummary({
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
