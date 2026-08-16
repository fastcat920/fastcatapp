import 'dart:async';
import 'dart:io';

import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:fl_clash/xboard/features/streaming_check/models/streaming_test_result.dart';
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
  bool _running = false;
  bool _copying = false;
  bool _checkingStoredNode = false;
  int _runGeneration = 0;
  String? _nodeName;
  String? _region;
  DateTime? _generatedAt;
  String? _message;
  bool _invalidated = false;
  final List<StreamingTestResult> _results = [];

  Future<void> _start() async {
    if (_running || ref.read(runTimeProvider) == null) return;
    final l10n = AppLocalizations.of(context);
    final generation = ++_runGeneration;
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

    final region = await streamingCheckService.detectRegion(nodeName);
    if (!await _validateRun(generation, nodeName)) return;
    if (mounted) setState(() => _region = region);

    const batchSize = 3;
    final targets = StreamingCheckService.targets;
    for (var start = 0; start < targets.length; start += batchSize) {
      final end = (start + batchSize).clamp(0, targets.length);
      final batch = targets.sublist(start, end);
      final results = await Future.wait(
        batch.map(
          (target) => streamingCheckService.testTarget(
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
  }

  Future<bool> _validateRun(int generation, String nodeName) async {
    if (!mounted || generation != _runGeneration) return false;
    if (ref.read(runTimeProvider) == null) {
      _invalidate(AppLocalizations.of(context).xboardStreamingDisconnected);
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
        ..writeln('${l10n.xboardStreamingCurrentNode}: ${_nodeName ?? '-'}')
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
          report
              .writeln('${l10n.xboardStreamingReportDetail}: ${result.detail}');
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

  IconData _serviceIcon(String id) {
    return switch (id) {
      'youtube' => Icons.play_circle_outline,
      'chatgpt' ||
      'claude' ||
      'gemini' ||
      'copilot' ||
      'grok' ||
      'google_ai_studio' =>
        Icons.auto_awesome_outlined,
      'tiktok' => Icons.smart_display_outlined,
      'prime_video' => Icons.video_library_outlined,
      _ => Icons.live_tv_outlined,
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
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: !connected || _running ? null : _start,
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
                  total: StreamingCheckService.targets.length,
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
                              icon: _serviceIcon(result.target.id),
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
    required this.icon,
    required this.statusText,
  });

  final StreamingTestResult result;
  final IconData icon;
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
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 19),
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
