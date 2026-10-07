import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_xboard_sdk/src/adapters/v2board/v2board_invite_adapter.dart';
import 'package:flutter_xboard_sdk/src/core/http/http_service.dart';
import 'package:flutter_xboard_sdk/src/panels/v2board/apis/v2board_invite_api.dart';

class _Http extends Fake implements HttpService {
  String? path;
  Map<String, dynamic>? payload;
  Map<String, dynamic> response = {'data': true};

  @override
  Future<Map<String, dynamic>> postRequest(
      String path, Map<String, dynamic> data,
      {Map<String, String>? headers}) async {
    this.path = path;
    payload = data;
    return response;
  }
}

void main() {
  test('custom withdrawal survives adapter and HTTP serialization in cents',
      () async {
    final http = _Http();
    final adapter = V2BoardInviteAdapter(V2BoardInviteApi(http));
    for (final entry in {100.50: 10050, 1.15: 115, 0.01: 1}.entries) {
      expect(
          await adapter.withdrawCommission(
            amount: entry.key,
            method: 'Alipay',
            params: {'account': 'test-account'},
          ),
          isTrue);
      expect(http.path, '/user/ticket/withdraw');
      expect(http.payload, {
        'withdraw_amount': entry.value,
        'withdraw_method': 'Alipay',
        'withdraw_account': 'test-account',
      });
    }
  });
  test('invalid amount does not submit a request', () async {
    final http = _Http();
    final adapter = V2BoardInviteAdapter(V2BoardInviteApi(http));
    for (final amount in [0.0, -1.0, 1.001, double.nan, double.infinity]) {
      await expectLater(
          adapter.withdrawCommission(
            amount: amount,
            method: 'Alipay',
            params: {'account': 'test-account'},
          ),
          throwsArgumentError);
    }
    expect(http.payload, isNull);
  });
  test('backend rejection is not reported as success', () async {
    final http = _Http()
      ..response = {
        'data': false,
        'message': 'The current required minimum withdrawal commission is 100',
      };
    final adapter = V2BoardInviteAdapter(V2BoardInviteApi(http));
    await expectLater(
        adapter.withdrawCommission(
          amount: 10,
          method: 'Alipay',
          params: {'account': 'test-account'},
        ),
        throwsException);
  });
}
