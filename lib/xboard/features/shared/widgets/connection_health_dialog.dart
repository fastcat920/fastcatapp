import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
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

class ConnectionHealthDialog extends ConsumerWidget {
  const ConnectionHealthDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const ConnectionHealthDialog(),
    );
  }

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

    return AlertDialog(
      shape: XbUiDialog.shape(),
      backgroundColor: XbUiDialog.background(context),
      titlePadding: const EdgeInsets.fromLTRB(22, 20, 14, 0),
      contentPadding: const EdgeInsets.fromLTRB(22, 14, 22, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: Row(
        children: [
          Icon(
            allHealthy ? Icons.verified_outlined : Icons.health_and_safety,
            color: allHealthy
                ? XbUiStatusColor.success(context)
                : theme.colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(l10n.xboardConnectionHealth)),
          IconButton(
            tooltip: l10n.cancel,
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.xboardConnectionHealthSubtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
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
                detail: subscriptionStatus?.getDetailMessage(context),
                healthy: subscriptionOk,
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
              _DeviceHealthRow(
                  fallbackDeviceLimit: subscriptionInfo?.deviceLimit),
            ],
          ),
        ),
      ),
      actions: [
        TextButton.icon(
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
        TextButton.icon(
          onPressed: () async {
            await ref.read(initializationProvider.notifier).refresh();
            await ref
                .read(xboardUserProvider.notifier)
                .refreshSubscriptionInfo();
          },
          icon: const Icon(Icons.refresh),
          label: Text(l10n.xboardRefreshStatus),
        ),
      ],
    );
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
        return '${gatewayDisplayLabel(baseUrl)}'
            '${_normalizeApiPrefix(sdk.httpService.apiPrefix)}';
      }
    }
    if (fallback == null) return '';
    return '${gatewayDisplayLabel(fallback.baseUrl)}${fallback.apiPrefix}';
  }

  static String _normalizeApiPrefix(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.startsWith('/') ? trimmed : '/$trimmed';
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
