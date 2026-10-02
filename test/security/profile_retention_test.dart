import 'package:fl_clash/models/profile.dart';
import 'package:fl_clash/security/profile_retention.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Profile urlProfile(String id, int updatedAt, {bool autoUpdate = true}) {
    return Profile.normal(label: id, url: 'https://example.com/$id').copyWith(
      id: id,
      lastUpdateDate: DateTime.fromMillisecondsSinceEpoch(updatedAt),
      autoUpdate: autoUpdate,
    );
  }

  test('keeps active and two latest URL profiles without touching manual ones',
      () {
    final manual = Profile.normal(label: 'manual').copyWith(id: 'manual');
    final profiles = [
      urlProfile('100', 100),
      manual,
      urlProfile('200', 200),
      urlProfile('300', 300),
      urlProfile('400', 400),
    ];

    final plan = buildProfileRetentionPlan(
      profiles,
      activeProfileId: '400',
    );

    expect(
      plan.profiles.map((profile) => profile.id),
      ['manual', '200', '300', '400'],
    );
    expect(plan.removedProfiles.map((profile) => profile.id), ['100']);
    expect(plan.profiles.singleWhere((item) => item.id == '400').autoUpdate,
        isTrue);
    expect(plan.profiles.singleWhere((item) => item.id == '300').autoUpdate,
        isFalse);
    expect(plan.profiles.singleWhere((item) => item.id == '200').autoUpdate,
        isFalse);
    expect(
        plan.profiles.singleWhere((item) => item.id == 'manual').url, isEmpty);
  });

  test('always protects active profile when retention limit is invalid', () {
    final profiles = [
      urlProfile('100', 100),
      urlProfile('200', 200),
    ];

    final plan = buildProfileRetentionPlan(
      profiles,
      activeProfileId: '100',
      maxRetained: 0,
    );

    expect(plan.profiles.map((profile) => profile.id), ['100']);
    expect(plan.removedProfiles.map((profile) => profile.id), ['200']);
  });
}
