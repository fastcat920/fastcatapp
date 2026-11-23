import 'package:fl_clash/security/local_test_profile_scope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('repairs leaked test selections while retaining ordinary choices', () {
    final source = {
      fastCatTestGroup: fastCatTestNodeName,
      'GLOBAL': fastCatTestGroup,
      'Subscription': 'node-a'
    };
    expect(scopedProfileSelections('subscription-id', source),
        {'Subscription': 'node-a'});
    expect(source.length, 3);
  });
  test('keeps the complete local test selection on cold start', () {
    final source = {
      fastCatTestGroup: fastCatTestNodeName,
      'GLOBAL': fastCatTestGroup
    };
    expect(scopedProfileSelections(fastCatTestProfileId, source), source);
  });
  test('does not weaken validation for unrelated invalid selections', () {
    expect(
        scopedProfileSelections(
            'subscription-id', {'GLOBAL': 'deleted-node', 'group': 'missing'}),
        {'GLOBAL': 'deleted-node', 'group': 'missing'});
  });
  test(
      'cold-start migration restores the local test and removes leaked URL choices',
      () {
    final config = <String, dynamic>{
      'currentProfileId': 'url-profile',
      'profiles': [
        {
          'id': fastCatTestProfileId,
          'url': '',
          'selectedMap': {
            fastCatTestGroup: fastCatTestNodeName,
            'GLOBAL': fastCatTestGroup
          }
        },
        {
          'id': 'url-profile',
          'url': 'https://subscription.test',
          'selectedMap': {
            fastCatTestGroup: fastCatTestNodeName,
            'GLOBAL': fastCatTestGroup,
            'normal': 'node-a'
          }
        },
      ]
    };
    expect(repairLocalTestProfileScope(config), isTrue);
    expect(config['currentProfileId'], fastCatTestProfileId);
    expect(config['profiles'][1]['selectedMap'], {'normal': 'node-a'});
    expect(repairLocalTestProfileScope(config), isFalse);
  });
  test('migration never replaces a normal subscription selection', () {
    final config = <String, dynamic>{
      'currentProfileId': 'url-profile',
      'profiles': [
        {
          'id': fastCatTestProfileId,
          'url': '',
          'selectedMap': {fastCatTestGroup: fastCatTestNodeName}
        },
        {
          'id': 'url-profile',
          'url': 'https://subscription.test',
          'selectedMap': {'normal': 'node-a'}
        },
      ]
    };
    expect(repairLocalTestProfileScope(config), isFalse);
    expect(config['currentProfileId'], 'url-profile');
  });

  test('each active test is isolated from the other test and subscriptions',
      () {
    const a = FastCatTestProtocol.https;
    const b = FastCatTestProtocol.h2;
    final choices = {a.group: a.node, b.group: b.node, 'GLOBAL': b.group};
    expect(scopedProfileSelections(a.profileId, choices), {a.group: a.node});
    expect(scopedProfileSelections(b.profileId, choices),
        {b.group: b.node, 'GLOBAL': b.group});
    expect(scopedProfileSelections('url-profile', choices), isEmpty);
    final config = <String, dynamic>{
      'currentProfileId': 'url-profile',
      'profiles': [
        {
          'id': a.profileId,
          'url': '',
          'selectedMap': {a.group: a.node}
        },
        {
          'id': b.profileId,
          'url': '',
          'selectedMap': {b.group: b.node}
        },
        {
          'id': 'url-profile',
          'url': 'https://subscription.test',
          'selectedMap': choices
        },
      ],
    };
    expect(repairLocalTestProfileScope(config), isTrue);
    expect(config['currentProfileId'], b.profileId);
    expect(config['profiles'][0]['selectedMap'], {a.group: a.node});
    expect(config['profiles'][2]['selectedMap'], isEmpty);
    expect(repairLocalTestProfileScope(config), isFalse);
  });
}
