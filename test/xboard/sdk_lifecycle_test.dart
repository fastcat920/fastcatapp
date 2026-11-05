import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';

void main() {
  test('Catboard APIs use the new connection and token after each login',
      () async {
    final sdk = XBoardSDK.instance;
    sdk.dispose();
    addTearDown(sdk.dispose);
    CatboardApi? previousApi;
    final requests = <RequestOptions>[];

    // Repeatedly model the dispose/initialize/saveToken sequence used by login.
    for (var session = 1; session <= 3; session++) {
      sdk.dispose();
      sdk.dispose(); // Cleanup must also be safe when called twice.
      await sdk.initialize(
        'http://127.0.0.1:${18000 + session}',
        panelType: 'v2board',
        useMemoryStorage: true,
        httpConfig: HttpConfig.development(),
      );
      await sdk.saveToken('test-session-$session');
      sdk.httpService.dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          // Intercept all traffic: no real server, account or credentials.
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: <String, dynamic>{
              'data': [
                {
                  'id': session,
                  'status': 'available',
                  'template': {'id': session, 'name': 'Test coupon'},
                },
              ],
              'total': 1,
            },
          ));
        },
      ));

      final api = sdk.catboard;
      expect(api, isNot(same(previousApi)),
          reason: 'A disposed HTTP service must not remain cached in Catboard');
      expect(sdk.catboard, same(api),
          reason: 'Reuse the API within the current session');
      expect((await api.getCouponWallet()).single.id, session);
      expect((await api.getInviteUsers()).items.single.id, session);
      expect((await api.getCommissionRecords()).items.single.id, session);

      expect(requests.length, session * 3);
      for (final request in requests.skip((session - 1) * 3)) {
        expect(request.uri.port, 18000 + session);
        expect(request.headers['Authorization'], 'test-session-$session');
      }
      expect(requests.skip((session - 1) * 3).map((r) => r.uri.path), [
        '/api/v1/user/coupon/wallet',
        '/api/v1/user/invite/users',
        '/api/v1/user/invite/ledger',
      ]);
      previousApi = api;
    }
  });
}
