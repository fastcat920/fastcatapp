# FastCat Support Flutter SDK

Flutter visitor SDK with a ready-to-use chat UI, attachment upload, visitor metadata, AI streaming, history sync, human handoff, and WebSocket reconnect.

## Add the package

Use a local path while developing:

```yaml
dependencies:
  fastcat_support:
    path: ../fastcat-support/flutter
```

The SDK currently targets Flutter 3.19+ and Dart 3.3+. Dependencies (`http`, `web_socket_channel`, `file_picker`, `shared_preferences`) are declared in `pubspec.yaml`.

## Show the chat screen

```dart
final client = FastCatSupport(
  baseUrl: 'https://support.example.com',
  projectId: 'your-project-id',
  projectKey: 'your-public-widget-key',
  visitorId: 'your-stable-app-user-id',
);

await client.load(
  profile: FastCatProfile(
    nickname: '访客昵称',
    email: 'customer@example.com',
    systemInfo: {'app_version': '1.0.0', 'os': 'iOS'},
  ),
);

Navigator.push(context, MaterialPageRoute(
  builder: (_) => FastCatChatScreen(client: client, disposeClient: true),
));
```

`visitorId` should be stable for the signed-in account and generated/stored locally for anonymous visitors. Use the project’s public widget key in client apps; never embed staff credentials or an AI provider secret. User profile and system metadata appear in the support console.

## Optional mobile push notifications

For replies received while the app is in the background, integrate Firebase Messaging in the host Flutter app (Firebase project setup, native `google-services.json` / `GoogleService-Info.plist`, notification permission, and `firebase_messaging` are app-specific and intentionally not bundled as mandatory SDK dependencies). After Firebase returns an FCM registration token, register it with the client:

```dart
final messaging = FirebaseMessaging.instance;
await messaging.requestPermission();
final fcmToken = await messaging.getToken();
if (fcmToken != null) await client.registerPushToken(fcmToken);

FirebaseMessaging.instance.onTokenRefresh.listen((token) {
  client.registerPushToken(token);
});
```

The SDK's `registerPushToken` method accepts the Firebase Installation ID (FID) delivered by the host app's Firebase Messaging integration. When signing out or disabling push, call `registerPushToken(installationId, enabled: false)`. In the FastCat admin console, open **推送通知**, paste the Firebase service-account JSON, validate it, then save. The server encrypts this credential at rest. Notifications are sent for AI replies and human-agent replies; the realtime chat stream remains the primary in-app delivery path.

## Custom UI

Use `register`, `history`, `send`, `sendFile(Uint8List, filename)`, `handoff`, and `connect` from `FastCatSupport`. Listen to `messages` through `ChangeNotifier`, or to raw typed socket notifications via `events`. AI stream lifecycle events update the message list and automatically reconnect with bounded backoff; reconnect also refreshes history to fill gaps. The SDK caches the latest 200 messages per server/project/visitor on-device, shows that cache before network history loads, and refreshes it after live updates. Local cache is best-effort and uses platform preferences; applications with regulated or highly sensitive chat content should disable/replace local persistence in their integration.

## Example app

Run `cd example && flutter pub get && flutter run`. Set the service URL, project ID, and public project key. This example stores an anonymous visitor ID using `shared_preferences`.
