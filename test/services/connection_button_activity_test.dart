import 'package:fl_clash/services/connection_button_activity.dart';
import 'package:fl_clash/services/core_switch_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  bool progress(
          {bool ready = true,
          bool subscription = false,
          bool user = false,
          bool switching = true,
          bool configuration = true,
          CoreSwitchStage stage = CoreSwitchStage.idle}) =>
      showConnectionProgress(
          ready: ready,
          checkingSubscription: subscription,
          userSwitching: user,
          coreSwitching: switching,
          configurationSwitching: configuration,
          status: CoreSwitchStatus(stage: stage));
  test('silent refresh preserves disconnected and connected displays', () {
    expect(progress(), false);
    expect(progress(stage: CoreSwitchStage.connected), false);
    expect(progress(switching: false), false);
  });
  test('initialization, user actions and account checks remain visible', () {
    expect(progress(ready: false), true);
    expect(progress(user: true), true);
    expect(progress(subscription: true), true);
    expect(progress(configuration: false), true);
  });
  test('real service and tunnel recovery stays visible during config changes',
      () {
    for (final stage in [
      CoreSwitchStage.checkingHelper,
      CoreSwitchStage.startingService,
      CoreSwitchStage.coreConnecting,
      CoreSwitchStage.tunApplying,
      CoreSwitchStage.stopping
    ]) {
      expect(progress(stage: stage), true, reason: stage.name);
    }
  });
  test('terminal states do not leave a spinner after lock release', () {
    for (final stage in [
      CoreSwitchStage.idle,
      CoreSwitchStage.connected,
      CoreSwitchStage.failed
    ]) {
      expect(progress(stage: stage, switching: false, configuration: false),
          false);
    }
  });
}
