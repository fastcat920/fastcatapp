import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fl_clash/xboard/features/connectivity/providers/service_connectivity_provider.dart';
import 'package:fl_clash/xboard/features/initialization/models/initialization_state.dart';
import 'package:fl_clash/xboard/features/initialization/providers/initialization_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Startup extends XBoardInitializationNotifier {
  _Startup(super.ref);
  void setStatus(InitializationStatus value) {
    state = InitializationState(
        status: value,
        errorMessage:
            value == InitializationStatus.failed ? 'config unavailable' : null);
  }
}

void main() {
  testWidgets(
      'desktop startup is pending, not offline; real failure still surfaces',
      (tester) async {
    final messenger = tester.binding.defaultBinaryMessenger;
    const channel = MethodChannel('dev.fluttercommunity.plus/connectivity');
    const events =
        MethodChannel('dev.fluttercommunity.plus/connectivity_status');
    messenger.setMockMethodCallHandler(channel, (_) async => ['none']);
    messenger.setMockMethodCallHandler(events, (_) async => null);
    final container = ProviderContainer(
        overrides: [initializationProvider.overrideWith(_Startup.new)]);
    final connectivity = container.read(serviceConnectivityProvider.notifier);
    final startup = container.read(initializationProvider.notifier) as _Startup;
    for (final phase in [
      InitializationStatus.idle,
      InitializationStatus.checkingDomain,
      InitializationStatus.initializingSDK
    ]) {
      startup.setStatus(phase);
      expect(await connectivity.verifyNow(), isFalse);
      await connectivity.handleConnectivityChanged([ConnectivityResult.wifi],
          debounce: false);
      expect(connectivity.state.isRecovering, isTrue);
      expect(connectivity.state.consecutiveFailures, 0);
    }
    startup.setStatus(InitializationStatus.failed);
    expect(connectivity.state.isOffline, isTrue);
    await tester.pump();
    container.dispose();
    await tester.pump(const Duration(seconds: 1));
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(events, null);
  });
}
