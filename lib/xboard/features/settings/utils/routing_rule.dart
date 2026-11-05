import 'dart:io';

/// Normalize the user's host before it is passed to Mihomo's CIDR parser.
String buildRoutingRule(String input, String target) {
  final value = input.trim().toLowerCase();
  final parts = value.split('/');
  if (target.trim().isEmpty ||
      parts.length > 2 ||
      target.contains(RegExp(r'[,\r\n]'))) {
    throw const FormatException();
  }
  final ip = InternetAddress.tryParse(parts.first);
  if (ip != null) {
    final ipv6 = ip.type == InternetAddressType.IPv6;
    final maximum = ipv6 ? 128 : 32;
    final prefix = parts.length == 2 ? int.tryParse(parts.last) : maximum;
    if (prefix == null || prefix < 0 || prefix > maximum) {
      throw const FormatException();
    }
    final bytes = ip.rawAddress;
    for (var index = 0; index < bytes.length; index++) {
      final bits = (prefix - index * 8).clamp(0, 8);
      bytes[index] &= bits == 0 ? 0 : (0xff << (8 - bits)) & 0xff;
    }
    final network = InternetAddress.fromRawAddress(bytes).address;
    return '${ipv6 ? 'IP-CIDR6' : 'IP-CIDR'},$network/$prefix,$target,no-resolve';
  }
  final domain = value.startsWith('+.') ? value.substring(2) : value;
  if (parts.length != 1 ||
      domain.length > 253 ||
      !domain.contains('.') ||
      !domain.split('.').every((label) =>
          label.isNotEmpty &&
          label.length <= 63 &&
          RegExp(r'^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$').hasMatch(label))) {
    throw const FormatException();
  }
  return 'DOMAIN-SUFFIX,$domain,$target';
}

bool sameRoutingDestination(String first, String second) {
  final a = first.split(',');
  final b = second.split(',');
  return a.length >= 2 && b.length >= 2 && a[0] == b[0] && a[1] == b[1];
}
