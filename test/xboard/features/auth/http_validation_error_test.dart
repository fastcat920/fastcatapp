import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';

void main() {
  test('Laravel validation errors expose the concrete field message', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen((request) async {
      request.response
        ..statusCode = HttpStatus.unprocessableEntity
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({
          'message': 'The given data was invalid.',
          'errors': {
            'password': ['密码必须大于 8 个字符'],
          },
        }));
      await request.response.close();
    });
    final service = await HttpService.create(
      'http://${server.address.host}:${server.port}',
    );

    try {
      await expectLater(
        service.postRequest('/passport/auth/login', {
          'email': 'test@example.com',
          'password': '123',
        }),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            '密码必须大于 8 个字符',
          ),
        ),
      );
    } finally {
      service.dispose();
      await subscription.cancel();
      await server.close(force: true);
    }
  });
}
