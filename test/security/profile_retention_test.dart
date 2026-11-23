import 'dart:convert';

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

  test(
      'background account sync preserves the active explicit URL after restart',
      () {
    final account = urlProfile('account', 100);
    final explicit = Profile.fromJson(jsonDecode(
        jsonEncode(urlProfile('manual', 300).copyWith(useProvidedUrl: true))));
    expect(keepSelectedSubscription(explicit, accountSync: true), isTrue);
    expect(keepSelectedSubscription(explicit, accountSync: false), isFalse);
    expect(keepSelectedSubscription(account, accountSync: true), isFalse);
    expect(
        keepSelectedSubscription(explicit.copyWith(url: ''), accountSync: true),
        isFalse);
    expect(keepSelectedSubscription(null, accountSync: true), isFalse);
    final otherAccount = urlProfile('other', 600);
    final duplicate = urlProfile('snapshot', 90).copyWith(url: account.url);
    final sameUrlManual = explicit.copyWith(url: account.url);
    final profiles = [account, sameUrlManual, otherAccount, duplicate];
    expect(latestAccountProfileForUrl(profiles, account.url)?.id, account.id);
    expect(
        latestAccountProfileForUrl([sameUrlManual, otherAccount], account.url),
        isNull);
    final retained =
        buildProfileRetentionPlan(profiles, activeProfileId: account.id);
    expect(retained.profiles.map((p) => p.id),
        containsAll([account.id, explicit.id]));
  });

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

  test(
      'remembers the supplied URL after reload and keeps it outside account snapshots',
      () {
    final link =
        Profile.normal(url: 'https://example.com/feed', useProvidedUrl: true);
    final restored = Profile.fromJson(jsonDecode(jsonEncode(link)));
    final plan = buildProfileRetentionPlan(
      [restored, urlProfile('200', 200)],
      activeProfileId: '200',
      maxRetained: 1,
    );
    expect(restored.useProvidedUrl, isTrue);
    expect(plan.profiles.first.autoUpdate, isTrue);
    expect(plan.removedProfiles, isEmpty);
    final previous =
        Map<String, dynamic>.from(jsonDecode(jsonEncode(restored)) as Map)
          ..remove('useProvidedUrl');
    expect(Profile.fromJson(previous).useProvidedUrl, isFalse);
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
