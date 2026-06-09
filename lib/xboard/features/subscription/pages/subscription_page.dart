import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:fl_clash/xboard/features/shared/widgets/widgets.dart';

// ─── Traffic Log Model ────────────────────────────────────────────────────────

class _TrafficLogEntry {
  final DateTime date;
  final int uploadBytes;
  final int downloadBytes;
  final double serverRate;

  const _TrafficLogEntry({
    required this.date,
    required this.uploadBytes,
    required this.downloadBytes,
    required this.serverRate,
  });

  int get totalBytes => uploadBytes + downloadBytes;

  factory _TrafficLogEntry.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v) => v == null
        ? 0
        : v is num
            ? v.toInt()
            : int.tryParse(v.toString()) ?? 0;
    double parseDouble(dynamic v, double def) => v == null
        ? def
        : v is num
            ? v.toDouble()
            : double.tryParse(v.toString()) ?? def;
    return _TrafficLogEntry(
      date: DateTime.fromMillisecondsSinceEpoch(
          parseInt(json['record_at']) * 1000),
      uploadBytes: parseInt(json['u']),
      downloadBytes: parseInt(json['d']),
      serverRate: parseDouble(json['server_rate'], 1.0),
    );
  }
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage>
    with SingleTickerProviderStateMixin {
  List<_TrafficLogEntry> _logs = [];
  bool _isLoading = true;
  String? _error;
  late final AnimationController _refreshAnim;

  @override
  void initState() {
    super.initState();
    _refreshAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fetchLogs();
  }

  @override
  void dispose() {
    _refreshAnim.dispose();
    super.dispose();
  }

  Future<void> _doRefresh() async {
    _refreshAnim.repeat();
    await _fetchLogs();
    if (mounted) {
      final remaining = 1.0 - _refreshAnim.value;
      if (remaining > 0.01) {
        await _refreshAnim.animateTo(
          1.0,
          duration: Duration(milliseconds: (remaining * 700).round()),
        );
      }
      _refreshAnim.stop();
      _refreshAnim.reset();
    }
  }

  Future<void> _fetchLogs() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final httpService = XBoardSDK.instance.httpService;
      final result = await httpService.getRequest('/user/stat/getTrafficLog');
      final data = result['data'];

      List<dynamic> rawList = [];
      if (data is List) {
        rawList = data;
      } else if (data is Map) {
        // Some versions nest under a key
        rawList = data.values.whereType<List>().expand((e) => e).toList();
      }

      final logs = rawList
          .whereType<Map<String, dynamic>>()
          .map((e) => _TrafficLogEntry.fromJson(e))
          .toList();

      // Sort by date descending
      logs.sort((a, b) => b.date.compareTo(a.date));

      if (mounted) {
        setState(() {
          _logs = logs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? null : XbUiTokens.pageBackgroundLight,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).xboardTrafficDetails),
        actions: [
          if (Platform.isLinux || Platform.isWindows || Platform.isMacOS || system.isTV)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _doRefresh,
              ),
            ),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return XbErrorState(
        message: _error!,
        onRetry: _fetchLogs,
      );
    }

    if (_logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_outlined,
                size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context).xboardNoTrafficRecords,
                style: XbUiText.sectionTitle(context)
                    .copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _doRefresh,
            child: ListView.builder(
              padding: XbUiTokens.pagePadding,
              itemCount: _logs.length,
              itemBuilder: (context, index) =>
                  _TrafficLogCard(entry: _logs[index]),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 10),
          child: Center(
            child: Text(
              AppLocalizations.of(context).xboardTrafficLogHint,
              style: XbUiText.bodySmall(context).copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Traffic Log Card ─────────────────────────────────────────────────────────

class _TrafficLogCard extends StatelessWidget {
  final _TrafficLogEntry entry;
  const _TrafficLogCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr =
        '${entry.date.year}-${entry.date.month.toString().padLeft(2, '0')}-${entry.date.day.toString().padLeft(2, '0')}';
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 0,
      margin: XbUiTokens.listCardGapBottom10,
      color: isDark ? null : Colors.white,
      shape: XbUiCardStyle.shape(context, radius: XbUiTokens.radiusCardCompact),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: date
            Row(
              children: [
                Icon(Icons.calendar_today_outlined,
                    size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  dateStr,
                  style: XbUiText.cardTitle(context).copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Stats row
            Row(
              children: [
                _StatItem(
                  icon: Icons.upload_outlined,
                  label: AppLocalizations.of(context).upload,
                  value: _formatBytes(entry.uploadBytes.toDouble()),
                  color: XbUiStatusColor.info(context),
                ),
                _VertDivider(),
                _StatItem(
                  icon: Icons.download_outlined,
                  label: AppLocalizations.of(context).download,
                  value: _formatBytes(entry.downloadBytes.toDouble()),
                  color: XbUiStatusColor.success(context),
                ),
                _VertDivider(),
                _StatItem(
                  icon: Icons.data_usage_outlined,
                  label: AppLocalizations.of(context).xboardTotal,
                  value: _formatBytes(entry.totalBytes.toDouble()),
                  color: XbUiStatusColor.offset(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatBytes(double bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    double size = bytes;
    int i = 0;
    while (size >= 1024 && i < units.length - 1) {
      size /= 1024;
      i++;
    }
    return size >= 100
        ? '${size.toStringAsFixed(0)} ${units[i]}'
        : size >= 10
            ? '${size.toStringAsFixed(1)} ${units[i]}'
            : '${size.toStringAsFixed(2)} ${units[i]}';
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatItem(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(color: color),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.25),
    );
  }
}
