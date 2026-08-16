import 'package:fl_clash/clash/clash.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/state.dart';

Future<void> testNodeLatency(Proxy proxy, [String? testUrl]) async {
  final controller = globalState.appController;
  final state = controller.getProxyCardState(proxy.name);
  final url = state.testUrl.getSafeValue(controller.getRealTestUrl(testUrl));
  if (state.proxyName.isEmpty) return;
  final recoveringFromBackground = globalState.shouldWarmUpLatencyAfterResume;
  if (recoveringFromBackground) {
    await _waitForLatencyCoreReady();
  }
  controller.setDelay(Delay(url: url, name: state.proxyName, value: 0));
  var result = await clashCore.getDelay(url, state.proxyName);
  if (recoveringFromBackground &&
      (result.value == null || result.value! <= 0)) {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await _waitForLatencyCoreReady();
    result = await clashCore.getDelay(url, state.proxyName);
  }
  controller.setDelay(result);
}

Future<void> testNodesLatency(
  List<Proxy> proxies, [
  String? testUrl,
  void Function(String proxyName)? onResult,
]) async {
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

  // Keep full concurrency as intended, but launch only one request for each
  // resolved node + URL pair. Results are staged so a transient all-timeout
  // immediately after foreground resume never overwrites valid cached delays.
  for (final target in targets) {
    controller.setDelay(
      Delay(url: target.url, name: target.proxyName, value: 0),
    );
  }

  var results = await _runLatencyTargets(targets);
  if (recoveringFromBackground && _allTargetsTimedOut(results)) {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await _waitForLatencyCoreReady();
    results = await _runLatencyTargets(targets);
  }

  for (var index = 0; index < targets.length; index++) {
    final target = targets[index];
    try {
      controller.setDelay(results[index]);
    } finally {
      for (final displayName in target.displayNames) {
        onResult?.call(displayName);
      }
    }
  }
  controller.addSortNum();
}

Future<List<Delay>> _runLatencyTargets(List<_LatencyTestTarget> targets) {
  return Future.wait(targets.map((target) async {
    try {
      return await clashCore.getDelay(target.url, target.proxyName);
    } catch (_) {
      return Delay(url: target.url, name: target.proxyName, value: -1);
    }
  }));
}

bool _allTargetsTimedOut(List<Delay> results) {
  return results.isNotEmpty &&
      results.every((delay) => delay.value == null || delay.value! <= 0);
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
