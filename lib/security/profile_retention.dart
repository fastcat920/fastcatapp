import '../enum/enum.dart';
import '../models/profile.dart';

/// The active subscription plus two known-good rollback snapshots.
const int subscriptionProfileRetentionLimit = 3;

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
  final urlProfiles =
      profiles.where((profile) => profile.type == ProfileType.url).toList();
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
      .where((profile) =>
          profile.type != ProfileType.url || retainedIds.contains(profile.id))
      .map((profile) {
    if (profile.type == ProfileType.url &&
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
