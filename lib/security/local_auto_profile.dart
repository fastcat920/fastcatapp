import 'dart:convert';

import 'local_test_profile_scope.dart';

/// A local profile stores only this reference. Its two inputs remain in their
/// own encrypted records and are resolved each time the core reads the profile.
const localAutoProfileMarker = '{"fastcat-local-auto":1}';

bool validLocalServer(String value) {
  if (value.isEmpty ||
      value.length > 253 ||
      value.contains(RegExp(r'[\s/:?#@]'))) {
    return false;
  }
  return value.split('.').every((part) =>
      part.isNotEmpty &&
      part.length <= 63 &&
      RegExp(r'^[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?$').hasMatch(part));
}

bool validLocalToken(String value) =>
    value.length >= 24 &&
    value.length <= 512 &&
    RegExp(r'^[\x21-\x7e]+$').hasMatch(value);

Future<String> resolveLocalAutoProfile(
    Future<String> Function(String id) readText) async {
  Future<Map> endpoint(FastCatTestProtocol protocol) async {
    final raw = await readText(protocol.profileId);
    Object? json;
    try {
      json = jsonDecode(raw);
    } on FormatException {
      // The decoder can attach plaintext input to its exception.
      throw const FormatException('Invalid saved FastCat endpoint');
    }
    final proxies = json is Map ? json['proxies'] : null;
    if (proxies is List && proxies.length == 1 && proxies.single is Map) {
      final node = proxies.single as Map;
      final server = node['server'];
      final port = node['port'];
      final token = node['token'];
      if (node['name'] == protocol.node &&
          node['type'] == protocol.type &&
          server is String &&
          validLocalServer(server) &&
          node['sni'] == server &&
          port is int &&
          port > 0 &&
          port <= 65535 &&
          token is String &&
          validLocalToken(token)) {
        return node;
      }
    }
    throw const FormatException('Invalid saved FastCat endpoint');
  }

  final primary = await endpoint(FastCatTestProtocol.h2);
  final backup = await endpoint(FastCatTestProtocol.https);
  return jsonEncode({
    'mode': 'rule',
    'proxies': [
      {
        'name': fastCatAutoNode,
        'type': 'fastcat-auto',
        'server': primary['server'],
        'port': primary['port'],
        'sni': primary['sni'],
        'token': primary['token'],
        'fallback-server': backup['server'],
        'fallback-port': backup['port'],
        'fallback-sni': backup['sni'],
        'fallback-token': backup['token'],
      }
    ],
    'proxy-groups': [
      {
        'name': fastCatAutoGroup,
        'type': 'select',
        'proxies': [fastCatAutoNode],
      }
    ],
    'rules': ['MATCH,$fastCatAutoGroup'],
  });
}
