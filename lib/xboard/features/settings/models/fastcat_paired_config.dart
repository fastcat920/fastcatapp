import 'dart:convert';

import 'package:fl_clash/models/profile.dart';
import 'fastcat_test_node.dart';

/// Adds the other saved test node to an iOS test runtime for named probes.
/// Stored profiles and the active selector continue to contain only their own node.
Future<Map<String, dynamic>> pairedTestRuntimeConfig(
  Map<String, dynamic> config, {
  required String activeId,
  required List<Profile> profiles,
  required Future<String> Function(String id) readText,
}) async {
  final active = FastCatTestProtocol.forProfile(activeId);
  if (active == null || profiles.getProfile(activeId)?.url != '') return config;
  final peer = active == FastCatTestProtocol.https
      ? FastCatTestProtocol.h2
      : FastCatTestProtocol.https;
  if (profiles.getProfile(peer.profileId)?.url != '') return config;

  // Scope this operation to the fixed graph created by the test-node editor.
  // A script may have changed the graph; keep its routing semantics intact.
  final nodes = config['proxies'];
  final groups = config['proxy-groups'];
  if (nodes is! List ||
      nodes.length != 1 ||
      groups is! List ||
      groups.length != 1) {
    return config;
  }
  final primary = nodes.single;
  final group = groups.single;
  if (primary is! Map ||
      primary['name'] != active.node ||
      primary['type'] != active.type ||
      group is! Map ||
      group['name'] != active.group ||
      group['type'] != 'select' ||
      group.keys
          .any((key) => !const {'name', 'type', 'proxies'}.contains(key))) {
    return config;
  }
  final members = group['proxies'];
  if (members is! List ||
      members.length != 2 ||
      members.first != active.node ||
      members.last != 'DIRECT') {
    return config;
  }

  // A removed, unreadable or invalid optional peer should never prevent the
  // selected node from connecting. Never put decoded credentials in logs.
  try {
    final saved = jsonDecode(await readText(peer.profileId));
    final proxies = saved is Map ? saved['proxies'] : null;
    if (proxies is! List || proxies.length != 1 || proxies.single is! Map) {
      return config;
    }
    final node = proxies.single as Map;
    final server = node['server'];
    final port = node['port'];
    final token = node['token'];
    if (node['type'] != peer.type ||
        node['name'] != peer.node ||
        server is! String ||
        !FastCatTestNode.validServer(server) ||
        node['sni'] != server ||
        port is! int ||
        port < 1 ||
        port > 65535 ||
        token is! String ||
        !FastCatTestNode.validToken(token)) {
      return config;
    }
    return {
      ...config,
      'proxies': [
        ...nodes,
        {
          'name': peer.node,
          'type': peer.type,
          'server': server,
          'sni': server,
          'port': port,
          'token': token,
        }
      ],
      // Without an explicit GLOBAL, Mihomo includes all proxy names in it.
      // Mirror the original one-node runtime's implicit GLOBAL membership.
      'proxy-groups': [
        ...groups,
        {
          'name': 'GLOBAL',
          'type': 'select',
          'proxies': ['DIRECT', 'REJECT', active.node, active.group],
        }
      ],
    };
  } catch (_) {
    return config;
  }
}
