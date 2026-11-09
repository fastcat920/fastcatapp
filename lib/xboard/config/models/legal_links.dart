/// Optional legal URLs. Malformed fields never invalidate the OSS document.
class LegalLinks {
  const LegalLinks({this.privacyPolicy, this.termsOfService});
  final Uri? privacyPolicy;
  final Uri? termsOfService;

  factory LegalLinks.fromJson(Object? value) {
    final map = value is Map ? value : const {};
    return LegalLinks(
      privacyPolicy: validUrl(map['privacy_policy_url']),
      termsOfService: validUrl(map['terms_of_service_url']),
    );
  }

  static Uri? validUrl(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    final text = value.trim();
    if (RegExp(r'\s').hasMatch(text)) return null;
    final uri = Uri.tryParse(text);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    return uri;
  }

  LegalLinks fallbackTo(LegalLinks fallback) => LegalLinks(
        privacyPolicy: privacyPolicy ?? fallback.privacyPolicy,
        termsOfService: termsOfService ?? fallback.termsOfService,
      );
}
