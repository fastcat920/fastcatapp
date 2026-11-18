import 'dart:io';

/// Support must never be routed through the user's selected proxy node.
/// These entries are consumed by both Mihomo rules and OS proxy bypass lists.
List<String> customerServiceDirectBypassDomains(String? proxyUrl) {
  final domains = <String>{};
  final proxy = _supportUrl(proxyUrl);
  final host = proxy.isEmpty ? '' : Uri.parse(proxy).host;
  if (host.isNotEmpty) domains.add(host);
  return domains.toList(growable: false);
}

List<String> customerServiceDirectRules(String? proxyUrl) {
  final rules = <String>[];
  final proxy = _supportUrl(proxyUrl);
  final host = proxy.isEmpty ? '' : Uri.parse(proxy).host;
  if (host.isNotEmpty) {
    final address = InternetAddress.tryParse(host);
    if (address == null) {
      rules.add('DOMAIN,$host,DIRECT');
    } else if (address.type == InternetAddressType.IPv4) {
      rules.add('IP-CIDR,$host/32,DIRECT,no-resolve');
    } else {
      rules.add('IP-CIDR6,$host/128,DIRECT,no-resolve');
    }
  }
  return rules;
}

List<String> mergeCustomerServiceBypassDomains(
  Iterable<String> configured,
  String? proxyUrl,
) {
  final result = <String>[];
  for (final domain in [
    ...configured,
    ...customerServiceDirectBypassDomains(proxyUrl)
  ]) {
    if (!result.contains(domain)) result.add(domain);
  }
  return result;
}

String _supportUrl(String? value) {
  final uri = Uri.tryParse(value?.trim() ?? '');
  if (uri == null ||
      !['https', 'http'].contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return '';
  }
  return uri.toString();
}
