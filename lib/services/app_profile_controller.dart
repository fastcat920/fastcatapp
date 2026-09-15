import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/plugins/app.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/security/profile_vault.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef ApplyProfileDebounce = void Function({bool silence});
typedef UpdateStatus = Future<bool> Function(bool isStart);

class AppProfileController {
  const AppProfileController(
    this._ref, {
    required this.applyProfileDebounce,
    required this.updateStatus,
  });

  final WidgetRef _ref;
  final ApplyProfileDebounce applyProfileDebounce;
  final UpdateStatus updateStatus;

  Future<void> addProfile(Profile profile) async {
    _ref.read(profilesProvider.notifier).setProfile(profile);
    if (_ref.read(currentProfileIdProvider) != null) return;
    _ref.read(currentProfileIdProvider.notifier).value = profile.id;
  }

  Future<void> deleteProfile(String id) async {
    _ref.read(profilesProvider.notifier).deleteProfileById(id);
    await clearEffect(id);
    if (globalState.config.currentProfileId == id) {
      final profiles = globalState.config.profiles;
      final currentProfileId = _ref.read(currentProfileIdProvider.notifier);
      if (profiles.isNotEmpty) {
        currentProfileId.value = profiles.first.id;
      } else {
        currentProfileId.value = null;
        unawaited(updateStatus(false));
      }
    }
  }

  Future<void> updateProfile(Profile profile) async {
    final newProfile = await profile.update();
    _ref
        .read(profilesProvider.notifier)
        .setProfile(newProfile.copyWith(isUpdating: false));
    if (profile.id == _ref.read(currentProfileIdProvider)) {
      applyProfileDebounce(silence: true);
    }
  }

  void setProfile(Profile profile) {
    _ref.read(profilesProvider.notifier).setProfile(profile);
  }

  void setProfileAndAutoApply(Profile profile) {
    _ref.read(profilesProvider.notifier).setProfile(profile);
    if (profile.id == _ref.read(currentProfileIdProvider)) {
      applyProfileDebounce(silence: true);
    }
  }

  void setProfiles(List<Profile> profiles) {
    _ref.read(profilesProvider.notifier).value = profiles;
  }

  Future<void> importProfileInBackground(String url) async {
    try {
      final profiles = globalState.config.profiles;
      final urlProfiles =
          profiles.where((profile) => profile.type == ProfileType.url).toList();

      final profile = await Profile.normal(
        url: url,
      ).update();
      await addProfile(profile);
      _ref.read(currentProfileIdProvider.notifier).value = profile.id;

      for (final oldProfile in urlProfiles) {
        if (oldProfile.id == profile.id) continue;
        commonPrint.log(
            'Removing existing URL profile: ${oldProfile.label ?? oldProfile.id}');
        await deleteProfile(oldProfile.id);
      }
      app?.tip('${appLocalizations.add} ${appLocalizations.profile}');
    } catch (e) {
      commonPrint.log('Failed to import profile in background: $e');
      app?.tip(appLocalizations.checkError);
    }
  }

  Future<void> clearEffect(String profileId) async {
    await ProfileVault.instance.delete(profileId);
    await ProfileVault.instance.removeProviders(profileId);
  }
}
