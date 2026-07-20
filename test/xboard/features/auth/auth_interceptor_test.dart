import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late HttpServer server;
  late StreamSubscription<HttpRequest> serverSubscription;
  late TokenManager tokenManager;
  late HttpService httpService;
  late String responseCode;

  setUp(() async {
    responseCode = 'DEVICE_KICKED_BY_NEW_LOGIN';
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    serverSubscription = server.listen((request) async {
      request.response
        ..statusCode = HttpStatus.unauthorized
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({
          'success': false,
          'code': responseCode,
          'message': 'device session revoked',
        }));
      await request.response.close();
    });

    tokenManager = TokenManager.memory();
    await tokenManager.saveToken('Bearer test-token');
    httpService = await HttpService.create(
      'http://${server.address.host}:${server.port}',
      tokenManager: tokenManager,
    );
  });

  tearDown(() async {
    httpService.dispose();
    tokenManager.dispose();
    await serverSubscription.cancel();
    await server.close(force: true);
  });

  Future<(AuthFailureEvent, Object)> makeUnauthorizedRequest() async {
    final eventFuture = XBoardAuthEvents.onUnauthorized.first.timeout(
      const Duration(seconds: 2),
    );
    Object? requestError;
    try {
      await httpService.getRequest('/user/devices');
    } catch (error) {
      requestError = error;
    }
    return (await eventFuture, requestError!);
  }

  test('raw JSON 401 maps a kick_oldest response to the specific event',
      () async {
    final (event, requestError) = await makeUnauthorizedRequest();

    expect(event.reason, AuthFailureReason.deviceKickedByNewLogin);
    expect(event.code, 'DEVICE_KICKED_BY_NEW_LOGIN');
    expect(requestError.toString(), contains('DEVICE_KICKED_BY_NEW_LOGIN'));
  });

  test('raw JSON 401 maps an admin removal to the specific event', () async {
    responseCode = 'DEVICE_REVOKED';

    final (event, requestError) = await makeUnauthorizedRequest();

    expect(event.reason, AuthFailureReason.deviceRevoked);
    expect(event.code, 'DEVICE_REVOKED');
    expect(requestError.toString(), contains('DEVICE_REVOKED'));
  });
}
