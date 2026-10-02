import 'dart:async';
import 'package:fl_clash/xboard/infrastructure/cache/api_request_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(ApiRequestCache.clear);
  tearDown(ApiRequestCache.clear);
  test('deduplicates in-flight reads and isolates keys', () async {
    var calls = 0;
    final pending = Completer<int>();
    Future<int> fetch() {
      calls++;
      return pending.future;
    }

    final a = ApiRequestCache.get('account:en',
        ttl: const Duration(minutes: 1), fetch: fetch);
    final b = ApiRequestCache.get('account:en',
        ttl: const Duration(minutes: 1), fetch: fetch);
    pending.complete(7);
    expect(await a, 7);
    expect(await b, 7);
    expect(calls, 1);
    await ApiRequestCache.get('account:zh',
        ttl: const Duration(minutes: 1), fetch: fetch);
    expect(calls, 2);
  });
  test('invalidated late responses cannot replace a newer entry', () async {
    final old = Completer<int>();
    final first = ApiRequestCache.get('key',
        ttl: const Duration(minutes: 1), fetch: () => old.future);
    ApiRequestCache.invalidate('key');
    expect(
        await ApiRequestCache.get('key',
            ttl: const Duration(minutes: 1), fetch: () async => 2),
        2);
    old.complete(1);
    expect(await first, 1);
    expect(
        await ApiRequestCache.get('key',
            ttl: const Duration(minutes: 1), fetch: () async => 3),
        2);
  });
  test('failed reads are not cached', () async {
    await expectLater(
        ApiRequestCache.get<int>('error',
            ttl: const Duration(minutes: 1),
            fetch: () => throw StateError('failed')),
        throwsStateError);
    expect(
        await ApiRequestCache.get('error',
            ttl: const Duration(minutes: 1), fetch: () async => 4),
        4);
  });
}
