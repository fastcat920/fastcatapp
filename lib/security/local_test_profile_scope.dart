const fastCatTestProfileId = 'fastcat-https-test-v1';
const fastCatTestGroup = 'FastCat 测试';
const fastCatTestNodeName = 'FastCat HTTPS 测试';

const fastCatAutoProfileId = 'fastcat-local-auto-v1';
const fastCatAutoNode = 'FastCat 自动连接（本机）';
const fastCatAutoGroup = 'FastCat 本地线路（本机）';

const fastCatDirectProfileId = 'fastcat-local-direct-v2';
const fastCatDirectNodeName = 'FastCat v2 Direct';
const fastCatDirectGroup = 'FastCat v2 直连（本机）';

bool isLocalFastCatProfile(String? id) =>
    id == fastCatDirectProfileId ||
    id == fastCatAutoProfileId ||
    FastCatTestProtocol.forProfile(id) != null;

enum FastCatTestProtocol {
  https(fastCatTestProfileId, fastCatTestGroup, fastCatTestNodeName,
      'fastcat-https', 8443),
  h2('fastcat-h2-test-v1', 'FastCat H2 测试', 'FastCat HTTP/2 测试', 'fastcat-h2',
      18444);

  const FastCatTestProtocol(
      this.profileId, this.group, this.node, this.type, this.port);

  final String profileId;
  final String group;
  final String node;
  final String type;
  final int port;

  static FastCatTestProtocol? forProfile(String? id) {
    for (final protocol in values) {
      if (protocol.profileId == id) return protocol;
    }
    return null;
  }
}

/// Local test choices must never be replayed against a subscription graph.
/// Repair the selections persisted by older builds without weakening native
/// validation of unrelated, explicitly selected nodes.
Map<String, String> scopedProfileSelections(
  String? profileId,
  Map<String, String> selections,
) {
  return Map.fromEntries(selections.entries.where((entry) =>
      (profileId == fastCatDirectProfileId ||
          (entry.key != fastCatDirectGroup &&
              entry.value != fastCatDirectGroup &&
              entry.value != fastCatDirectNodeName)) &&
      (profileId == fastCatAutoProfileId ||
          (entry.key != fastCatAutoGroup &&
              entry.value != fastCatAutoGroup &&
              entry.value != fastCatAutoNode)) &&
      !FastCatTestProtocol.values.any((p) =>
          p.profileId != profileId &&
          (entry.key == p.group ||
              entry.value == p.group ||
              entry.value == p.node))));
}

/// Recover the old build's persisted cross-profile inheritance on launch.
/// Restore the local test only when both of its reserved selections leaked
/// into the active URL profile and the actual local profile still exists.
bool repairLocalTestProfileScope(Map<String, dynamic> config) {
  final profiles = config['profiles'];
  if (profiles is! List) return false;
  final ids = profiles.whereType<Map>().map((p) => p['id']).toSet();
  var changed = false;
  for (final profile in profiles.whereType<Map>()) {
    final profileId = profile['id'];
    final raw = profile['selectedMap'];
    if (profileId is! String || raw is! Map) continue;
    if (!isLocalFastCatProfile(profileId) &&
        profileId == config['currentProfileId'] &&
        profile['url'] is String &&
        (profile['url'] as String).isNotEmpty) {
      for (final p in FastCatTestProtocol.values) {
        if (raw['GLOBAL'] == p.group &&
            raw[p.group] == p.node &&
            ids.contains(p.profileId)) {
          config['currentProfileId'] = p.profileId;
          changed = true;
          break;
        }
      }
    }
    final clean =
        scopedProfileSelections(profileId, Map<String, String>.from(raw));
    if (clean.length != raw.length) {
      profile['selectedMap'] = clean;
      changed = true;
    }
  }
  return changed;
}
