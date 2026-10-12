import 'dart:async';

import 'package:fl_clash/clash/interface.dart';
import 'package:fl_clash/models/core.dart';
import 'package:flutter_test/flutter_test.dart';

class _UnresponsiveCore extends ClashHandlerInterface {
  @override
  Future<bool> preload() async => true;

  @override
  void sendMessage(String message) {}

  @override
  void reStart() {}

  @override
  bool destroy() => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('unacknowledged config throws instead of returning success', () async {
    final core = _UnresponsiveCore();
    await expectLater(
      core.setupConfig(
        const SetupParams(config: {}, selectedMap: {}, testUrl: ''),
        timeout: const Duration(milliseconds: 20),
      ),
      throwsA(isA<TimeoutException>()),
    );
  });
}
