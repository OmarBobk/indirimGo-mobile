# İndirimGo Mobile

Customer-only Android application for İndirimGo. Milestone **M2.2** adds the
authenticated Commerce Shell (catalog home, package browse/search, and package
detail). Purchasing, wallet, and orders remain out of scope.

## Requirements

- Flutter **3.44.8** / Dart **3.12.2** (pinned; CI enforces the same versions)
- Android Studio or an Android SDK and emulator
- The Laravel repository running locally with its `staging` configuration and
  migrations

The Android namespace and application ID are both `tr.indirimgo.app`. The Dart
package name is `indirimgo_mobile`.

## Run locally

Start Laravel so the emulator can reach it:

```powershell
php artisan serve --host=0.0.0.0 --port=8000
```

Set Laravel `APP_URL` correctly so package image URLs resolve. Android emulators
reach the host machine at `10.0.2.2`:

```powershell
flutter pub get --enforce-lockfile
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

For a physical Android device, prefer `adb reverse` with loopback rather than
broadening debug cleartext:

```powershell
adb reverse tcp:8000 tcp:8000
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```

`API_BASE_URL` is required, validated at startup, and normalized to one
`/api/v1/` suffix. Debug builds may use HTTP only for `10.0.2.2`, `127.0.0.1`,
or `localhost`. Profile and release builds require HTTPS. Do not pass
credentials, tokens, 2FA values, or other secrets through `--dart-define`.
There is deliberately no `.env` file and no staging URL yet.

Android cleartext is denied by default. The debug network-security config
allows only those local hosts. Main/release keep cleartext disabled. App backup
is disabled so secure session storage cannot restore into an incompatible
Keystore state.

## Authentication behavior

- Username/password authentication against Laravel
- Fortify authenticator and recovery-code 2FA
- Sanctum bearer token stored atomically with `flutter_secure_storage`
- 30-day server-controlled token expiry and no refresh-token flow
- Startup restoration through `GET /me`
- Authoritative 401/403 session rejection clears only the matching session
- Connectivity, timeout, server, and storage failures preserve the token for
  retry where appropriate
- 2FA challenges and codes remain only in memory and are never logged
- Laravel remains authoritative for challenge expiry and attempt limits

## Commerce shell (M2.2)

Authenticated routes:

- `/app` — catalog home (frequently ordered, featured, categories)
- `/app/packages` — browse/search with `category_id` and `q`
- `/app/packages/:id` — package detail with fixed/custom product options
- `/app/account` — account details and logout

Consumed endpoints only:

- `GET /api/v1/catalog/home`
- `GET /api/v1/packages`
- `GET /api/v1/packages/{id}`

Prices are displayed from Laravel `display.formatted` only. Flutter never
parses authoritative USD amounts into `double`, never converts currency, and
never shows purchase CTAs. `meta.prices_visible=false` is distinct from an
individual unavailable price.

The authoritative contract is Laravel
`docs/api/v1/openapi.yaml` on `origin/staging`. The Flutter client must not
invent API fields, calculate trusted prices, or mutate financial state without
Laravel.

## Localization and accessibility

Arabic and English use Flutter ARB localization. Arabic is the fallback when no
supported preferred locale exists; a preference list such as Turkish then
English selects English. Active locale is sent in `Accept-Language`. The UI
supports RTL/LTR, light/dark themes with contrast-checked accents, semantic
labels, keyboard traversal, large text, and minimum touch targets. Catalog
names/descriptions remain exactly as returned by Laravel.

## Verify

```powershell
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter build apk --debug --dart-define=API_BASE_URL=https://example.invalid/api/v1
apkanalyzer manifest print build/app/outputs/flutter-apk/app-debug.apk |
  dart run tool/verify_android_security.dart --merged-manifest-stdin
```

Tests use fake repositories, fake secure storage, and an in-memory Dio adapter;
they do not need a live Laravel server.

## Release blocker

Release builds still use the debug signing configuration so local
`flutter run --release` works. Production signing must be configured before any
distribution or publishing workflow. No Play upload or deploy step exists in CI.

## M2.2 exclusions

No cart, buy now, checkout, wallet, top-ups, orders, fulfillments, refunds,
activity, notifications, registration, password reset, deep links, analytics,
push, biometrics, recommendations, client-side pricing, bottom navigation,
Firebase, or deployment is part of this milestone.

See [`docs/architecture/m2.2-commerce-shell.md`](docs/architecture/m2.2-commerce-shell.md)
for architecture details and
[`docs/architecture/m1.2-auth-foundation.md`](docs/architecture/m1.2-auth-foundation.md)
for authentication foundations.
