import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:flutter_xboard_sdk/src/core/auth/auth_interceptor.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);

  final Future<ResponseBody> Function(RequestOptions) respond;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
          Stream<Uint8List>? requestStream, Future<void>? cancelFuture) =>
      respond(options);

  @override
  void close({bool force = false}) {}
}

class _DelayedReadTokenManager extends TokenManager {
  _DelayedReadTokenManager() : super.memory();

  Completer<void>? readStarted;
  Completer<void>? readGate;

  @override
  Future<String?> getToken() async {
    final token = await super.getToken();
    final gate = readGate;
    if (gate != null) {
      readStarted!.complete();
      await gate.future;
    }
    return token;
  }
}

ResponseBody _failure([int status = 401]) => ResponseBody.fromString(
      jsonEncode({
        'code': 'DEVICE_REVOKED',
        'message': 'test device revoked',
      }),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Dio client(TokenManager manager,
      Future<ResponseBody> Function(RequestOptions) respond) {
    final dio = Dio(BaseOptions(baseUrl: 'https://unit-test.invalid'))
      ..httpClientAdapter = _Adapter(respond)
      ..interceptors.add(AuthInterceptor(tokenManager: manager));
    addTearDown(() => dio.close(force: true));
    return dio;
  }

  Future<List<AuthFailureEvent>> collectEvents() async {
    final events = <AuthFailureEvent>[];
    final sub = XBoardAuthEvents.onUnauthorized.listen(events.add);
    addTearDown(sub.cancel);
    return events;
  }

  Future<DioException> rejected(Future<Response<dynamic>> response) async {
    try {
      await response;
      fail('Expected an HTTP failure');
    } on DioException catch (error) {
      return error;
    }
  }

  test('current private 401 and 403 retain their specific failure reason',
      () async {
    final manager = TokenManager.memory();
    addTearDown(manager.dispose);
    await manager.saveToken('test-token');
    final events = await collectEvents();
    var status = 401;
    final dio = client(manager, (_) async => _failure(status));
    await rejected(dio.get('/api/v1/user/devices'));
    status = 403;
    await rejected(dio.get('/api/v1/user/devices'));
    await Future<void>.delayed(Duration.zero);
    expect(events.length, 2);
    expect(
        events.every((event) =>
            event.reason == AuthFailureReason.deviceRevoked &&
            event.code == 'DEVICE_REVOKED' &&
            identical(event.sessionIdentity, manager.sessionIdentity)),
        isTrue);
  });

  test('public login failures never terminate an existing account', () async {
    final manager = TokenManager.memory();
    addTearDown(manager.dispose);
    await manager.saveToken('test-token');
    final events = await collectEvents();
    final dio = client(manager, (_) async => _failure());
    await rejected(dio.post('/api/v1/passport/auth/login?source=test'));
    await Future<void>.delayed(Duration.zero);
    expect(events, isEmpty);
  });

  test('unauthenticated private requests cannot emit a session failure',
      () async {
    final manager = TokenManager.memory();
    addTearDown(manager.dispose);
    final events = await collectEvents();
    final dio = client(manager, (_) async => _failure());
    await rejected(dio.get('/api/v1/user/devices'));
    await Future<void>.delayed(Duration.zero);
    expect(events, isEmpty);
  });

  for (final mutation in ['login', 'same token login', 'logout', 'dispose']) {
    test('late previous request failure is ignored after $mutation', () async {
      final manager = TokenManager.memory();
      if (mutation != 'dispose') addTearDown(manager.dispose);
      await manager.saveToken('first-test-token');
      final events = await collectEvents();
      final started = Completer<void>();
      final reply = Completer<ResponseBody>();
      final dio = client(manager, (_) {
        started.complete();
        return reply.future;
      });
      final result = rejected(dio.get('/api/v1/user/devices'));
      await started.future;
      switch (mutation) {
        case 'login':
          await manager.saveToken('second-test-token');
        case 'same token login':
          await manager.saveToken('first-test-token');
        case 'logout':
          await manager.clearToken();
        case 'dispose':
          manager.dispose();
      }
      reply.complete(_failure());
      expect((await result).response?.statusCode, 401);
      await Future<void>.delayed(Duration.zero);
      expect(events, isEmpty);
    });
  }

  test('token change during async error validation suppresses failure event',
      () async {
    final manager = _DelayedReadTokenManager();
    addTearDown(manager.dispose);
    await manager.saveToken('first-test-token');
    final events = await collectEvents();
    final started = Completer<void>();
    final reply = Completer<ResponseBody>();
    final dio = client(manager, (_) {
      started.complete();
      return reply.future;
    });
    final result = rejected(dio.get('/api/v1/user/devices'));
    await started.future;
    manager.readStarted = Completer<void>();
    manager.readGate = Completer<void>();
    reply.complete(_failure());
    await manager.readStarted!.future;
    await manager.saveToken('second-test-token');
    manager.readGate!.complete();
    await result;
    await Future<void>.delayed(Duration.zero);
    expect(events, isEmpty);
  });

  test('session change while reading a request token cancels dispatch',
      () async {
    final manager = _DelayedReadTokenManager();
    addTearDown(manager.dispose);
    await manager.saveToken('first-test-token');
    manager.readStarted = Completer<void>();
    manager.readGate = Completer<void>();
    var dispatched = false;
    final dio = client(manager, (_) async {
      dispatched = true;
      return _failure();
    });
    final result = rejected(dio.get('/api/v1/user/devices'));
    await manager.readStarted!.future;
    await manager.saveToken('second-test-token');
    manager.readGate!.complete();
    expect((await result).type, DioExceptionType.cancel);
    expect(dispatched, isFalse);
  });

  for (final initiallyAuthenticated in [true, false]) {
    test(
        'replayed ${initiallyAuthenticated ? 'authenticated' : 'anonymous'} '
        'request cannot acquire a new login token', () async {
      final manager = TokenManager.memory();
      addTearDown(manager.dispose);
      if (initiallyAuthenticated) await manager.saveToken('first-test-token');
      RequestOptions? previous;
      var dispatches = 0;
      final dio = client(manager, (options) async {
        dispatches++;
        previous = options;
        return _failure(503);
      });
      await rejected(dio.get('/api/v1/user/devices'));
      final originalAuthorization = previous!.headers['Authorization'];
      await manager.saveToken('second-test-token');
      final error = await rejected(dio.fetch(previous!));
      expect(error.type, DioExceptionType.cancel);
      expect(dispatches, 1);
      expect(previous!.headers['Authorization'], originalAuthorization);
    });
  }

  test('same-session failover can replay its original request', () async {
    final manager = TokenManager.memory();
    addTearDown(manager.dispose);
    await manager.saveToken('test-token');
    RequestOptions? previous;
    var dispatches = 0;
    final dio = client(manager, (options) async {
      dispatches++;
      previous = options;
      return dispatches == 1
          ? _failure(503)
          : ResponseBody.fromString('{}', 200);
    });
    await rejected(dio.get('/api/v1/user/devices'));
    expect((await dio.fetch(previous!)).statusCode, 200);
    expect(dispatches, 2);
  });

  test('consumer rejects an already queued event after the account changes',
      () async {
    final manager = TokenManager.memory();
    addTearDown(manager.dispose);
    await manager.saveToken('first-test-token');
    final accepted = <AuthFailureEvent>[];
    final sub = XBoardAuthEvents.onUnauthorized.listen((event) {
      if (manager.isCurrentSession(event.sessionIdentity)) accepted.add(event);
    });
    addTearDown(sub.cancel);
    XBoardAuthEvents.notifyUnauthorized(AuthFailureEvent(
      reason: AuthFailureReason.unauthorized,
      sessionIdentity: manager.sessionIdentity,
    ));
    await manager.saveToken('second-test-token');
    await Future<void>.delayed(Duration.zero);
    expect(accepted, isEmpty);
  });

  test('a replacement SDK token manager never owns the previous event',
      () async {
    final first = TokenManager.memory();
    final second = TokenManager.memory();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    await first.saveToken('same-test-token');
    await second.saveToken('same-test-token');
    expect(second.isCurrentSession(first.sessionIdentity), isFalse);
  });

  test('pending initialization cannot authenticate an account being cleared',
      () async {
    SharedPreferences.setMockInitialValues({'xboard_token': 'old-test-token'});
    final manager = TokenManager();
    addTearDown(manager.dispose);
    final states = <AuthState>[];
    final sub = manager.authStateStream.listen(states.add);
    addTearDown(sub.cancel);
    await manager.clearToken();
    await Future<void>.delayed(Duration.zero);
    expect(await manager.getToken(), isNull);
    expect(manager.isAuthenticated, isFalse);
    expect(states, isEmpty);
  });
}
