import 'package:fl_clash/clash/core.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/common.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/xboard/config/gateway_config.dart';
import 'package:fl_clash/xboard/config/xboard_config.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';

import '../providers/app.dart';

class DeveloperView extends ConsumerWidget {
  const DeveloperView({super.key});

  Widget _getDeveloperList(BuildContext context, WidgetRef ref) {
    return generateSectionV2(
      title: appLocalizations.options,
      items: [
        ListItem(
          title: Text(appLocalizations.messageTest),
          onTap: () {
            context.showNotifier(
              appLocalizations.messageTestTip,
            );
          },
        ),
        ListItem(
          title: Text(appLocalizations.logsTest),
          onTap: () {
            for (int i = 0; i < 1000; i++) {
              ref.read(requestsProvider.notifier).addRequest(Connection(
                    id: utils.id,
                    start: DateTime.now(),
                    metadata: Metadata(
                      uid: i * i,
                      network: utils.generateRandomString(
                        maxLength: 1000,
                        minLength: 20,
                      ),
                      sourceIP: '',
                      sourcePort: '',
                      destinationIP: '',
                      destinationPort: '',
                      host: '',
                      process: '',
                      remoteDestination: '',
                    ),
                    chains: ['chains'],
                  ));
              globalState.appController.addLog(
                Log.app(
                  utils.generateRandomString(
                    maxLength: 200,
                    minLength: 20,
                  ),
                ),
              );
            }
          },
        ),
        ListItem(
          title: Text(appLocalizations.crashTest),
          onTap: () {
            clashCore.clashInterface.crash();
          },
        ),
        const ListItem.open(
          title: const Text('网关诊断'),
          subtitle: const Text('查看当前网关、生效前缀、熔断状态和最近切换事件'),
          delegate: OpenDelegate(
            title: '网关诊断',
            widget: _GatewayDiagnosticsPage(),
          ),
        ),
        const ListItem.open(
          title: const Text('API诊断'),
          subtitle: const Text('查看主业务 API 列表、探测状态和最近验证结果'),
          delegate: OpenDelegate(
            title: 'API诊断',
            widget: _ApiDiagnosticsPage(),
          ),
        ),
        ListItem(
          title: Text(appLocalizations.clearData),
          onTap: () async {
            await globalState.appController.handleClear();
          },
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context, ref) {
    final enable = ref.watch(
      appSettingProvider.select(
        (state) => state.developerMode,
      ),
    );
    final logCapture = ref.watch(
      appSettingProvider.select(
        (state) => state.logCapture,
      ),
    );
    return SingleChildScrollView(
      padding: baseInfoEdgeInsets,
      child: Column(
        children: [
          CommonCard(
            type: CommonCardType.filled,
            radius: 18,
            child: ListItem.switchItem(
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
              ),
              title: Text(appLocalizations.developerMode),
              delegate: SwitchDelegate(
                value: enable,
                onChanged: (value) {
                  ref.read(appSettingProvider.notifier).updateState(
                        (state) => state.copyWith(
                          developerMode: value,
                          // 关闭开发者模式时一并关闭日志捕获
                          logCapture: value ? state.logCapture : false,
                        ),
                      );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          CommonCard(
            type: CommonCardType.filled,
            radius: 18,
            child: ListItem.switchItem(
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
              ),
              title: const Text('日志捕获'),
              subtitle: const Text('开启后日志将在日志页面中显示'),
              delegate: SwitchDelegate(
                value: logCapture,
                onChanged: (value) {
                  ref.read(appSettingProvider.notifier).updateState(
                        (state) => state.copyWith(
                          logCapture: value,
                          // 联动核心日志：开启日志捕获时同时开启核心日志推送
                          openLogs: value ? true : state.openLogs,
                        ),
                      );
                  // XBoardLogger 由 application.dart ref.listen 统一切换
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          CommonCard(
            type: CommonCardType.filled,
            radius: 18,
            child: _LogLevelSelector(),
          ),
          const SizedBox(height: 16),
          _getDeveloperList(context, ref)
        ],
      ),
    );
  }
}

class _LogLevelSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logLevel =
        ref.watch(patchClashConfigProvider.select((state) => state.logLevel));
    return ListItem<LogLevel>.options(
      padding: const EdgeInsets.only(left: 16, right: 16),
      title: Text(appLocalizations.logLevel),
      subtitle: Text(logLevel.name),
      delegate: OptionsDelegate<LogLevel>(
        title: appLocalizations.logLevel,
        options: LogLevel.values,
        onChanged: (LogLevel? value) {
          if (value == null) return;
          ref.read(patchClashConfigProvider.notifier).updateState(
                (state) => state.copyWith(logLevel: value),
              );
        },
        textBuilder: (logLevel) => logLevel.name,
        value: logLevel,
      ),
    );
  }
}

class _GatewayDiagnosticsPage extends StatefulWidget {
  const _GatewayDiagnosticsPage();

  @override
  State<_GatewayDiagnosticsPage> createState() =>
      _GatewayDiagnosticsPageState();
}

class _GatewayDiagnosticsPageState extends State<_GatewayDiagnosticsPage> {
  late final GatewayRuntimeService _runtime;
  bool _isReverifying = false;
  bool _isClearingCircuits = false;

  @override
  void initState() {
    super.initState();
    _runtime = GatewayRuntimeService.instance;
    _runtime.bootstrapFromCurrentConfig();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<GatewayRuntimeSnapshot>(
      stream: _runtime.stream,
      initialData: GatewayRuntimeSnapshot(
        activeConfig: _runtime.activeConfig,
        lastKnownGoodConfig: _runtime.lastKnownGoodConfig,
        candidates: _runtime.candidates,
        activeVersionTag: _runtime.activeConfig?.versionTag,
      ),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final active = data?.activeConfig;
        final lastGood = data?.lastKnownGoodConfig;
        final candidates = data?.candidates ?? const <GatewayEndpointConfig>[];
        final events = _runtime.recentEvents;
        final openCircuits =
            candidates.where((candidate) => candidate.isCircuitOpen).length;

        return ListView(
          padding: baseInfoEdgeInsets,
          children: [
            CommonCard(
              type: CommonCardType.filled,
              radius: 18,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '当前状态',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    _KvRow(
                      label: 'Active URL',
                      value: active == null
                          ? '-'
                          : gatewayDisplayLabel(active.baseUrl),
                    ),
                    _KvRow(
                        label: 'API Prefix', value: active?.apiPrefix ?? '-'),
                    _KvRow(
                      label: 'Config Version',
                      value: data?.activeVersionTag ?? '-',
                    ),
                    _KvRow(
                      label: 'Last Good',
                      value: lastGood == null
                          ? '-'
                          : gatewayDisplayLabel(lastGood.baseUrl),
                    ),
                    _KvRow(
                      label: 'Candidates',
                      value: '${candidates.length}',
                    ),
                    _KvRow(
                      label: 'Open Circuits',
                      value: '$openCircuits',
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: _isReverifying
                              ? null
                              : () async {
                                  setState(() => _isReverifying = true);
                                  try {
                                    final results =
                                        await _runtime.reverifyAllCandidates(
                                      userAgent: globalState.ua,
                                    );
                                    if (!mounted) return;
                                    final failedCount = _runtime.candidates
                                        .where(
                                          (candidate) =>
                                              candidate.verificationStatus ==
                                                  GatewayVerificationStatus
                                                      .failed ||
                                              candidate.verificationStatus ==
                                                  GatewayVerificationStatus
                                                      .circuitOpen,
                                        )
                                        .length;
                                    context.showNotifier(
                                      '网关探测完成，可用 ${results.length} 个，失败 $failedCount 个',
                                    );
                                  } finally {
                                    if (mounted) {
                                      setState(() => _isReverifying = false);
                                    }
                                  }
                                },
                          icon: _isReverifying
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.monitor_heart_outlined),
                          label: Text(_isReverifying ? '探测中...' : '重新探测全部网关'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            await _copyGatewayDiagnosticsSummary(
                              context: context,
                              snapshot: GatewayRuntimeSnapshot(
                                activeConfig: _runtime.activeConfig,
                                lastKnownGoodConfig:
                                    _runtime.lastKnownGoodConfig,
                                candidates: _runtime.candidates,
                                activeVersionTag:
                                    _runtime.activeConfig?.versionTag,
                              ),
                              events: _runtime.recentEvents,
                            );
                          },
                          icon: const Icon(Icons.copy_all_outlined),
                          label: const Text('复制网关诊断摘要'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _isClearingCircuits
                              ? null
                              : () async {
                                  setState(() => _isClearingCircuits = true);
                                  try {
                                    await _runtime.clearCircuitBreakers();
                                    if (!mounted) return;
                                    context.showNotifier('已清空熔断状态');
                                  } finally {
                                    if (mounted) {
                                      setState(
                                        () => _isClearingCircuits = false,
                                      );
                                    }
                                  }
                                },
                          icon: _isClearingCircuits
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.restart_alt),
                          label: Text(
                            _isClearingCircuits ? '处理中...' : '清空熔断状态并重试',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            CommonCard(
              type: CommonCardType.filled,
              radius: 18,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '候选节点',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    if (candidates.isEmpty)
                      const Text('暂无候选节点')
                    else
                      for (final candidate in candidates) ...[
                        _CandidateTile(
                          candidate: candidate,
                          isActive: active?.baseUrl == candidate.baseUrl,
                        ),
                        if (candidate != candidates.last)
                          const Divider(height: 16),
                      ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            CommonCard(
              type: CommonCardType.filled,
              radius: 18,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '最近事件',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    if (events.isEmpty)
                      const Text('暂无事件')
                    else
                      for (final event in events.take(30)) ...[
                        _EventTile(event: event),
                        if (event != events.take(30).last)
                          const Divider(height: 16),
                      ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _KvRow extends StatelessWidget {
  final String label;
  final String value;

  const _KvRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontFamily: 'JetBrainsMono'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CandidateTile extends StatelessWidget {
  final GatewayEndpointConfig candidate;
  final bool isActive;

  const _CandidateTile({
    required this.candidate,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final status = _candidateStatus(candidate);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: SelectableText(
                gatewayDisplayLabel(candidate.baseUrl),
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'ACTIVE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.blue,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _MetaChip(label: 'Prefix', value: candidate.apiPrefix),
            _MetaChip(label: 'Source', value: candidate.source),
            _MetaChip(label: 'Version', value: candidate.versionTag ?? '-'),
            _MetaChip(
              label: 'HTTP',
              value: candidate.lastVerificationStatusCode?.toString() ?? '-',
            ),
            _MetaChip(
              label: 'Failures',
              value: '${candidate.failureCount}',
            ),
            _MetaChip(
              label: 'Status',
              value: status.$1,
              color: status.$2,
            ),
            _MetaChip(
              label: 'Disabled Until',
              value: candidate.disabledUntil == null
                  ? '-'
                  : _formatTs(candidate.disabledUntil!),
            ),
          ],
        ),
      ],
    );
  }

  (String, Color) _candidateStatus(GatewayEndpointConfig candidate) {
    switch (candidate.verificationStatus) {
      case GatewayVerificationStatus.circuitOpen:
        return ('熔断中', Colors.red);
      case GatewayVerificationStatus.verified:
        return ('已验证可用', Colors.green);
      case GatewayVerificationStatus.failed:
        return ('验证失败', Colors.orange);
      case GatewayVerificationStatus.unverified:
        return ('未验证', Colors.blueGrey);
    }
  }
}

class _PanelApiTile extends StatelessWidget {
  final String url;
  final String apiPrefix;
  final _ApiProbeResult? probeResult;

  const _PanelApiTile({
    required this.url,
    required this.apiPrefix,
    required this.probeResult,
  });

  @override
  Widget build(BuildContext context) {
    final ok = probeResult?.ok == true;
    final statusText = probeResult == null
        ? '未探测'
        : ok
            ? '已验证可用'
            : '验证失败';
    final statusColor = probeResult == null
        ? Colors.blueGrey
        : ok
            ? Colors.green
            : Colors.orange;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(
          gatewayDisplayLabel(url),
          style: const TextStyle(
            fontFamily: 'JetBrainsMono',
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        SelectableText(
          'API Root: ${gatewayDisplayLabel(url)}$apiPrefix',
          style: const TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _MetaChip(
              label: 'HTTP',
              value: probeResult?.statusCode?.toString() ?? '-',
            ),
            _MetaChip(
              label: 'Latency',
              value: probeResult?.latencyMs == null
                  ? '-'
                  : '${probeResult!.latencyMs} ms',
            ),
            _MetaChip(
              label: 'Status',
              value: statusText,
              color: statusColor,
            ),
            _MetaChip(
              label: 'Checked At',
              value: probeResult?.checkedAt == null
                  ? '-'
                  : _formatTs(probeResult!.checkedAt!),
            ),
          ],
        ),
        if (probeResult?.message != null) ...[
          const SizedBox(height: 8),
          SelectableText(
            'Message: ${probeResult!.message}',
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ],
    );
  }
}

enum _ApiDiagnosticEventType {
  probeStarted,
  probeSuccess,
  probeFailure,
  probeCompleted,
  summaryCopied,
}

class _ApiDiagnosticEvent {
  final DateTime timestamp;
  final _ApiDiagnosticEventType type;
  final String message;
  final Map<String, Object?> payload;

  const _ApiDiagnosticEvent({
    required this.timestamp,
    required this.type,
    required this.message,
    required this.payload,
  });
}

class _ApiDiagnosticEventTile extends StatelessWidget {
  final _ApiDiagnosticEvent event;

  const _ApiDiagnosticEventTile({
    required this.event,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_formatTs(event.timestamp)}  ${event.type.name}',
          style: const TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(event.message),
        if (event.payload.isNotEmpty) ...[
          const SizedBox(height: 6),
          SelectableText(
            event.payload.entries
                .map((entry) =>
                    '${entry.key}: ${_maskEventValue(entry.key, entry.value)}')
                .join('\n'),
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _MetaChip({
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (color ?? Colors.grey).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 12,
          color: color ?? Colors.grey.shade800,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ApiDiagnosticsPage extends StatefulWidget {
  const _ApiDiagnosticsPage();

  @override
  State<_ApiDiagnosticsPage> createState() => _ApiDiagnosticsPageState();
}

class _ApiDiagnosticsPageState extends State<_ApiDiagnosticsPage> {
  final Map<String, _ApiProbeResult> _panelApiProbeResults = {};
  final List<_ApiDiagnosticEvent> _events = [];
  bool _isProbing = false;

  @override
  void initState() {
    super.initState();
    _probePanelApis();
  }

  Future<void> _probePanelApis() async {
    if (_isProbing || !XBoardConfig.isInitialized) return;
    setState(() => _isProbing = true);
    try {
      final urls = XBoardConfig.allPanelUrls;
      final apiPrefix = XBoardConfig.provider.getApiPrefix();
      _recordApiEvent(
        type: _ApiDiagnosticEventType.probeStarted,
        message: '开始探测主业务API列表',
        payload: {
          'count': urls.length,
          'api_prefix': apiPrefix,
        },
      );
      final next = <String, _ApiProbeResult>{};
      for (final url in urls) {
        final result = await _probeApiEndpoint(url, apiPrefix);
        next[url] = result;
        _recordApiEvent(
          type: result.ok
              ? _ApiDiagnosticEventType.probeSuccess
              : _ApiDiagnosticEventType.probeFailure,
          message: result.ok ? '主业务API探测成功' : '主业务API探测失败',
          payload: {
            'url': url,
            'http': result.statusCode?.toString() ?? '-',
            'latency_ms': result.latencyMs?.toString() ?? '-',
            'message': result.message ?? '-',
          },
        );
      }
      _recordApiEvent(
        type: _ApiDiagnosticEventType.probeCompleted,
        message: '主业务API批量探测完成',
        payload: {
          'count': urls.length,
          'success': next.values.where((result) => result.ok).length,
          'failed': next.values.where((result) => !result.ok).length,
        },
      );
      if (!mounted) return;
      setState(() {
        _panelApiProbeResults
          ..clear()
          ..addAll(next);
      });
    } finally {
      if (mounted) {
        setState(() => _isProbing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final panelUrls = XBoardConfig.isInitialized
        ? XBoardConfig.allPanelUrls
        : const <String>[];
    final panelApiPrefix = XBoardConfig.isInitialized
        ? XBoardConfig.provider.getApiPrefix()
        : '/api/v1';
    final panelSummary = _buildPanelApiSummary(
      panelUrls: panelUrls,
      probeResults: _panelApiProbeResults,
    );

    return ListView(
      padding: baseInfoEdgeInsets,
      children: [
        CommonCard(
          type: CommonCardType.filled,
          radius: 18,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '主业务API状态',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                _KvRow(label: 'API Count', value: '${panelSummary.totalCount}'),
                _KvRow(
                    label: 'Available',
                    value: '${panelSummary.availableCount}'),
                _KvRow(label: 'Failed', value: '${panelSummary.failedCount}'),
                _KvRow(
                    label: 'Unverified',
                    value: '${panelSummary.unverifiedCount}'),
                _KvRow(label: 'API Prefix', value: panelApiPrefix),
                _KvRow(
                  label: 'First Available',
                  value: panelSummary.firstAvailableLabel,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: _isProbing ? null : _probePanelApis,
                      icon: _isProbing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.monitor_heart_outlined),
                      label: Text(_isProbing ? '探测中...' : '重新探测全部主业务API'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await _copyApiDiagnosticsSummary(
                          context: context,
                          panelUrls: panelUrls,
                          panelApiPrefix: panelApiPrefix,
                          panelProbeResults: _panelApiProbeResults,
                        );
                        _recordApiEvent(
                          type: _ApiDiagnosticEventType.summaryCopied,
                          message: '已复制API诊断摘要',
                          payload: {
                            'count': panelUrls.length,
                            'api_prefix': panelApiPrefix,
                          },
                        );
                      },
                      icon: const Icon(Icons.copy_all_outlined),
                      label: const Text('复制API诊断摘要'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        CommonCard(
          type: CommonCardType.filled,
          radius: 18,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '主业务API列表',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                if (panelUrls.isEmpty)
                  const Text('暂无主业务API列表')
                else
                  for (final panelUrl in panelUrls) ...[
                    _PanelApiTile(
                      url: panelUrl,
                      apiPrefix: panelApiPrefix,
                      probeResult: _panelApiProbeResults[panelUrl],
                    ),
                    if (panelUrl != panelUrls.last) const Divider(height: 16),
                  ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        CommonCard(
          type: CommonCardType.filled,
          radius: 18,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '最近事件',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                if (_events.isEmpty)
                  const Text('暂无事件')
                else
                  for (final event in _events.take(30)) ...[
                    _ApiDiagnosticEventTile(event: event),
                    if (event != _events.take(30).last)
                      const Divider(height: 16),
                  ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _recordApiEvent({
    required _ApiDiagnosticEventType type,
    required String message,
    Map<String, Object?> payload = const {},
  }) {
    final next = _ApiDiagnosticEvent(
      timestamp: DateTime.now(),
      type: type,
      message: message,
      payload: payload,
    );
    _events.insert(0, next);
    if (_events.length > 30) {
      _events.removeRange(30, _events.length);
    }
  }
}

class _ApiProbeResult {
  final bool ok;
  final int? statusCode;
  final int? latencyMs;
  final String? message;
  final DateTime? checkedAt;

  const _ApiProbeResult({
    required this.ok,
    this.statusCode,
    this.latencyMs,
    this.message,
    this.checkedAt,
  });
}

class _PanelApiSummary {
  final int totalCount;
  final int availableCount;
  final int failedCount;
  final int unverifiedCount;
  final String firstAvailableLabel;

  const _PanelApiSummary({
    required this.totalCount,
    required this.availableCount,
    required this.failedCount,
    required this.unverifiedCount,
    required this.firstAvailableLabel,
  });

  String get summaryText {
    if (totalCount == 0) return '暂无主业务API';
    return '$availableCount/$totalCount 可用';
  }
}

_PanelApiSummary _buildPanelApiSummary({
  required List<String> panelUrls,
  required Map<String, _ApiProbeResult> probeResults,
}) {
  var availableCount = 0;
  var failedCount = 0;
  var unverifiedCount = 0;
  String firstAvailableLabel = '-';

  for (final url in panelUrls) {
    final probe = probeResults[url];
    if (probe == null) {
      unverifiedCount += 1;
      continue;
    }
    if (probe.ok) {
      availableCount += 1;
      if (firstAvailableLabel == '-') {
        firstAvailableLabel = gatewayDisplayLabel(url);
      }
    } else {
      failedCount += 1;
    }
  }

  return _PanelApiSummary(
    totalCount: panelUrls.length,
    availableCount: availableCount,
    failedCount: failedCount,
    unverifiedCount: unverifiedCount,
    firstAvailableLabel: firstAvailableLabel,
  );
}

Future<_ApiProbeResult> _probeApiEndpoint(
  String baseUrl,
  String apiPrefix,
) async {
  HttpClient? client;
  final stopwatch = Stopwatch()..start();
  try {
    client = HttpClient();
    client.findProxy = (_) => 'DIRECT';
    client.connectionTimeout = const Duration(seconds: 4);
    client.badCertificateCallback = (_, __, ___) => true;
    final uri = Uri.parse('$baseUrl$apiPrefix/guest/comm/config');
    final request = await client.getUrl(uri);
    request.headers.set(HttpHeaders.userAgentHeader, globalState.ua);
    final response = await request.close().timeout(const Duration(seconds: 4));
    await response.drain<void>();
    stopwatch.stop();
    final statusCode = response.statusCode;
    return _ApiProbeResult(
      ok: statusCode >= 200 && statusCode < 300,
      statusCode: statusCode,
      latencyMs: stopwatch.elapsedMilliseconds,
      message: statusCode >= 200 && statusCode < 300
          ? '接口可用'
          : '接口返回 HTTP $statusCode',
      checkedAt: DateTime.now(),
    );
  } catch (e) {
    stopwatch.stop();
    return _ApiProbeResult(
      ok: false,
      latencyMs: stopwatch.elapsedMilliseconds,
      message: e.toString(),
      checkedAt: DateTime.now(),
    );
  } finally {
    client?.close(force: true);
  }
}

class _EventTile extends StatelessWidget {
  final GatewayRuntimeEvent event;

  const _EventTile({
    required this.event,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_formatTs(event.timestamp)}  ${event.type.name}',
          style: const TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(event.message),
        if (event.payload.isNotEmpty) ...[
          const SizedBox(height: 6),
          SelectableText(
            event.payload.entries
                .map((entry) =>
                    '${entry.key}: ${_maskEventValue(entry.key, entry.value)}')
                .join('\n'),
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}

Future<void> _copyApiDiagnosticsSummary({
  required BuildContext context,
  required List<String> panelUrls,
  required String panelApiPrefix,
  required Map<String, _ApiProbeResult> panelProbeResults,
}) async {
  final panelSummary = _buildPanelApiSummary(
    panelUrls: panelUrls,
    probeResults: panelProbeResults,
  );
  final buffer = StringBuffer()
    ..writeln('API诊断摘要')
    ..writeln('时间: ${_formatTs(DateTime.now())}')
    ..writeln(
      '主业务API摘要: ${panelSummary.summaryText} | prefix=$panelApiPrefix | first=${panelSummary.firstAvailableLabel}',
    )
    ..writeln(
      '配置版本: ${XBoardConfig.configVersion.isEmpty ? '-' : XBoardConfig.configVersion}',
    );

  if (panelUrls.isNotEmpty) {
    buffer.writeln('主业务API列表:');
    for (final panelUrl in panelUrls) {
      final probe = panelProbeResults[panelUrl];
      final status = probe == null
          ? '未验证'
          : probe.ok
              ? '已验证可用'
              : '验证失败';
      buffer.writeln(
        '- ${gatewayDisplayLabel(panelUrl)}$panelApiPrefix | $status | HTTP ${probe?.statusCode?.toString() ?? '-'} | ${probe?.latencyMs?.toString() ?? '-'}ms',
      );
    }
  }

  await Clipboard.setData(ClipboardData(text: buffer.toString()));
  if (context.mounted) {
    context.showNotifier('API诊断摘要已复制');
  }
}

Future<void> _copyGatewayDiagnosticsSummary({
  required BuildContext context,
  required GatewayRuntimeSnapshot snapshot,
  required List<GatewayRuntimeEvent> events,
}) async {
  final candidates = snapshot.candidates;
  final verifiedCount = candidates
      .where(
        (candidate) =>
            candidate.verificationStatus == GatewayVerificationStatus.verified,
      )
      .length;
  final failedCount = candidates
      .where(
        (candidate) =>
            candidate.verificationStatus == GatewayVerificationStatus.failed ||
            candidate.verificationStatus ==
                GatewayVerificationStatus.circuitOpen,
      )
      .length;
  final unverifiedCount = candidates
      .where(
        (candidate) =>
            candidate.verificationStatus ==
            GatewayVerificationStatus.unverified,
      )
      .length;

  String statusLabel(GatewayEndpointConfig candidate) {
    switch (candidate.verificationStatus) {
      case GatewayVerificationStatus.circuitOpen:
        return '熔断中';
      case GatewayVerificationStatus.verified:
        return '已验证可用';
      case GatewayVerificationStatus.failed:
        return '验证失败';
      case GatewayVerificationStatus.unverified:
        return '未验证';
    }
  }

  final buffer = StringBuffer()
    ..writeln('网关诊断摘要')
    ..writeln('时间: ${_formatTs(DateTime.now())}')
    ..writeln(
      '当前网关: ${snapshot.activeConfig == null ? '-' : '${gatewayDisplayLabel(snapshot.activeConfig!.baseUrl)}${snapshot.activeConfig!.apiPrefix}'}',
    )
    ..writeln(
      '最后可用: ${snapshot.lastKnownGoodConfig == null ? '-' : '${gatewayDisplayLabel(snapshot.lastKnownGoodConfig!.baseUrl)}${snapshot.lastKnownGoodConfig!.apiPrefix}'}',
    )
    ..writeln(
      '配置版本: ${snapshot.activeVersionTag ?? (XBoardConfig.configVersion.isEmpty ? '-' : XBoardConfig.configVersion)}',
    )
    ..writeln(
      '候选摘要: $verifiedCount/${candidates.length} 可用 | 失败 $failedCount | 未验证 $unverifiedCount',
    );

  if (candidates.isNotEmpty) {
    buffer.writeln('候选网关列表:');
    for (final candidate in candidates) {
      buffer.writeln(
        '- ${gatewayDisplayLabel(candidate.baseUrl)}${candidate.apiPrefix} | ${statusLabel(candidate)} | source=${candidate.source} | HTTP ${candidate.lastVerificationStatusCode?.toString() ?? '-'} | failures=${candidate.failureCount} | verified=${candidate.lastVerifiedAt == null ? '-' : _formatTs(candidate.lastVerifiedAt!)}',
      );
    }
  }

  if (events.isNotEmpty) {
    buffer.writeln('最近事件:');
    for (final event in events.take(30)) {
      buffer.writeln(
        '- ${_formatTs(event.timestamp)} | ${event.type.name} | ${event.message}',
      );
      if (event.payload.isNotEmpty) {
        buffer.writeln(
          '  ${event.payload.entries.map((entry) => '${entry.key}=${_maskEventValue(entry.key, entry.value)}').join(', ')}',
        );
      }
    }
  }

  await Clipboard.setData(ClipboardData(text: buffer.toString()));
  if (context.mounted) {
    context.showNotifier('网关诊断摘要已复制');
  }
}

String _maskEventValue(String key, Object? value) {
  if (value == null) return '-';
  final lowerKey = key.toLowerCase();
  if (lowerKey.contains('base_url') || lowerKey == 'url') {
    return gatewayDisplayLabel(value.toString());
  }
  return value.toString();
}

String _formatTs(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  final second = local.second.toString().padLeft(2, '0');
  return '$month-$day $hour:$minute:$second';
}
