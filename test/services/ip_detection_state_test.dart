import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter_test/flutter_test.dart';

const oldIp = IpInfo(ip: '203.0.113.1', countryCode: 'US');
const newIp = IpInfo(ip: '203.0.113.2', countryCode: 'GB');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('failure clears all busy flags and a subsequent check can succeed',
      () async {
    var shouldFail = true;
    final state = DetectionState.forTesting(
      readContext: () => (initialized: true, identity: 'connection'),
      lookup: (_) async {
        if (shouldFail) throw StateError('network failed');
        return Result.success(newIp);
      },
    );
    addTearDown(state.dispose);
    await state.checkNow();
    expect(state.state.value.isTesting, isFalse);
    expect(state.state.value.isLoading, isFalse);
    shouldFail = false;
    await state.checkNow();
    expect(state.state.value.ipInfo?.ip, newIp.ip);
  });

  test('external cancellation clears both busy flags', () async {
    final gate = Completer<Result<IpInfo?>>();
    final state = DetectionState.forTesting(
      readContext: () => (initialized: true, identity: 'connection'),
      lookup: (token) {
        token.whenCancel.then((_) => gate.complete(Result.error('cancelled')));
        return gate.future;
      },
    );
    addTearDown(state.dispose);
    final pending = state.checkNow();
    state.cancelToken!.cancel();
    await pending;
    expect(state.state.value.isTesting, isFalse);
    expect(state.state.value.isLoading, isFalse);
    expect(state.state.value.ipInfo, isNull);
  });

  test('old completion cannot overwrite a newer IP result', () async {
    final first = Completer<Result<IpInfo?>>();
    var calls = 0;
    CancelToken? firstToken;
    final state = DetectionState.forTesting(
      readContext: () => (initialized: true, identity: 'connection'),
      lookup: (token) {
        if (calls++ == 0) {
          firstToken = token;
          return first.future;
        }
        return Future.value(Result.success(newIp));
      },
    );
    addTearDown(state.dispose);
    final oldCheck = state.checkNow();
    await state.checkNow();
    expect(firstToken!.isCancelled, isTrue);
    first.complete(Result.success(oldIp));
    await oldCheck;
    expect(state.state.value.ipInfo?.ip, newIp.ip);
    expect(state.state.value.isTesting, isFalse);
  });

  test('connection identity change suppresses a late response', () async {
    Object identity = ('connected', 'node1');
    final gate = Completer<Result<IpInfo?>>();
    final state = DetectionState.forTesting(
      readContext: () => (initialized: true, identity: identity),
      lookup: (_) => gate.future,
    );
    addTearDown(state.dispose);
    final pending = state.checkNow();
    identity = ('disconnected', 'node2');
    gate.complete(Result.success(oldIp));
    await pending;
    expect(state.state.value.ipInfo, isNull);
    expect(state.state.value.isLoading, isFalse);
  });

  test('new queued check immediately invalidates in-flight response', () async {
    final gate = Completer<Result<IpInfo?>>();
    final state = DetectionState.forTesting(
      debounceDuration: const Duration(days: 1),
      readContext: () => (initialized: true, identity: 'connection'),
      lookup: (_) => gate.future,
    );
    addTearDown(state.dispose);
    final pending = state.checkNow();
    state.startCheck();
    gate.complete(Result.success(oldIp));
    await pending;
    expect(state.state.value.ipInfo, isNull);
    expect(state.state.value.isLoading, isTrue);
    expect(state.state.value.isTesting, isFalse);
  });

  test('uninitialized state does not start requests or remain busy', () async {
    final state = DetectionState.forTesting(
      readContext: () => (initialized: false, identity: null),
      lookup: (_) => throw StateError('must not request'),
    );
    addTearDown(state.dispose);
    await state.checkNow();
    expect(state.state.value.isLoading, isFalse);
    expect(state.state.value.isTesting, isFalse);
  });

  test('dispose cancels an active check and ignores its later completion',
      () async {
    final gate = Completer<Result<IpInfo?>>();
    CancelToken? token;
    final state = DetectionState.forTesting(
      readContext: () => (initialized: true, identity: 'connection'),
      lookup: (value) {
        token = value;
        return gate.future;
      },
    );
    final pending = state.checkNow();
    state.dispose();
    expect(token!.isCancelled, isTrue);
    gate.complete(Result.success(oldIp));
    await pending;
  });
}
