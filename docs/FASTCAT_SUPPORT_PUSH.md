# FastCat Support mobile push setup

FastCatAPP uses Firebase Cloud Messaging only on Android and iOS. The integration is optional: builds without Firebase options continue to use in-app chat and do not request notification permission.

## Firebase project setup

1. Create or select the Firebase project that will send FastCat Support notifications.
2. Register the Android app with application ID `com.fastcat.app` and the iOS app with bundle ID `com.fastcat.app`.
3. Enable Firebase Cloud Messaging. For iOS, upload an APNs authentication key in Firebase and enable the Push Notifications capability for the App ID and provisioning profile.
4. In Firebase Console, create a service account for the same project. In FastCat Support, open **推送通知**, validate and save that service-account JSON. The server encrypts it at rest; it is not an app build parameter.
5. Pass the Firebase client options as Flutter compile-time defines when building mobile releases:

```sh
flutter build apk --flavor mobile \
  --dart-define=FASTCAT_FIREBASE_API_KEY=... \
  --dart-define=FASTCAT_FIREBASE_APP_ID=... \
  --dart-define=FASTCAT_FIREBASE_PROJECT_ID=... \
  --dart-define=FASTCAT_FIREBASE_MESSAGING_SENDER_ID=...
```

Use the corresponding Firebase values from the Android app configuration. For an iOS build, use the iOS app ID and the same project ID, sender ID, and API key. These are Firebase client identifiers, not service-account credentials. Do not put the service-account private key in the app or source repository.

The release packaging scripts accept the same four values from the environment (`FASTCAT_FIREBASE_API_KEY`, `FASTCAT_FIREBASE_APP_ID`, `FASTCAT_FIREBASE_PROJECT_ID`, `FASTCAT_FIREBASE_MESSAGING_SENDER_ID`) and forward them as Dart defines. Keep them in the release environment or CI secret store; builds with any value missing deliberately omit push registration.

The app initializes Firebase only on Android/iOS and only when all four values are present. When a user opens FastCat Support, the app requests notification permission and registers the current FCM token against that visitor. Token rotations are synchronized while the support screen is open; opening the screen again always registers the current token.

## Platform notes

- Android already declares `POST_NOTIFICATIONS`; Android 13+ prompts when the user opens support.
- iOS requires a valid APNs key in Firebase and Push Notifications enabled for the signed app. Without APNs credentials, FCM token registration may fail even when Firebase initializes.
- Debug, desktop, and non-Firebase builds remain usable without push.
- Push delivery is best-effort. The live chat stream remains the primary delivery path.
