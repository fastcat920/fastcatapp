import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fl_clash/xboard/features/auth/services/qr_login_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _QrGatewayAdapter implements HttpClientAdapter {
  _QrGatewayAdapter(this.respond);

  final ResponseBody Function(RequestOptions) respond;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
          Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async =>
      respond(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Map<String, dynamic> value, [int status = 200]) =>
    ResponseBody.fromString(jsonEncode(value), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'FastCat',
      packageName: 'test.invalid',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    await XBoardSDK.instance.initialize(
      'https://qr-gateway.invalid',
      panelType: 'v2board',
      useMemoryStorage: true,
    );
    addTearDown(XBoardSDK.instance.dispose);
  });

  test('create negotiates ACK and poll/ACK keep the same delivery receipt',
      () async {
    final requests = <String>[];
    XBoardSDK.instance.httpService.dio.httpClientAdapter =
        _QrGatewayAdapter((request) {
      requests.add('${request.method} ${request.uri.path}');
      switch (request.uri.path) {
        case '/api/v1/auth/qr/sessions':
          expect(request.method, 'POST');
          expect(request.data['delivery_ack'], isTrue);
          expect(request.data['device_id'], isNotEmpty);
          return _json({
            'data': {
              'id': 'qr_test',
              'poll_token': 'test-poll+secret',
              'qr_data': 'fastcat://login/qr?challenge=qr_test',
              'expires_at': '2026-01-01T00:02:00Z',
              'delivery_ack': true,
            },
          });
        case '/api/v1/auth/qr/sessions/qr_test':
          expect(request.method, 'GET');
          expect(request.uri.queryParameters['poll_token'], 'test-poll+secret');
          return _json({
            'data': {
              'status': 'approved',
              'delivery_id': 'test-delivery-id',
              'login': {
                'auth_data': 'test-auth-token',
                'email': 'test@invalid'
              },
            },
          });
        case '/api/v1/auth/qr/sessions/qr_test/ack':
          expect(request.method, 'POST');
          expect(request.data, {
            'poll_token': 'test-poll+secret',
            'delivery_id': 'test-delivery-id',
          });
          expect(request.uri.query, isEmpty);
          return _json({
            'data': {'status': 'consumed'},
          });
        default:
          throw StateError('Unexpected test request');
      }
    });

    final challenge = await QrLoginService.create();
    expect(challenge.deliveryAck, isTrue);
    final result = (await QrLoginService.poll(challenge))!;
    expect(result.token, 'test-auth-token');
    expect(result.deliveryId, 'test-delivery-id');
    await QrLoginService.acknowledge(challenge, result);
    await QrLoginService.acknowledge(challenge, result);
    expect(requests, [
      'POST /api/v1/auth/qr/sessions',
      'GET /api/v1/auth/qr/sessions/qr_test',
      'POST /api/v1/auth/qr/sessions/qr_test/ack',
      'POST /api/v1/auth/qr/sessions/qr_test/ack',
    ]);
  });

  test('legacy gateway response never makes an ACK request', () async {
    final challenge = QrLoginChallenge(
      id: 'qr_old',
      pollToken: 'test-poll-secret',
      qrData: 'fastcat://login/qr?challenge=qr_old',
      expiresAt: DateTime.utc(2026),
    );
    XBoardSDK.instance.httpService.dio.httpClientAdapter =
        _QrGatewayAdapter((_) => throw StateError('No ACK should be sent'));
    await QrLoginService.acknowledge(
      challenge,
      const QrLoginResult(token: 'test-auth-token', email: 'test@invalid'),
    );
  });

  test('ACK permission failure cannot terminate a successful local login',
      () async {
    final sdk = XBoardSDK.instance;
    await sdk.saveToken('test-signed-in-token');
    final failures = <AuthFailureEvent>[];
    final sub = XBoardAuthEvents.onUnauthorized.listen(failures.add);
    addTearDown(sub.cancel);
    var carriedAccountToken = false;
    sdk.httpService.dio.httpClientAdapter = _QrGatewayAdapter((request) {
      carriedAccountToken = request.headers.keys
          .any((key) => key.toLowerCase() == 'authorization');
      return _json({'message': 'test QR receipt no longer valid'}, 403);
    });
    final challenge = QrLoginChallenge(
      id: 'qr_test',
      pollToken: 'test-poll-secret',
      qrData: 'fastcat://login/qr?challenge=qr_test',
      expiresAt: DateTime.utc(2026),
      deliveryAck: true,
    );
    await expectLater(
      QrLoginService.acknowledge(
        challenge,
        const QrLoginResult(
          token: 'test-auth-token',
          email: 'test@invalid',
          deliveryId: 'test-delivery-id',
        ),
      ),
      throwsA(isA<Exception>()),
    );
    await Future<void>.delayed(Duration.zero);
    expect(carriedAccountToken, isFalse);
    expect(failures, isEmpty);
    expect(await sdk.getToken(), 'test-signed-in-token');
  });

  test('anonymous QR methods strip account auth and ignore QR 401 responses',
      () async {
    final sdk = XBoardSDK.instance;
    await sdk.saveToken('test-signed-in-token');
    final failures = <AuthFailureEvent>[];
    final sub = XBoardAuthEvents.onUnauthorized.listen(failures.add);
    addTearDown(sub.cancel);
    final observed = <bool>[];
    sdk.httpService.dio.httpClientAdapter = _QrGatewayAdapter((request) {
      observed.add(request.headers.keys
          .any((key) => key.toLowerCase() == 'authorization'));
      return _json({'message': 'test challenge failure'}, 401);
    });
    for (final (method, path) in [
      ('POST', '/api/v1/auth/qr/sessions'),
      ('GET', '/api/v1/auth/qr/sessions/qr_test?poll_token=test-only'),
      ('DELETE', '/api/v1/auth/qr/sessions/qr_test?poll_token=test-only'),
      ('POST', '/api/v1/auth/qr/sessions/qr_test/ack'),
    ]) {
      await expectLater(
        sdk.httpService.dio.request<dynamic>(path,
            options: Options(method: method, headers: {
              'Authorization': 'accidental-test-account-token',
            })),
        throwsA(isA<DioException>()),
      );
    }
    await Future<void>.delayed(Duration.zero);
    expect(observed, [false, false, false, false]);
    expect(failures, isEmpty);
  });

  test('phone approval remains authenticated and its 401 retains auth handling',
      () async {
    final sdk = XBoardSDK.instance;
    await sdk.saveToken('test-signed-in-token');
    final failures = <AuthFailureEvent>[];
    final sub = XBoardAuthEvents.onUnauthorized.listen(failures.add);
    addTearDown(sub.cancel);
    String? sentAuthorization;
    sdk.httpService.dio.httpClientAdapter = _QrGatewayAdapter((request) {
      sentAuthorization = request.headers['Authorization'] as String?;
      expect(request.method, 'POST');
      expect(request.uri.path, '/api/v1/auth/qr/sessions/qr_test');
      return _json({
        'code': 'TOKEN_EXPIRED',
        'message': 'test account token expired',
      }, 401);
    });
    await expectLater(
        QrLoginService.approve('qr_test'), throwsA(isA<Exception>()));
    await Future<void>.delayed(Duration.zero);
    expect(sentAuthorization, 'test-signed-in-token');
    expect(failures, hasLength(1));
    expect(failures.single.reason, AuthFailureReason.tokenExpired);
  });
}
