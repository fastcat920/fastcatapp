/// US storefront checkout leaves the app for the external browser. Never put
/// the original URL in errors: checkout links can contain payment credentials.
Uri appleCheckoutUri(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    throw const FormatException(
        'iOS external payments require a valid HTTPS checkout URL.');
  }
  return uri;
}
