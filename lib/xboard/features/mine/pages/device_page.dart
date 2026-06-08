import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:fl_clash/common/common.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';
import 'package:fl_clash/xboard/config/xboard_config.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:fl_clash/xboard/features/shared/widgets/xb_error_state.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:fl_clash/xboard/config/gateway_config.dart';

/// 网关 API 前缀（与 gateway_config.dart 的 gatewayApiPrefix 一致）
/// 设备管理接口是网关私有端点，前缀必须与网关 DG_API_PREFIX 匹配
const _deviceGatewayApiPrefix = gatewayApiPrefix;

class DeviceManagementPage extends ConsumerStatefulWidget {
  const DeviceManagementPage({super.key});

  @override
  ConsumerState<DeviceManagementPage> createState() =>
      _DeviceManagementPageState();
}

class _DeviceManagementPageState extends ConsumerState<DeviceManagementPage>
    with SingleTickerProviderStateMixin {
  @override
  void activate() {
    super.activate();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
  }

  late final AnimationController _refreshAnim;
  late Future<_DevicePageData> _future;

  @override
  void initState() {
    super.initState();
    _refreshAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _future = _loadPageData();
  }

  @override
  void dispose() {
    _refreshAnim.dispose();
    super.dispose();
  }

  Future<void> _refreshPage() async {
    setState(() {
      _future = _loadPageData();
    });
    _refreshAnim.repeat();
    try {
      await _future;
    } finally {
      if (_refreshAnim.isAnimating) {
        final remaining = 1.0 - (_refreshAnim.value % 1.0);
        await _refreshAnim.animateTo(
          _refreshAnim.value + remaining,
          duration: Duration(milliseconds: (remaining * 700).round()),
        );
        _refreshAnim.stop();
        _refreshAnim.reset();
      }
    }
  }

  Future<_DevicePageData> _loadPageData() async {
    final sdk = await ref.read(xboardSdkProvider.future);

    // Send heartbeat first so last_seen_at is current before querying
    try {
      await _requestFromDeviceGateway<void>(
        sdk,
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
    Future<T> Function(HttpService http, Map<String, String> headers) request,
  ) async {
    final token = await sdk.getToken();
    if (token == null || token.isEmpty || !token.contains('dg_')) {
      throw Exception('当前登录会话不是设备网关会话，请退出后重新登录');
    }
    final headers = <String, String>{
      'Authorization': token,
    };
    Object? lastError;

    // 优先复用 SDK 自身的 httpService：共享连接池、auth 拦截器、故障转移
    try {
      return await request(sdk.httpService, headers);
    } catch (e) {
      lastError = e;
    }

    // 回退：通过解析订阅 URL 等方式推测网关地址
    final endpoints = _resolveDeviceGatewayEndpoints();
    for (final endpoint in endpoints) {
      try {
        final http = await HttpService.create(
          endpoint.baseUrl,
          httpConfig: HttpConfig.development(),
          apiPrefix: endpoint.apiPrefix,
        );
        return await request(http, headers);
      } catch (e) {
        lastError = e;
      }
    }

    throw lastError ?? Exception('设备网关请求失败');
  }


  List<_DeviceGatewayEndpoint> _resolveDeviceGatewayEndpoints() {
    final endpoints = <_DeviceGatewayEndpoint>[];
    final seen = <String>{};

    void addEndpoint(String baseUrl, String apiPrefix) {
      final base = baseUrl.trim().replaceAll(RegExp(r'/$'), '');
      final prefix = _normalizeApiPrefix(apiPrefix);
      if (base.isEmpty || prefix.isEmpty) return;
      final key = '$base|$prefix';
      if (seen.add(key)) {
        endpoints.add(_DeviceGatewayEndpoint(base, prefix));
      }
    }

    void addFromBaseUrl(String url, {String? apiPrefix}) {
      final uri = Uri.tryParse(url.trim());
      if (uri == null || !uri.hasScheme || uri.host.isEmpty) return;
      final origin = _originFromUri(uri);
      final pathPrefix =
          uri.path.isNotEmpty && uri.path != '/' ? uri.path : null;
      addEndpoint(origin, apiPrefix ?? pathPrefix ?? _configuredApiPrefix());
    }

    final runtime = GatewayRuntimeService.instance;
    runtime.syncFromCurrentConfig();

    final active = runtime.activeConfig;
    if (active != null) {
      addEndpoint(active.baseUrl, active.apiPrefix);
    }
    for (final candidate in runtime.candidates) {
      addEndpoint(candidate.baseUrl, candidate.apiPrefix);
    }

    addFromBaseUrl(
      XBoardSDK.instance.httpService.baseUrl,
      apiPrefix: XBoardSDK.instance.httpService.apiPrefix,
    );
    addFromBaseUrl(productionGatewayUrl, apiPrefix: _deviceGatewayApiPrefix);

    return endpoints;
  }

  String _configuredApiPrefix() {
    try {
      if (XBoardConfig.isInitialized) {
        return XBoardConfig.provider.getApiPrefix();
      }
    } catch (_) {}
    return _deviceGatewayApiPrefix;
  }

  static String _normalizeApiPrefix(String value) {
    var prefix = value.trim();
    if (prefix.isEmpty || prefix == '/') return _deviceGatewayApiPrefix;
    if (!prefix.startsWith('/')) prefix = '/$prefix';
    return prefix.replaceAll(RegExp(r'/$'), '');
  }

  static String _originFromUri(Uri uri) {
    return uri.replace(path: '', query: '', fragment: '').toString();
  }

  Future<void> _deleteDevice(_DeviceRecordView device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: XbUiDialog.shape(),
        backgroundColor: XbUiDialog.background(dialogContext),
        title: Text(AppLocalizations.of(dialogContext).xboardDeviceRemoveTitle, style: XbUiText.sectionTitle(dialogContext)),
        content: Text(
          device.isCurrent
              ? AppLocalizations.of(dialogContext).xboardDeviceRemoveCurrentConfirm
              : '${AppLocalizations.of(dialogContext).remove} "${device.deviceName}"?',
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: XbUiButton.outlinedNeutral(dialogContext),
            child: Text(AppLocalizations.of(dialogContext).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: XbUiButton.filledDanger(dialogContext),
            child: Text(AppLocalizations.of(dialogContext).remove),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final sdk = await ref.read(xboardSdkProvider.future);
    await _requestFromDeviceGateway<void>(
      sdk,
      (http, headers) => http.deleteRequest(
        '/user/devices/${device.id}',
        headers: headers,
      ),
    );

    if (!mounted) return;
    XBoardNotification.showSuccess(AppLocalizations.of(context).xboardDeviceRemoved);

    if (device.isCurrent) {
      await ref.read(xboardUserProvider.notifier).logout();
      if (mounted) {
        context.go('/login');
      }
      return;
    }

    await _refreshPage();
  }

  Widget _buildRefreshButton() {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: RotationTransition(
        turns: _refreshAnim,
        child: IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: AppLocalizations.of(context).refresh,
          onPressed: _refreshPage,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? null : XbUiTokens.pageBackgroundLight,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).xboardDeviceManagement),
        actions: [
if (Platform.isLinux || Platform.isWindows || Platform.isMacOS || system.isTV)
                      _buildRefreshButton(),
        ],
      ),
      body: FutureBuilder<_DevicePageData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return XbErrorState(
              message: snapshot.error.toString(),
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
    final isDark = theme.brightness == Brightness.dark;
    final effectiveLimitText =
        data.deviceLimit == null ? '无限制' : '${data.deviceLimit} 台';
    return Card(
      elevation: isDark ? 0 : 1,
      margin: EdgeInsets.zero,
      shadowColor: isDark ? null : Colors.black.withValues(alpha: 0.08),
      color: isDark ? null : Colors.white,
      shape: XbUiCardStyle.shape(context),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
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
                  Text(AppLocalizations.of(context).xboardDeviceCurrentDeviceLabel, style: XbUiText.cardTitle(context)),
                  const SizedBox(height: 4),
                  Text(
                    AppLocalizations.of(context).xboardDeviceSummary(data.activeCount, effectiveLimitText),
                    style: XbUiText.bodySmall(
                      context,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppLocalizations.of(context).xboardDeviceAutoOfflineHint,
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

  Widget _buildHistorySection(
      BuildContext context, List<Widget> historyCards) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: isDark ? 0 : 1,
      margin: EdgeInsets.zero,
      shadowColor: isDark ? null : Colors.black.withValues(alpha: 0.08),
      color: isDark ? null : Colors.white,
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
    final isDark = theme.brightness == Brightness.dark;
    final isRevoked = device.status == 'revoked';
    final statusColor = device.isActive
        ? (device.isOnline ? XbUiStatusColor.success(context) : XbUiStatusColor.pending(context))
        : isRevoked
            ? XbUiStatusColor.error(context)
            : theme.colorScheme.primary;

    return Card(
      elevation: isDark ? 0 : 1,
      margin: EdgeInsets.zero,
      shadowColor: isDark ? null : Colors.black.withValues(alpha: 0.08),
      color: isDark ? null : Colors.white,
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
                _statusBadge(context, device.status, statusColor,
                    isOnline: device.isOnline),
                const SizedBox(width: 8),
                if (!isRevoked)
                  IconButton(
                    tooltip: AppLocalizations.of(context).remove,
                    onPressed: () => _deleteDevice(device),
                    icon: Icon(
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
                  device.appVersion.isEmpty ? AppLocalizations.of(context).xboardDeviceUnknownVersion : device.appVersion,
                ),
                _infoChip(
                  context,
                  Icons.schedule_outlined,
                  '最后在线 ${_formatDateTime(device.lastSeenAt)}',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '设备标识：${device.id}',
              style: XbUiText.bodySmall(
                context,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (device.osVersion.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '系统版本：${device.osVersion}',
                style: XbUiText.bodySmall(
                  context,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (device.lastIp.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '最近 IP：${device.lastIp}',
                style: XbUiText.bodySmall(
                  context,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (device.revokedAt != null) ...[
              const SizedBox(height: 4),
              Text(
                '移除时间：${_formatDateTime(device.revokedAt!)}',
                style: XbUiText.bodySmall(
                  context,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (device.revokedBy.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '移除来源：${device.revokedBy}',
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
                ).copyWith(fontWeight: FontWeight.w600),
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
      'active' => AppLocalizations.of(context).xboardDeviceOffline,
      'revoked' => AppLocalizations.of(context).xboardDeviceRevoked,
      'expired' => AppLocalizations.of(context).xboardDeviceExpired,
      _ => status.isEmpty ? AppLocalizations.of(context).xboardDeviceUnknown : status,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: XbUiText.bodySmall(
          context,
          color: color,
        ).copyWith(fontWeight: FontWeight.w600),
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

class _DeviceGatewayEndpoint {
  final String baseUrl;
  final String apiPrefix;

  const _DeviceGatewayEndpoint(this.baseUrl, this.apiPrefix);
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
    required this.isCurrent,
    required this.isOnline,
  });

  bool get isActive => status == 'active';

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
      isCurrent: json['is_current'] == true,
      isOnline: json['is_online'] == true,
    );
  }
}
