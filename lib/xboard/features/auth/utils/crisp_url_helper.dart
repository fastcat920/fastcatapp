import 'dart:io';

const crispOfficialBaseUrl = 'https://go.crisp.chat';
const crispProxyFallbackDelay = Duration(seconds: 5);

/// Support must never be routed through the user's selected proxy node.
/// These entries are consumed by both Mihomo rules and OS proxy bypass lists.
List<String> customerServiceDirectBypassDomains(String? proxyUrl) {
  final domains = <String>{'crisp.chat', '*.crisp.chat'};
  final proxy = normalizeCrispProxyUrl(proxyUrl);
  final host = proxy.isEmpty ? '' : Uri.parse(proxy).host;
  if (host.isNotEmpty) domains.add(host);
  return domains.toList(growable: false);
}

List<String> customerServiceDirectRules(String? proxyUrl) {
  final rules = <String>['DOMAIN-SUFFIX,crisp.chat,DIRECT'];
  final proxy = normalizeCrispProxyUrl(proxyUrl);
  final host = proxy.isEmpty ? '' : Uri.parse(proxy).host;
  if (host.isNotEmpty &&
      !host.endsWith('.crisp.chat') &&
      host != 'crisp.chat') {
    final address = InternetAddress.tryParse(host);
    if (address == null) {
      rules.add('DOMAIN,$host,DIRECT');
    } else if (address.type == InternetAddressType.IPv4) {
      rules.add('IP-CIDR,$host/32,DIRECT');
    } else {
      rules.add('IP-CIDR6,$host/128,DIRECT');
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

String normalizeCrispProxyUrl(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) return '';
  final withScheme =
      trimmed.startsWith(RegExp(r'https?://')) ? trimmed : 'https://$trimmed';
  final uri = Uri.tryParse(withScheme);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return '';
  return uri.toString().replaceAll(RegExp(r'/+$'), '');
}

Uri crispEmbedUri({
  required String websiteId,
  String? proxyUrl,
}) {
  final proxy = normalizeCrispProxyUrl(proxyUrl);
  final base = Uri.parse(proxy.isNotEmpty ? proxy : crispOfficialBaseUrl);
  return base.replace(
    path: _embedPath(base.path),
    queryParameters: {'website_id': websiteId},
  );
}

Uri officialCrispEmbedUri(String websiteId) {
  return crispEmbedUri(websiteId: websiteId);
}

bool isCrispProxyConfigured(String? proxyUrl) {
  return normalizeCrispProxyUrl(proxyUrl).isNotEmpty;
}

String _embedPath(String basePath) {
  final trimmed = basePath.replaceAll(RegExp(r'/+$'), '');
  if (trimmed.endsWith('/chat/embed')) {
    return '$trimmed/';
  }
  if (trimmed.isEmpty) return '/chat/embed/';
  return '$trimmed/chat/embed/';
}
