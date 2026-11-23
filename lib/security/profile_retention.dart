import '../enum/enum.dart';
import '../models/profile.dart';

/// The active subscription plus two known-good rollback snapshots.
const int subscriptionProfileRetentionLimit = 3;

/// An account refresh can populate its cache without selecting over a URL the
/// user explicitly chose. Logout clears URLs, ending this protection.
bool keepSelectedSubscription(Profile? active, {required bool accountSync}) =>
    accountSync && active?.useProvidedUrl == true && active!.url.isNotEmpty;

Profile? latestAccountProfileForUrl(Iterable<Profile> profiles, String url) {
  Profile? latest;
  for (final profile in profiles) {
    if (profile.useProvidedUrl || profile.url.isEmpty || profile.url != url) {
      continue;
    }
    if (latest == null ||
        _profileTimestamp(profile) > _profileTimestamp(latest)) {
      latest = profile;
    }
  }
  return latest;
}

class ProfileRetentionPlan {
  const ProfileRetentionPlan({
    required this.profiles,
    required this.removedProfiles,
  });

  final List<Profile> profiles;
  final List<Profile> removedProfiles;
}

/// Builds a bounded retention plan without touching manual/file profiles.
///
/// The active profile is always retained. Older URL profiles are ordered by
/// their successful update time and kept only as inert rollback snapshots so
/// background refresh does not download the same subscription repeatedly.
ProfileRetentionPlan buildProfileRetentionPlan(
  List<Profile> profiles, {
  required String activeProfileId,
  int maxRetained = subscriptionProfileRetentionLimit,
}) {
  final effectiveLimit = maxRetained < 1 ? 1 : maxRetained;
  bool managed(Profile p) => p.type == ProfileType.url && !p.useProvidedUrl;
  final urlProfiles = profiles.where(managed).toList();
  urlProfiles.sort((left, right) {
    if (left.id == right.id) return 0;
    if (left.id == activeProfileId) return -1;
    if (right.id == activeProfileId) return 1;
    return _profileTimestamp(right).compareTo(_profileTimestamp(left));
  });

  final retainedIds =
      urlProfiles.take(effectiveLimit).map((profile) => profile.id).toSet();
  // A malformed/migrated profile should never make the active profile lose
  // protection merely because its URL field is unexpectedly empty.
  retainedIds.add(activeProfileId);

  final removedProfiles = urlProfiles
      .where((profile) => !retainedIds.contains(profile.id))
      .toList(growable: false);
  final retainedProfiles = profiles
      .where((profile) => !managed(profile) || retainedIds.contains(profile.id))
      .map((profile) {
    if (managed(profile) &&
        profile.id != activeProfileId &&
        profile.autoUpdate) {
      return profile.copyWith(autoUpdate: false);
    }
    return profile;
  }).toList(growable: false);

  return ProfileRetentionPlan(
    profiles: retainedProfiles,
    removedProfiles: removedProfiles,
  );
}

int _profileTimestamp(Profile profile) {
  return profile.lastUpdateDate?.millisecondsSinceEpoch ??
      int.tryParse(profile.id) ??
      0;
}
