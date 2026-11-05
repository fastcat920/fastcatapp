import '../xboard/security/fastcat_subscription_decoder.dart';

/// Runtime-only keyring. Never persist or log this map, including in diagnostics.
/// Reuses the subscription key lifecycle without adding another disk key file.
Map<String, dynamic>? providerCacheConfiguration() {
  final keys = FastCatSubscriptionDecoder.configuredKeys;
  final current = FastCatSubscriptionDecoder.currentKeyId;
  if (current.isEmpty || keys[current]?.isNotEmpty != true) return null;
  return {'currentKeyId': current, 'keys': keys};
}
