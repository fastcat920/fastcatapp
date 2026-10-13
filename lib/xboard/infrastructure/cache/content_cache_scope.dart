import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/xboard/core/content_locale.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';

/// Opaque account + language identity. Never persist authentication tokens in
/// cache keys, and never reuse authenticated content for an anonymous session.
abstract final class ContentCacheScope {
  static String? accountForToken(String? token) {
    if (token == null || token.isEmpty) return null;
    return sha256.convert(utf8.encode(token)).toString().substring(0, 24);
  }

  static Future<String?> account() async {
    final sdk = XBoardSDK.instance;
    if (!sdk.isInitialized) return null;
    return accountForToken(await sdk.getToken());
  }

  static Future<String?> current() async {
    final scope = await account();
    if (scope == null) return null;
    final locale = xboardContentLocale(globalState.config.appSetting.locale);
    return '$scope:$locale';
  }
}
