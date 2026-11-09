import 'latency_epoch.dart';
import 'package:fl_clash/clash/clash.dart';
import 'dart:io';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/state.dart';

final _latencyEpoch = LatencyEpoch();

void invalidateLatencyTests() => _latencyEpoch.invalidate();
bool _observingCoreSwitches = false;
int _captureLatencyEpoch() {
  if (!_observingCoreSwitches) {
    _observingCoreSwitches = true;
    globalState.isCoreSwitchingNotifier.addListener(() {
      if (globalState.isCoreSwitchingNotifier.value) _latencyEpoch.invalidate();
    });
  }
  if (globalState.isCoreSwitchingNotifier.value) {
    throw StateError('VPN 正在切换，测速已暂停');
  }
  return _latencyEpoch.capture();
}

bool _isLatencyEpochCurrent(int epoch) =>
    _latencyEpoch.accepts(epoch) && !globalState.isCoreSwitchingNotifier.value;
void _requireLatencyEpoch(int epoch) {
  if (!_isLatencyEpochCurrent(epoch)) {
    throw StateError('连接已切换，丢弃旧测速结果');
  }
}

Future<void> testNodeLatency(Proxy proxy, [String? testUrl]) async {
  final epoch = _captureLatencyEpoch();
  final controller = globalState.appController;
  final state = controller.getProxyCardState(proxy.name);
  final url = state.testUrl.getSafeValue(controller.getRealTestUrl(testUrl));
  if (state.proxyName.isEmpty) return;
  final recoveringFromBackground = globalState.shouldWarmUpLatencyAfterResume;
  if (recoveringFromBackground) {
    await _waitForLatencyCoreReady();
  }
  _requireLatencyEpoch(epoch);
  controller.setDelay(Delay(url: url, name: state.proxyName, value: 0));
  final target = _LatencyTestTarget(url: url, proxyName: state.proxyName);
  final result = await _testTargetOnce(target);
  _requireLatencyEpoch(epoch);
  controller.setDelay(result);
}

Future<void> testNodesLatency(
  List<Proxy> proxies, [
  String? testUrl,
  void Function(String proxyName)? onResult,
]) async {
  final epoch = _captureLatencyEpoch();
  final controller = globalState.appController;
  final testsByTarget = <String, _LatencyTestTarget>{};

  // URLTest/Fallback entries resolve to their currently selected real node.
  // Group by the resolved target so strategy groups and their real node share
  // one request, while retaining every displayed name for progress callbacks.
  for (final proxyName in proxies.map((proxy) => proxy.name).toSet()) {
    final state = controller.getProxyCardState(proxyName);
    final url = state.testUrl.getSafeValue(controller.getRealTestUrl(testUrl));
    if (state.proxyName.isEmpty) {
      onResult?.call(proxyName);
      continue;
    }
    final key = '$url\u0000${state.proxyName}';
    final target = testsByTarget.putIfAbsent(
      key,
      () => _LatencyTestTarget(url: url, proxyName: state.proxyName),
    );
    target.displayNames.add(proxyName);
  }

  final targets = testsByTarget.values.toList(growable: false);
  if (targets.isEmpty) {
    controller.addSortNum();
    return;
  }

  final recoveringFromBackground = globalState.shouldWarmUpLatencyAfterResume;
  if (recoveringFromBackground) {
    await _waitForLatencyCoreReady();
  }

  _requireLatencyEpoch(epoch);
  // One request per resolved node + URL pair; never retry a failed batch.
  for (final target in targets) {
    controller.setDelay(
      Delay(url: target.url, name: target.proxyName, value: 0),
    );
  }

  final publishedTargets = <int>{};
  final results = await _runLatencyTargets(
    targets,
    isCurrent: () => _isLatencyEpochCurrent(epoch),
    onResult: (index, result) {
      if (!_isLatencyEpochCurrent(epoch)) return;
      _publishTargetResult(
        setDelay: controller.setDelay,
        target: targets[index],
        result: result,
        onResult: onResult,
      );
      publishedTargets.add(index);
    },
  );

  _requireLatencyEpoch(epoch);
  for (var index = 0; index < targets.length; index++) {
    if (publishedTargets.contains(index)) continue;
    _publishTargetResult(
      setDelay: controller.setDelay,
      target: targets[index],
      result: results[index],
      onResult: onResult,
    );
  }
  controller.addSortNum();
}

Future<List<Delay>> _runLatencyTargets(
  List<_LatencyTestTarget> targets, {
  required void Function(int index, Delay result) onResult,
  required bool Function() isCurrent,
}) async {
  if (Platform.isIOS) {
    final results = List<Delay?>.filled(targets.length, null);
    var next = 0;
    Future<void> worker() async {
      while (next < targets.length) {
        if (!isCurrent()) throw StateError('连接切换，停止旧批次测速');
        final index = next++;
        final result = await _testTargetOnce(targets[index]);
        results[index] = result;
        onResult(index, result);
      }
    }

    await Future.wait(List.generate(
        targets.length < 4 ? targets.length : 4, (_) => worker()));
    return results.cast<Delay>();
  }
  return Future.wait(targets.indexed.map((entry) async {
    final index = entry.$1;
    final target = entry.$2;
    final result = await _testTargetOnce(target);
    onResult(index, result);
    return result;
  }));
}

final Map<String, Future<Delay>> _pendingLatencyTests = {};

Future<Delay> _testTargetOnce(_LatencyTestTarget target) {
  final key =
      '${_latencyEpoch.capture()}\u0000${target.url}\u0000${target.proxyName}';
  final existing = _pendingLatencyTests[key];
  if (existing != null) return existing;
  late final Future<Delay> task;
  task = _performTargetTest(target).whenComplete(() {
    if (identical(_pendingLatencyTests[key], task)) {
      _pendingLatencyTests.remove(key);
    }
  });
  _pendingLatencyTests[key] = task;
  return task;
}

Future<Delay> _performTargetTest(_LatencyTestTarget target) async {
  try {
    return await clashCore.getDelay(target.url, target.proxyName);
  } catch (_) {
    return Delay(url: target.url, name: target.proxyName, value: -1);
  }
}

Delay lowestSuccessfulDelay(
  List<Delay> samples, {
  required String url,
  required String proxyName,
}) {
  final successful = samples.where((sample) => (sample.value ?? -1) > 0);
  if (successful.isEmpty) {
    return Delay(url: url, name: proxyName, value: -1);
  }
  return successful.reduce(
    (best, sample) => sample.value! < best.value! ? sample : best,
  );
}

void _publishTargetResult({
  required void Function(Delay delay) setDelay,
  required _LatencyTestTarget target,
  required Delay result,
  required void Function(String proxyName)? onResult,
}) {
  setDelay(result);
  for (final displayName in target.displayNames) {
    onResult?.call(displayName);
  }
}

Future<void> _waitForLatencyCoreReady() async {
  for (var attempt = 0; attempt < 4; attempt++) {
    try {
      final groups = await clashCore.getProxiesGroups().timeout(
            const Duration(milliseconds: 900),
            onTimeout: () => const <Group>[],
          );
      if (groups.isNotEmpty) return;
    } catch (_) {}
    if (attempt < 3) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }
}

class _LatencyTestTarget {
  _LatencyTestTarget({required this.url, required this.proxyName});

  final String url;
  final String proxyName;
  final Set<String> displayNames = {};
}
