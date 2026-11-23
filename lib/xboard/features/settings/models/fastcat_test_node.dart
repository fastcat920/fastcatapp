import 'dart:convert';

import 'package:fl_clash/security/local_auto_profile.dart';
import 'package:fl_clash/security/local_test_profile_scope.dart';
export 'package:fl_clash/security/local_test_profile_scope.dart';

class FastCatTestNode {
  const FastCatTestNode(
      {required this.server,
      required this.port,
      required this.token,
      this.protocol = FastCatTestProtocol.https});
  final FastCatTestProtocol protocol;
  final String server;
  final int port;
  final String token;

  static bool validServer(String value) => validLocalServer(value);
  static bool validToken(String value) => validLocalToken(value);

  String configuration() {
    if (!validServer(server) ||
        port < 1 ||
        port > 65535 ||
        !validToken(token)) {
      throw const FormatException('Invalid test node');
    }
    // JSON is valid YAML and safely quotes user-supplied values.
    return jsonEncode({
      'mode': 'rule',
      'proxies': [
        {
          'name': protocol.node,
          'type': protocol.type,
          'server': server,
          'port': port,
          'sni': server,
          'token': token
        }
      ],
      'proxy-groups': [
        {
          'name': protocol.group,
          'type': 'select',
          'proxies': [protocol.node, 'DIRECT']
        }
      ],
      'rules': ['MATCH,${protocol.group}'],
    });
  }
}
