import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/security/local_test_profile_scope.dart';
import 'package:fl_clash/xboard/features/profile/providers/profile_import_provider.dart';
import 'package:fl_clash/xboard/features/profile/services/profile_import_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _LocalTestCurrent extends CurrentProfileId {
  final String id;
  _LocalTestCurrent(this.id);
  @override
  String? build() => id;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final profileId in [
    fastCatAutoProfileId,
    fastCatDirectProfileId,
    ...FastCatTestProtocol.values.map((p) => p.profileId)
  ]) {
    test(
        'subscription refresh cannot replace active $profileId or begin downloading',
        () async {
      var requested = false;
      final container = ProviderContainer(overrides: [
        currentProfileIdProvider
            .overrideWith(() => _LocalTestCurrent(profileId)),
        xboardProfileImportServiceProvider.overrideWith((ref) {
          requested = true;
          throw StateError('Must not start subscription download');
        }),
      ]);
      addTearDown(container.dispose);
      final notifier = container.read(profileImportProvider.notifier);
      final before = container.read(profileImportProvider);
      expect(
          await notifier.importSubscription('https://subscription.test',
              forceRefresh: true),
          isFalse);
      expect(requested, isFalse);
      expect(container.read(currentProfileIdProvider), profileId);
      expect(container.read(profileImportProvider), same(before));
    });
  }
}
