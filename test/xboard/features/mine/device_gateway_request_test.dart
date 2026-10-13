import 'dart:async';

import 'package:fl_clash/xboard/features/mine/services/device_gateway_request.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late XBoardSDK sdk;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sdk = XBoardSDK.instance;
    await sdk.initialize('https://gateway.invalid',
        panelType: 'v2board', useMemoryStorage: true);
    await sdk.saveToken('dg_test_only');
    addTearDown(sdk.dispose);
  });

  test('uses the shared SDK client and does not repeat its exhausted failover',
      () async {
    final http = sdk.httpService;
    var calls = 0;
    final failure = StateError('SDK candidates exhausted');
    await expectLater(
      requestDeviceGateway<void>(
        sdk: sdk,
        isCurrent: () => true,
        request: (client, headers) async {
          calls++;
          expect(identical(client, http), isTrue);
          expect(headers['Authorization'], 'dg_test_only');
          throw failure;
        },
      ),
      throwsA(same(failure)),
    );
    expect(calls, 1);
    expect(sdk.isInitialized, isTrue);
    expect(identical(sdk.httpService, http), isTrue);
  });

  test('rejects an old account response when the session changes in flight',
      () async {
    var current = true;
    final started = Completer<void>();
    final response = Completer<String>();
    final pending = requestDeviceGateway<String>(
      sdk: sdk,
      isCurrent: () => current,
      request: (_, __) {
        started.complete();
        return response.future;
      },
    );
    final check =
        expectLater(pending, throwsA(isA<DeviceGatewaySessionChanged>()));
    await started.future;
    current = false;
    response.complete('old account devices');
    await check;
  });

  test('does not issue requests after logout or with a business-only token',
      () async {
    var calls = 0;
    Future<void> request(HttpService _, Map<String, String> __) async =>
        calls++;
    await expectLater(
        requestDeviceGateway<void>(
            sdk: sdk, isCurrent: () => false, request: request),
        throwsA(isA<DeviceGatewaySessionChanged>()));
    await sdk.saveToken('business_test_only');
    await expectLater(
        requestDeviceGateway<void>(
            sdk: sdk, isCurrent: () => true, request: request),
        throwsA(isA<DeviceGatewaySessionChanged>()));
    expect(calls, 0);
  });
}
