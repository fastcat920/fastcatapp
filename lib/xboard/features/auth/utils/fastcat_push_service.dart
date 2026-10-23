import 'dart:async';
import 'dart:io';

import 'package:fastcat_support/fastcat_support.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Optional FCM integration for FastCat Support. Firebase configuration is
/// supplied at build time so unrelated app targets do not need Firebase files.
class FastCatPushService {
  FastCatPushService._();

  static const _apiKey = String.fromEnvironment('FASTCAT_FIREBASE_API_KEY');
  static const _appId = String.fromEnvironment('FASTCAT_FIREBASE_APP_ID');
  static const _projectId =
      String.fromEnvironment('FASTCAT_FIREBASE_PROJECT_ID');
  static const _senderId =
      String.fromEnvironment('FASTCAT_FIREBASE_MESSAGING_SENDER_ID');
  static bool get _configured =>
      _apiKey.isNotEmpty &&
      _appId.isNotEmpty &&
      _projectId.isNotEmpty &&
      _senderId.isNotEmpty;

  static bool get isConfigured => _configured;
  static bool get _isMobile =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static FirebaseOptions get _options => const FirebaseOptions(
        apiKey: _apiKey,
        appId: _appId,
        messagingSenderId: _senderId,
        projectId: _projectId,
      );

  static Future<void> initialize() async {
    if (!_configured || !_isMobile) return;
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: _options);
    }
    FirebaseMessaging.onBackgroundMessage(fastCatMessagingBackgroundHandler);
  }

  /// Requests permission only when the customer opens support, then registers
  /// the current token and returns a subscription for token rotations.
  static Future<StreamSubscription<String>?> register(
    FastCatSupport client,
  ) async {
    if (!_configured || !_isMobile || Firebase.apps.isEmpty) return null;
    try {
      final messaging = FirebaseMessaging.instance;
      final permission = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (permission.authorizationStatus == AuthorizationStatus.denied ||
          permission.authorizationStatus == AuthorizationStatus.notDetermined) {
        return null;
      }

      final registration = messaging.onRegistered.listen((token) {
        unawaited(_registerToken(client, token));
      });
      await messaging.register();
      return registration;
    } catch (error) {
      debugPrint('[FastCat Support] Push registration unavailable: $error');
      return null;
    }
  }

  static Future<void> _registerToken(
    FastCatSupport client,
    String token,
  ) async {
    try {
      await client.registerPushToken(
        token,
        platform: Platform.isIOS ? 'ios' : 'android',
      );
    } catch (error) {
      // Push is an optional delivery path; it must not interrupt the chat.
      debugPrint('[FastCat Support] Push token sync failed: $error');
    }
  }
}

@pragma('vm:entry-point')
Future<void> fastCatMessagingBackgroundHandler(RemoteMessage message) async {
  if (FastCatPushService.isConfigured && Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: String.fromEnvironment('FASTCAT_FIREBASE_API_KEY'),
        appId: String.fromEnvironment('FASTCAT_FIREBASE_APP_ID'),
        messagingSenderId:
            String.fromEnvironment('FASTCAT_FIREBASE_MESSAGING_SENDER_ID'),
        projectId: String.fromEnvironment('FASTCAT_FIREBASE_PROJECT_ID'),
      ),
    );
  }
}
