import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/security/local_auto_profile.dart';
import 'package:fl_clash/security/local_test_profile_scope.dart';

/// A local node descriptor, not a subscription or an arbitrary core config.
class FastCatDirectNode {
  const FastCatDirectNode(
      this.server, this.port, this.token, this.h3Port, this.h3Token,
      {this.caPem, this.entryDoH, this.entryDoHIP});

  final String server, token, h3Token;
  final int port, h3Port;
  final String? caPem, entryDoH, entryDoHIP;
  static const maxBytes = 32 * 1024;

  factory FastCatDirectNode.parse(String text) {
    if (text.length > maxBytes) throw const FormatException('File too large');
    Object? raw;
    try {
      raw = jsonDecode(text);
    } on FormatException {
      throw const FormatException('Invalid node JSON');
    }
    if (raw is! Map ||
        raw['type'] != 'fastcat-auto' ||
        raw['udp'] != true ||
        raw.keys.any((k) => !const {
              'type',
              'name',
              'udp',
              'server',
              'port',
              'token',
              'h3-port',
              'h3-token',
              'ca-pem',
              'entry-doh',
              'entry-doh-ip',
            }.contains(k))) {
      throw const FormatException('Unsupported direct node');
    }
    final server = raw['server'], port = raw['port'], h3Port = raw['h3-port'];
    final token = raw['token'], h3Token = raw['h3-token'], ca = raw['ca-pem'];
    final doh = raw['entry-doh'], bootstrap = raw['entry-doh-ip'];
    if (doh != null || bootstrap != null) {
      final uri = doh is String ? Uri.tryParse(doh) : null;
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          uri.hasQuery ||
          uri.hasFragment ||
          bootstrap is! String ||
          bootstrap.contains('%') ||
          InternetAddress.tryParse(bootstrap) == null) {
        throw const FormatException('Invalid entry DoH settings');
      }
    }
    bool validPort(Object? n) => n is int && n > 0 && n <= 65535;
    if (server is! String ||
        !validLocalServer(server) ||
        !validPort(port) ||
        !validPort(h3Port) ||
        token is! String ||
        !validLocalToken(token) ||
        h3Token is! String ||
        !validLocalToken(h3Token) ||
        (ca != null &&
            (ca is! String ||
                !RegExp(
                  r'^-----BEGIN CERTIFICATE-----[\r\n]+[A-Za-z0-9+/=\r\n]+-----END CERTIFICATE-----\s*$',
                ).hasMatch(ca)))) {
      throw const FormatException('Invalid direct node settings');
    }
    return FastCatDirectNode(server, port as int, token, h3Port as int, h3Token,
        caPem: ca as String?,
        entryDoH: doh as String?,
        entryDoHIP: bootstrap as String?);
  }

  String configuration({String? privateCAPath}) => jsonEncode({
        'mode': 'rule',
        'proxies': [
          {
            'name': fastCatDirectNodeName,
            'type': entryDoH == null ? 'fastcat-auto' : 'fastcat-auto-ech',
            'server': server,
            'sni': server,
            'port': port,
            'token': token,
            'h3-port': h3Port,
            'h3-token': h3Token,
            'udp': true,
            if (entryDoH != null) 'entry-doh': entryDoH,
            if (entryDoHIP != null) 'entry-doh-ip': entryDoHIP,
            if (privateCAPath != null) 'ca-file': privateCAPath,
          }
        ],
        'proxy-groups': [
          {
            'name': fastCatDirectGroup,
            'type': 'select',
            'proxies': [fastCatDirectNodeName],
          }
        ],
        'rules': ['MATCH,$fastCatDirectGroup'],
      });
}
