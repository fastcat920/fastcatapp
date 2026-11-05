import 'dart:async';

/// A native VPN start acknowledgement does not mean its core is ready yet.
/// Only fresh, non-empty groups can prove readiness; display caches cannot.
Future<List<T>> waitForLiveCoreGroups<T>({
  required Future<List<T>> Function() read,
  Duration timeout = const Duration(seconds: 10),
  Duration interval = const Duration(milliseconds: 250),
  Duration queryTimeout = const Duration(seconds: 5),
}) async {
  final watch = Stopwatch()..start();
  Object? lastError;
  while (watch.elapsed < timeout) {
    final remaining = timeout - watch.elapsed;
    try {
      // This is a read-only probe. A late reply cannot publish a connection or
      // overwrite configuration; only the awaited result is returned below.
      final groups = await read().timeout(
        remaining < queryTimeout ? remaining : queryTimeout,
      );
      if (groups.isNotEmpty) return groups;
    } catch (error) {
      lastError = error;
    }
    final delayBudget = timeout - watch.elapsed;
    if (delayBudget <= Duration.zero) break;
    await Future<void>.delayed(
      delayBudget < interval ? delayBudget : interval,
    );
  }
  throw TimeoutException(
    'Core proxy groups unavailable${lastError == null ? '' : ': $lastError'}',
    timeout,
  );
}
