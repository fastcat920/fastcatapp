import 'dart:async';
import 'dart:convert';
import 'package:fl_clash/clash/interface.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

class _Core extends ClashHandlerInterface {
  int checks = 0;
  bool fail = true;
  @override
  sendMessage(String message) {
    final action = Action.fromJson(jsonDecode(message));
    if (action.method == ActionMethod.checkGeoData) {
      checks++;
      if (fail) throw TimeoutException('No acknowledgement');
    }
    handleResult(ActionResult(
        id: action.id,
        method: action.method,
        data: action.method == ActionMethod.initClash
            ? true
            : '{"invalid":[],"error":""}'));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('missing Geo acknowledgement fails queued checks fast until reinit',
      () async {
    final core = _Core();
    await expectLater(core.checkGeoData(), throwsA(isA<TimeoutException>()));
    await expectLater(core.checkGeoData(), throwsStateError);
    expect(core.checks, 1);
    core.fail = false;
    await core.init(const InitParams(homeDir: '/tmp/test', version: 1));
    expect(await core.checkGeoData(), contains('invalid'));
    expect(core.checks, 2);
  });
}
