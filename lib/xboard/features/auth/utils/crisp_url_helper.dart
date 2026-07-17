const crispOfficialBaseUrl = 'https://go.crisp.chat';
const crispProxyFallbackDelay = Duration(seconds: 2);

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
