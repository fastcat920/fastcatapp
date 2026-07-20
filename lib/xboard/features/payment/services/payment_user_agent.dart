/// Desktop override retained for desktop payment WebViews.
const desktopPaymentUserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
    'AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/125.0.0.0 Safari/537.36';

/// Returns the payment WebView UA override for the current platform type.
///
/// A null override makes Android WebView and iOS WKWebView use their native
/// mobile UA, including the real OS and browser engine versions. Desktop
/// platforms retain the explicit desktop UA expected by payment gateways.
String? paymentGatewayUserAgentOverride({required bool isMobilePlatform}) {
  return isMobilePlatform ? null : desktopPaymentUserAgent;
}
