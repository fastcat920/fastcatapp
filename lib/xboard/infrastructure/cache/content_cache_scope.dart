import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/xboard/core/content_locale.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';

/// Opaque account + language identity. Never persist authentication tokens in
/// cache keys, and never reuse authenticated content for an anonymous session.
abstract final class ContentCacheScope {
  static Future<String?> current() async {
    final sdk = XBoardSDK.instance;
    if (!sdk.isInitialized) return null;
    final token = await sdk.getToken();
    if (token == null || token.isEmpty) return null;
    final locale = xboardContentLocale(globalState.config.appSetting.locale);
    return '${sha256.convert(utf8.encode(token)).toString().substring(0, 24)}:$locale';
  }
}
