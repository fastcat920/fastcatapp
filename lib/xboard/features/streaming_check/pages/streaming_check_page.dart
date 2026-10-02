import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fl_clash/common/sensitive_masker.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:fl_clash/xboard/features/streaming_check/models/streaming_test_result.dart';
import 'package:fl_clash/xboard/features/streaming_check/models/streaming_platform_brand.dart';
import 'package:fl_clash/xboard/features/streaming_check/services/streaming_check_service.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class StreamingCheckPage extends ConsumerStatefulWidget {
  const StreamingCheckPage({super.key});

  @override
  ConsumerState<StreamingCheckPage> createState() => _StreamingCheckPageState();
}

class _StreamingCheckPageState extends ConsumerState<StreamingCheckPage> {
  static const _cacheTtl = Duration(minutes: 10);
  static final Map<String, _StreamingCacheEntry> _cache = {};

  StreamingCheckRun? _activeRun;
  StreamSubscription<List<ConnectivityResult>>? _networkSubscription;
  static int _networkGeneration = 0;
  bool _selectionChanged = false;

  @override
  void initState() {
    super.initState();
    // Do not reuse a result across an unobserved network change while closed.
    _cache.clear();
    _networkSubscription = Connectivity().onConnectivityChanged.listen((_) {
      _networkGeneration++;
      _cache.clear();
      if (mounted && _running) {
        _invalidate(_isChinese
            ? '网络已变化，请重新检测'
            : 'Network changed. Run the check again.');
      }
    });
    _loadSelection();
  }

  Future<void> _loadSelection() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || _selectionChanged) return;
    final saved = prefs.getStringList('streaming_custom_targets_v1');
    final valid = StreamingCheckService.targets.map((e) => e.id).toSet();
    setState(() {
      if (saved != null) _customTargetIds = saved.toSet().intersection(valid);
      if (prefs.getString('streaming_check_mode_v1') == 'custom' &&
          _customTargetIds.isNotEmpty) {
        _mode = _StreamingCheckMode.custom;
      }
    });
  }

  Future<void> _saveSelection() async {
    _selectionChanged = true;
    final mode = _mode.name;
    final targets = _customTargetIds.toList()..sort();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('streaming_check_mode_v1', mode);
    await prefs.setStringList('streaming_custom_targets_v1', targets);
  }

  @override
  void dispose() {
    _runGeneration++;
    _activeRun?.cancel();
    _networkSubscription?.cancel();
    super.dispose();
  }

  bool _running = false;
  bool _copying = false;
  bool _checkingStoredNode = false;
  int _runGeneration = 0;
  String? _activeProfileScope;
  String get _profileScope {
    final profile = ref.read(currentProfileProvider);
    return '${profile?.id}|${profile?.lastUpdateDate}|${ref.read(runTimeProvider)}';
  }

  String? _nodeName;
  String? _region;
  DateTime? _generatedAt;
  String? _message;
  bool _invalidated = false;
  final List<StreamingTestResult> _results = [];
  _StreamingCheckMode _mode = _StreamingCheckMode.full;
  Set<String> _customTargetIds =
      StreamingCheckService.targets.map((target) => target.id).toSet();

  List<StreamingTarget> get _activeTargets => switch (_mode) {
        _StreamingCheckMode.full => StreamingCheckService.targets,
        _StreamingCheckMode.custom => StreamingCheckService.targets
            .where((target) => _customTargetIds.contains(target.id))
            .toList(growable: false),
      };

  Future<void> _start({bool forceRefresh = false}) async {
    if (_running || ref.read(runTimeProvider) == null) return;
    _selectionChanged = true;
    _activeProfileScope = _profileScope;
    final generation = ++_runGeneration;
    final run = _activeRun = StreamingCheckRun();
    final checker = StreamingCheckService(run: run);
    try {
      await _executeRun(generation, checker, forceRefresh);
    } catch (_) {
      if (mounted && generation == _runGeneration) {
        setState(() {
          _message =
              _isChinese ? '检测失败，请重试' : 'The check failed. Please try again.';
        });
      }
    } finally {
      unawaited(run.cancel());
      if (mounted && generation == _runGeneration) {
        setState(() => _running = false);
      }
    }
  }

  Future<void> _executeRun(
      int generation, StreamingCheckService checker, bool forceRefresh) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _running = true;
      _copying = false;
      _nodeName = null;
      _region = null;
      _generatedAt = null;
      _message = null;
      _invalidated = false;
      _results.clear();
    });

    final nodeName = await streamingCheckService.resolveCurrentNodeName();
    if (!mounted || generation != _runGeneration) return;
    if (nodeName == null) {
      setState(() {
        _running = false;
        _message = l10n.xboardStreamingNodeUnavailable;
      });
      return;
    }
    setState(() => _nodeName = nodeName);

    final targets = _activeTargets;
    final profile = ref.read(currentProfileProvider);
    final cacheKey = '${profile?.id}|${profile?.lastUpdateDate}|'
        '${ref.read(runTimeProvider)}|$_networkGeneration|$nodeName|'
        '${targets.map((item) => item.id).join(',')}';
    _cache.removeWhere((_, entry) =>
        DateTime.now().difference(entry.generatedAt) >= _cacheTtl);
    final cached = _cache[cacheKey];
    if (!forceRefresh &&
        cached != null &&
        DateTime.now().difference(cached.generatedAt) < _cacheTtl) {
      setState(() {
        _running = false;
        _region = cached.region;
        _generatedAt = cached.generatedAt;
        _results.addAll(cached.results);
        _message = _isChinese
            ? '已显示 10 分钟内的缓存结果'
            : 'Showing results cached within 10 minutes';
      });
      return;
    }

    final region = await checker.detectRegion(nodeName);
    if (!await _validateRun(generation, nodeName)) return;
    if (mounted) setState(() => _region = region);

    const batchSize = 3;
    for (var start = 0; start < targets.length; start += batchSize) {
      final end = (start + batchSize).clamp(0, targets.length);
      final batch = targets.sublist(start, end);
      final results = await Future.wait(
        batch.map(
          (target) => checker.testTarget(
            target,
            nodeName,
            region: region,
          ),
        ),
      );
      if (!await _validateRun(generation, nodeName)) return;
      if (mounted) setState(() => _results.addAll(results));
    }

    if (!mounted || generation != _runGeneration) return;
    setState(() {
      _running = false;
      _generatedAt = DateTime.now();
    });
    if (_cache.length >= 32) _cache.remove(_cache.keys.first);
    _cache[cacheKey] = _StreamingCacheEntry(
      generatedAt: _generatedAt!,
      region: region,
      results: List.unmodifiable(_results),
    );
  }

  bool get _isChinese => Localizations.localeOf(context).languageCode == 'zh';

  void _stop() {
    if (!_running) return;
    _runGeneration++;
    _activeRun?.cancel();
    setState(() {
      _running = false;
      _message = AppLocalizations.of(context).xboardStreamingCancelled;
    });
  }

  void _selectMode(_StreamingCheckMode mode) {
    if (mode == _StreamingCheckMode.custom) {
      _chooseCustomTargets();
      return;
    }
    setState(() {
      _mode = mode;
      _results.clear();
      _nodeName = null;
      _region = null;
      _message = null;
      _generatedAt = null;
    });
    unawaited(_saveSelection());
  }

  Future<void> _chooseCustomTargets() async {
    final selected = {..._customTargetIds};
    final allTargetIds =
        StreamingCheckService.targets.map((target) => target.id).toSet();
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Expanded(
                child: Text(_isChinese ? '选择检测项目' : 'Choose services'),
              ),
              Text(
                _isChinese ? '全选' : 'Select all',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Checkbox(
                value: selected.length == allTargetIds.length &&
                    selected.containsAll(allTargetIds),
                onChanged: (checked) => setDialogState(() {
                  if (checked == true) {
                    selected
                      ..clear()
                      ..addAll(allTargetIds);
                  } else {
                    selected.clear();
                  }
                }),
              ),
            ],
          ),
          content: SizedBox(
            width: 460,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final target in StreamingCheckService.targets)
                  CheckboxListTile(
                    value: selected.contains(target.id),
                    title: Text(target.name),
                    onChanged: (checked) => setDialogState(() {
                      if (checked == true) {
                        selected.add(target.id);
                      } else {
                        selected.remove(target.id);
                      }
                    }),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(_isChinese ? '取消' : 'Cancel'),
            ),
            FilledButton(
              onPressed: selected.isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, selected),
              child: Text(_isChinese ? '确定' : 'Done'),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _mode = _StreamingCheckMode.custom;
      _customTargetIds = result;
      _results.clear();
      _nodeName = null;
      _region = null;
      _message = null;
      _generatedAt = null;
    });
    unawaited(_saveSelection());
  }

  Future<bool> _validateRun(int generation, String nodeName) async {
    if (!mounted || generation != _runGeneration) return false;
    if (ref.read(runTimeProvider) == null) {
      _invalidate(AppLocalizations.of(context).xboardStreamingDisconnected);
      return false;
    }
    if (_activeProfileScope != _profileScope) {
      _invalidate(_isChinese
          ? '订阅或连接已变化，请重新检测'
          : 'Subscription or connection changed. Run the check again.');
      return false;
    }
    final currentNode = await streamingCheckService.resolveCurrentNodeName();
    if (!mounted || generation != _runGeneration) return false;
    if (currentNode != nodeName) {
      _invalidate(AppLocalizations.of(context).xboardStreamingNodeChanged);
      return false;
    }
    return true;
  }

  void _invalidate(String message) {
    _runGeneration++;
    _activeRun?.cancel();
    _cache.clear();
    if (!mounted) return;
    setState(() {
      _running = false;
      _invalidated = true;
      _message = message;
    });
  }

  Future<void> _verifyStoredNode() async {
    if (_running ||
        _checkingStoredNode ||
        _results.isEmpty ||
        _invalidated ||
        _nodeName == null) {
      return;
    }
    _checkingStoredNode = true;
    try {
      final currentNode = await streamingCheckService.resolveCurrentNodeName();
      if (mounted && currentNode != _nodeName) {
        _invalidate(AppLocalizations.of(context).xboardStreamingNodeChanged);
      }
    } finally {
      _checkingStoredNode = false;
    }
  }

  Future<void> _copyReport() async {
    if (_results.isEmpty || _copying) return;
    setState(() => _copying = true);
    try {
      final l10n = AppLocalizations.of(context);
      final report = StringBuffer()
        ..writeln(l10n.xboardStreamingReportTitle)
        ..writeln()
        ..writeln(
          '${l10n.xboardStreamingReportTime}: '
          '${_formatDateTime(_generatedAt ?? DateTime.now())}',
        )
        ..writeln(
          '${l10n.xboardStreamingReportVersion}: '
          '${globalState.packageInfo.version}+${globalState.packageInfo.buildNumber}',
        )
        ..writeln(
            '${l10n.xboardStreamingReportSystem}: ${Platform.operatingSystem}')
        ..writeln('${l10n.xboardStreamingCurrentNode}: [redacted-node]')
        ..writeln('${l10n.xboardStreamingExitRegion}: ${_region ?? '-'}')
        ..writeln();
      for (final result in _results) {
        final httpStatus =
            result.statusCode == null ? 'HTTP -' : 'HTTP ${result.statusCode}';
        report
          ..writeln('${result.target.name}:')
          ..writeln(
            '${_statusText(l10n, result.status)} / '
            '${result.region ?? '-'} / ${result.elapsedMs}ms / $httpStatus',
          );
        if (result.detail?.isNotEmpty == true) {
          report.writeln(
            '${l10n.xboardStreamingReportDetail}: '
            '${SensitiveMasker.maskText(result.detail!)}',
          );
        }
        report.writeln();
      }
      report
        ..writeln(
          '${l10n.xboardStreamingSummary}: '
          '${l10n.xboardStreamingSummaryAccessible} $_confirmedAccessibleCount / '
          '${l10n.xboardStreamingSummaryPartial} $_partiallyAccessibleCount / '
          '${l10n.xboardStreamingSummaryRestricted} $_restrictedCount / '
          '${l10n.xboardStreamingSummaryVerification} $_verificationCount / '
          '${l10n.xboardStreamingSummaryInconclusive} $_inconclusiveCount',
        )
        ..writeln(l10n.xboardStreamingDisclaimer);
      await Clipboard.setData(ClipboardData(text: report.toString()));
      XBoardNotification.showSuccess(l10n.xboardStreamingReportCopied);
    } finally {
      if (mounted) setState(() => _copying = false);
    }
  }

  int get _accessibleCount => _results
      .where(
        (result) =>
            result.status == StreamingTestStatus.accessible ||
            result.status == StreamingTestStatus.partiallyAccessible,
      )
      .length;

  int get _confirmedAccessibleCount => _results
      .where((result) => result.status == StreamingTestStatus.accessible)
      .length;

  int get _partiallyAccessibleCount => _results
      .where(
        (result) => result.status == StreamingTestStatus.partiallyAccessible,
      )
      .length;

  int get _restrictedCount => _results
      .where(
        (result) =>
            result.status == StreamingTestStatus.restricted ||
            result.status == StreamingTestStatus.blocked ||
            result.status == StreamingTestStatus.unavailable,
      )
      .length;

  int get _verificationCount => _results
      .where(
        (result) => result.status == StreamingTestStatus.verificationRequired,
      )
      .length;

  int get _inconclusiveCount => _results
      .where(
        (result) =>
            result.status == StreamingTestStatus.uncertain ||
            result.status == StreamingTestStatus.timeout ||
            result.status == StreamingTestStatus.error ||
            result.status == StreamingTestStatus.cancelled,
      )
      .length;

  String _formatDateTime(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}/${two(value.month)}/${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}';
  }

  String _statusText(AppLocalizations l10n, StreamingTestStatus status) {
    return switch (status) {
      StreamingTestStatus.accessible => l10n.xboardStreamingAccessible,
      StreamingTestStatus.partiallyAccessible =>
        l10n.xboardStreamingPartiallyAccessible,
      StreamingTestStatus.restricted => l10n.xboardStreamingRestricted,
      StreamingTestStatus.blocked => l10n.xboardStreamingBlocked,
      StreamingTestStatus.verificationRequired =>
        l10n.xboardStreamingVerificationRequired,
      StreamingTestStatus.uncertain => l10n.xboardStreamingUncertain,
      StreamingTestStatus.unavailable => l10n.xboardStreamingUnavailable,
      StreamingTestStatus.timeout => l10n.xboardStreamingTimeout,
      StreamingTestStatus.error => l10n.xboardStreamingError,
      StreamingTestStatus.cancelled => l10n.xboardStreamingCancelled,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final connected = ref.watch(runTimeProvider) != null;
    ref.listen(runTimeProvider, (previous, next) {
      if (previous != null &&
          next == null &&
          (_running || _results.isNotEmpty)) {
        _invalidate(l10n.xboardStreamingDisconnected);
      }
    });
    ref.listen(groupsProvider, (previous, next) {
      unawaited(_verifyStoredNode());
    });

    return Scaffold(
      backgroundColor: XbUiTokens.pageBackground(context),
      appBar: AppBar(
        title: Text(l10n.xboardStreamingCheck),
        backgroundColor: XbUiTokens.pageBackground(context),
        surfaceTintColor: Colors.transparent,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            children: [
              _Panel(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _StatusLine(
                        connected: connected,
                        nodeName: _nodeName,
                      ),
                      const SizedBox(height: 14),
                      SegmentedButton<_StreamingCheckMode>(
                        segments: [
                          ButtonSegment(
                            value: _StreamingCheckMode.full,
                            label: Text(_isChinese ? '完整' : 'Full'),
                          ),
                          ButtonSegment(
                            value: _StreamingCheckMode.custom,
                            label: Text(_isChinese ? '自定义' : 'Custom'),
                          ),
                        ],
                        selected: {_mode},
                        onSelectionChanged: _running
                            ? null
                            : (value) => _selectMode(value.first),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: !connected || _running
                                ? null
                                : () => _start(
                                      forceRefresh: _results.isNotEmpty,
                                    ),
                            style: XbUiButton.filledPrimary(
                              context,
                              busy: _running,
                            ),
                            icon: _running
                                ? SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimary,
                                    ),
                                  )
                                : const Icon(Icons.play_arrow),
                            label: Text(
                              _running
                                  ? l10n.xboardStreamingChecking
                                  : _results.isEmpty
                                      ? l10n.xboardStreamingStart
                                      : l10n.xboardStreamingRetest,
                            ),
                          ),
                          if (_running)
                            OutlinedButton.icon(
                              onPressed: _stop,
                              icon: const Icon(Icons.stop_circle_outlined),
                              label: Text(_isChinese ? '停止' : 'Stop'),
                            ),
                          OutlinedButton.icon(
                            onPressed: _running || _copying || _results.isEmpty
                                ? null
                                : _copyReport,
                            icon: _copying
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.copy_outlined),
                            label: Text(l10n.xboardStreamingCopyReport),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (!connected || _message != null) ...[
                const SizedBox(height: 12),
                _MessageCard(
                  message: _message ?? l10n.xboardStreamingConnectFirst,
                ),
              ],
              if (_nodeName != null) ...[
                const SizedBox(height: 16),
                Text(
                  l10n.xboardStreamingSummary,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: XbFontWeight.bold,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                _SummaryCard(
                  nodeName: _nodeName!,
                  region: _region,
                  completed: _results.length,
                  accessible: _accessibleCount,
                  total: _activeTargets.length,
                ),
              ],
              if (_results.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  l10n.xboardStreamingResults,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: XbFontWeight.bold,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 760 ? 2 : 1;
                    final width = columns == 2
                        ? (constraints.maxWidth - 12) / 2
                        : constraints.maxWidth;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        for (final result in _results)
                          SizedBox(
                            width: width,
                            child: _ResultCard(
                              result: result,
                              statusText: _statusText(l10n, result.status),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                if (_running) ...[
                  const SizedBox(height: 12),
                  const _CheckingMoreIndicator(),
                ],
              ],
              const SizedBox(height: 16),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    l10n.xboardStreamingDisclaimer,
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _StreamingCheckMode { full, custom }

class _StreamingCacheEntry {
  const _StreamingCacheEntry({
    required this.generatedAt,
    required this.region,
    required this.results,
  });

  final DateTime generatedAt;
  final String? region;
  final List<StreamingTestResult> results;
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: XbUiCardStyle.elevation(context),
      shadowColor: XbUiCardStyle.shadowColor(context),
      color: XbUiCardStyle.background(context),
      shape: XbUiCardStyle.shape(context, radius: 16),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _CheckingMoreIndicator extends StatelessWidget {
  const _CheckingMoreIndicator();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: color,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              AppLocalizations.of(context).xboardStreamingChecking,
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: XbFontWeight.semibold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.connected, required this.nodeName});

  final bool connected;
  final String? nodeName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final color = connected
        ? XbUiStatusColor.success(context)
        : theme.colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(connected ? Icons.shield : Icons.shield_outlined, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                connected
                    ? l10n.xboardStreamingConnected
                    : l10n.xboardStreamingNotConnected,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: XbFontWeight.bold,
                ),
              ),
              if (nodeName != null)
                Text(
                  '${l10n.xboardStreamingCurrentNode}: $nodeName',
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final color = XbUiStatusColor.pending(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.nodeName,
    required this.region,
    required this.completed,
    required this.accessible,
    required this.total,
  });

  final String nodeName;
  final String? region;
  final int completed;
  final int accessible;
  final int total;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _Panel(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            _SummaryRow(
              label: l10n.xboardStreamingCurrentNode,
              value: nodeName,
            ),
            const SizedBox(height: 8),
            _SummaryRow(
              label: l10n.xboardStreamingExitRegion,
              value: region ?? l10n.xboardStreamingUnknown,
            ),
            const SizedBox(height: 8),
            _SummaryRow(
              label: l10n.xboardStreamingProgress,
              value: '$completed/$total',
            ),
            const SizedBox(height: 8),
            _SummaryRow(
              label: l10n.xboardStreamingAccessibleCount,
              value: '$accessible/$total',
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: XbFontWeight.semibold,
            ),
          ),
        ),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.result,
    required this.statusText,
  });

  final StreamingTestResult result;
  final String statusText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final healthy = result.status == StreamingTestStatus.accessible;
    final warning = result.status == StreamingTestStatus.partiallyAccessible ||
        result.status == StreamingTestStatus.verificationRequired ||
        result.status == StreamingTestStatus.uncertain ||
        result.status == StreamingTestStatus.timeout;
    final color = healthy
        ? XbUiStatusColor.success(context)
        : warning
            ? XbUiStatusColor.pending(context)
            : XbUiStatusColor.error(context);
    final brand = StreamingPlatformBrand.forId(result.target.id);
    final brandColor = brand.colorFor(theme.brightness);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: XbUiCardStyle.background(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: XbUiTokens.cardBorder(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: brandColor.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.16 : 0.11,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: _StreamingBrandLogo(brand: brand, color: brandColor),
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
                        result.target.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: XbFontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      statusText,
                      textAlign: TextAlign.right,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: color,
                        fontWeight: XbFontWeight.semibold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        result.region ?? '-',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    TextButton.icon(
                      onPressed: () => launchUrl(
                        Uri.parse(result.target.url),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(Icons.open_in_new, size: 13),
                      label: Text(
                        AppLocalizations.of(context).xboardStreamingVisit,
                        style: const TextStyle(fontSize: 11),
                      ),
                      style: XbUiButton.textChipPrimary(context).copyWith(
                        minimumSize: const WidgetStatePropertyAll(Size(0, 28)),
                        padding: const WidgetStatePropertyAll(
                          EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StreamingBrandLogo extends StatelessWidget {
  const _StreamingBrandLogo({required this.brand, required this.color});

  final StreamingPlatformBrand brand;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (brand.icon != null) {
      return Icon(brand.icon, color: color, size: 21);
    }
    return Center(
      child: Text(
        brand.mark,
        maxLines: 1,
        style: TextStyle(
          color: color,
          fontSize: brand.mark.length > 2 ? 9 : 14,
          fontWeight: FontWeight.w900,
          letterSpacing: brand.mark.length > 2 ? -0.6 : -0.2,
        ),
      ),
    );
  }
}
