import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fl_clash/clash/clash.dart';
import 'package:fl_clash/common/constant.dart' show defaultTestUrl;
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/mihomo/mihomo.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/security/local_test_profile_scope.dart';
import '../models/fastcat_paired_probe.dart';
import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Runs inside the active VPN extension using its actual node and connection pool.
class FastCatDeviceProbe extends ConsumerStatefulWidget {
  const FastCatDeviceProbe({super.key, required this.nodeName});
  final String nodeName;

  @override
  ConsumerState<FastCatDeviceProbe> createState() => _FastCatDeviceProbeState();
}

enum _ProbeMode { consecutive, switchNetwork, paired }

enum _PairedTarget {
  google('Google', defaultTestUrl),
  cloudflare('Cloudflare', 'https://cp.cloudflare.com/generate_204');

  const _PairedTarget(this.label, this.url);
  final String label;
  final String url;
}

class _FastCatDeviceProbeState extends ConsumerState<FastCatDeviceProbe>
    with WidgetsBindingObserver {
  String? _run;
  _ProbeMode? _mode;
  _PairedTarget _pairedTarget = _PairedTarget.google;
  String _result = '';
  Completer<void>? _pathChanged;

  String _text(String zh, String en) =>
      Localizations.localeOf(context).languageCode == 'zh' ? zh : en;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _interruptPair(_text('对照已停止，请保持测试页在前台重测。',
          'Comparison stopped. Keep this page in the foreground and run again.'));
    }
  }

  void _interruptPair(String message) {
    if (_mode != _ProbeMode.paired || _run == null || !mounted) return;
    _cancel();
    setState(() => _result = message);
  }

  void _cancel() {
    final id = _run;
    _run = null;
    _mode = null;
    final pending = _pathChanged;
    if (pending != null && !pending.isCompleted) pending.complete();
    if (id != null) {
      unawaited(clashCore.cancelStreamingProbes(id).catchError((_) {}));
    }
  }

  @override
  void dispose() {
    _cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<int?> _sample(String id, Duration timeout) async {
    try {
      final response = await clashCore.streamingProbe(
          defaultTestUrl, widget.nodeName,
          runId: id, followRedirects: false, timeout: timeout, maxBodySize: 1);
      if (response['ok'] == true && response['status-code'] == 204) {
        return response['first-byte-ms'] as int?;
      }
    } catch (_) {
      // An interrupted VPN or failed IPC counts as an unsuccessful sample.
    }
    return null;
  }

  Future<void> _start(_ProbeMode mode) async {
    if (_run != null || ref.read(runTimeProvider) == null) return;
    final id = 'fastcat-device-${DateTime.now().microsecondsSinceEpoch}';
    var started = globalState.startTime;
    final profile = ref.read(currentProfileIdProvider);
    bool sameProfile() =>
        mounted &&
        _run == id &&
        ModalRoute.of(context)?.isCurrent != false &&
        ref.read(runTimeProvider) != null &&
        ref.read(currentProfileIdProvider) == profile;
    bool valid() => sameProfile() && globalState.startTime == started;
    setState(() {
      _run = id;
      _mode = mode;
      _result = '';
    });
    try {
      if (mode == _ProbeMode.paired) {
        bool hasBoth(Map proxies) => FastCatTestProtocol.values
            .every((node) => proxies.containsKey(node.node));
        var proxies = await clashCore.clashInterface.getProxies();
        if (!valid()) return;
        if (!hasBoth(proxies)) {
          final saved = ref.read(profilesProvider);
          if (FastCatTestProtocol.forProfile(profile) == null ||
              !FastCatTestProtocol.values
                  .every((node) => saved.any((p) => p.id == node.profileId))) {
            return;
          }
          setState(() =>
              _result = _text('正在载入两个已保存的节点…', 'Loading the two saved nodes…'));
          await ref.read(coreGatewayProvider).applyCurrentProfile();
          if (!sameProfile()) return;
          started = globalState.startTime;
          proxies = await clashCore.clashInterface.getProxies();
          if (!valid()) return;
          if (!hasBoth(proxies)) {
            setState(() => _result = _missingNodeMessage());
            return;
          }
        }
      }
      final result = switch (mode) {
        _ProbeMode.switchNetwork => await _measureSwitch(id, valid),
        _ProbeMode.consecutive => await _measureRequests(id, valid),
        _ProbeMode.paired => await _measurePair(id, valid, _pairedTarget),
      };
      if (!mounted || _run != id) return;
      setState(() => _result = valid()
          ? result
          : _text('VPN 会话已更换，请重测。', 'VPN session changed. Run again.'));
      if (mode != _ProbeMode.paired) {
        debugPrint('[FastCatDeviceProbe] ${widget.nodeName} $_result');
      }
    } catch (_) {
      if (mounted && _run == id) {
        setState(
            () => _result = _text('未能完成测试。', 'Could not complete the test.'));
      }
    } finally {
      if (mounted && _run == id) {
        _cancel();
        setState(() {});
      }
    }
  }

  Future<String> _measureRequests(String id, bool Function() valid) async {
    const count = 20;
    const limit = Duration(seconds: 8);
    final first = await _sample(id, limit);
    final samples = <int>[];
    for (var i = 0; i < count && valid(); i++) {
      setState(() =>
          _result = _text('正在测试 ${i + 1}/$count', 'Testing ${i + 1}/$count'));
      final ms = await _sample(id, limit);
      if (ms != null) samples.add(ms);
    }
    if (!valid()) return '';
    samples.sort();
    final firstText = first == null ? _text('失败', 'failed') : '$first ms';
    final prefix = _text('本轮首个请求 $firstText，后续成功 ${samples.length}/$count',
        'First request $firstText. Following requests ${samples.length}/$count successful');
    if (samples.isEmpty) return prefix;
    final median =
        (samples[(samples.length - 1) ~/ 2] + samples[samples.length ~/ 2]) / 2;
    final p95 = samples[(samples.length * .95).ceil() - 1];
    return '$prefix\nP50 ${median.toStringAsFixed(1)} ms · P95 $p95 ms';
  }

  String _missingNodeMessage() => _text(
      '当前 VPN 还未加载两个测试节点。请确认两个节点均已保存，再重新连接 VPN。',
      'Both saved nodes must be loaded in the VPN. Check both nodes, then reconnect.');

  Future<String> _measurePair(
      String id, bool Function() valid, _PairedTarget target) async {
    const rounds = 20;
    final connectivity = Connectivity();
    final baseline = (await connectivity.checkConnectivity()).toSet();
    if (!valid()) return '';
    final changed = _text('网络状态已变化，请在同一 Wi-Fi 或蜂窝网络重新对照。',
        'Network changed. Run again on a single Wi-Fi or cellular network.');
    final subscription = connectivity.onConnectivityChanged.listen((types) {
      if (_run == id && !setEquals(types.toSet(), baseline)) {
        _interruptPair(changed);
      }
    }, onError: (Object _) {
      if (_run == id) _interruptPair(changed);
    });
    try {
      final pair = FastCatPairedProbe();
      await pair.run(
          rounds: rounds,
          valid: valid,
          onRound: (round) {
            setState(() => _result = round == 0
                ? _text('正在分别测量两个节点的首个请求…',
                    'Measuring the first request on each node…')
                : _text(
                    '同网交替对照 $round/$rounds', 'Paired round $round/$rounds'));
          },
          sample: (node) => clashCore.streamingProbe(target.url, node.node,
              runId: id,
              followRedirects: false,
              maxBodySize: 1,
              phaseTiming: true));
      if (!valid()) return '';
      if (pair.pathChanged) return changed;
      if (pair.missingNode != null) return _missingNodeMessage();
      if (pair.arms.values.every((arm) => arm.following.isEmpty)) {
        return _text('两个节点访问 ${target.label} 的首个请求均失败。请检查连接后重测。',
            'Both first requests to ${target.label} failed. Check the connection and run again.');
      }
      final lines = <String>[
        _text('对照目标 · ${target.label}', 'Comparison target · ${target.label}')
      ];
      for (final entry in pair.arms.entries) {
        final name = entry.key == FastCatTestProtocol.https ? 'v1' : 'HTTP/2';
        final arm = entry.value;
        debugPrint(
            '[FastCatDeviceAB] run=$id arm=$name target=${target.name} ${arm.logFields()}');
        final slowest = arm.slowestLogFields();
        if (slowest != null) {
          debugPrint(
              '[FastCatDeviceABSlow] run=$id arm=$name target=${target.name} $slowest');
        }
        final first = arm.first!;
        final firstMs = first.firstByte == null
            ? _text('失败', 'failed')
            : '${first.firstByte} ms';
        final reuse = switch (first.gatewayReused) {
          true => _text('（入口已复用）', ' (reused gateway)'),
          false => _text('（新入口连接）', ' (new gateway connection)'),
          null => '',
        };
        lines.add(_text('$name 首个 $firstMs$reuse；后续成功 ${arm.successes}/$rounds',
            '$name first $firstMs$reuse; then ${arm.successes}/$rounds successful'));
        if (arm.successes > 0) {
          lines
              .add('P50 ${arm.p50!.toStringAsFixed(1)} ms · P95 ${arm.p95} ms');
        }
        final phaseLabels = {
          'gateway-tcp-ms': _text('入口 TCP', 'gateway TCP'),
          'gateway-tls-ms': _text('入口 TLS', 'gateway TLS'),
          'connect-response-ms': 'CONNECT',
          'origin-tls-ms': _text('目标 TLS', 'target TLS'),
          'response-wait-ms': _text('等待响应', 'response wait'),
        };
        final details = [
          for (final phase in phaseLabels.entries)
            if (first.timing.containsKey(phase.key))
              '${phase.value} ${first.timing[phase.key]} ms',
        ];
        if (details.isNotEmpty) {
          lines.add(
              _text('首次分段 ', 'First request phases ') + details.join(' · '));
        }
      }
      return lines.join('\n');
    } finally {
      await subscription.cancel();
    }
  }

  ConnectivityResult? _physical(List<ConnectivityResult> types) {
    final wifi = types.contains(ConnectivityResult.wifi);
    final mobile = types.contains(ConnectivityResult.mobile);
    if (wifi == mobile) return null;
    return wifi ? ConnectivityResult.wifi : ConnectivityResult.mobile;
  }

  Future<String> _measureSwitch(String id, bool Function() valid) async {
    final connectivity = Connectivity();
    final baseline = _physical(await connectivity.checkConnectivity());
    if (!valid()) return '';
    if (baseline == null) {
      return _text('系统未报告明确的 Wi-Fi 或蜂窝网络，请稍后再测。',
          'No distinct Wi-Fi or cellular path reported. Try again later.');
    }
    final ready = await _sample(id, const Duration(seconds: 8));
    if (!valid()) return '';
    if (ready == null) {
      return _text('切网前请求失败，请检查节点连接。',
          'The initial request failed. Check the node connection.');
    }
    final changed = _pathChanged = Completer<void>();
    final clock = Stopwatch();
    final sub = connectivity.onConnectivityChanged.listen((types) {
      final next = _physical(types);
      if (next != null && next != baseline && !changed.isCompleted) {
        clock.start();
        changed.complete();
      }
    }, onError: (Object err) {
      if (!changed.isCompleted) changed.completeError(err);
    });
    try {
      setState(() => _result = _text('请在 60 秒内切换 Wi-Fi / 蜂窝网络，再返回此页。',
          'Switch between Wi-Fi and cellular within 60 seconds, then return here.'));
      await changed.future.timeout(const Duration(seconds: 60));
      if (!valid()) return '';
      setState(() => _result = _text(
          '已发现网络切换，正在检查连接…', 'Network changed. Checking the connection…'));
      const budget = Duration(seconds: 30);
      while (valid() && clock.elapsed < budget) {
        final remaining = budget - clock.elapsed;
        if (remaining.inMilliseconds < 1) break;
        final timeout = remaining < const Duration(seconds: 3)
            ? remaining
            : const Duration(seconds: 3);
        final ms = await _sample(id, timeout);
        if (!valid()) return '';
        if (ms != null) {
          final elapsed = clock.elapsedMilliseconds;
          return _text('从 App 发现网络切换到收到首个成功响应：$elapsed ms。',
              'From detected network change to first successful response: $elapsed ms.');
        }
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      return _text('切网后 30 秒内没有成功响应。',
          'No successful response within 30 seconds of the network change.');
    } on TimeoutException {
      return _text('60 秒内未检测到 Wi-Fi 与蜂窝网络之间的切换。',
          'No Wi-Fi/cellular change detected within 60 seconds.');
    } finally {
      await sub.cancel();
      if (_pathChanged == changed) _pathChanged = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final online = ref.watch(runTimeProvider.select((value) => value != null));
    final running = _run != null;
    final bothSaved = ref.watch(profilesProvider.select((profiles) =>
        FastCatTestProtocol.values
            .every((node) => profiles.any((p) => p.id == node.profileId))));
    ref.listen(runTimeProvider.select((t) => t != null), (_, connected) {
      if (!connected) {
        _interruptPair(
            _text('VPN 已断开，对照已停止。', 'VPN disconnected. Comparison stopped.'));
      }
    });
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (!online)
        Text(_text('连接 VPN 后可测试此节点。', 'Connect the VPN to test this node.')),
      if (online) ...[
        if (bothSaved) ...[
          Text(_text('对照目标', 'Comparison target')),
          SegmentedButton<_PairedTarget>(
            segments: [
              for (final target in _PairedTarget.values)
                ButtonSegment(value: target, label: Text(target.label)),
            ],
            selected: {_pairedTarget},
            onSelectionChanged: running
                ? null
                : (targets) => setState(() => _pairedTarget = targets.single),
          ),
          OutlinedButton(
            onPressed: running ? null : () => _start(_ProbeMode.paired),
            child: Text(_text(
                '同网对照 v1 / HTTP/2', 'Compare v1 / HTTP/2 on this network')),
          ),
        ],
        OutlinedButton(
          onPressed: running ? null : () => _start(_ProbeMode.consecutive),
          child: Text(_text('测连续请求', 'Test consecutive requests')),
        ),
        OutlinedButton(
          onPressed: running ? null : () => _start(_ProbeMode.switchNetwork),
          child: Text(_text('测切网恢复', 'Test network switching')),
        ),
      ],
      if (running)
        TextButton(
            onPressed: () => setState(() {
                  _cancel();
                  _result = _text('测试已停止。', 'Test stopped.');
                }),
            child: Text(_text('停止测试', 'Stop test'))),
      if (_result.isNotEmpty) SelectableText(_result),
    ]);
  }
}
