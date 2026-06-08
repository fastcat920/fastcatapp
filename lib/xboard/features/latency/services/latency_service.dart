import 'package:fl_clash/clash/clash.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/xboard/xboard.dart';

class LatencyService {
  LatencyService();

  /// Dedup: ongoing test futures keyed by proxyName, so repeated calls
  /// for the same node reuse the in-flight request instead of firing again.
  final Map<String, Future<Delay>> _pending = {};

  Future<Map<String, int>> testNodes(List<Proxy> nodes) async {
    final Map<String, int> latencies = {};
    if (nodes.isEmpty) {
      return latencies;
    }

    final testUrl = await ConfigFileLoaderHelper.getLatencyTestUrl();

    // Deduplicate by node name
    final uniqueNames = nodes.map((n) => n.name).toSet().toList();

    // Build futures with dedup
    final tasks = uniqueNames.map<Future>((name) async {
      try {
        // Reuse in-flight request for the same node
        _pending[name] ??= clashCore.getDelay(testUrl, name);
        final delay = await _pending[name]!;
        latencies[name] = delay.value ?? -1;
      } catch (_) {
        latencies[name] = -1;
      } finally {
        _pending.remove(name);
      }
    }).toList();

    // Batch 100 concurrent to avoid flooding
    final batches = tasks.batch(100);
    for (final batch in batches) {
      await Future.wait(batch);
    }

    return latencies;
  }
}
final latencyServiceProvider = Provider<LatencyService>((ref) {
  return LatencyService();
});