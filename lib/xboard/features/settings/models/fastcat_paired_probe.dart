import 'package:fl_clash/security/local_test_profile_scope.dart';

const pairedTimingFields = [
  'gateway-tcp-ms',
  'gateway-tls-ms',
  'connect-response-ms',
  'origin-tls-ms',
  'response-wait-ms',
  'tunnel-ready-ms',
];

double? _median(Iterable<int> values) {
  final sorted = values.toList()..sort();
  if (sorted.isEmpty) return null;
  return (sorted[(sorted.length - 1) ~/ 2] + sorted[sorted.length ~/ 2]) / 2;
}

class PairedProbeSample {
  PairedProbeSample.fromResponse(Map<String, dynamic> response)
      : firstByte = response['ok'] == true && response['status-code'] == 204
            ? _duration(response['first-byte-ms'])
            : null,
        missingNode = response['error'] == 'proxy not found' {
    final phases = response['phases'];
    if (phases is Map) {
      for (final key in pairedTimingFields) {
        final value = _duration(phases[key]);
        if (value != null) timing[key] = value;
      }
      pathGeneration = _duration(phases['path-generation']);
      pathChanged = phases['path-changed'] == true;
      final reused = phases['gateway-reused'];
      if (reused is bool) gatewayReused = reused;
    }
  }

  static int? _duration(Object? value) =>
      value is int && value >= 0 ? value : null;

  final int? firstByte;
  final bool missingNode;
  final timing = <String, int>{};
  bool? gatewayReused;
  int? pathGeneration;
  bool pathChanged = false;
}

class PairedProbeArm {
  PairedProbeSample? first;
  final following = <PairedProbeSample>[];

  List<int> get times =>
      following.map((s) => s.firstByte).whereType<int>().toList()..sort();
  int get successes => times.length;
  double? get p50 => _median(times);
  int? get p95 {
    final sorted = times;
    return sorted.isEmpty ? null : sorted[(sorted.length * .95).ceil() - 1];
  }

  double? phaseMedian(String key) => _median(following
      .where((s) => s.firstByte != null)
      .map((s) => s.timing[key])
      .whereType<int>());

  /// Preserve a single observed request's phases. A phase median can belong to a different request.
  String? slowestLogFields() {
    int? slowest;
    for (var i = 0; i < following.length; i++) {
      final ms = following[i].firstByte;
      if (ms != null &&
          (slowest == null || ms > following[slowest].firstByte!)) {
        slowest = i;
      }
    }
    if (slowest == null) return null;
    final sample = following[slowest];
    return [
      'round=${slowest + 1}',
      'first_byte_ms=${sample.firstByte}',
      'reused=${sample.gatewayReused ?? "unknown"}',
      for (final entry in sample.timing.entries) '${entry.key}=${entry.value}',
    ].join(' ');
  }

  /// Only aggregated numeric fields and fixed labels can reach the device log.
  String logFields() {
    final initial = first;
    final reused = following.where((s) => s.gatewayReused == true).length;
    final known = following.where((s) => s.gatewayReused != null).length;
    return [
      'first_ms=${initial?.firstByte ?? "failed"}',
      'first_reused=${initial?.gatewayReused ?? "unknown"}',
      'success=$successes/${following.length}',
      'p50_ms=${p50 ?? "-"}',
      'p95_ms=${p95 ?? "-"}',
      'reused=$reused/$known',
      for (final key in pairedTimingFields) ...[
        if (initial?.timing[key] != null) 'first_$key=${initial!.timing[key]}',
        if (phaseMedian(key) != null) 'median_$key=${phaseMedian(key)}',
      ],
    ].join(' ');
  }
}

class FastCatPairedProbe {
  final arms = {
    for (final p in FastCatTestProtocol.values) p: PairedProbeArm()
  };
  FastCatTestProtocol? missingNode;
  bool pathChanged = false;

  /// The first observation for each node is kept out of all subsequent percentiles.
  /// Each subsequent round visits both nodes and alternates the starting node.
  Future<void> run({
    required Future<Map<String, dynamic>> Function(FastCatTestProtocol node)
        sample,
    required bool Function() valid,
    required void Function(int round) onRound,
    int rounds = 20,
  }) async {
    final nodes = FastCatTestProtocol.values;
    int? generation;
    for (var round = 0; round <= rounds; round++) {
      if (!valid()) return;
      onRound(round);
      for (final node in round > 0 && round.isEven ? nodes.reversed : nodes) {
        if (!valid()) return;
        Map<String, dynamic> raw;
        try {
          raw = await sample(node);
        } catch (_) {
          raw = const {};
        }
        if (!valid()) return;
        final observation = PairedProbeSample.fromResponse(raw);
        final current = observation.pathGeneration;
        if (observation.pathChanged ||
            (generation != null &&
                current != null &&
                current > 0 &&
                current != generation)) {
          pathChanged = true;
          return;
        }
        if (current != null && current > 0) generation ??= current;
        if (observation.missingNode) {
          missingNode = node;
          return;
        }
        final arm = arms[node]!;
        if (round == 0) {
          arm.first = observation;
        } else {
          arm.following.add(observation);
        }
      }
      if (round == 0 && arms.values.every((a) => a.first?.firstByte == null)) {
        return;
      }
    }
  }
}
