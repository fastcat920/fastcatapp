import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/clash/native_listener_command.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final method in [
    ActionMethod.startListener,
    ActionMethod.stopListener,
  ]) {
    for (final accepted in [true, false]) {
      test('${method.name} returns the actual native $accepted reply',
          () async {
        final reply = Completer<String>();
        late Action request;
        var completed = false;
        final operation = invokeNativeListenerCommand(method, (message) {
          request = Action.fromJson(json.decode(message));
          return reply.future;
        });
        unawaited(operation.then((_) => completed = true));
        await Future<void>.delayed(Duration.zero);
        expect(completed, isFalse);
        expect(request.method, method);
        reply.complete(json.encode(ActionResult(
          id: request.id,
          method: method,
          data: accepted,
        )));
        expect(await operation, accepted);
      });
    }
  }

  test('missing acknowledgement times out instead of succeeding', () async {
    await expectLater(
      invokeNativeListenerCommand(
        ActionMethod.startListener,
        (_) => Completer<String>().future,
        timeout: const Duration(milliseconds: 10),
      ),
      throwsA(isA<TimeoutException>()),
    );
  });

  for (final failure in ['wrong-id', 'wrong-method', 'error', 'empty']) {
    test('$failure acknowledgement is rejected', () async {
      await expectLater(
        invokeNativeListenerCommand(ActionMethod.startListener,
            (message) async {
          final request = Action.fromJson(json.decode(message));
          return json.encode(ActionResult(
            id: failure == 'wrong-id' ? 'other' : request.id,
            method: failure == 'wrong-method'
                ? ActionMethod.stopListener
                : request.method,
            code: failure == 'error' ? ResultType.error : ResultType.success,
            data: failure == 'empty' ? '' : true,
          ));
        }),
        throwsStateError,
      );
    });
  }

  test('Android wiring keeps asynchronous ACK and service-isolate isolation',
      () {
    final lib = File('lib/clash/lib.dart').readAsStringSync();
    final main = File('lib/main.dart').readAsStringSync();
    final core = File('lib/clash/core.dart').readAsStringSync();
    expect(lib, isNot(contains('clashFFI.startListener()')));
    expect(lib, isNot(contains('clashFFI.stopListener()')));
    expect(lib, contains('timeout: nativeListenerTimeout'));
    expect(lib, contains('completer.future.timeout(timeout)'));
    expect(main, contains('!await clashLibHandler.startListener()'));
    expect(main, contains('!await clashLibHandler.stopListener()'));
    expect(main, contains('ClashCore.initGeo(validate: false)'));
    expect(core, contains('!(Platform.isAndroid && globalState.isService)'));
    expect(
        core, contains('validate && canUseMainCore && await clashCore.isInit'));
  });
}
