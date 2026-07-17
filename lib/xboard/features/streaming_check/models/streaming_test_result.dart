enum StreamingTestStatus {
  accessible,
  partiallyAccessible,
  restricted,
  blocked,
  verificationRequired,
  uncertain,
  unavailable,
  timeout,
  error,
  cancelled,
}

class StreamingTarget {
  const StreamingTarget({
    required this.id,
    required this.name,
    required this.url,
  });

  final String id;
  final String name;
  final String url;
}

class StreamingTestResult {
  const StreamingTestResult({
    required this.target,
    required this.status,
    required this.elapsedMs,
    this.region,
    this.statusCode,
    this.detail,
  });

  final StreamingTarget target;
  final StreamingTestStatus status;
  final int elapsedMs;
  final String? region;
  final int? statusCode;
  final String? detail;
}

class StreamingCheckSnapshot {
  const StreamingCheckSnapshot({
    required this.generatedAt,
    required this.nodeName,
    required this.region,
    required this.results,
    this.invalidated = false,
  });

  final DateTime generatedAt;
  final String nodeName;
  final String? region;
  final List<StreamingTestResult> results;
  final bool invalidated;

  int get accessibleCount => results
      .where(
        (result) =>
            result.status == StreamingTestStatus.accessible ||
            result.status == StreamingTestStatus.partiallyAccessible,
      )
      .length;
}
