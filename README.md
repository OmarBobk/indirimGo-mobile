# İndirimGo Mobile

Customer-only Android application for İndirimGo. Milestone M1.2 establishes the
Flutter foundation and Laravel-backed authentication; shopping and financial
features are intentionally not implemented yet.

## Requirements

- Current stable Flutter (M1.2 was developed with Flutter 3.44.8 / Dart 3.12.2)
- Android Studio or an Android SDK and emulator
- The Laravel repository running locally with its `staging` configuration and
  migrations

The Android namespace and application ID are both `tr.indirimgo.app`. The Dart
package name is `indirimgo_mobile`.

## Run locally

Start Laravel on port 8000. Android emulators reach the host machine at
`10.0.2.2`, so run the Flutter app with:

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

`API_BASE_URL` is required, validated at startup, and normalized to one
`/api/v1/` suffix. Use HTTPS outside local debug development. Do not pass
credentials, tokens, 2FA values, or other secrets through `--dart-define`.
There is deliberately no `.env` file and no staging URL yet.

Cleartext HTTP is permitted only by the Android debug manifest for emulator
development. The main/release manifest explicitly disables cleartext traffic.

## Authentication behavior

- Username/password authentication against Laravel
- Fortify authenticator and recovery-code 2FA
- Sanctum bearer token stored with `flutter_secure_storage`
- 30-day server-controlled token expiry and no refresh-token flow
- Startup restoration through `GET /me`
- Authoritative 401/403 session rejection clears local credentials
- Connectivity and server failures preserve the token and show retry UI
- 2FA challenges and codes remain only in memory and are never logged

The authoritative contract is Laravel
`docs/api/v1/openapi.yaml` on `origin/staging`. The Flutter client must not
invent API fields, calculate trusted prices, or mutate financial state without
Laravel.

## Localization and accessibility

Arabic and English use Flutter ARB localization. Arabic is the fallback;
supported device locales are respected. Active locale is sent in
`Accept-Language`. The UI supports RTL, light/dark themes, semantic labels,
keyboard traversal, large text, minimum touch targets, and non-animated status
feedback.

## Verify

```powershell
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

Tests use fake repositories, fake secure storage, and an in-memory Dio adapter;
they do not need a live Laravel server.

## M1.2 exclusions

No registration, password reset, social login, catalog, categories, search,
cart, checkout, wallet, top-ups, orders, fulfillments, refunds, activity,
notifications, deep links, analytics, push, biometrics, or deployment is part
of this milestone.

See [`docs/architecture/m1.2-auth-foundation.md`](docs/architecture/m1.2-auth-foundation.md)
for architecture, dependency, and security decisions.