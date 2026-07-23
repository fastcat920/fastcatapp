# Flutter Version Policy

This project treats CI as the supported Flutter baseline.

- Supported Flutter: `3.44.7` stable.
- Local development should use the version in `.flutter-version`.
- GitHub Actions reads the same version through `FLUTTER_VERSION`.
- `Dockerfile.linux` should stay aligned with `.flutter-version`.

When upgrading Flutter:

1. Update `.flutter-version`.
2. Update `FLUTTER_VERSION` in `.github/workflows/build-client.yml`.
3. Update `ENV FLUTTER_VERSION` in `Dockerfile.linux`.
4. Run `flutter pub get`, targeted `dart analyze`, and at least one platform build.
5. Check compatibility shims such as `lib/common/rounded_superellipse_border.dart`.
