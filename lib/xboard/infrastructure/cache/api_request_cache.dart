import 'dart:async';

class _ApiRequestCacheEntry {
  final Future<dynamic> future;
  final DateTime createdAt;
  final Duration ttl;

  _ApiRequestCacheEntry({
    required this.future,
    required this.createdAt,
    required this.ttl,
  });

  bool get isExpired => DateTime.now().difference(createdAt) > ttl;
}

/// Small in-memory cache for idempotent API reads.
///
/// It also deduplicates concurrent calls with the same key by sharing the same
/// future until the TTL expires or the entry is invalidated.
class ApiRequestCache {
  ApiRequestCache._();

  static final Map<String, _ApiRequestCacheEntry> _entries = {};

  static Future<T> get<T>(
    String key, {
    required Duration ttl,
    required Future<T> Function() fetch,
  }) {
    final cached = _entries[key];
    if (cached != null && !cached.isExpired) {
      return cached.future.then((value) => value as T);
    }

    final future = fetch();
    final entry = _ApiRequestCacheEntry(
      future: future,
      createdAt: DateTime.now(),
      ttl: ttl,
    );
    _entries[key] = entry;

    future.then<void>(
      (_) {},
      onError: (_, __) {
        if (identical(_entries[key], entry)) {
          _entries.remove(key);
        }
      },
    );

    return future;
  }

  static void invalidate(String key) {
    _entries.remove(key);
  }

  static void invalidatePrefix(String prefix) {
    _entries.removeWhere((key, _) => key.startsWith(prefix));
  }

  static void clear() {
    _entries.clear();
  }
}
