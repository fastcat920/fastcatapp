import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/xboard/domain/domain.dart';
import 'package:fl_clash/xboard/features/auth/models/auth_state.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/xboard/features/initialization/models/initialization_state.dart';
import 'package:fl_clash/xboard/features/initialization/providers/initialization_provider.dart';
import 'package:fl_clash/xboard/features/profile/providers/profile_import_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Startup extends XBoardInitializationNotifier {
  _Startup(super.ref) {
    state = const InitializationState(status: InitializationStatus.ready);
  }
  @override
  Future<void> initialize() async {}
}

class _Auth extends XBoardUserAuthNotifier {
  @override
  UserAuthState build() => const UserAuthState(
        isAuthenticated: true,
        subscriptionInfo: DomainSubscription(
            subscribeUrl: 'https://example.test/sub',
            email: 'test@example.test',
            uuid: 'test',
            planId: 1,
            transferLimit: 100,
            uploadedBytes: 0,
            downloadedBytes: 0),
      );
}

class _Importer extends ProfileImportNotifier {
  _Importer(super.ref);
  int calls = 0;
  @override
  Future<bool> importSubscription(String url,
      {bool forceRefresh = false}) async {
    calls++;
    return calls > 1;
  }
}

void main() {
  testWidgets(
      'failed automatic import retries; in-flight and success deduplicate',
      (tester) async {
    final previous = globalState.coreStatusReadyNotifier.value;
    globalState.coreStatusReadyNotifier.value = true;
    final container = ProviderContainer(overrides: [
      initializationProvider.overrideWith(_Startup.new),
      xboardUserAuthProvider.overrideWith(_Auth.new),
      profileImportProvider.overrideWith(_Importer.new),
      currentProfileProvider.overrideWithValue(null),
    ]);
    final auth = container.read(xboardUserAuthProvider.notifier);
    final importer =
        container.read(profileImportProvider.notifier) as _Importer;
    for (var attempt = 0; attempt < 3; attempt++) {
      auth.retryAutomaticSubscriptionImport();
      auth.retryAutomaticSubscriptionImport();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pump();
      expect(importer.calls, attempt == 0 ? 1 : 2);
    }
    container.dispose();
    globalState.coreStatusReadyNotifier.value = previous;
    await tester.pump(const Duration(seconds: 1));
  });
}
