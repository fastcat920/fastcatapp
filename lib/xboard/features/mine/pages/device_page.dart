import 'package:flutter/material.dart';
import 'dart:io';
import 'package:fl_clash/common/common.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';
import 'package:fl_clash/xboard/features/auth/providers/session_epoch_provider.dart';
import 'package:fl_clash/xboard/features/mine/services/device_gateway_request.dart';
import 'package:fl_clash/xboard/features/auth/pages/qr_login_scanner_page.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:fl_clash/xboard/features/shared/widgets/xb_error_state.dart';
import 'package:fl_clash/xboard/features/shared/widgets/xb_dialog.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:fl_clash/xboard/utils/backend_message_mapper.dart';

class DeviceManagementPage extends ConsumerStatefulWidget {
  const DeviceManagementPage({super.key});

  @override
  ConsumerState<DeviceManagementPage> createState() =>
      _DeviceManagementPageState();
}

class _DeviceManagementPageState extends ConsumerState<DeviceManagementPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _refreshAnim;
  late Future<_DevicePageData> _future;
  bool _isRefreshing = false;
  bool _isReleasingOfflineDevices = false;
  String? _removingDeviceId;

  @override
  void initState() {
    super.initState();
    _refreshAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _future = _loadPageData();
    ref.listenManual(sessionEpochProvider, (_, __) {
      if (!mounted) return;
      setState(() => _future = _loadPageData());
    });
    ref.listenManual(xboardUserAuthProvider, (previous, next) {
      if (mounted &&
          next.isAuthenticated &&
          !next.isLoading &&
          (previous?.isLoading == true || previous?.isAuthenticated != true)) {
        setState(() => _future = _loadPageData());
      }
    });
  }

  @override
  void dispose() {
    _refreshAnim.dispose();
    super.dispose();
  }

  Future<void> _refreshPage() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    setState(() {
      _future = _loadPageData();
    });
    _refreshAnim.repeat();
    try {
      await _future;
    } finally {
      if (mounted && _refreshAnim.isAnimating) {
        final remaining = 1.0 - (_refreshAnim.value % 1.0);
        await _refreshAnim.animateTo(
          _refreshAnim.value + remaining,
          duration: Duration(milliseconds: (remaining * 700).round()),
        );
        if (mounted) {
          _refreshAnim.stop();
          _refreshAnim.reset();
        }
      }
      _isRefreshing = false;
      if (mounted) setState(() {});
    }
  }

  Future<_DevicePageData> _loadPageData() async {
    final epoch = ref.read(sessionEpochProvider);
    final sdk = await ref.read(xboardSdkProvider.future);

    // Send heartbeat first so last_seen_at is current before querying
    try {
      await _requestFromDeviceGateway<void>(
        sdk,
        epoch,
        (http, headers) => http.postRequest(
          '/user/devices/heartbeat',
          <String, dynamic>{},
          headers: headers,
        ),
      );
    } catch (_) {
      // Non-critical: device list will still load even if heartbeat fails
    }

    final response = await _requestFromDeviceGateway(
      sdk,
      epoch,
      (http, headers) => http.getRequest(
        '/user/devices',
        headers: headers,
      ),
    );
    final data = _mapOf(response['data']);
    final rawDevices = data?['devices'];
    final devices = <_DeviceRecordView>[];
    if (rawDevices is List) {
      for (final item in rawDevices) {
        final map = _mapOf(item);
        if (map == null) continue;
        devices.add(_DeviceRecordView.fromJson(map));
      }
    }

    final activeDevices = devices.where((d) => d.isActive).toList();
    final historyDevices = devices.where((d) => !d.isActive).toList();

    return _DevicePageData(
      activeDevices: activeDevices,
      historyDevices: historyDevices,
      activeCount: _intFromAny(data?['active_count']),
      deviceLimit: _intFromAnyOrNull(data?['device_limit']),
    );
  }

  Future<T> _requestFromDeviceGateway<T>(
    XBoardSDK sdk,
    int epoch,
    Future<T> Function(HttpService http, Map<String, String> headers) request,
  ) =>
      requestDeviceGateway(
        sdk: sdk,
        isCurrent: () => _isCurrent(epoch),
        request: request,
      );

  bool _isCurrent(int epoch) =>
      mounted &&
      ref.read(sessionEpochProvider) == epoch &&
      ref.read(xboardUserAuthProvider).isAuthenticated &&
      !ref.read(xboardUserAuthProvider).isLoading;

  Future<void> _deleteDevice(_DeviceRecordView device) async {
    if (_removingDeviceId != null || _isReleasingOfflineDevices) return;
    final epoch = ref.read(sessionEpochProvider);
    final l10n = AppLocalizations.of(context);
    final confirmed = await XbConfirmDialog.show(
      context,
      title: l10n.xboardDeviceRemoveTitle,
      message: device.isCurrent
          ? l10n.xboardDeviceRemoveCurrentConfirm
          : '${l10n.remove} "${device.deviceName}"?',
      confirmLabel: l10n.remove,
      cancelLabel: l10n.cancel,
      tone: XbDialogTone.danger,
      icon: Icons.devices_other_outlined,
    );
    if (!confirmed || !_isCurrent(epoch)) return;

    setState(() => _removingDeviceId = device.id);
    try {
      final sdk = await ref.read(xboardSdkProvider.future);
      await _requestFromDeviceGateway<void>(
        sdk,
        epoch,
        (http, headers) => http.deleteRequest(
          '/user/devices/${device.id}',
          headers: headers,
        ),
      );

      if (!mounted || !_isCurrent(epoch)) return;
      XBoardNotification.showSuccess(
          AppLocalizations.of(context).xboardDeviceRemoved);

      if (device.isCurrent) {
        // 当前设备已在服务端移除，本地登录凭证不再有效，必须完成退出。
        await ref
            .read(xboardUserProvider.notifier)
            .logout(allowWhenServiceUnavailable: true);
        if (mounted) {
          context.go('/login');
        }
        return;
      }

      await _refreshPage();
    } catch (e) {
      if (_isCurrent(epoch)) {
        XBoardNotification.showError(
          BackendMessageMapper.mapError(
            e,
            context: BackendMessageContext.generic,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _removingDeviceId = null);
    }
  }

  Future<void> _releaseOfflineDevices(_DevicePageData data) async {
    if (_isReleasingOfflineDevices || _removingDeviceId != null) return;
    final epoch = ref.read(sessionEpochProvider);
    final targets = data.offlineActiveDevices;
    if (targets.isEmpty) return;

    final l10n = AppLocalizations.of(context);
    final confirmed = await XbConfirmDialog.show(
      context,
      title: l10n.xboardReleaseOfflineDevices,
      message: l10n.xboardReleaseOfflineDevicesConfirm,
      confirmLabel: l10n.remove,
      cancelLabel: l10n.cancel,
      tone: XbDialogTone.danger,
      icon: Icons.cleaning_services_outlined,
    );
    if (!confirmed || !_isCurrent(epoch)) return;

    setState(() => _isReleasingOfflineDevices = true);
    try {
      final sdk = await ref.read(xboardSdkProvider.future);
      for (final device in targets) {
        await _requestFromDeviceGateway<void>(
          sdk,
          epoch,
          (http, headers) => http.deleteRequest(
            '/user/devices/${device.id}',
            headers: headers,
          ),
        );
      }

      if (!mounted || !_isCurrent(epoch)) return;
      XBoardNotification.showSuccess(
        AppLocalizations.of(context).xboardDeviceRemoved,
      );
      await _refreshPage();
    } catch (e) {
      if (_isCurrent(epoch)) {
        XBoardNotification.showError(
          BackendMessageMapper.mapError(
            e,
            context: BackendMessageContext.generic,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isReleasingOfflineDevices = false);
    }
  }

  Widget _buildRefreshButton() {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: RotationTransition(
        turns: _refreshAnim,
        child: IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: AppLocalizations.of(context).refresh,
          onPressed: _isRefreshing ? null : _refreshPage,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = Platform.isAndroid || Platform.isIOS;

    return Scaffold(
      backgroundColor: isDark ? null : XbUiTokens.pageBackgroundLight,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).xboardDeviceManagement),
        actions: [
          if (isMobile)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: IconButton(
                tooltip: AppLocalizations.of(context).xboardQrLogin,
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const QrLoginScannerPage(),
                  ),
                ),
              ),
            ),
          if (Platform.isLinux ||
              Platform.isWindows ||
              Platform.isMacOS ||
              system.isTV)
            _buildRefreshButton(),
        ],
      ),
      body: FutureBuilder<_DevicePageData>(
        key: ValueKey(ref.watch(sessionEpochProvider)),
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return XbErrorState(
              message: snapshot.error is DeviceGatewaySessionChanged
                  ? AppLocalizations.of(context).xboardDeviceGatewayRelogin
                  : BackendMessageMapper.mapError(snapshot.error,
                      context: BackendMessageContext.generic),
              onRetry: _refreshPage,
            );
          }

          final data = snapshot.data ?? const _DevicePageData();
          if (data.activeDevices.isEmpty && data.historyDevices.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refreshPage,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: XbUiTokens.pagePadding,
                children: [
                  _buildSummaryCard(data),
                  const SizedBox(height: 16),
                  _buildEmptyState(context),
                ],
              ),
            );
          }

          final activeCards = data.activeDevices.map((device) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildDeviceCard(device),
            );
          }).toList();

          final historyCards = data.historyDevices.map((device) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildDeviceCard(device),
            );
          }).toList();

          final children = <Widget>[
            _buildSummaryCard(data),
            const SizedBox(height: 16),
            ...activeCards,
          ];

          if (historyCards.isNotEmpty) {
            children.add(const SizedBox(height: 8));
            children.add(_buildHistorySection(context, historyCards));
          }

          return RefreshIndicator(
            onRefresh: _refreshPage,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: XbUiTokens.pagePadding,
              children: children,
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(_DevicePageData data) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final effectiveLimitText = data.deviceLimit == null
        ? l10n.xboardDeviceUnlimited
        : '${data.deviceLimit}';
    return Card(
      elevation: XbUiCardStyle.elevation(context),
      margin: EdgeInsets.zero,
      shadowColor: XbUiCardStyle.shadowColor(context),
      color: XbUiCardStyle.background(context),
      shape: XbUiCardStyle.shape(context),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.devices_outlined,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.xboardDeviceCurrentDeviceLabel,
                          style: XbUiText.cardTitle(context)),
                      const SizedBox(height: 4),
                      Text(
                        l10n.xboardDeviceSummary(
                            data.activeCount, effectiveLimitText),
                        style: XbUiText.bodySmall(
                          context,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.xboardDeviceAutoOfflineHint,
                        style: XbUiText.bodySmall(
                          context,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (data.offlineActiveDevices.isNotEmpty) ...[
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed:
                      _isReleasingOfflineDevices || _removingDeviceId != null
                          ? null
                          : () => _releaseOfflineDevices(data),
                  style: XbUiButton.filledDanger(
                    context,
                    busy: _isReleasingOfflineDevices,
                  ),
                  icon: _isReleasingOfflineDevices
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.link_off_outlined),
                  label: Text(l10n.xboardReleaseOfflineDevices),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 72),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.devices_other_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 14),
            Text(
              AppLocalizations.of(context).xboardDeviceNoRecords,
              style: XbUiText.sectionTitle(context).copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              AppLocalizations.of(context).xboardDeviceNoRecordsHint,
              textAlign: TextAlign.center,
              style: XbUiText.bodySmall(
                context,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection(BuildContext context, List<Widget> historyCards) {
    final theme = Theme.of(context);

    return Card(
      elevation: XbUiCardStyle.elevation(context),
      margin: EdgeInsets.zero,
      shadowColor: XbUiCardStyle.shadowColor(context),
      color: XbUiCardStyle.background(context),
      shape: XbUiCardStyle.shape(context),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        title: Row(
          children: [
            Icon(
              Icons.history_outlined,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              AppLocalizations.of(context).xboardDeviceHistory,
              style: XbUiText.cardTitle(context),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${historyCards.length}',
                style: XbUiText.bodySmall(
                  context,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            AppLocalizations.of(context).xboardDeviceHistoryHint,
            style: XbUiText.bodySmall(
              context,
              color: theme.colorScheme.outline,
            ),
          ),
        ),
        children: historyCards,
      ),
    );
  }

  Widget _buildDeviceCard(_DeviceRecordView device) {
    final theme = Theme.of(context);
    final isRevoked = device.status == 'revoked';
    final statusColor = device.isActive
        ? (device.isOnlineEffective
            ? XbUiStatusColor.success(context)
            : XbUiStatusColor.pending(context))
        : isRevoked
            ? XbUiStatusColor.error(context)
            : theme.colorScheme.primary;

    return Card(
      elevation: XbUiCardStyle.elevation(context),
      margin: EdgeInsets.zero,
      shadowColor: XbUiCardStyle.shadowColor(context),
      color: XbUiCardStyle.background(context),
      shape: XbUiCardStyle.shape(context),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    device.deviceName,
                    style: XbUiText.cardTitle(context),
                  ),
                ),
                _statusBadge(
                  context,
                  device.status,
                  statusColor,
                  isOnline: device.isOnlineEffective,
                ),
                const SizedBox(width: 8),
                if (!isRevoked)
                  IconButton(
                    tooltip: AppLocalizations.of(context).remove,
                    onPressed:
                        _removingDeviceId != null || _isReleasingOfflineDevices
                            ? null
                            : () => _deleteDevice(device),
                    icon: _removingDeviceId == device.id
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: XbUiStatusColor.error(context),
                            ),
                          )
                        : Icon(
                            Icons.delete_outline,
                            color: XbUiStatusColor.error(context),
                          ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _infoChip(
                    context, Icons.phone_android_outlined, device.platform),
                _infoChip(
                  context,
                  Icons.monitor_heart_outlined,
                  device.appVersion.isEmpty
                      ? AppLocalizations.of(context).xboardDeviceUnknownVersion
                      : device.appVersion,
                ),
                _infoChip(
                  context,
                  Icons.schedule_outlined,
                  '${AppLocalizations.of(context).xboardDeviceLabelLastOnline} ${_formatDateTime(device.lastSeenAt)}',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${AppLocalizations.of(context).xboardDeviceLabelId}: ${device.id}',
              style: XbUiText.bodySmall(
                context,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (device.osVersion.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '${AppLocalizations.of(context).xboardDeviceLabelOsVersion}: ${device.osVersion}',
                style: XbUiText.bodySmall(
                  context,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (device.lastIpRegion.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '${AppLocalizations.of(context).xboardDeviceLabelRegion}: ${device.lastIpRegion}',
                style: XbUiText.bodySmall(
                  context,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (device.revokedAt != null) ...[
              const SizedBox(height: 4),
              Text(
                '${AppLocalizations.of(context).xboardDeviceLabelRevokedAt}: ${_formatDateTime(device.revokedAt!)}',
                style: XbUiText.bodySmall(
                  context,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (device.revokedBy.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '${AppLocalizations.of(context).xboardDeviceLabelRevokedBy}: ${device.revokedBy}',
                style: XbUiText.bodySmall(
                  context,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (device.isCurrent) ...[
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context).xboardDeviceCurrentDeviceLabel,
                style: XbUiText.bodySmall(
                  context,
                  color: theme.colorScheme.primary,
                ).copyWith(fontWeight: XbFontWeight.semibold),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(BuildContext context, String status, Color color,
      {bool isOnline = false}) {
    final label = switch (status) {
      'active' when isOnline => AppLocalizations.of(context).xboardDeviceOnline,
      'active' => AppLocalizations.of(context).xboardOfflineButActive,
      'revoked' => AppLocalizations.of(context).xboardDeviceRevoked,
      'expired' => AppLocalizations.of(context).xboardDeviceExpired,
      _ => status.isEmpty
          ? AppLocalizations.of(context).xboardDeviceUnknown
          : status,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: XbUiText.bodySmall(
          context,
          color: color,
        ).copyWith(fontWeight: XbFontWeight.semibold),
      ),
    );
  }

  Widget _infoChip(BuildContext context, IconData icon, String label) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: XbUiText.bodySmall(
              context,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  static Map<String, dynamic>? _mapOf(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return null;
  }

  static int _intFromAny(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static int? _intFromAnyOrNull(dynamic value) {
    if (value == null) return null;
    final parsed = _intFromAny(value);
    return parsed <= 0 ? null : parsed;
  }
}

class _DevicePageData {
  final List<_DeviceRecordView> activeDevices;
  final List<_DeviceRecordView> historyDevices;
  final int activeCount;
  final int? deviceLimit;

  const _DevicePageData({
    this.activeDevices = const [],
    this.historyDevices = const [],
    this.activeCount = 0,
    this.deviceLimit,
  });

  List<_DeviceRecordView> get offlineActiveDevices => activeDevices
      .where((device) => !device.isCurrent && !device.isOnlineEffective)
      .toList();
}

class _DeviceRecordView {
  final String id;
  final String deviceName;
  final String platform;
  final String appVersion;
  final String osVersion;
  final String status;
  final DateTime lastSeenAt;
  final DateTime? createdAt;
  final DateTime? revokedAt;
  final String revokedBy;
  final String lastIp;
  final String lastIpRegion;
  final String lastIpIsp;
  final bool isCurrent;
  final bool isOnline;

  const _DeviceRecordView({
    required this.id,
    required this.deviceName,
    required this.platform,
    required this.appVersion,
    required this.osVersion,
    required this.status,
    required this.lastSeenAt,
    required this.createdAt,
    required this.revokedAt,
    required this.revokedBy,
    required this.lastIp,
    required this.lastIpRegion,
    required this.lastIpIsp,
    required this.isCurrent,
    required this.isOnline,
  });

  bool get isActive => status == 'active';

  bool get isOnlineEffective {
    if (!isActive) return false;
    if (isOnline) return true;
    final now = DateTime.now();
    final lastSeen = lastSeenAt.toLocal();
    if (lastSeen.year <= 1970) return false;
    final diff = now.difference(lastSeen).abs();
    return diff <= const Duration(minutes: 5);
  }

  factory _DeviceRecordView.fromJson(Map<String, dynamic> json) {
    return _DeviceRecordView(
      id: json['id']?.toString() ?? '',
      deviceName: json['device_name']?.toString() ?? '未知设备',
      platform: json['platform']?.toString() ?? 'unknown',
      appVersion: json['app_version']?.toString() ?? '',
      osVersion: json['os_version']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      lastSeenAt: DateTime.tryParse(json['last_seen_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      revokedAt: DateTime.tryParse(json['revoked_at']?.toString() ?? ''),
      revokedBy: json['revoked_by']?.toString() ?? '',
      lastIp: json['last_ip']?.toString() ?? '',
      lastIpRegion: json['last_ip_region']?.toString() ?? '',
      lastIpIsp: json['last_ip_isp']?.toString() ?? '',
      isCurrent: json['is_current'] == true,
      isOnline: json['is_online'] == true,
    );
  }
}
